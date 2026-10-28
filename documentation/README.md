# LaStarter — Documentation de refondation (100 % Frappe)

> **À l'attention de l'agent (ou de la personne) qui reprend le projet.**
> Ce dossier contient TOUT : l'histoire complète de la session d'analyse, les
> décisions stratégiques actées, le fonctionnement vérifié dans le code de
> chaque outil Frappe, l'audit des applications, les licences, la stack cloud,
> et la feuille de route. Aucune ligne de code du nouveau projet n'existe
> encore — c'est le point de départ propre.

## Le cap en une phrase

Reconstruire LaStarter en **100 % Frappe** : le framework comme socle, les
applications Frappe comme catalogue, **Frappe comme IdP universel (OIDC)** à
la place de Keycloak, une CLI + un catalogue de briques épinglées pour le
déploiement, et une plateforme cloud inspirée de Frappe Cloud (Press/Central)
rebrandée et enrichie. Open source, contributions amont.

## Sommaire

- **00-DECISIONS/** — les décisions stratégiques actées (à lire en premier)
- **01-FRAPPE-FRAMEWORK/** — le framework décortiqué (architecture, auth, OIDC, limites)
- **02-APPS/** — audit app par app (licence, auth, maturité, adéquation)
- **03-LICENCES/** — carte MIT/AGPL/GPL et règles de rebranding
- **04-CLOUD/** — modèle multi-tenant, stack Frappe Cloud, LaStarter Cloud cible
- **05-DEPLOIEMENT/** — frappe_docker, Helm, conception de la CLI LaStarter
- **06-CATALOGUE/** — catalogue v2 et ce qu'on retient du catalogue v1 (La Suite)
- **07-SKILLS/** — les skills Frappe pour agents, et les conventions de travail
- **08-HISTORIQUE/** — journal de session complet, archive Convex, enseignements, pièges machine
- **09-AUJOURDHUI/** — état des clones, plan du POC trancheur, prochaines étapes ordonnées

## Faits d'ancrage (vérifiés, pas supposés)

- Org GitHub `frappe` : 236 dépôts, **59 actifs** (push ≥ 2026-10-01, non
  archivés, hors forks) clonés en shallow dans `../frappe/` avec
  `INVENTAIRE.md` (licences, étoiles, dernière activité).
- Framework **MIT**, apps métier récentes **AGPLv3**, ERPNext/HRMS **GPLv3**.
- Frappe est un **fournisseur OIDC complet** (code : `frappe/integrations/oauth2.py`,
  endpoint `get_openid_configuration`, serveur oauthlib OIDC intégré).
- Keycloak est un **preset natif** du doctype Social Login Key (authentification
  OK en ~10 min ; rôles et SLO non couverts nativement — voir
  `01-FRAPPE-FRAMEWORK/09-limites-identifiees.md`).
- **Convex est abandonné** (décision 2026-10-28) ; l'archive de ce qui avait
  été construit est documentée dans `08-HISTORIQUE/02-convex-archive.md`.
