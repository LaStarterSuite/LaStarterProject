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
