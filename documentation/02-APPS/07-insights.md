# Insights (frappe/insights) — BI

**Licence : AGPLv3.** 1 031 étoiles, push 2026-10-27. Verdict LaStarter : **marginal** (réserve BI).

## Qu'est-ce que c'est

Outil de Business Intelligence : sources de données, requêtes visuelles,
dashboards. 22 doctypes, 231 .vue (frontend dédié). Architecture v3 avec une
couche de connecteurs (ibis) : Postgres, BigQuery (google.oauth2),
MySQL, CSV…

## Authentification (audit)

Framework only. Les mentions oauth du repo sont des **connecteurs de
données**, pas du SSO.

## Utilisation LaStarter

- Hors catalogue v1, mais c'est la seule option BI crédible de l'écosystème :
  à proposer en brique optionnelle « Analytics » du catalogue v2.
- Bonus : elle sait se connecter aux bases des autres apps (le site Frappe
  expose sa MariaDB) — les dashboards croisés clients/deviennent naturels.
