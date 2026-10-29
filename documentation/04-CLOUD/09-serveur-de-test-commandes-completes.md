# Serveur de test : toutes les commandes (2026-10-29)

La séquence complète pour un serveur Linux neuf (Ubuntu 22.04/24.04,
4 Go RAM min, 20 Go disque) : la suite entière (14 apps), le SSO entre
le site identité et le site bureau, Stalwart pour le mail, HTTPS
automatique. Zéro outil maison : leurs images, leur Containerfile,
leurs commandes bench.

> **Le raccourci** : `bash install.sh` à la racine du dépôt fait tout
> ce document en une commande (questions ou variables d'environnement,
> idempotent). Ce document détaille chaque étape et sert de référence
> de dépannage.

## 0. Prérequis (avant toute commande)

Chez le registrar, sur l'IP du serveur (la commande 1 la détecte) :

```
A    apps.tondomaine.tld     → IP
A    id.apps.tondomaine.tld  → IP
A    mail.apps.tondomaine.tld → IP
```

Le DNS doit être en place AVANT le premier démarrage (Caddy demande
les certificats Let's Encrypt dès le boot).

## 1. Préparation du serveur

```bash
sudo apt update && sudo apt install -y git curl
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker
docker compose version   # doit répondre v2
curl -4 ifconfig.me      # ton IP publique, pour les records DNS
```

## 2. Le répertoire et les fichiers

```bash
mkdir -p ~/lasarter && cd ~/lasarter

cat > .env <<'EOF'
DOMAIN=apps.tondomaine.tld
IDP_DOMAIN=id.apps.tondomaine.tld
MAIL_DOMAIN=mail.apps.tondomaine.tld
ADMIN_EMAIL=admin@tondomaine.tld
ADMIN_PASSWORD=ChangeMoi-2026
MYSQL_ROOT_PASSWORD=ChangeMoi-aussi
OIDC_SECRET=un-secret-long-aleatoire
STALWART_ADMIN_PASSWORD=ChangeMoi-mail
STALWART_DOMAIN=tondomaine.tld
EOF
chmod 600 .env
```

Remplace les valeurs (les trois domaines, l'email, les mots de passe —
des longs et aléatoires pour tout ce qui touche au mail).

```bash
cat > apps.json <<'EOF'
[
  {"url": "https://github.com/frappe/crm", "branch": "main"},
  {"url": "https://github.com/frappe/helpdesk", "branch": "main"},
  {"url": "https://github.com/frappe/telephony", "branch": "develop"},
  {"url": "https://github.com/frappe/wiki", "branch": "version-3"},
  {"url": "https://github.com/frappe/insights", "branch": "version-3"},
  {"url": "https://github.com/frappe/raven", "branch": "main"},
  {"url": "https://github.com/frappe/lms", "branch": "main"},
  {"url": "https://github.com/frappe/payments", "branch": "version-16"},
  {"url": "https://github.com/frappe/erpnext", "branch": "version-16"},
  {"url": "https://github.com/frappe/hrms", "branch": "version-16"},
  {"url": "https://github.com/frappe/webshop", "branch": "version-16"},
  {"url": "https://github.com/frappe/gameplan", "branch": "main"},
  {"url": "https://github.com/frappe/builder", "branch": "develop"}
]
EOF
```

Le compose (bench + mariadb + redis + workers + Caddy + Stalwart) :

```bash
cat > compose.yml <<'EOF'
name: lasarter
x-deploy: &deploy
  restart_policy: { condition: on-failure }

services:
  backend:
    image: lasarter-bench:16
    networks: [lasarter]
    deploy: *deploy
    volumes: &bench-volumes
      - sites:/home/frappe/frappe-bench/sites
      - logs:/home/frappe/frappe-bench/logs
    extra_hosts:
      - "apps.tondomaine.tld:host-gateway"
      - "id.apps.tondomaine.tld:host-gateway"
    environment:
      DB_HOST: db
      DB_PORT: "3306"
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}

  configurator:
    image: lasarter-bench:16
    networks: [lasarter]
    restart: "no"
    entrypoint: ["bash", "-c"]
    command:
      - >
        ls -1 apps > sites/apps.txt;
        bench set-config -g db_host $$DB_HOST;
        bench set-config -gp db_port $$DB_PORT;
        bench set-config -g redis_cache "redis://redis-cache:6379";
        bench set-config -g redis_queue "redis://redis-queue:6379";
        bench set-config -gp socketio_port 9000;
    environment:
      DB_HOST: db
      DB_PORT: "3306"
    volumes: *bench-volumes
    depends_on: [db, redis-cache, redis-queue]

  create-sites:
    image: lasarter-bench:16
    networks: [lasarter]
    restart: "no"
    volumes: *bench-volumes
    entrypoint: ["bash", "-c"]
    command:
      - >
        wait-for-it -t 120 db:3306;
        wait-for-it -t 120 redis-cache:6379;
        wait-for-it -t 120 redis-queue:6379;
        if [ ! -d "sites/id.apps.tondomaine.tld" ]; then
          bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$MYSQL_ROOT_PASSWORD" --set-default id.apps.tondomaine.tld;
        fi;
        if [ ! -d "sites/apps.tondomaine.tld" ]; then
          bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$MYSQL_ROOT_PASSWORD" --install-app crm apps.tondomaine.tld;
        fi;
    environment:
      DB_HOST: db
      DB_PORT: "3306"
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      ADMIN_PASSWORD: ${ADMIN_PASSWORD}
    depends_on:
      configurator: { condition: service_completed_successfully }

  db:
    image: mariadb:11.8
    networks: [lasarter]
    restart: on-failure
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      start_period: 5s
      interval: 5s
      timeout: 5s
      retries: 5
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-character-set-client-handshake
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes: [db-data:/var/lib/mysql]

  frontend:
    image: lasarter-bench:16
    networks: [lasarter]
    restart: on-failure
    depends_on: [websocket, backend]
    command: [nginx-entrypoint.sh]
    environment:
      BACKEND: backend:8000
      FRAPPE_SITE_NAME_HEADER: $$host
      SOCKETIO: websocket:9000
      PROXY_READ_TIMEOUT: "120"
      CLIENT_MAX_BODY_SIZE: 50m
    volumes: *bench-volumes
    ports: ["8080:8080"]

  queue-long:
    image: lasarter-bench:16
    networks: [lasarter]
    deploy: *deploy
    command: [bench, worker, --queue, long,default,short]
    volumes: *bench-volumes
    environment: &worker-env
      FRAPPE_REDIS_CACHE: redis://redis-cache:6379
      FRAPPE_REDIS_QUEUE: redis://redis-queue:6379
    depends_on:
      configurator: { condition: service_completed_successfully }

  queue-short:
    image: lasarter-bench:16
    networks: [lasarter]
    deploy: *deploy
    command: [bench, worker, --queue, short,default]
    volumes: *bench-volumes
    environment: *worker-env
    depends_on:
      configurator: { condition: service_completed_successfully }

  scheduler:
    image: lasarter-bench:16
    networks: [lasarter]
    deploy: *deploy
    command: [bench, schedule]
    volumes: *bench-volumes
    depends_on:
      configurator: { condition: service_completed_successfully }

  websocket:
    image: lasarter-bench:16
    networks: [lasarter]
    deploy: *deploy
    command: [node, /home/frappe/frappe-bench/apps/frappe/socketio.js]
    volumes: *bench-volumes
    environment: *worker-env
    depends_on:
      configurator: { condition: service_completed_successfully }

  redis-cache:
    image: redis:6.2-alpine
    networks: [lasarter]
    restart: on-failure

  redis-queue:
    image: redis:6.2-alpine
    networks: [lasarter]
    restart: on-failure
    volumes: [redis-queue-data:/data]

  stalwart:
    image: stalwartlabs/stalwart:v0.16.27
    networks: [lasarter]
    restart: on-failure
    environment:
      STALWART_PUBLIC_URL: "https://mail.apps.tondomaine.tld"
      STALWART_RECOVERY_ADMIN: "admin:${STALWART_ADMIN_PASSWORD}"
    volumes:
      - stalwart-config:/etc/stalwart
      - stalwart-data:/var/lib/stalwart

  caddy:
    image: caddy:2
    networks: [lasarter]
    restart: on-failure
    depends_on: [frontend]
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config

volumes:
  db-data:
  sites:
  logs:
  redis-queue-data:
  stalwart-config:
  stalwart-data:
  caddy-data:
  caddy-config:

networks:
  lasarter:
    driver: bridge
EOF
```

Amorce le volume de config Stalwart AVANT le premier boot (sans ce
fichier, le serveur ne démarre pas) :

```bash
docker volume create lasarter_stalwart-config
printf '%s' '{"@type":"RocksDb","path":"/var/lib/stalwart/","blobSize":4096,"bufferSize":134217728,"cacheSize":134217728}' \
  | docker run --rm -i -v lasarter_stalwart-config:/c alpine sh -c 'cat > /c/config.json'
```

Le Caddyfile (HTTPS automatique pour les trois domaines) :

```bash
cat > Caddyfile <<'EOF'
apps.tondomaine.tld {
	encode gzip
	reverse_proxy frontend:8080
}

id.apps.tondomaine.tld {
	encode gzip
	reverse_proxy frontend:8080
}

mail.apps.tondomaine.tld {
	encode gzip
	reverse_proxy stalwart:8080
}
EOF
```

## 3. Construction de l'image (20-30 min)

Leur Containerfile officiel, nos apps épinglées :

```bash
git clone --depth 1 https://github.com/frappe/frappe_docker
export DOCKER_BUILDKIT=1
docker build \
  --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg FRAPPE_BRANCH=version-16 \
  --build-arg CACHE_BUST="$(date +%s)" \
  --secret id=apps_json,src=apps.json \
  --tag lasarter-bench:16 \
  --file frappe_docker/images/layered/Containerfile \
  frappe_docker
```

## 4. Démarrage et création des sites

```bash
docker compose up -d
# attends la fin du create-sites (10-15 min) :
docker inspect lasarter-create-sites-1 --format '{{.State.Status}}|{{.State.ExitCode}}'
# => "exited|0"
```

Puis les apps restantes sur le site bureau :

```bash
for APP in helpdesk raven lms telephony wiki insights payments erpnext hrms webshop gameplan builder; do
  docker compose exec backend bench --site apps.tondomaine.tld install-app $APP || exit 1
done
```

## 5. Nos réglages (la checklist)

```bash
DC="docker compose exec backend bench"
# setup complet, langue FR, pas de boucle wizard
$DC --site apps.tondomaine.tld execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe", "crm"]]}, "is_setup_complete", 1]'
$DC --site id.apps.tondomaine.tld execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe"]]}, "is_setup_complete", 1]'
$DC --site apps.tondomaine.tld execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}'
$DC --site id.apps.tondomaine.tld execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}'
# desk par défaut après login
$DC --site apps.tondomaine.tld execute frappe.db.set_value --args '["Role","Desk User","home_page","/desk"]'
# interdire les inscriptions mail
$DC --site apps.tondomaine.tld execute frappe.db.set_single_value --kwargs '{"doctype":"Mail Settings","fieldname":"allow_signup","value":0}'
$DC --site apps.tondomaine.tld execute frappe.db.commit
$DC --site apps.tondomaine.tld execute frappe.clear_cache
```

## 6. Administrateur

```bash
source .env
docker compose exec backend bench --site apps.tondomaine.tld execute frappe.client.insert --kwargs '{"doc":{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PASSWORD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"System Manager"},{"role":"Desk User"},{"role":"Accounts Manager"},{"role":"Sales Manager"},{"role":"Purchase Manager"},{"role":"Stock Manager"},{"role":"HR Manager"},{"role":"Projects User"},{"role":"Raven User"},{"role":"LMS Student"},{"role":"Wiki User"},{"role":"Insights Admin"}]}}'
docker compose exec backend bench --site id.apps.tondomaine.tld execute frappe.client.insert --kwargs '{"doc":{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PASSWORD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}}'
docker compose exec backend bench --site apps.tondomaine.tld execute frappe.clear_cache
```

## 7. SSO entre le site identité et le site bureau

```bash
set -a; source .env; set +a
REDIRECT="https://$DOMAIN/api/method/frappe.integrations.oauth2_logins.login_via_frappe"
docker compose exec backend bench --site "$IDP_DOMAIN" execute frappe.client.insert --kwargs "{\"doc\":{\"doctype\":\"OAuth Client\",\"app_name\":\"lasarter-desk\",\"client_id\":\"lasarter-desk\",\"client_secret\":\"$OIDC_SECRET\",\"default_redirect_uri\":\"$REDIRECT\",\"redirect_uris\":\"$REDIRECT\",\"grant_type\":\"Authorization Code\",\"response_type\":\"Code\",\"scopes\":\"openid email profile\",\"skip_authorization\":1}}"
docker compose exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs "{\"doc\":{\"doctype\":\"Social Login Key\",\"provider_name\":\"Frappe\",\"social_login_provider\":\"Frappe\",\"enable_social_login\":1,\"client_id\":\"lasarter-desk\",\"client_secret\":\"$OIDC_SECRET\",\"base_url\":\"https://$IDP_DOMAIN\",\"custom_base_url\":1,\"authorize_url\":\"/api/method/frappe.integrations.oauth2.authorize\",\"access_token_url\":\"/api/method/frappe.integrations.oauth2.get_token\",\"api_endpoint\":\"/api/method/frappe.integrations.oauth2.openid_profile\",\"redirect_url\":\"/api/method/frappe.integrations.oauth2_logins.login_via_frappe\",\"auth_url_data\":\"{\\\"response_type\\\": \\\"code\\\", \\\"scope\\\": \\\"openid email profile\\\"}\",\"sign_ups\":\"Allow\"}}"
```

## 8. Stalwart : le domaine et les comptes

Le serveur s'auto-provisionne au premier boot (listeners, boîtes).
La console d'admin : https://mail.apps.tondomaine.tld/admin avec
admin / $STALWART_ADMIN_PASSWORD. En ligne de commande :

```bash
set -a; source .env; set +a
API="http://stalwart:8080/jmap/"
AUTH="admin:$STALWART_ADMIN_PASSWORD"
# le domaine mail
docker compose exec backend curl -s -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
  -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Domain/set",{"create":{"d1":{"name":"'"$STALWART_DOMAIN"'","description":"Domaine LaStarter","isEnabled":true}}},"c0"]]}'
# les comptes (name = partie locale, credentials en carte, pas d'emailAddress : le serveur le dérive)
docker compose exec backend curl -s -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
  -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Account/set",{"create":{"a1":{"@type":"User","name":"admin","description":"Administrateur","domainId":"b","credentials":{"0":{"@type":"Password","secret":"'"$STALWART_ADMIN_PASSWORD"'"}}}}},"c0"]]}'
docker compose exec backend curl -s -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
  -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Account/set",{"update":{"b":{"roles":{"@type":"Admin"}}}},"c0"]]}'
# l'envoi Frappe passe par Stalwart
docker compose exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"Email Account","email_account_name":"Stalwart","email_id":"admin@'"$STALWART_DOMAIN"'","enable_outgoing":1,"smtp_server":"stalwart","use_tls":0,"smtp_port":25,"default_outgoing":1,"no_smtp_authentication":1}}'
```

## 9. Vérifications

```bash
curl -sI https://$DOMAIN/desk | head -1        # HTTP/2 200 ou 301
curl -sI https://$IDP_DOMAIN/api/method/ping    # 200
docker compose exec backend bench --site $DOMAIN execute frappe.db.count --args '["Installed Application"]'
```

Connexion : https://apps.tondomaine.tld (l'admin), le sélecteur
d'applications affiche les tuiles filtrées par droits, le webmail est
sur https://mail.apps.tondomaine.tld.

## Dépannage express

- Un 500 général après les installs : `docker compose restart backend`
  puis `docker compose exec backend bench --site $DOMAIN clear-cache`
  (les workers ont importé le site avant la fin des installs).
- La boucle setup-wizard : vérifier `is_setup_complete` (le bloc 5).
- Stalwart ne démarre pas « invalid type: null » : le volume
  stalwart-config n'a pas été amorcé (le bloc 2).
- Les boîtes mail ne s'affichent pas : les URLs annoncées suivent
  STALWART_PUBLIC_URL — il doit être https://mail.<domaine> et le DNS
  doit pointer ici.
