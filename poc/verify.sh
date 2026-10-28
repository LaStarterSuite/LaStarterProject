#!/bin/sh
# Vérifications HTTP du POC trancheur (à lancer une fois le compose up).
# Rappel machine : curl renvoie exit 0 même sur 404 -> toujours -w "%{http_code}".
set -e
cd "$(dirname "$0")/.."
DC="docker compose -f poc/compose.yml"

echo "== conteneurs =="
$DC ps --format "table {{.Service}}\t{{.Status}}" 2>/dev/null

echo "== sites installés =="
$DC exec -T backend ls -1 sites | grep -v assets

echo "== apps installées sur crm.localhost =="
$DC exec -T backend bench --site crm.localhost list-apps

echo "== ping IdP (api guest) =="
curl -s -w " [HTTP %{http_code}]\n" "http://id.localhost:8081/api/method/ping"

echo "== page login IdP =="
curl -s -o /dev/null -w "id.localhost:8081/login [HTTP %{http_code}]\n" "http://id.localhost:8081/login"

echo "== SPA CRM (site client) =="
curl -s -o /dev/null -w "crm.localhost:8081/crm [HTTP %{http_code}]\n" "http://crm.localhost:8081/crm"

echo "== discovery OIDC de l'IdP =="
curl -s -w "\n[HTTP %{http_code}]\n" "http://id.localhost:8081/api/method/frappe.integrations.oauth2.get_openid_configuration" | head -c 500
echo ""

echo "== OAuth Client côté IdP =="
$DC exec -T backend bench --site id.localhost execute frappe.db.exists --args "['OAuth Client', {'app_name': 'lasarter-crm'}]"

echo "== Social Login Key côté consommateur =="
$DC exec -T backend bench --site crm.localhost execute frappe.db.exists --args "['Social Login Key', 'frappe']"
