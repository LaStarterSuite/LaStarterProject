# Installer avec les outils officiels Frappe (2026-10-29)

Décision du soir : AUCUN outil maison. On reprend tout chez eux — bench
(leur CLI), frappe_docker (leurs compose), press (leur cloud). Si ça
tourne chez eux, ça tourne chez nous. La seule partie « nous » : la
checklist de réglages au lancement, en fin de document.

## Voie A — démo en 10 minutes (leur pwd.yml)

Leur démonstration officielle, le git clone + up :

```bash
git clone https://github.com/frappe/frappe_docker
cd frappe_docker
docker compose -f pwd.yml up -d
```

Site sur http://localhost:8080, admin/admin. Pour nos apps, décommenter
les services X dans pwd.yml ou basculer vers la voie B/C ensuite.

## Voie B — production sur un serveur (leur méthode bench)

Le tutoriel officiel : frappe_docker/docs ou docs.frappeframework.com
« Production Setup ». Le cœur, de mémoire :

```bash
# dépendances système (leur doc liste tout)
sudo apt install -y python3-dev python3-pip mariadb-server redis-server \
  nodejs npm supervisor nginx certbot
sudo pip install frappe-bench

# le bench, la branche v16
bench init --frappe-branch version-16 frappe-bench
cd frappe-bench

# la base et le site
bench setup mariadb
bench new-site client1.mondomaine.tld

# les applications (les upstreams, telles quelles)
bench get-app https://github.com/frappe/crm
bench get-app https://github.com/frappe/helpdesk
bench --site client1.mondomaine.tld install-app crm helpdesk

# le passage en production : supervisor (les workers) + nginx (le front)
bench setup production <utilisateur>
bench setup nginx
sudo supervisorctl restart all
bench setup add-domain client1.mondomaine.tld   # + certbot pour le TLS
```

Mise à jour : `bench update` (ou git pull + migrate par site). C'est LEUR
procédure officielle, maintenue par eux.

## Voie C — le cloud multi-clients (press, leur système)

Voir `07-press-pas-a-pas-sur-tes-serveurs.md` : le control plane press,
les Release Groups (sources = les upstreams, ou les forks LaStarterSuite
si on veut figer/dévier un jour), les sites clients, le billing. Press
est leur produit : on l'installe, on le configure, on ne le réécrit pas.

## Notre partie : la checklist de réglages au lancement

À jouer après chaque installation (elle tient en quelques bench execute,
reprise de poc/reset-and-provision.sh) :

1. **Langue et setup** : System Settings `language=fr`,
   `setup_complete=1`, les Installed Application `is_setup_complete=1`
   (sinon la boucle du setup wizard).
2. **Desk par défaut** : Role « Desk User ».home_page = /desk (le login
   atterrit sur le sélecteur d'applications).
3. **Mail : interdire les inscriptions** : Mail Settings
   `allow_signup = 0` — seuls nous créons les comptes, tout passe par
   le SSO.
4. **SSO OIDC entre les sites** (si multi-sites : un site identité +
   un site bureau) : le OAuth Client côté identité, le Social Login Key
   côté bureau — le script poc/oidc-setup.sh est la référence.
5. **Comptes** : les comptes de démo (admin/alice/demo) avec les rôles
   Métier, le mot de passe imposé par le client.
6. **Stalwart (optionnel)** : le conteneur v0.16.27, le domaine mail,
   les comptes via l'API de gestion, l'Email Account Frappe en SMTP
   local — la procédure éprouvée est dans le constat 09-AUJOURDHUI.
7. **Données de démo** : leads, tickets, cours, canal chat — la phase 9
   du reset script.

## Les mises à jour

- Les apps : `bench update` (ou les forks : leur workflow sync-upstream
  fusionne l'amont chaque nuit, puis bench update côté serveur).
- frappe_docker / press : git pull + leur procédure.
- Aucun code à nous à maintenir : la dette technique de la couche
  « installation » est nulle.
