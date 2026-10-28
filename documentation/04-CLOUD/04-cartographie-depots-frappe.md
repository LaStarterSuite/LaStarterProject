# Cartographie des dépôts Frappe : où est l'information dont LaStarter a besoin

**Question posée par Bastien (2026-10-28) :** parmi les 236 dépôts de l'org
GitHub `frappe`, n'existe-t-il pas déjà, quelque part, l'information dont
l'agent a besoin au lieu de tout réinventer ?

**Réponse courte : OUI, l'information existe et est codée, mais elle est
répartie entre plusieurs dépôts et aucun n'est un « runbook unique ».** La
fouille systématique (5 agents en parallèle, 253 lectures de code, périmètres
: press, cluster control plane v2, pilot/bench, frappe_docker/helm/framework,
carte des 236) a produit la carte ci-dessous. Résultat brut complet :
`../.research/frappe-repos-mining-2026-10-28.json`.

## Le constat structurant : le SSO de Frappe Cloud n'est PAS de l'OIDC

Le « connecté partout » constaté sur Frappe Cloud est une **injection de
session par l'opérateur** : le dashboard press poste l'identifiant/mot de
passe (Administrator stocké chiffré, ou `bench console` +
`LoginManager.login_as`) sur le site et récupère le cookie `sid`
(`press/press/doctype/site/site.py:get_login_sid`, `agent/agent/site.py`).
Aucun Social Login Key ni OAuth Client n'est préconfiguré sur les sites gérés.

**Conséquence pour LaStarter : notre doctrine « Frappe = IdP OIDC universel »
est précisément la pièce que Frappe Cloud n'a jamais construite.** Elle n'est
pas à imiter d'eux : elle est à écrire par nous, et le framework fournit tout
le nécessaire (voir §4). Le minting de session reste un raccourci opérateur
à connaître pour le support, pas un mécanisme produit.

## 1. Épinglage et builds : le modèle press

| Besoin | Source | Verdict |
|---|---|---|
| Unité d'épinglage | `press` : AppSource (repo+branche) → **AppRelease (commit exact)**, poll GitHub ou webhook ; le pin est un hash, jamais une branche | concept réimplémenté tel quel dans le catalogue v2 |
| Snapshot de déploiement | `press` : DeployCandidate = snapshot immuable {app, source, release, hash} + dependencies + env ; build Docker une fois → registre → benches jetables | pattern à imiter |
| Montée de version d'un site | `press` : JAMAIS in-place : nouveau bench depuis un nouveau candidate + move du site (backup/restore/migrate/réactivation) | pattern à imiter |
| Format de catalogue | `marketplace` : releases commit-scoped + gating PR/CI | pattern à imiter |
| Images serveurs | `chef` : recipe.toml déclaratif, golden images avec apps désactivées | pattern à imiter |

## 2. Agent serveur : press-agent-manager est le socle

- **`press-agent-manager` : réutilisable tel quel.** C'est un SDK Frappe
  (AGPL) double-face agent/control plane : jobs Agent Job/Step avec
  version_counter, ack/reject/finalize/retry, realtime Socket.IO, Router REST
  avec OpenAPI, workflow engine, IaC ansible, auth key:secret. LaStarter
  déclare ses types de jobs et ses handlers via les hooks. Jeune (un stub,
  cible v16 develop) : à épingler et combler ponctuellement.
- `agent` (v1) : le pattern Job/Step persisté + timeouts en cascade +
  callback minimal est exactement le nôtre ; le code (Flask+RQ+SQLite) se
  réécrit en Frappe natif.
- `press-api-spec` : approche contract-first (contrôleur ↔ agent) ; squelette
  réutilisable pour nos contrats.
- `press-compute-agent/orchestrator` : patrons de workers (« documents →
  infra, contrôleurs source de vérité, endpoint de réconciliation ») ;
  sans objet tant que nous ne gérons pas de VM.

## 3. IAM du cloud : central

Le modèle capacités/grants de `central` (17 capacités team-scopées avec
implications, grants scopés serveur, double enforcement query conditions +
has_permission) est du Frappe pur sans dépendance billing :
`iam.py` + `permissions.py` + `CAPABILITIES.md` + fixtures **se transportent
quasi verbatim** dans l'app identité LaStarter.

## 4. Identité : ce que le framework fournit déjà (vérifié dans le code)

- **Dynamic Client Registration RFC7591** : création de clients OAuth SANS
  Desk ni credentials admin (`frappe/integrations/oauth2.py:register_client`).
- OAuth Client créable par code ; `client_id` est TOUJOURS écrasé par le nom
  du document (`oauth_client.py:52`) : le pattern d'automatisation est
  « créer → relire le client_id généré → l'injecter chez le consommateur ».
- Social Login Key créable par code avec le preset « Frappe » (URLs
  relatives déjà bonnes) ; **« frappe » est un nom réservé** : pour nos
  providers custom, passer par `custom/<provider>`.
- Claims émis : `email_verified` toujours vrai, rôles inclus, `sub` stable.
- `get_url()` dérive l'URL publique du Host **sans port** (nginx frappe_docker
  transmet `Host: $host`) : la passerelle doit écouter sur 80/443, sinon les
  redirect_uri dérivés ne correspondent plus aux redirect enregistrés.
- `Connected App` n'est PAS un générateur de Social Login Key : ignorer.
- Discovery `.well-known` : exige une session en v16 (403 invité) ; le preset
  Frappe utilise les URLs directes, donc pas bloquant.
- `OAUTHLIB_INSECURE_TRANSPORT` piloté par la conf pour les tests locaux HTTP.

## 5. Provisionnement : pilot/bench/frappe_docker/helm

- `pilot` : non embarquable (produit autonome Flask+Vue, modèle de confiance
  root-équivalent), mais son astuce d'invocation **directe de
  `python -m frappe.utils.bench_helper`** (sans le CLI bench) et ses
  pratiques sont à copier : pipeline en étapes + rollback, lock de création,
  compte MariaDB jetable scopé, tâches détachées avec clés d'idempotence.
- `bench`/`frappe` : flags vérifiés de new-site (`--admin-password --force
  --install-app` multiple via bench_helper, `--source-sql`, `--db-root-*`,
  `--mariadb-user-host-login-scope`, `--setup-db`, `--set-default`), restore
  (`--with-*-files --encryption-key`, sous filelock), backup (`--backup-path*`
  `--with-files --compress`), common_site_config en read-modify-write (sans
  lock : attention), dns_multitenant/serve_default_site.
- `frappe_docker` : variables d'env documentées, overrides, recette
  multi-bench « 1 client = 1 stack compose sur hôte partagé », header
  `X-Frappe-Site-Name`, docs/ à lire (recettes prêtes).
- `helm` : jobs createSite/createMultipleSites et configure-bench prêts ;
  patron « 1 client = 1 namespace/release » réutilisable tel quel.

## 6. Références d'exploitation (lire, ne pas fourker)

- `press/press/playbooks/` : 167 playbooks Ansible (database, docker, TLS,
  agent, monitoring) qui provisionnent réellement les serveurs du cloud.
- `press/deployment/` : la config de production de frappe.cloud versionnée
  (nginx, supervisor, redis) + procédure de mise à jour.
- `platform` : LE dépôt de documentation interne VitePress de Frappe Cloud
  v2 (responsabilités Central/Atlas/Metal/Pilot/Cargo, auth/trust, workflows,
  `regional/bootstrap.md` = runbook de création d'une région).
- `atlas/docs/operate/` + `atlas/docs/region/` : runbooks par composant,
  diagnostic hôte, post-mortems datés.
- `grove` : infra-as-code piloté depuis le Desk (mixin AnsibleHost, un
  projet Ansible par doctype).
- `release_manager` : control plane de tests de release (Testing Site +
  token + plans planifiés) : squelette du trancheur LaStarter.
- `fc-scripts` (MIT) : scripts d'exploitation réutilisables tels quels.
- `raven_integration` : le pattern provider/hook + diff + provenance pour la
  synchronisation d'appartenances cross-apps (notre sync d'identités).
- `pulse` : télémétrie (ingest cross-origin par clé API + buffer Redis).
- `caffeine` : benchmarks du framework, utile ponctuellement.

## 7. À ignorer

`cargo` (interne Atlas/Central), `press-on-prem-failover` (mineur),
`atlas-neo`/`satellite` (à surveiller quand nous gérerons des VM),
`frappe-react-sdk`/`frappe-js-sdk` (sauf client REST TS pour une CLI future),
`writer`/`slides` (brique bureautique plus tard, via Suite).

## Conclusion opérable

Tout ce dont LaStarter a besoin existe chez Frappe, éparpillé mais codé :
nous réutilisons `press-agent-manager` (agent), l'IAM de `central`, les
jobs Helm de provisionnement, les scripts `fc-scripts`, et nous imitons cinq
patterns éprouvés de press (pin = hash, candidate immuable, move de site,
agent-jobs persistés, callbacks). La seule pièce vraiment à écrire est celle
qui nous différencie : le câblage OIDC automatique à la création du site
(l'app `lastarter_core` : RFC7591 ou insert + relire le client_id + Social
Login Key preset Frappe + élévation des users), celle-là même que Frappe
Cloud n'a jamais faite.
