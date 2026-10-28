# État des clones Frappe

## Où

`C:\Users\Bastien\Documents\Projects\LaStarterProject\frappe\` — **59 dossiers**
(58 dépôts actifs clonés + INVENTAIRE.md).

- Clone shallow (`--depth 1`, branche par défaut — frappe/frappe est sur
  develop = **17.0.0-dev**).
- `INVENTAIRE.md` : par dépôt — étoiles, licence, dernier push, description
  (généré depuis l'API GitHub du 2026-10-28).

## Comment rafraîchir

```sh
cd frappe && for d in */; do git -C "$d" pull --ff-only; done   # maj shallow
# re-générer la liste active :
gh repo list frappe --limit 500 --json name,pushedAt,isArchived,isFork \
  > ../.research/frappe-org.json
# filtrer push >= (mois courant) && !archived && !fork, puis re-cloner les nouveaux
```

## Les fichiers de travail de l'analyse

Dans `C:\Users\Bastien\.t3\projects\convex\.research\` :
`frappe-org.json` (les 236 dépôts avec stars/pushedAt/archived/fork/langue),
`frappe-clonelist.txt` (les 58 clonés). À copier dans ce projet si le
workspace Convex devait disparaître.

## Les dépôts qui comptent le plus pour LaStarter (rappel)

frappe (framework, MIT), crm, helpdesk, wiki (MIT), raven, suite, drive,
insights, gameplan, lms, erpnext/hrms (GPLv3), frappe_docker + helm (MIT),
bench + press + central + agent + pilot + atlas (cloud, AGPL), skills,
frappe-ui.
