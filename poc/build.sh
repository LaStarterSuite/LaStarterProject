#!/bin/sh
# Construit une image bench LaStarter via le Containerfile « layered »
# officiel de frappe_docker (commande documentée dans son
# docs/02-setup/02-build-setup.md : build arg FRAPPE_PATH/FRAPPE_BRANCH,
# apps.json en SECRET de build, CACHE_BUST pour invalider la couche
# bench init car le secret ne fait pas partie de la clé de cache).
#
# Variables : APPS_JSON (défaut poc/apps.json), TAG (défaut
# lasarter-bench:poc). Exemple architecture complète :
#   APPS_JSON=poc/apps-full.json TAG=lasarter-bench:full sh poc/build.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS_JSON="${APPS_JSON:-$ROOT/poc/apps.json}"
TAG="${TAG:-lasarter-bench:poc}"
BUST="${CACHE_BUST:-poc-$(date +%Y%m%d%H%M%S)}"
docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-16 \
  --build-arg=CACHE_BUST="$BUST" \
  --secret=id=apps_json,src="$APPS_JSON" \
  --tag="$TAG" \
  --file="$ROOT/frappe/frappe_docker/images/layered/Containerfile" \
  "$ROOT/frappe/frappe_docker"
