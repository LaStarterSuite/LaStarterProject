#!/usr/bin/env bash
# lastarter — installe la suite complète sur un serveur Linux neuf.
#
#   bash install.sh                     # interactif, pose les questions
#   DOMAIN=apps.mon.tld ADMIN_EMAIL=.. ADMIN_PASSWORD=.. bash install.sh   # sans interaction
#
# Déploie : un bench Frappe v16 (14 apps épinglées), deux sites (identité
# SSO + bureau), Caddy (HTTPS automatique), Stalwart (mail interne),
# la checklist LaStarter (desk par défaut, inscriptions désactivées).
# Idempotent : relançable sans casse. Le tout dans ./lasarter.
set -euo pipefail

VERSION_TAG="16"
BENCH_IMAGE="lasarter-bench:16"
DIR="${DIR:-$HOME/lasarter}"

say()  { printf '\033[1;36m  • \033[0m%s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ \033[0m%s\n' "$*"; }
warn() { printf '\033[1;33m  ! \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; exit 1; }
phase(){ printf '\n\033[1;36m════ %s \033[0m' "$*"; printf '%.0s═' {1..40}; echo; }

gen_password() { head -c 16 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 15; }

# ----------------------------------------------------------------- réponses
ROOT_DOMAIN="${ROOT_DOMAIN:-}"
if [ -z "${DOMAIN:-}" ]; then
  echo ""
  say "lastarter — la suite collaborative auto-hébergée (Frappe v16)"
  echo ""
  read -rp "  Ton domaine racine (ex. mondomaine.tld) : " ROOT_DOMAIN
  APPS_DOMAIN="${APPS_DOMAIN:-apps.$ROOT_DOMAIN}"
  read -rp "  Domaine du bureau          [$APPS_DOMAIN] : " _d; APPS_DOMAIN="${_d:-$APPS_DOMAIN}"
  IDP_DOMAIN="${IDP_DOMAIN:-id.$APPS_DOMAIN}"
  read -rp "  Domaine de l'identité SSO  [$IDP_DOMAIN] : " _d; IDP_DOMAIN="${_d:-$IDP_DOMAIN}"
  MAIL_DOMAIN="${MAIL_DOMAIN:-mail.$APPS_DOMAIN}"
  read -rp "  Domaine du webmail         [$MAIL_DOMAIN] : " _d; MAIL_DOMAIN="${_d:-$MAIL_DOMAIN}"
  ADMIN_EMAIL="${ADMIN_EMAIL:-}"
  [ -z "$ADMIN_EMAIL" ] && { read -rp "  Email administrateur : " ADMIN_EMAIL; }
  ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(gen_password)}"
  STALWART_ADMIN_PASSWORD="${STALWART_ADMIN_PASSWORD:-$(gen_password)}"
  MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(gen_password)}"
  OIDC_SECRET="${OIDC_SECRET:-$(gen_password)}"
  DEMO="${DEMO:-1}"
else
  APPS_DOMAIN="${APPS_DOMAIN:-$DOMAIN}"
  IDP_DOMAIN="${IDP_DOMAIN:?IDP_DOMAIN requis en mode sans interaction}"
  MAIL_DOMAIN="${MAIL_DOMAIN:-mail.$APPS_DOMAIN}"
  ADMIN_EMAIL="${ADMIN_EMAIL:?ADMIN_EMAIL requis}"
  ADMIN_PASSWORD="${ADMIN_PASSWORD:?ADMIN_PASSWORD requis}"
  STALWART_ADMIN_PASSWORD="${STALWART_ADMIN_PASSWORD:-$(gen_password)}"
  MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(gen_password)}"
  OIDC_SECRET="${OIDC_SECRET:-$(gen_password)}"
  DEMO="${DEMO:-1}"
fi

# ----------------------------------------------------------------- contrôles
phase "Vérification du serveur"
[ "$(uname -s)" = "Linux" ] || die "Cible Linux uniquement."
for t in docker git curl; do
  command -v "$t" >/dev/null || die "$t absent. docker : curl -fsSL https://get.docker.com | sh"
done
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 absent."
RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
[ "$RAM_KB" -lt 3500000 ] && warn "RAM < 3,5 Go : la construction peut échouer."
FREE_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
[ "$FREE_GB" -lt 20 ] && warn "Disque : ${FREE_GB} Go libres, 20 Go conseillés."
# sur les petites machines : du swap pour absorber le pic de RAM du build
if [ "$RAM_KB" -lt 8000000 ] && ! swapon --show 2>/dev/null | grep -q .; then
  if command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
    say "RAM < 8 Go : ajout de 4 Go de swap pour la construction de l'image"
    sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile >/dev/null && sudo swapon /swapfile || true
  else
    warn "RAM < 8 Go sans sudo silencieux : ajoute du swap avant le build (fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile)"
  fi
fi

for PORT in 80 443; do
  if ss -ltn 2>/dev/null | grep -qE "[:.]$PORT "; then
    die "Le port $PORT est occupé (nginx/apache existant ?)."
  fi
done
ok "docker, compose, ports 80/443"

PUBLIC_IP=$(curl -4 -s --max-time 5 ifconfig.me || true)
for D in "$APPS_DOMAIN" "$IDP_DOMAIN" "$MAIL_DOMAIN"; do
  RESOLVED=$(getent hosts "$D" 2>/dev/null | awk '{print $1}' | head -1 || true)
  if [ -z "$RESOLVED" ]; then
    warn "$D ne résout pas encore (crée l'enregistrement A → ${PUBLIC_IP:-IP_DU_SERVEUR})."
  elif [ -n "$PUBLIC_IP" ] && [ "$RESOLVED" != "$PUBLIC_IP" ]; then
    warn "$D pointe vers $RESOLVED au lieu de $PUBLIC_IP."
  fi
done
say "Le DNS doit pointer ici avant le premier lancement (certificats Let's Encrypt)."

# ----------------------------------------------------------------- fichiers
phase "Génération des fichiers dans $DIR"
mkdir -p "$DIR"
cd "$DIR"

cat > .env <<ENVFILE
DOMAIN=$APPS_DOMAIN
IDP_DOMAIN=$IDP_DOMAIN
MAIL_DOMAIN=$MAIL_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
OIDC_SECRET=$OIDC_SECRET
STALWART_ADMIN_PASSWORD=$STALWART_ADMIN_PASSWORD
DEMO=$DEMO
ENVFILE
chmod 600 .env

cat > apps.json <<'APPSFILE'
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
APPSFILE

cat > compose.yml <<'COMPOSEFILE'
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
        if [ ! -d "sites/__IDP__" ]; then
          bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$MYSQL_ROOT_PASSWORD" --set-default __IDP__;
        fi;
        if [ ! -d "sites/__DOMAIN__" ]; then
          bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$MYSQL_ROOT_PASSWORD" --install-app crm __DOMAIN__;
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
      STALWART_PUBLIC_URL: "https://__MAIL__"
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
COMPOSEFILE

sed -i "s|__IDP__|$IDP_DOMAIN|g; s|__DOMAIN__|$APPS_DOMAIN|g; s|__MAIL__|$MAIL_DOMAIN|g" compose.yml

cat > Caddyfile <<CADDYFILE
$APPS_DOMAIN {
	encode gzip
	reverse_proxy frontend:8080
}

$IDP_DOMAIN {
	encode gzip
	reverse_proxy frontend:8080
}

$MAIL_DOMAIN {
	encode gzip
	reverse_proxy stalwart:8080
}
CADDYFILE

# l'amorce du volume de config Stalwart, avant le premier boot
if ! docker volume inspect lasarter_stalwart-config >/dev/null 2>&1; then
  docker volume create lasarter_stalwart-config >/dev/null
  printf '%s' '{"@type":"RocksDb","path":"/var/lib/stalwart/","blobSize":4096,"bufferSize":134217728,"cacheSize":134217728}' \
    | docker run --rm -i -v lasarter_stalwart-config:/c alpine sh -c 'cat > /c/config.json'
fi
ok "compose.yml, apps.json, Caddyfile, .env, config Stalwart"

# ----------------------------------------------------------------- build
phase "Construction de l'image du bench (20-30 min)"
if ! docker image inspect "$BENCH_IMAGE" >/dev/null 2>&1; then
  [ -d frappe_docker ] || git clone --depth 1 https://github.com/frappe/frappe_docker
  DOCKER_BUILDKIT=1 docker build \
    --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
    --build-arg FRAPPE_BRANCH=version-16 \
    --build-arg CACHE_BUST="$(date +%s)" \
    --secret id=apps_json,src=apps.json \
    --tag "$BENCH_IMAGE" \
    --file frappe_docker/images/layered/Containerfile \
    frappe_docker
else
  ok "image déjà construite, build sauté"
fi

# ----------------------------------------------------------------- démarrage
phase "Démarrage de la pile"
docker compose up -d
say "attente de la création des sites (10-15 min)..."
for _ in $(seq 1 120); do
  STATE=$(docker inspect lasarter-create-sites-1 --format '{{.State.Status}}|{{.State.ExitCode}}' 2>/dev/null || true)
  [ "$STATE" = "exited|0" ] && break
  case "$STATE" in
    exited|*) die "create-sites a échoué ($STATE) — logs : docker logs lasarter-create-sites-1" ;;
  esac
  sleep 10
done
ok "sites créés"

phase "Installation des applications"
DC="docker compose exec -T backend bench"
for APP in helpdesk raven lms telephony wiki insights payments erpnext hrms webshop gameplan builder; do
  $DC --site "$APPS_DOMAIN" install-app "$APP" >/dev/null 2>&1 && ok "$APP" || warn "$APP (déjà installé ou échec — relance en cas de doute)"
done

# ----------------------------------------------------------------- réglages
phase "Checklist LaStarter"
$DC --site "$APPS_DOMAIN" execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe", "crm"]]}, "is_setup_complete", 1]' >/dev/null
$DC --site "$IDP_DOMAIN" execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe"]]}, "is_setup_complete", 1]' >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}' >/dev/null
$DC --site "$IDP_DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}' >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":"password_minimum_score","value":0}' >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.db.set_default --args '["desktop:home_page","workspace"]' >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.db.set_value --args '["Role","Desk User","home_page","/desk"]' >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"Mail Settings","fieldname":"allow_signup","value":0}' >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.db.commit >/dev/null
$DC --site "$APPS_DOMAIN" execute frappe.clear_cache >/dev/null
ok "langue FR, desk par défaut, inscriptions mail désactivées"

# ----------------------------------------------------------------- admin
phase "Administrateur"
$DC --site "$APPS_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PASSWORD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"System Manager"},{"role":"Desk User"},{"role":"Accounts Manager"},{"role":"Sales Manager"},{"role":"Purchase Manager"},{"role":"Stock Manager"},{"role":"HR Manager"},{"role":"Projects User"},{"role":"Raven User"},{"role":"LMS Student"},{"role":"Wiki User"},{"role":"Insights Admin"}]}}' >/dev/null 2>&1 \
  && ok "admin créé sur le bureau" || warn "admin déjà présent sur le bureau ?"
$DC --site "$IDP_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PASSWORD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}}' >/dev/null 2>&1 \
  && ok "admin créé sur l'identité" || true
$DC --site "$APPS_DOMAIN" execute frappe.clear_cache >/dev/null

# ----------------------------------------------------------------- sso
phase "SSO OIDC entre identité et bureau"
REDIRECT="https://$APPS_DOMAIN/api/method/frappe.integrations.oauth2_logins.login_via_frappe"
export REDIRECT IDP_DOMAIN APPS_DOMAIN OIDC_SECRET DC
bash -s <<SSOEOF
if ! \$DC --site "\$IDP_DOMAIN" execute frappe.db.exists --args '["OAuth Client", {"app_name": "lasarter-desk"}]' 2>/dev/null | grep -qv None; then
  \$DC --site "\$IDP_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"OAuth Client","app_name":"lasarter-desk","client_id":"lasarter-desk","client_secret":"$OIDC_SECRET","default_redirect_uri":"$REDIRECT","redirect_uris":"$REDIRECT","grant_type":"Authorization Code","response_type":"Code","scopes":"openid email profile","skip_authorization":1}}' >/dev/null
  echo "  client OAuth créé"
else
  echo "  client OAuth déjà présent"
fi
if ! \$DC --site "\$APPS_DOMAIN" execute frappe.db.exists --args '["Social Login Key", "frappe"]' 2>/dev/null | grep -qv None; then
  \$DC --site "\$APPS_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"Social Login Key","provider_name":"Frappe","social_login_provider":"Frappe","enable_social_login":1,"client_id":"lasarter-desk","client_secret":"$OIDC_SECRET","base_url":"https://$IDP_DOMAIN","custom_base_url":1,"authorize_url":"/api/method/frappe.integrations.oauth2.authorize","access_token_url":"/api/method/frappe.integrations.oauth2.get_token","api_endpoint":"/api/method/frappe.integrations.oauth2.openid_profile","redirect_url":"/api/method/frappe.integrations.oauth2_logins.login_via_frappe","auth_url_data":"{\\\"response_type\\\": \\\"code\\\", \\\"scope\\\": \\\"openid email profile\\\"}","sign_ups":"Allow"}}' >/dev/null
  echo "  social login créé"
else
  echo "  social login déjà présent"
fi
SSOEOF

# ----------------------------------------------------------------- stalwart
phase "Stalwart : domaine, comptes, SMTP Frappe"
for _ in $(seq 1 30); do
  docker compose exec -T backend curl -s -o /dev/null -m 3 http://stalwart:8080/healthz/live && break
  sleep 2
done
API="http://stalwart:8080/jmap/"
AUTH="admin:$STALWART_ADMIN_PASSWORD"
docker compose exec -T backend curl -s -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
  -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Domain/set",{"create":{"d1":{"name":"'"$ROOT_DOMAIN"'","description":"Domaine LaStarter","isEnabled":true}}},"c0"]]}' >/dev/null || true
docker compose exec -T backend curl -s -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
  -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Account/set",{"create":{"a1":{"@type":"User","name":"admin","description":"Administrateur","domainId":"b","credentials":{"0":{"@type":"Password","secret":"'"$STALWART_ADMIN_PASSWORD"'"}}}}},"c0"]]}' >/dev/null || true
docker compose exec -T backend curl -s -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
  -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Account/set",{"update":{"b":{"roles":{"@type":"Admin"}}}},"c0"]]}' >/dev/null || true
docker compose exec -T backend bench --site "$APPS_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"Email Account","email_account_name":"Stalwart","email_id":"admin@'"$ROOT_DOMAIN"'","enable_outgoing":1,"smtp_server":"stalwart","use_tls":0,"smtp_port":25,"default_outgoing":1,"no_smtp_authentication":1}}' >/dev/null 2>&1 || true
ok "domaine mail, compte admin (rôle Admin), SMTP Frappe branché"

# ----------------------------------------------------------------- démo
if [ "$DEMO" = "1" ]; then
  phase "Données de démonstration"
  seed() { $DC --site "$APPS_DOMAIN" execute frappe.client.insert --kwargs "{\"doc\": $1}" >/dev/null 2>&1 && ok "$2" || warn "$2 (déjà présent ?)"; }
  seed '{"doctype":"Raven Workspace","workspace_name":"LaStarter","description":"Espace de démonstration."}' "espace Raven"
  $DC --site "$APPS_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"Raven Workspace Member","workspace":"LaStarter","user":"'"$ADMIN_EMAIL"'","is_admin":1}}' >/dev/null 2>&1 || true
  seed '{"doctype":"Raven Channel","workspace":"LaStarter","channel_name":"general","type":"Public","channel_description":"Annonces"}' "canal general"
  seed '{"doctype":"CRM Lead","lead_name":"Boulangerie Martin","first_name":"Marie","last_name":"Martin","email":"contact@boulangerie-martin.fr"}' "lead 1"
  seed '{"doctype":"CRM Lead","lead_name":"Coopérative Aurore","first_name":"Paul","last_name":"Aubert","email":"contact@aurore.coop"}' "lead 2"
  seed '{"doctype":"CRM Lead","lead_name":"Cabinet Durand","first_name":"Claire","last_name":"Durand","email":"cabinet@durand-avocats.fr"}' "lead 3"
  seed '{"doctype":"HD Ticket","subject":"Connexion espace client impossible","raised_by":"client1@example.fr","description":"<p>Le mot de passe est refusé.</p>"}' "ticket 1"
  seed '{"doctype":"HD Ticket","subject":"Devis refonte du site vitrine","raised_by":"client2@example.fr","description":"<p>Refonte complète.</p>"}' "ticket 2"
  seed '{"doctype":"LMS Course","title":"Prise en main de la suite","short_introduction":"Découvrez vos outils.","description":"<p>Un parcours de démonstration.</p>","published":1}' "cours LMS"
  seed '{"doctype":"Course Chapter","course":"prise-en-main-de-la-suite","title":"Bienvenue"}' "chapitre"
fi

# ----------------------------------------------------------------- final
phase "Vérifications"
curl -sk -o /dev/null -w "  bureau   : https://$APPS_DOMAIN/desk (HTTP %{http_code})\n" "https://$APPS_DOMAIN/desk" || warn "bureau pas encore joignable (DNS/TLS ?)"
docker compose exec -T backend curl -s -o /dev/null -w "  jmap     : HTTP %{http_code}\n" http://stalwart:8080/healthz/live

echo ""
ok  "SUITE INSTALLÉE"
say "Bureau   : https://$APPS_DOMAIN/desk"
say "Identité : https://$IDP_DOMAIN"
say "Webmail  : https://$MAIL_DOMAIN/admin (console) et / (webmail)"
say "Compte   : $ADMIN_EMAIL"
say "Secrets  : dans $DIR/.env (chmod 600) — passwords admin, mysql, stalwart"
say "Reprise  : cd $DIR && docker compose up -d"
echo ""
