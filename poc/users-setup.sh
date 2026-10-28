#!/bin/sh
# Utilisateurs de test du POC trancheur.
# - alice@example.com : les DEUX sites (System User) -> SSO direct sans
#   provisioning (reconnaissance par email).
# - bob@example.com : UNIQUEMENT sur l'IdP -> teste le provisioning JIT côté
#   consommateur (Website User, à élever à la main : le mapping auto des
#   rôles est le travail de lastarter_core, PAS du POC).
# NB Frappe : "System User" est un user_type, PAS un rôle — les rôles sont
# "System Manager", "Sales User", etc. (le rôle "All" est automatique).
# v3 : `bench execute frappe.client.insert --kwargs '{"doc": {...}}'`
# (execute transmet les kwargs à la fonction ; le paramètre de insert()
# s'appelle doc).
set -e
cd "$(dirname "$0")/.."
DC="docker compose -f poc/compose.yml"

exists() {
  out="$($DC exec -T backend bench --site "$1" execute frappe.db.exists --args "['User', '$2']" 2>/dev/null | tail -1)"
  [ -n "$out" ] && [ "$out" != "None" ]
}

echo "== 1. alice + bob sur l'IdP (id.localhost) =="
for u in alice bob; do
  email="$u@example.com"
  if exists id.localhost "$email"; then
    echo "$email: EXISTS"
  else
    $DC exec -T backend bench --site id.localhost execute frappe.client.insert --kwargs "{
      \"doc\": {
        \"doctype\": \"User\",
        \"email\": \"$email\",
        \"first_name\": \"$u\",
        \"user_type\": \"System User\",
        \"new_password\": \"poc-password-1234\",
        \"send_welcome_email\": 0,
        \"roles\": [{\"role\": \"Desk User\"}]
      }
    }" > /dev/null
    echo "$email: CREATED"
  fi
done

echo "== 2. alice sur le site client (crm.localhost, System User) =="
if exists crm.localhost "alice@example.com"; then
  echo "alice@example.com: EXISTS"
else
  $DC exec -T backend bench --site crm.localhost execute frappe.client.insert --kwargs "{
    \"doc\": {
      \"doctype\": \"User\",
      \"email\": \"alice@example.com\",
      \"first_name\": \"alice\",
      \"user_type\": \"System User\",
      \"send_welcome_email\": 0,
      \"roles\": [{\"role\": \"Desk User\"}]
    }
  }" > /dev/null
  echo "alice@example.com: CREATED"
fi

echo "== Terminé =="
