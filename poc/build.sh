#!/bin/sh
# Construit l'image bench du POC depuis poc/apps.json (idempotent).
# Image : lasarter-bench:poc = frappe version-16 + crm@main + helpdesk@main
# (mêmes sources que celles déployées par Frappe Cloud, cf.
# documentation/06-CATALOGUE/03-pins-frappe-cloud.md ; l'épinglage par
# release tag arrive avec le catalogue v2, pas dans ce POC).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# apps.json est monté comme SECRET de build (id=apps_json), plus un build-arg
docker buildx build \
  --build-arg=FRAPPE_BRANCH=version-16 \
  --secret id=apps_json,src="$ROOT/poc/apps.json" \
  --tag lasarter-bench:poc \
  --load \
  "$ROOT/frappe/frappe_docker/images/custom"
