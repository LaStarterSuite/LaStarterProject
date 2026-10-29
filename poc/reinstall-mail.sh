#!/bin/sh
# Réinstalle l'app mail (0.2.1, archivée) dans le conteneur backend après
# une recréation (le code vit sur le FS du conteneur, hors volumes — la
# base et les User Settings survivent, pas le code).
#
# Étapes : get-app depuis l'archive GitHub (le dernier commit 0690fd5 porte
# déjà le correctif de base /mail du routeur), application du patch local
# hooks (poc/mail-local-fixes.patch), bench build --app mail, copie réelle
# des assets dans le volume sites (le conteneur frontend ne suit pas les
# symlinks), restart frontend.
#
# Usage : sh poc/reinstall-mail.sh   (la pile doit être montée)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DC="docker compose -f $ROOT/poc/compose.yml"

echo "── 1. get-app mail (l'archive, HEAD develop)"
if $DC exec -T backend test -d apps/mail; then
  echo "    apps/mail déjà présent, get-app sauté"
else
  $DC exec -T backend bench get-app https://github.com/frappe/mail
fi

echo "── 2. patch local hooks.py"
docker cp "$ROOT/poc/mail-local-fixes.patch" poc-backend-1:/tmp/mail-fixes.patch
$DC exec -T backend bash -c 'cd apps/mail && git apply --check /tmp/mail-fixes.patch 2>/dev/null && git apply /tmp/mail-fixes.patch && echo "    patch appliqué" || echo "    patch déjà appliqué ou non applicable"'

echo "── 3. purge __pycache__ (les .pyc de l'ancienne install)"
$DC exec -T backend bash -c 'find apps/mail -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null; true'

echo "── 4. bench build --app mail (le bundle vue)"
$DC exec -T backend bench build --app mail 2>&1 | tail -3

echo "── 5. assets en fichiers réels, copiés vers le FRONTEND (nginx)"
# Piège Docker Desktop Windows : les écritures du backend dans le volume
# partagé ne sont pas vues par le frontend (bug de write-through). Le
# nginx du frontend sert /assets : la copie doit passer par l hôte et
# arriver DANS le conteneur frontend. node_modules (symlink) exclu.
rm -rf "$ROOT/poc/tmp-assets" && mkdir -p "$ROOT/poc/tmp-assets"
for SUB in css email frontend images; do
  MSYS_NO_PATHCONV=1 docker cp "poc-backend-1:/home/frappe/frappe-bench/apps/mail/mail/public/$SUB" "$ROOT/poc/tmp-assets/" 2>/dev/null
done
MSYS_NO_PATHCONV=1 docker exec poc-frontend-1 sh -c 'rm -rf /home/frappe/frappe-bench/sites/assets/mail'
MSYS_NO_PATHCONV=1 docker cp "$ROOT/poc/tmp-assets/." poc-frontend-1:/home/frappe/frappe-bench/sites/assets/mail
MSYS_NO_PATHCONV=1 docker exec poc-backend-1 sh -c 'rm -rf /home/frappe/frappe-bench/sites/assets/mail && cp -rL /home/frappe/frappe-bench/apps/mail/mail/public /home/frappe/frappe-bench/sites/assets/mail' 2>/dev/null
rm -rf "$ROOT/poc/tmp-assets"

echo "── 6. restart frontend"
$DC restart frontend 2>&1 | tail -1

echo "── 7. vérification"
curl -s -o /dev/null -w "/mail/login : HTTP %{http_code}\n" http://crm.localhost/mail/login
echo "════ réinstallation mail terminée ════"
