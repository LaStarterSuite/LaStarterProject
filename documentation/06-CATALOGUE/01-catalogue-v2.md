# Catalogue v2 — les briques LaStarter sur socle Frappe

## Le principe

On reprend **la structure même de Frappe** : un dépôt par application, des
releases épinglées, une image bench construite par CI. Le « catalogue
LaStarter » est la couche au-dessus : quels dépôts, quelles versions, quelles
dépendances, quels réglages — consommé par la CLI.

Le dossier `catalogue/` de la v1 (un TOML par brique) reste le bon format ;
seul le contenu change.

## Les briques v2 (découpage issu de l'audit)

| Brique | App(s) Frappe | Licence | Statut |
|---|---|---|---|
| `identity` | site Frappe principal (IdP OIDC) | MIT | cœur |
| `crm` | frappe/crm | AGPLv3 | cœur |
| `tickets` | frappe/helpdesk | AGPLv3 | cœur |
| `drive-docs` | frappe/suite (drive/writer/sheets) | AGPLv3 | cœur — quand Suite stabilise ; à suivre |
| `chat-visio` | frappe/raven | AGPLv3 | utile — arbitrage Matrix/Raven ouvert |
| `wiki` | frappe/wiki | **MIT** | utile |
| `discussions` | frappe/gameplan | AGPLv3 | réserve (refonte en cours) |
| `analytics` | frappe/insights | AGPLv3 | option |
| `formation` | frappe/lms | AGPLv3 | option |
| `erp` | frappe/erpnext (+hrms) | GPLv3 | option lourde |
| `calendar-mail` | frappe/suite (calendar, mail/Stalwart) | AGPLv3 | à suivre Suite |

## Dépendances (nouveau champ `requires` v2)

- TOUTE brique requiert `identity`.
- `chat-visio` requiert `identity` + aucune autre (Raven vit dans le site).
- `erp` : bench dédié recommandé (poids).

## Règles d'épinglage

- Une brique référence une **release tag exacte** (jamais main/develop — les
  tags `latest`/main des dépôts suivent la preprod).
- Le framework est épinglé au niveau de l'IMAGE bench (frappe 16.x LTS
  aujourd'hui, v17-dev clonée pour l'audit uniquement).
- Gate licence à chaque bump (comme v1).
- Suivi amont : `check-updates` liste les écarts entre pin et dernière release.

## Ce qui reste à décider (ouvert)

- Chat : Raven par défaut + Matrix en option, ou l'inverse ?
- Visio : Suite Meet quand prêt ; sinon brique LiveKit optionnelle (hors
  Frappe) pour la fédération externes.
- La brique `docs` riche (OnlyOffice/Collabora) : Suite Writer doit d'abord
  mûrir.
