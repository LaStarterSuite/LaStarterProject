#!/bin/sh
# Reset complet + provisionnement de la pile POC LaStarter v2.
# Destruction des volumes, recreation des deux sites, installation des 13
# apps, configuration complete et donnees de demonstration. Idempotent :
# chaque etape verifie avant d'ecrire, les echecs sont affiches.
#
# Usage : sh poc/reset-and-provision.sh
# Destructif : supprime db-data, redis-queue-data, sites, logs.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
DC="docker compose -f $ROOT/poc/compose.yml"

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PWD="${ADMIN_PWD:-admin-LaStarter-2026}"
ALICE_PWD="${ALICE_PWD:-poc-password-1234}"
DEMO_PWD="${DEMO_PWD:-demo-password-1234}"

echo "════════ PHASE 1 : destruction des volumes ════════"
$DC down -v --remove-orphans 2>&1 | tail -3

echo "════════ PHASE 2 : recreation de la pile ════════"
$DC up -d 2>&1 | tail -3

echo "attente de la fin de create-sites (installation crm+helpdesk incluse)..."
I=0
while [ $I -lt 120 ]; do
  STATE=$(docker inspect poc-create-sites-1 --format "{{.State.Status}}|{{.State.ExitCode}}" 2>/dev/null)
  case "$STATE" in
    exited\|0)
      echo "create-sites termine avec succes apres ${I}0 s env."
      break
      ;;
    exited\|*)
      echo "ECHEC : create-sites a echoue ($STATE)"; exit 1
      ;;
  esac
  sleep 10
  I=$((I + 1))
done
[ $I -lt 120 ] || { echo "ECHEC : create-sites pas fini en 20 min"; exit 1; }
sleep 5
# Precondition dure : frappe + crm + helpdesk doivent etre listes.
LIST=$($DC exec -T backend bench --site crm.localhost list-apps 2>/dev/null)
echo "$LIST" | grep -q frappe || { echo "ECHEC : frappe absent"; echo "$LIST"; exit 1; }
echo "$LIST" | grep -q crm || { echo "ECHEC : crm absent"; echo "$LIST"; exit 1; }
echo "$LIST" | grep -q helpdesk || { echo "ECHEC : helpdesk absent"; echo "$LIST"; exit 1; }
echo "socle OK (frappe, crm, helpdesk)"

echo "════════ PHASE 3 : installation des apps restantes ════════"
# Ordre : erpnext d'abord (hrms et webshop l'exigent), payments viendra
# tout seul avec lms (required_apps). PAS de pipe : le code de sortie doit
# rester celui de bench et la progression partir dans le journal.
for APP in erpnext hrms webshop wiki insights raven lms builder; do
  echo "── install-app $APP"
  $DC exec -T backend bench --site crm.localhost install-app "$APP" || exit 1
done
echo "apps installees :"
$DC exec -T backend bench --site crm.localhost list-apps

echo "════════ PHASE 4 : marqueurs de setup (APRES les installs) ════════"
# Piege grave : la redirection desk -> setup-wizard lit les lignes
# Installed Application (frappe ET erpnext) ; install-app les cree a 0.
$DC exec -T backend bench --site crm.localhost execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe", "erpnext", "hrms", "webshop", "builder", "crm", "helpdesk", "telephony", "wiki", "insights", "raven", "lms", "payments"]]}, "is_setup_complete", 1]' >/dev/null && echo "Installed Application : tous a 1"
$DC exec -T backend bench --site id.localhost execute frappe.db.set_value --args '["Installed Application", {"app_name": ["in", ["frappe"]]}, "is_setup_complete", 1]' >/dev/null
$DC exec -T backend bench --site crm.localhost execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}' >/dev/null && echo "System Settings crm : fr + setup_complete"
$DC exec -T backend bench --site id.localhost execute frappe.db.set_single_value --kwargs '{"doctype":"System Settings","fieldname":{"language":"fr","setup_complete":1}}' >/dev/null && echo "System Settings id : fr + setup_complete"
# Controle anti-pollution : DefaultValue setup_complete doit etre ABSENT
POLL=$($DC exec -T backend bench --site crm.localhost execute frappe.db.get_all --kwargs '{"doctype":"DefaultValue","filters":{"defkey":"setup_complete"},"fields":["name"]}')
if [ "$POLL" = "[]" ] || [ -z "$POLL" ]; then echo "DefaultValue setup_complete : propre"; else
  echo "pollution detectee, suppression..."
  $DC exec -T backend bench --site crm.localhost execute frappe.db.delete --args '["DefaultValue", {"defkey": "setup_complete", "parent": "__default"}]' >/dev/null
  $DC exec -T backend bench --site id.localhost execute frappe.db.delete --args '["DefaultValue", {"defkey": "setup_complete", "parent": "__default"}]' >/dev/null
fi
$DC exec -T backend bench --site crm.localhost execute frappe.clear_cache >/dev/null
$DC exec -T backend bench --site id.localhost execute frappe.clear_cache >/dev/null

echo "════════ PHASE 5 : cablage OIDC ════════"
sh "$ROOT/poc/oidc-setup.sh"

echo "════════ PHASE 6 : utilisateurs ════════"
seed() { # $1 site, $2 doc JSON ; affiche l'erreur si echec
  if ! $DC exec -T backend bench --site "$1" execute frappe.client.insert --kwargs "{\"doc\": $2}" >/dev/null 2>&1; then
    echo "    ECHEC:"; $DC exec -T backend bench --site "$1" execute frappe.client.insert --kwargs "{\"doc\": $2}" 2>&1 | tail -2
  else echo "    OK"; fi
}

echo "── admin (crm) : $ADMIN_EMAIL"
seed crm.localhost '{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"System Manager"},{"role":"Accounts Manager"},{"role":"Sales Manager"},{"role":"Stock Manager"},{"role":"HR Manager"},{"role":"Desk User"},{"role":"Raven User"},{"role":"LMS Student"},{"role":"Wiki User"},{"role":"Insights Admin"}]}'
echo "── admin (id) : $ADMIN_EMAIL"
seed id.localhost '{"doctype":"User","email":"'"$ADMIN_EMAIL"'","first_name":"Admin","new_password":"'"$ADMIN_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}'
echo "── alice (crm)"
seed crm.localhost '{"doctype":"User","email":"alice@example.com","first_name":"alice","last_name":"demo","new_password":"'"$ALICE_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"System Manager"},{"role":"Desk User"},{"role":"Sales User"},{"role":"Agent"},{"role":"Accounts User"},{"role":"Stock User"},{"role":"Projects User"},{"role":"HR User"},{"role":"Website Manager"},{"role":"Raven User"},{"role":"LMS Student"},{"role":"Wiki User"},{"role":"Insights Admin"}]}'
echo "── alice (id)"
seed id.localhost '{"doctype":"User","email":"alice@example.com","first_name":"alice","last_name":"demo","new_password":"'"$ALICE_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}'
echo "── bob (id, JIT a observer)"
seed id.localhost '{"doctype":"User","email":"bob@example.com","first_name":"bob","new_password":"'"$ALICE_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}'
echo "── demo visiteur (crm)"
seed crm.localhost '{"doctype":"User","email":"demo@example.com","first_name":"Visiteur","new_password":"'"$DEMO_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"},{"role":"Sales User"},{"role":"Agent"},{"role":"Raven User"},{"role":"LMS Student"}]}'
echo "── demo visiteur (id)"
seed id.localhost '{"doctype":"User","email":"demo@example.com","first_name":"Visiteur","new_password":"'"$DEMO_PWD"'","language":"fr","user_type":"System User","send_welcome_email":0,"roles":[{"role":"Desk User"}]}'
echo "── Administrator en francais"
$DC exec -T backend bench --site crm.localhost execute frappe.client.set_value --kwargs '{"doctype":"User","name":"Administrator","fieldname":"language","value":"fr"}' >/dev/null 2>&1 && echo "    OK crm"
$DC exec -T backend bench --site id.localhost execute frappe.client.set_value --kwargs '{"doctype":"User","name":"Administrator","fieldname":"language","value":"fr"}' >/dev/null 2>&1 && echo "    OK id"

echo "════════ PHASE 7 : donnees de reference ERP/HR ════════"
echo "── Gender Female"
seed crm.localhost '{"doctype":"Gender","gender":"Female"}'
echo "── Warehouse Type Transit"
seed crm.localhost '{"doctype":"Warehouse Type","warehouse_type":"Transit","name":"Transit"}'
echo "── Company Lastarter Demo"
seed crm.localhost '{"doctype":"Company","company_name":"Lastarter Demo","country":"France","default_currency":"EUR","abbr":"LD"}'
echo "── Employee alice"
seed crm.localhost '{"doctype":"Employee","naming_series":"HR-EMP-.YYYY.-","first_name":"Alice","company":"Lastarter Demo","user_id":"alice@example.com","company_email":"alice@example.com","date_of_joining":"2026-10-28","date_of_birth":"1990-01-01","gender":"Female"}'

echo "════════ PHASE 8 : publication du wiki ════════"
W=$($DC exec -T backend bench --site crm.localhost execute frappe.db.exists --args '["Wiki Document", {"title": "Welcome to Frappe Wiki"}]')
if [ -n "$W" ] && [ "$W" != "None" ]; then
  $DC exec -T backend bench --site crm.localhost execute frappe.client.set_value --kwargs '{"doctype":"Wiki Document","name":"'"$W"'","fieldname":"is_published","value":1}' >/dev/null 2>&1 && echo "wiki publie : $W"
else
  echo "ECHEC : page d accueil wiki introuvable"
fi

echo "════════ PHASE 9 : donnees de demonstration ════════"
echo "── Raven : espace LaStarter"
seed crm.localhost '{"doctype":"Raven Workspace","workspace_name":"LaStarter","description":"Espace de demonstration de la suite."}'
seed crm.localhost '{"doctype":"Raven Workspace Member","workspace":"LaStarter","user":"alice@example.com","is_admin":1}'
seed crm.localhost '{"doctype":"Raven Workspace Member","workspace":"LaStarter","user":"'"$ADMIN_EMAIL"'","is_admin":1}'
seed crm.localhost '{"doctype":"Raven Workspace Member","workspace":"LaStarter","user":"demo@example.com"}'
seed crm.localhost '{"doctype":"Raven Channel","workspace":"LaStarter","channel_name":"general","type":"Public","channel_description":"Annonces generales"}'
seed crm.localhost '{"doctype":"Raven Channel","workspace":"LaStarter","channel_name":"support-clients","type":"Public","channel_description":"Coordination du support"}'
C1=$($DC exec -T backend bench --site crm.localhost execute frappe.db.exists --args '["Raven Channel", {"channel_name": "lastarter-general"}]')
C2=$($DC exec -T backend bench --site crm.localhost execute frappe.db.exists --args '["Raven Channel", {"channel_name": "lastarter-support-clients"}]')
seed crm.localhost '{"doctype":"Raven Message","channel_id":"'"$C1"'","text":"Bienvenue dans le canal general de la demonstration."}'
seed crm.localhost '{"doctype":"Raven Message","channel_id":"'"$C2"'","text":"Premier ticket traite aujourd hui, bravo a l equipe."}'
echo "── CRM : 3 leads"
seed crm.localhost '{"doctype":"CRM Lead","lead_name":"Boulangerie Martin","first_name":"Marie","last_name":"Martin","email":"contact@boulangerie-martin.fr"}'
seed crm.localhost '{"doctype":"CRM Lead","lead_name":"Cooperative Aurore","first_name":"Paul","last_name":"Aubert","email":"contact@aurore.coop"}'
seed crm.localhost '{"doctype":"CRM Lead","lead_name":"Cabinet Durand","first_name":"Claire","last_name":"Durand","email":"cabinet@durand-avocats.fr"}'
echo "── Helpdesk : 3 tickets"
seed crm.localhost '{"doctype":"HD Ticket","subject":"Connexion espace client impossible","raised_by":"client1@example.fr","description":"<p>Le mot de passe est refuse sur la page de connexion.</p>"}'
seed crm.localhost '{"doctype":"HD Ticket","subject":"Devis refonte du site vitrine","raised_by":"client2@example.fr","description":"<p>Besoin d une refonte complete avec prise de rendez-vous integree.</p>"}'
seed crm.localhost '{"doctype":"HD Ticket","subject":"Factures illisibles sur mobile","raised_by":"client3@example.fr","description":"<p>Le tableau deborde de l ecran sur iOS.</p>"}'
echo "── LMS : cours + chapitre + lecon"
seed crm.localhost '{"doctype":"LMS Course","title":"Prise en main de la suite","short_introduction":"Decouvrez vos outils collaboratifs.","description":"<p>Un parcours de demonstration.</p>","published":1}'
seed crm.localhost '{"doctype":"Course Chapter","course":"prise-en-main-de-la-suite","title":"Bienvenue"}'
CH=$($DC exec -T backend bench --site crm.localhost execute frappe.db.exists --args '["Course Chapter", {"course": "prise-en-main-de-la-suite", "title": "Bienvenue"}]')
seed crm.localhost '{"doctype":"Course Lesson","chapter":"'"$CH"'","title":"Votre premier tour","body":"<p>Bienvenue dans votre suite collaborative. Ouvrez le CRM et creez un contact, puis discutez dans Raven.</p>"}'

echo "════════ PHASE 10 : verification finale ════════"
echo -n "raven espaces: "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["Raven Workspace"]'
echo -n "raven canaux: "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["Raven Channel"]'
echo -n "leads: "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["CRM Lead"]'
echo -n "tickets: "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["HD Ticket"]'
echo -n "chapitres: "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["Course Chapter"]'
echo -n "employes: "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["Employee"]'
echo -n "DefaultValue setup_complete (doit etre vide): "; $DC exec -T backend bench --site crm.localhost execute frappe.db.count --args '["DefaultValue",{"defkey":"setup_complete"}]'
echo -n "login admin: "; curl -s -X POST "http://crm.localhost/api/method/login" -d "usr=$ADMIN_EMAIL&pwd=$ADMIN_PWD" -o /dev/null -w "%{http_code}\n"
echo -n "/docs (302 attendu): "; curl -s -o /dev/null -w "%{http_code}\n" "http://crm.localhost/docs"
echo -n "/all-products (200 attendu): "; curl -s -o /dev/null -w "%{http_code}\n" "http://crm.localhost/all-products"
echo "════════ RESET + PROVISIONNEMENT TERMINES ════════"
