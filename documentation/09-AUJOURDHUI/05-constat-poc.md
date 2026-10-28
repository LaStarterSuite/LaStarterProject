# Constat du POC trancheur (2026-10-28)

**Verdict : le POC est VERT.** Les trois preuves visées par
`02-poc-plan.md` sont acquises, reproductibles par script
(`poc/build.sh`, `poc/compose.yml`, `poc/oidc-setup.sh`, `poc/users-setup.sh`,
`poc/verify.sh`).

## Les preuves

1. **Bench Frappe en Docker** (image `lasarter-bench:poc`, construite par le
   Containerfile `layered` officiel de frappe_docker) : un bench, deux sites
   (`id.localhost` identité, `crm.localhost` client), apps installées :
   frappe 16.54.0, crm 1.89.2, helpdesk, telephony.
2. **Un site Frappe est l'IdP OIDC d'un autre site** : OAuth Client sur
   `id.localhost`, Social Login Key preset « Frappe » sur `crm.localhost`,
   échange de tokens serveur à serveur (les conteneurs joignent l'IdP via
   `extra_hosts: host-gateway`, glibc ne résout pas `*.localhost`).
3. **SSO navigué** : login alice sur l'IdP → Helpdesk et CRM accessibles
   sans re-saisie de mot de passe (session IdP vivante → authorize → code →
   callback → session client). Socket.io opérationnel en http après login.
4. (Bonus Keycloak 8180 : non testé dans ce passage, conteneur à recréer
   depuis le workspace Convex archivé.)

## Frictions rencontrées (chacune = une leçon de constat)

| # | Friction | Résolution |
|---|---|---|
| 1 | Build : `Dockerfile` introuvable | Le fichier s'appelle `Containerfile` : `-f images/layered/Containerfile`, contexte = racine frappe_docker, `apps.json` passé en **secret de build** (`--secret id=apps_json`) |
| 2 | `bench init` : `TypeError: string indices must be integers` | `apps.json` est une **LISTE** `[{url, branch}]` (bench `install_apps_from_path`), pas un dict ; vérifier les formats dans le code amont avant d'écrire (leçon `feedback-verifier-amont-dabord`) |
| 3 | Install helpdesk fatale : `No module named 'telephony'` | `required_apps = ["frappe/telephony"]` (helpdesk/hooks.py) : **telephony fait partie de l'image** (branche develop, le pin marketplace Frappe Cloud). CRM requiert whatsapp (bénin, rattrapé) |
| 4 | redirect_uri OIDC rejeté | Le nginx frappe_docker transmet `Host: $host` **sans port** : Frappe dérive toutes ses URLs sans port → la passerelle écoute sur **80**, URLs sans port partout (OAuth Client, base_url Social Login) |
| 5 | `client_id` « lasarter-crm » ignoré | `OAuth Client.validate()` écrase `client_id = self.name` (oauth_client.py:52) : créer, **relire le client_id généré**, l'injecter chez le consommateur (c'est LE pattern d'automatisation de lastarter_core) |
| 6 | 400 « Invalid client_id » trompeur | `validate_client_id` exige `client.user_has_allowed_role()` : le client autorise par défaut « Desk User » et l'utilisateur doit l'avoir (oauth.py:20-30) |
| 7 | « Not Permitted » malgré le rôle en base | Les rôles sont **en cache** : un insert direct de Has Role n'invalide pas `frappe.get_roles()` ; un login reconstruit tout. Modifier `user_type` force `clear_sessions` (user.py:379) |
| 8 | /crm → redirection « Set Password » | CRM (`redirect_to_set_password`) pousse les users SSO **sans mot de passe local** vers update-password : lastarter_core devra pré-poser un mot de passe aléatoire au provisioning (ou neutraliser ce flux pour les users SSO) |
| 9 | discovery `.well-known` en 403 invité | En v16 le endpoint exige une session ; le preset Frappe utilise les URLs directes, donc sans impact (à contribuer amont : la discovery devrait être guest) |
| 10 | Heredocs vers `bench console` muets | IPython via docker exec n'exécute pas les blocs indentés non terminés : tout script passe par `bench execute frappe.client.insert --kwargs '{"doc": {...}}'` (kwargs JSON = arguments de la FONCTION) |
| 11 | SPA → socket.io en https refusé | Au premier chargement pré-login le SPA tente https ; après login, socket.io http fonctionne (200 + sid). Traitement propre : TLS partout (passerelle v2) |
| 12 | Appel télémétrie vers `pulse.m.frappe.cloud` | Le Desk embarque un client Pulse : à désactiver pour un produit souverain (réglage site, chantier lastarter_core) |

## Ce que lastarter_core devra automatiser (liste précise, issue du POC)

1. Création des OAuth Clients par site + relecture des `client_id` générés +
   injection dans les Social Login Key des sites consommateurs.
2. Rôles : attribution métier par app (Desk User, Sales User, Agent…) au
   provisioning + invalidation du cache (`frappe.clear_cache(user=)`), et
   élévation des users OIDC (le gap §1 des limites connues).
3. Mot de passe local aléatoire (ou neutralisation du flux) pour les users
   SSO, à cause de `redirect_to_set_password` de CRM.
4. Branding/white-label + désactivation de la télémétrie Pulse.
5. Idempotence de tout le câblage (le POC le prouve : scripts rejouables).

## Écarts et choix à documenter

- v16 : le CLI `bench new-site --install-app` est à valeur unique ; passer
  par `bench --site X install-app <app>` chaîné (ou bench_helper, cf.
  astuce pilot dans `04-cartographie-depots-frappe.md`).
- `FRAPPE_SITE_NAME_HEADER=$$host` : le Host désigne le site (multi-sites).
- Ports : 8080 occupé sur cette machine, la passerelle POC est sur 80.

## Temps de provisioning mesurés (base de la CLI future)

- Build image layered (avec cache de base) : ~10 min.
- Création des 2 sites + install apps (compose up) : ~2-3 min.
- Câblage OIDC + users (scripts) : ~1 min.
