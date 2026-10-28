#!/bin/sh
# Câble l'OIDC du POC trancheur LaStarter v2.
#
# - IdP (id.localhost) : OAuth Client "lasarter-crm" (Authorization Code,
#   redirect vers login_via_frappe du site client, skip_authorization en POC).
# - Consommateur (crm.localhost) : Social Login Key preset "Frappe" (les URLs
#   du preset pointent déjà vers les endpoints OIDC du framework) ; scope
#   élargi à "openid email profile" sinon le userinfo ne rend pas l'email.
#
# v3 du script : appels `bench execute frappe.client.insert --kwargs
# '{"doc": {...}}'` — execute transmet les kwargs à la FONCTION (le paramètre
# de insert() s'appelle doc), et les heredocs vers `bench console` (IPython)
# ne s'exécutent pas de façon fiable via docker exec.
# Idempotent : vérifie l'existence avant de créer.
set -e
cd "$(dirname "$0")/.."
DC="docker compose -f poc/compose.yml"
SECRET="${POC_CLIENT_SECRET:-poc-secret-dev}"
REDIRECT="http://crm.localhost/api/method/frappe.integrations.oauth2_logins.login_via_frappe"

exists() { # $1 = site, $2 = args JSON ; vrai si l'objet existe
  out="$($DC exec -T backend bench --site "$1" execute frappe.db.exists --args "$2" 2>/dev/null | tail -1)"
  [ -n "$out" ] && [ "$out" != "None" ]
}

echo "== 1. OAuth Client sur id.localhost (IdP) =="
if exists id.localhost '["OAuth Client", {"app_name": "lasarter-crm"}]'; then
  echo "oauth-client: EXISTS"
else
  $DC exec -T backend bench --site id.localhost execute frappe.client.insert --kwargs "{
    \"doc\": {
      \"doctype\": \"OAuth Client\",
      \"app_name\": \"lasarter-crm\",
      \"client_id\": \"lasarter-crm\",
      \"client_secret\": \"$SECRET\",
      \"default_redirect_uri\": \"$REDIRECT\",
      \"redirect_uris\": \"$REDIRECT\",
      \"grant_type\": \"Authorization Code\",
      \"response_type\": \"Code\",
      \"scopes\": \"openid email profile\",
      \"skip_authorization\": 1
    }
  }"
  echo "oauth-client: CREATED"
fi

echo "== 2. Social Login Key preset Frappe sur crm.localhost (consommateur) =="
if exists crm.localhost '["Social Login Key", "frappe"]'; then
  echo "social-login: EXISTS"
else
  $DC exec -T backend bench --site crm.localhost execute frappe.client.insert --kwargs "{
    \"doc\": {
      \"doctype\": \"Social Login Key\",
      \"provider_name\": \"Frappe\",
      \"social_login_provider\": \"Frappe\",
      \"enable_social_login\": 1,
      \"client_id\": \"lasarter-crm\",
      \"client_secret\": \"$SECRET\",
      \"base_url\": \"http://id.localhost\",
      \"custom_base_url\": 1,
      \"authorize_url\": \"/api/method/frappe.integrations.oauth2.authorize\",
      \"access_token_url\": \"/api/method/frappe.integrations.oauth2.get_token\",
      \"api_endpoint\": \"/api/method/frappe.integrations.oauth2.openid_profile\",
      \"redirect_url\": \"/api/method/frappe.integrations.oauth2_logins.login_via_frappe\",
      \"auth_url_data\": \"{\\\"response_type\\\": \\\"code\\\", \\\"scope\\\": \\\"openid email profile\\\"}\",
      \"sign_ups\": \"Allow\"
    }
  }"
  echo "social-login: CREATED"
fi

echo "== 3. discovery OIDC de l'IdP (vérification) =="
# En v16 le endpoint exige une session (pas allow_guest) : 403 attendu hors
# login — le preset Frappe utilise les URLs directes, pas la discovery.
curl -s -o /dev/null -w "get_openid_configuration [HTTP %{http_code}]\n" \
  "http://id.localhost:8081/api/method/frappe.integrations.oauth2.get_openid_configuration"
echo "== Terminé =="
