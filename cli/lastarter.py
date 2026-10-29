#!/usr/bin/env python3
"""lastarter — installation assistée de la suite LaStarter sur un serveur Linux.

Un seul fichier, zéro dépendance : python3 lastarter.py suffit (Ubuntu
22.04/24.04, Debian 12). Vérifie le serveur, pose les questions, génère la
pile docker (bench Frappe v16 épinglé, SSO OIDC, Caddy HTTPS, Stalwart
optionnel), imprime la checklist DNS, puis construit et installe.

Le code généré t'appartient (MIT).
"""
import os
import random
import re
import shutil
import socket
import string
import subprocess
import sys
import urllib.request

REPO = "https://raw.githubusercontent.com/LaStarterSuite/LaStarterProject/main"
PACKS = {
    "full": [
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
        {"url": "https://github.com/frappe/builder", "branch": "develop"},
    ],
    "minimal": [
        {"url": "https://github.com/frappe/crm", "branch": "main"},
        {"url": "https://github.com/frappe/helpdesk", "branch": "main"},
        {"url": "https://github.com/frappe/raven", "branch": "main"},
        {"url": "https://github.com/frappe/lms", "branch": "main"},
    ],
}

# ---------------------------------------------------------------- présentation


def c(text, code):
    return f"\033[{code}m{text}\033[0m"


def info(msg):
    print(c("  • ", "36") + msg)


def ok(msg):
    print(c("  ✓ ", "32") + msg)


def warn(msg):
    print(c("  ! ", "33") + msg)


def fail(msg):
    print(c("  ✗ ", "31") + msg)


def header(title):
    print("\n" + c(f"════ {title} ".ljust(64, "═"), "1;36"))


def password(length=15):
    alphabet = string.ascii_letters + string.digits
    return "".join(random.choice(alphabet) for _ in range(length))


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


# ------------------------------------------------------------------ contrôles


def port_busy(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1)
        return s.connect_ex(("127.0.0.1", port)) == 0


def run_checks():
    problems = []
    if sys.platform != "linux":
        problems.append("Cible Linux uniquement (Ubuntu 22.04/24.04 ou Debian 12).")
    for tool, hint in [
        ("docker", "curl -fsSL https://get.docker.com | sh"),
        ("git", "sudo apt-get install -y git"),
        ("curl", "sudo apt-get install -y curl"),
    ]:
        if shutil.which(tool) is None:
            problems.append(f"{tool} absent : {hint}")
    if shutil.which("docker") and subprocess.run(
        ["docker", "compose", "version"], capture_output=True
    ).returncode != 0:
        problems.append("Docker Compose v2 absent (inclus dans docker-ce récent).")
    meminfo = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, _, value = line.partition(":")
            meminfo[key.strip()] = int(value.strip().split()[0])
    ram_gb = meminfo.get("MemTotal", 0) / 1024 ** 2
    if ram_gb < 3.5:
        problems.append(f"RAM : {ram_gb:.1f} Go détectés, 4 Go minimum.")
    try:
        free_gb = os.statvfs("/").f_bavail * os.statvfs("/").f_frsize / 1024 ** 3
        if free_gb < 20:
            problems.append(f"Disque : {free_gb:.0f} Go libres, 20 Go minimum.")
    except OSError:
        pass
    for port in (80, 443):
        if port_busy(port):
            problems.append(f"Port {port} occupé (nginx/apache existant ?).")
    return problems


# ------------------------------------------------------------------ questions


def ask(label, default="", validator=None):
    while True:
        suffix = f" [{default}]" if default else ""
        raw = input(c(f"  ? {label}{suffix} : ", "1;36")).strip() or default
        if validator:
            error = validator(raw)
            if error:
                warn(error)
                continue
        return raw


def ask_yesno(label, default=True):
    hint = "O/n" if default else "o/N"
    raw = input(c(f"  ? {label} [{hint}] : ", "1;36")).strip().lower()
    if not raw:
        return default
    return raw in ("o", "oui", "y", "yes")


def is_domain(value):
    if not value or "." not in value:
        return "Un vrai domaine, avec un point."
    return None


def is_email(value):
    if "@" not in value:
        return "Un email valide svp."
    return None


def gather_answers():
    a = {}
    a["domain"] = ask("Domaine principal du client (le bureau y vivra)", validator=is_domain)
    a["idp_domain"] = ask("Domaine de l'identité (SSO OIDC)", f"id.{a['domain']}", is_domain)
    choice = ask("Pack d'applications : 1) complète 14 apps  2) démo commerciale (CRM+Helpdesk+Raven+LMS)", "1")
    a["pack"] = "minimal" if choice == "2" else "full"
    a["admin_email"] = ask("Email du compte administrateur", validator=is_email)
    a["admin_password"] = ask("Mot de passe administrateur", password())
    a["demo"] = ask_yesno("Semer des données de démonstration ?", True)
    a["stalwart"] = ask_yesno("Installer le serveur mail Stalwart ?", True)
    if a["stalwart"]:
        a["mail_domain"] = ask("Domaine du webmail/serveur mail", f"mail.{a['domain']}", is_domain)
    tls = ask("HTTPS : 1) Caddy certificats automatiques (recommandé)  2) HTTP seul (tests)", "1")
    a["tls"] = "none" if tls == "2" else "caddy"
    a["dir"] = os.path.expanduser(ask("Répertoire d'installation", "~/lastarter"))
    a["mysql_root"] = password()
    a["secret"] = password()
    if a["stalwart"]:
        a["stalwart_admin"] = password()
        a["stalwart_alice"] = password()
    return a


def public_ip():
    for url in ("https://ifconfig.me", "https://api.ipify.org"):
        try:
            ip = urllib.request.urlopen(url, timeout=5).read().decode().strip()
            if re.fullmatch(r"\d+\.\d+\.\d+\.\d+", ip):
                return ip
        except Exception:
            continue
    return None


# ------------------------------------------------------------------- pile
COMPOSE = """name: lasarter
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
      - "@@DOMAIN@@:host-gateway"
      - "@@IDP@@:host-gateway"
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
        if [ ! -d "sites/@@IDP@@" ]; then
          bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$MYSQL_ROOT_PASSWORD" --set-default @@IDP@@;
        fi;
        if [ ! -d "sites/@@DOMAIN@@" ]; then
          bench new-site --mariadb-user-host-login-scope='%' --admin-password="$$ADMIN_PASSWORD" --db-root-username=root --db-root-password="$$MYSQL_ROOT_PASSWORD" --install-app crm @@DOMAIN@@;
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
    ports: [@@FRONTEND_PORTS@@]

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
@@STALWART_BLOCK@@
@@CADDY_BLOCK@@
volumes:
  db-data:
  sites:
  logs:
  redis-queue-data:
@@STALWART_VOLUMES@@
@@CADDY_VOLUMES@@
networks:
  lasarter:
    driver: bridge
"""

STALWART_BLOCK = """
  stalwart:
    image: stalwartlabs/stalwart:v0.16.27
    networks: [lasarter]
    restart: on-failure
    environment:
      STALWART_PUBLIC_URL: "https://@@MAIL_DOMAIN@@"
      STALWART_RECOVERY_ADMIN: "admin:${STALWART_ADMIN_PASSWORD}"
    volumes:
      - stalwart-config:/etc/stalwart
      - stalwart-data:/var/lib/stalwart
"""
STALWART_VOLUMES = "  stalwart-config:\n  stalwart-data:"

CADDY_BLOCK = """
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
"""
CADDY_VOLUMES = "  caddy-data:\n  caddy-config:"


def caddyfile(a):
    domains = [a["domain"], a["idp_domain"]] + ([a["mail_domain"]] if a.get("stalwart") else [])
    return "\n\n".join(
        f"{d} {{\n\tencode gzip\n\treverse_proxy frontend:8080\n}}" for d in domains
    ) + "\n"


def write_stack(a):
    d = a["dir"]
    os.makedirs(d, exist_ok=True)
    compose = COMPOSE.replace("@@DOMAIN@@", a["domain"]).replace("@@IDP@@", a["idp_domain"])
    compose = compose.replace("@@FRONTEND_PORTS@@", '"8080:8080"' if a["tls"] == "caddy" else '"80:8080"')
    compose = compose.replace("@@STALWART_BLOCK@@", STALWART_BLOCK if a["stalwart"] else "")
    compose = compose.replace("@@STALWART_VOLUMES@@", STALWART_VOLUMES if a["stalwart"] else "")
    compose = compose.replace("@@CADDY_BLOCK@@", CADDY_BLOCK if a["tls"] == "caddy" else "")
    compose = compose.replace("@@CADDY_VOLUMES@@", CADDY_VOLUMES if a["tls"] == "caddy" else "")
    compose = compose.replace("@@MAIL_DOMAIN@@", a.get("mail_domain", ""))
    compose = re.sub(r"\n{3,}", "\n\n", compose)
    with open(os.path.join(d, "compose.yml"), "w", encoding="utf-8") as f:
        f.write(compose)

    with open(os.path.join(d, "apps.json"), "w", encoding="utf-8") as f:
        import json

        json.dump(PACKS[a["pack"]], f, indent=2)
        f.write("\n")

    env = [
        f"DOMAIN={a['domain']}",
        f"IDP_DOMAIN={a['idp_domain']}",
        f"ADMIN_EMAIL={a['admin_email']}",
        f"ADMIN_PASSWORD={a['admin_password']}",
        f"MYSQL_ROOT_PASSWORD={a['mysql_root']}",
        f"SECRET={a['secret']}",
        f"PACK={a['pack']}",
        f"DEMO={'1' if a['demo'] else '0'}",
        f"TLS={a['tls']}",
    ]
    if a["stalwart"]:
        env += [
            "STALWART=1",
            f"MAIL_DOMAIN={a['mail_domain']}",
            f"STALWART_ADMIN_PASSWORD={a['stalwart_admin']}",
            f"STALWART_DOMAIN={a['domain']}",
            f"STALWART_ALICE_PASSWORD={a['stalwart_alice']}",
        ]
    with open(os.path.join(d, ".env"), "w", encoding="utf-8") as f:
        f.write("\n".join(env) + "\n")
    os.chmod(os.path.join(d, ".env"), 0o600)

    if a["tls"] == "caddy":
        with open(os.path.join(d, "Caddyfile"), "w", encoding="utf-8") as f:
            f.write(caddyfile(a))

    if not os.path.isdir(os.path.join(d, "frappe_docker")):
        sh("git clone --depth 1 https://github.com/frappe/frappe_docker frappe_docker")
    return d


# ------------------------------------------------------- provisioning généré

PROVISION = r"""#!/usr/bin/env bash
# Généré par lastarter — installation complète et idempotente de la suite.
set -e
cd "$(dirname "$0")"
set -a
source .env
set +a

DC="docker compose -f compose.yml"

phase() { echo ""; echo "════ $1 ════"; }

phase "1. construction de l'image du bench (apps épinglées, 20-30 min)"
export DOCKER_BUILDKIT=1
docker build \
  --build-arg FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg FRAPPE_BRANCH=version-16 \
  --build-arg CACHE_BUST="$(date +%s)" \
  --secret id=apps_json,src=apps.json \
  --tag lasarter-bench:16 \
  --file frappe_docker/images/layered/Containerfile \
  frappe_docker

phase "2. démarrage de la pile"
$DC up -d
echo "attente de la création des sites..."
for i in $(seq 1 120); do
  STATE=$(docker inspect lasarter-create-sites-1 --format '{{.State.Status}}|{{.State.ExitCode}}' 2>/dev/null)
  [ "$STATE" = "exited|0" ] && break
  case "$STATE" in exited|*) echo "create-sites a échoué ($STATE)"; exit 1;; esac
  sleep 10
done
$DC exec backend bench --site "$IDP_DOMAIN" list-apps | grep -q frappe || { echo "frappe absent"; exit 1; }
$DC exec backend bench --site "$DOMAIN" install-app helpdesk >/dev/null 2>&1 || true
if [ "$PACK" = "full" ]; then
  for APP in erpnext hrms webshop wiki insights raven lms builder payments telephony; do
    $DC exec backend bench --site "$DOMAIN" install-app "$APP" || exit 1
  done
else
  for APP in helpdesk raven lms; do
    $DC exec backend bench --site "$DOMAIN" install-app "$APP" || exit 1
  done
fi

phase "3. marqueurs d'installation et réglages"
$DC exec backend bench --site "$DOMAIN" execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe", "crm"]]}, "is_setup_complete", 1]' >/dev/null
$DC exec backend bench --site "$IDP_DOMAIN" execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe"]]}, "is_setup_complete", 1]' >/dev/null
$DC exec backend bench --site "$DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}' >/dev/null
$DC exec backend bench --site "$IDP_DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}' >/dev/null
$DC exec backend bench --site "$DOMAIN" execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":"password_minimum_score","value":0}' >/dev/null
$DC exec backend bench --site "$DOMAIN" execute frappe.db.set_default --args '["desktop:home_page","workspace"]' >/dev/null
$DC exec backend bench --site "$DOMAIN" execute frappe.db.set_value --args '["Role","Desk User","home_page","/desk"]' >/dev/null
$DC exec backend bench --site "$DOMAIN" execute frappe.db.commit >/dev/null
$DC exec backend bench --site "$DOMAIN" execute frappe.clear_cache >/dev/null

phase "4. câblage SSO OIDC entre les deux sites"
SECRET_REF="$SECRET" REDIRECT="https://$DOMAIN/api/method/frappe.integrations.oauth2_logins.login_via_frappe" IDP="$IDP_DOMAIN" DOMAIN="$DOMAIN" bash -s <<OIDC
if ! $DC exec backend bench --site "$IDP" execute frappe.db.exists --args '["OAuth Client", {"app_name": "lasarter-desk"}]' 2>/dev/null | grep -qv None; then
  $DC exec backend bench --site "$IDP" execute frappe.client.insert --kwargs "{\"doc\":{\"doctype\":\"OAuth Client\",\"app_name\":\"lasarter-desk\",\"client_id\":\"lasarter-desk\",\"client_secret\":\"$SECRET_REF\",\"default_redirect_uri\":\"$REDIRECT\",\"redirect_uris\":\"$REDIRECT\",\"grant_type\":\"Authorization Code\",\"response_type\":\"Code\",\"scopes\":\"openid email profile\",\"skip_authorization\":1}}" >/dev/null
fi
if ! $DC exec backend bench --site "$DOMAIN" execute frappe.db.exists --args '["Social Login Key", "frappe"]' 2>/dev/null | grep -qv None; then
  $DC exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs "{\"doc\":{\"doctype\":\"Social Login Key\",\"provider_name\":\"Frappe\",\"social_login_provider\":\"Frappe\",\"enable_social_login\":1,\"client_id\":\"lasarter-desk\",\"client_secret\":\"$SECRET_REF\",\"base_url\":\"https://$IDP\",\"custom_base_url\":1,\"authorize_url\":\"/api/method/frappe.integrations.oauth2.authorize\",\"access_token_url\":\"/api/method/frappe.integrations.oauth2.get_token\",\"api_endpoint\":\"/api/method/frappe.integrations.oauth2.openid_profile\",\"redirect_url\":\"/api/method/frappe.integrations.oauth2_logins.login_via_frappe\",\"auth_url_data\":\"{\\\"response_type\\\": \\\"code\\\", \\\"scope\\\": \\\"openid email profile\\\"}\",\"sign_ups\":\"Allow\"}}" >/dev/null
fi
echo "SSO câblé"
OIDC

phase "5. administrateur"
$DC exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PASSWORD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"System Manager"},{"role":"Desk User"},{"role":"Accounts Manager"},{"role":"Sales Manager"},{"role":"Purchase Manager"},{"role":"Stock Manager"},{"role":"HR Manager"},{"role":"Projects User"},{"role":"Raven User"},{"role":"LMS Student"},{"role":"Wiki User"},{"role":"Insights Admin"}]}}' >/dev/null 2>&1 || echo "admin déjà présent"
$DC exec backend bench --site "$IDP_DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PASSWORD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}}' >/dev/null 2>&1 || true
$DC exec backend bench --site "$DOMAIN" execute frappe.clear_cache >/dev/null

phase "6. données de démonstration"
if [ "$DEMO" = "1" ]; then
  seed() { $DC exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs "{\"doc\": $1}" >/dev/null 2>&1 && echo "  ✓ $2" || echo "  - $2 (déjà présent ?)"; }
  seed '{"doctype":"Raven Workspace","workspace_name":"LaStarter","description":"Espace de démonstration."}' "espace Raven"
  $DC exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"Raven Workspace Member","workspace":"LaStarter","user":"'"$ADMIN_EMAIL"'","is_admin":1}}' >/dev/null 2>&1 || true
  seed '{"doctype":"Raven Channel","workspace":"LaStarter","channel_name":"general","type":"Public","channel_description":"Annonces"}' "canal general"
  seed '{"doctype":"CRM Lead","lead_name":"Boulangerie Martin","first_name":"Marie","last_name":"Martin","email":"contact@boulangerie-martin.fr"}' "lead 1"
  seed '{"doctype":"CRM Lead","lead_name":"Coopérative Aurore","first_name":"Paul","last_name":"Aubert","email":"contact@aurore.coop"}' "lead 2"
  seed '{"doctype":"CRM Lead","lead_name":"Cabinet Durand","first_name":"Claire","last_name":"Durand","email":"cabinet@durand-avocats.fr"}' "lead 3"
  seed '{"doctype":"HD Ticket","subject":"Connexion espace client impossible","raised_by":"client1@example.fr","description":"<p>Le mot de passe est refusé.</p>"}' "ticket 1"
  seed '{"doctype":"HD Ticket","subject":"Devis refonte du site vitrine","raised_by":"client2@example.fr","description":"<p>Refonte complète.</p>"}' "ticket 2"
  seed '{"doctype":"LMS Course","title":"Prise en main de la suite","short_introduction":"Découvrez vos outils.","description":"<p>Un parcours de démonstration.</p>","published":1}' "cours LMS"
  seed '{"doctype":"Course Chapter","course":"prise-en-main-de-la-suite","title":"Bienvenue"}' "chapitre"
fi

if [ "$STALWART" = "1" ]; then
phase "7. serveur mail Stalwart (comptes internes)"
  for i in $(seq 1 30); do
    $DC exec backend curl -s -o /dev/null -m 3 "http://stalwart:8080/healthz/live" && break
    sleep 2
  done
  API="http://stalwart:8080/jmap/"
  AUTH="admin:$STALWART_ADMIN_PASSWORD"
  $DC exec backend curl -s -m 8 -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
    -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Domain/set",{"create":{"d1":{"name":"'"$STALWART_DOMAIN"'","description":"Domaine LaStarter","isEnabled":true}}},"c0"]]}' >/dev/null
  $DC exec backend curl -s -m 8 -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
    -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Account/set",{"create":{"a1":{"@type":"User","name":"admin","description":"Administrateur","domainId":"b","credentials":{"0":{"@type":"Password","secret":"'"$STALWART_ADMIN_PASSWORD"'"}}}}},"c0"]]}' >/dev/null
  $DC exec backend curl -s -m 8 -u "$AUTH" -X POST "$API" -H "Content-Type: application/json" \
    -d '{"using":["urn:stalwart:jmap"],"methodCalls":[["x:Account/set",{"update":{"b":{"roles":{"@type":"Admin"}}}},"c0"]]}' >/dev/null
  $DC exec backend bench --site "$DOMAIN" execute frappe.client.insert --kwargs '{"doc":{"doctype":"Email Account","email_account_name":"Stalwart","email_id":"admin@'"$STALWART_DOMAIN"'","enable_outgoing":1,"smtp_server":"stalwart","use_tls":0,"smtp_port":25,"default_outgoing":1,"no_smtp_authentication":1}}' >/dev/null 2>&1 || true
  echo "  ✓ domaine et compte mail admin créés (webmail : https://$MAIL_DOMAIN)"
fi

phase "8. vérifications"
curl -s -o /dev/null -w "  bureau HTTP %{http_code}\n" "http://localhost/desk" || true
$DC exec backend bench --site "$DOMAIN" execute frappe.db.get_single_value --args '["System Settings","setup_complete"]' >/dev/null && echo "  site configuré"
echo ""
echo "════ SUITE INSTALLÉE ════"
echo "  Bureau   : https://$DOMAIN/desk  (connexion : $ADMIN_EMAIL)"
echo "  Identité : https://$IDP_DOMAIN"
[ "$STALWART" = "1" ] && echo "  Webmail  : https://$MAIL_DOMAIN"
echo "  Reprise  : docker compose up -d"
"""


def write_provision(a, d):
    script = (
        PROVISION.replace("@@DOMAIN@@", a["domain"])
        .replace("@@IDP@@", a["idp_domain"])
        .replace("@@MAIL_DOMAIN@@", a.get("mail_domain", ""))
    )
    path = os.path.join(d, "provision.sh")
    with open(path, "w", encoding="utf-8") as f:
        f.write(script)
    os.chmod(path, 0o755)
    return path


# ---------------------------------------------------------------------- main


def main():
    print(c("\n  lastarter — la suite collaborative auto-hébergée (Frappe v16)\n", "1;36"))
    header("Vérification du serveur")
    problems = run_checks()
    if problems:
        for problem in problems:
            warn(problem)
        print(c("\n  Corrige les points ci-dessus puis relance : python3 lastarter.py\n", "1"))
        sys.exit(1)
    ok("Serveur prêt (docker, compose, ports 80/443, RAM, disque)")

    header("Questions")
    a = gather_answers()

    header("Génération")
    d = write_stack(a)
    write_provision(a, d)
    ok(f"Pile générée dans {d}")

    header("Checklist DNS à créer chez ton registrar")
    ip = public_ip()
    print(f"  IP publique : {ip or '<prends l IP de ton serveur : ip a>'}")
    records = [(a["domain"], ip), (a["idp_domain"], ip)]
    if a["stalwart"]:
        records.append((a["mail_domain"], ip))
    for host, _ in records:
        print(f"  A   {host.ljust(30)} →  {ip or '<IP_DU_SERVEUR>'}")
    if a["stalwart"]:
        print(f"  MX  {a['domain'].ljust(30)} →  {a['mail_domain']}")
    if a["tls"] == "caddy":
        print("  Le DNS doit pointer ici AVANT le lancement (certificats Let's Encrypt).")

    print()
    launch = ask_yesno("Lancer la construction et l'installation maintenant ? (20-30 min)", True)
    if not launch:
        print(c(f"\n  Tout est prêt dans {d}. Quand tu veux : bash {d}/provision.sh\n", "1"))
        return
    code = subprocess.run(["bash", "provision.sh"], cwd=d).returncode
    if code == 0:
        print(c(f"\n  ✓ Suite installée — bureau : https://{a['domain']}/desk\n", "1;32"))
    else:
        fail(f"L'installation a échoué (code {code}) : relance bash {d}/provision.sh")
        sys.exit(code)


if __name__ == "__main__":
    main()
