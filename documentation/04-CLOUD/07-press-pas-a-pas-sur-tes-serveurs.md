# Press auto-hébergé pas à pas : ton serveur de test (2026-10-29)

Le plan concret pour louer des serveurs, installer TOUT le système Frappe
Cloud (press) dessus, créer un compte, simuler un paiement et déployer NOS
versions (les forks LaStarterSuite). Source : le runbook 06-self-host-
press-runbook.md (la lecture du code press) + le guide officiel
local-fc-setup. Press est AGPL : l'usage commercial est autorisé, l'obligation
est de publier les modifications aux utilisateurs du service.

## 0. Ce qu'il faut avant de commencer

- 3 serveurs Linux (Ubuntu 22.04 ou 24.04) : 1 control plane (2 Go RAM
  suffisent), 1 serveur unifié (app + base, 8 Go RAM recommandés pour
  builder des images), 1 proxy (2 Go). Option débutant : commencer avec
  2 VM (le control plane + l'unifié), le proxy peut attendre la première
  mise en production réelle.
- Un nom de domaine avec un WILDCARD pointant vers le serveur d'app :
  `*.apps.mondomaine.tld → IP` et `apps.mondomaine.tld → IP`.
- Un registre Docker (les benches construisent des images) : le plus
  simple = un dépôt Docker Hub gratuit, ou un `registry:2` auto-hébergé.
- Un token GitHub (les Release Groups tirent les apps depuis les repos).

## 1. Le control plane (le cerveau : le dashboard et l'API)

```bash
# python, mariadb, redis, bench
sudo apt update && sudo apt install -y python3-pip python3-dev \
  mariadb-server redis-server nodejs npm
sudo pip install frappe-bench
bench init press-bench --frappe-branch version-16
cd press-bench
bench get-app https://github.com/frappe/press
bench new-site press.mondomaine.tld --install-app press
bench start   # en prod : gunicorn + workers via supervisor/systemd
```

Puis dans le site (le desk de press) : **Press Settings** —
- `domain` : apps.mondomaine.tld
- `registry` : ton registre (ex. docker.io/moncompte)
- `agent_repository_owner` / `agent_branch` : figer la source de l'agent
- `cluster` : « Default » (créé automatiquement à l'install)

## 2. Les serveurs managés (l'agent et les playbooks)

Chaque serveur managé (proxy, base, app) exécute l'**agent** (un daemon
Flask sur 127.0.0.1:25052 derrière son nginx) et est préparé par les
playbooks Ansible de press. L'ordre :

1. **Proxy Server** : créer dans le desk → action « Setup Server »
   (joue proxy.yml : nginx, ProxySQL, docker).
2. **Database Server** : idem (database.yml : MariaDB 10.6 — noter le
   mot de passe root généré).
3. **Server (app)** : idem (server.yml : nginx, redis, docker, durcissement)
   puis « Add to Proxy ».
4. Les serveurs sont rejoints par SSH : press y pousse les playbooks
   tout seul (prévoir la clé SSH dans les settings).

Version débutant sans Ansible : installer à la main docker + redis + nginx
sur l'unifié et déclarer le serveur avec `is_server_setup=True`
(new_server=False) — press saute le provisionnement.

## 3. Le Release Group : déployer NOS versions (les forks)

C'est ICI que les forks LaStarterSuite servent :

1. **App Sources** : pour chaque app, une source `LaStarterSuite/<app>`
   branche épinglée (main / version-16...). Exemple :
   `https://github.com/LaStarterSuite/erpnext` branche `version-16`.
2. **Release Group** « lasarter-v16 » : y lister les sources dans l'ordre
   (frappe version-16 d'abord, puis crm, helpdesk, ... l'ordre du
   manifeste). Serveur cible : l'unifié.
3. **Deploy** : press construit l'image Docker du bench (les Deploy
   Candidates), puis crée le bench sur le serveur. Le premier build
   prend 20-40 min (les suivants, quelques minutes).
4. **Site** : créer le site client sur le Release Group (le nom = le
   domaine du client, le plan = Free pour les tests).
5. Le wildcard DNS + le proxy routent `client1.apps.mondomaine.tld`
   vers le bench. Le certificat TLS : Let's Encrypt géré par press.

## 4. Le compte client et le paiement simulé

1. Créer une **Team** (le compte client) depuis /dashboard : email +
   mot de passe, la team reçoit son espace de facturation.
2. **Plan** : créer un Site Plan « Démo » à 0 € (ou le prix réel) dans
   le desk press, puis l'assigner au site de test.
3. **Paiement** : press facture via Stripe. Pour simuler SANS Stripe
   réel : activer le mode test de Stripe (les clés test), payer avec la
   carte 4242 4242 4242 4242. Sans Stripe du tout : ajuster le crédit
   de la team à la main (l'entrée de facturation manuelle) — le système
   de facturation suit alors un scénario réel sans encaisser.
4. Vérifier la boucle complète : la team se connecte, installe une app
   depuis la liste, son site se met à jour, la facture apparaît.

## 5. Nos versions dans les Release Groups

Les 16 forks LaStarterSuite ont chacun un workflow `sync-upstream`
(cron quotidien 04:23 UTC) qui fusionne l'amont dans nos branches
épinglées. Les Release Groups pointant les forks héritent donc des mises
à jour amont en redeployant. Mail (archivé) : le fork est la base du
chantier « remise sur patte » — aucune sync attendue, c'est notre base
de travail.

## 6. Ce qui peut coincer (retours du code)

- Le registre Docker doit être joignable des deux côtés (press pousse,
  les serveurs tires) : configurer les creds dans Press Settings.
- Le wildcard TLS exige le DNS-01 ou le HTTP-01 avec le DNS déjà posé.
- Les singletons annexes de press (Registry/Log/Monitor/Trace, la
  facturation Stripe) existent mais peuvent rester inutilisés au début.
- Les chaînes de press vieillissent (ansible 3.4, MariaDB 10.6) :
  prévoir de la patience au premier Setup Server.

## 7. L'alternative simple en attendant press

Le produit v1 de LaStarter (le mutualisé) n'a PAS besoin de press : la
CLI `cli/lastarter.py` provisionne un serveur complet en une commande,
et un client = un serveur (ou un ensemble de conteneurs). Press devient
pertinent quand on veut : le self-service client, le billing automatisé,
les déploiements en un clic, la montée en densité (plusieurs sites par
bench). Les deux coexistent : lastarter pour les premiers clients,
press pour l'industrialisation.

## 8. Le catalogue marketplace (le sélecteur d'apps)

La page « Select an app to get started » du dashboard client liste le
doctype **Marketplace App** (filtres `status = Published` et
`show_for_site_creation = 1`) — PAS les doctypes App / App Source des
Release Groups. Les deux chaînes sont distinctes :

```
App (slug, public) ── App Source (branche, public, versions 15/16)
                          └── App Release (status Approved) ──┐
Marketplace App (Published, show_for_site_creation, sources) ─┘
```

Le validateur de publication exige au moins une App Release avec
status Approved sur une source de l'app : c'est aussi ce que produit
leur auto-approbation (`App Release.before_save` approuve tout ce qui
est listé dans Marketplace Settings).

Le script `poc/press-marketplace-catalog.py` reconstruit tout le
catalogue (7 apps : CRM, Helpdesk, Raven, LMS, ERPNext, HR, Webshop)
de façon idempotente :

```bash
scp poc/press-marketplace-catalog.py ubuntu@SERVEUR:/home/ubuntu/
ssh ubuntu@SERVEUR "cd ~/press-bench && \
  bench --site press.wardhive.app console < ~/press-marketplace-catalog.py"
```

Pièges constatés : les lignes enfants (versions, sources) passent par
le constructeur `frappe.get_doc({...})` — l'affectation d'un attribut
avec une liste de dictionnaires casse ; `bench execute frappe.get_all`
n'imprime RIEN pour une liste vide (silence = zéro ligne) ; l'insert
d'un Marketplace App déclenche un fetch du README GitHub qui peut
jeter un `KeyError: 'content'` cosmétique sous rate-limit (l'insert
aboutit quand même). Vérification côté client :

```bash
printf 'import press.api.marketplace as m\nfrappe.set_user("grand.client@wardhive.app")\nprint(len(m.get_marketplace_apps_for_onboarding()))\n' | \
  ssh ubuntu@SERVEUR "cd ~/press-bench && bench --site press.wardhive.app console" | grep -E '^[0-9]'
```

### La machinerie trial (le suffixe du sous-domaine)

L'ecran « Let's set up your site » charge le document **Product Trial**
nomme comme la Marketplace App (le `:productId` de l'URL), puis appelle
`press.api.product_trial.get_request` qui renvoie le `domain` du
document (un lien vers **Root Domain**). Sans ces documents, l'ecran
n'affiche qu'un point sans suffixe et `get_request` n'est jamais
appele : la ressource frontend a `auto: !!saasProduct`, donc tant que
le document Product Trial n'existe pas, rien ne se declenche.

Le script catalogue seme aussi : Root Domain (apps.wardhive.app,
`dns_provider` Generic, `default_cluster` Default), Press
Settings.domain, le Site Plan « Standard LaStarter » (`document_type`
Site, `price_inr` et `price_usd` obligatoires, **`is_trial_plan`=1
sinon le Product Trial refuse : « Selected plan is not a trial
plan »**), un Release Group par produit (team, version, apps enfant
avec la source frappe version-15 — `release_group` et `email_subject`
sont obligatoires sur Product Trial) et le patch Cluster (`public`=1,
`status` Active, `cloud_provider` Generic, sinon les clusters
disponibles ne remontent pas dans les flux clients).

Trois gardes a connaitre : la validation de publication d'une
Marketplace App exige une App Release `Approved` ; `create_site`
valide le sous-domaine (5 a 32 caracteres, regex stricte) contre les
Root Domain `enabled` ; le deploiement final du site demande l'infra
managee (Server + DatabaseServer + ProxyServer + agent frappe/agent +
Docker + nginx press) — voir la section 4. Sans elle, la demande
reste en « Wait for Site » puis passe en erreur.

Test E2E Playwright du parcours client (login, selecteur d'apps,
suffixe, marketplace) : `tests/press-e2e/test_client_flow.py`,
a executer sur le serveur avec l'env du bench press
(`env/bin/playwright install chromium` une fois, puis le script avec
PRESS_EMAIL/PRESS_PASSWORD en variables d'environnement).
