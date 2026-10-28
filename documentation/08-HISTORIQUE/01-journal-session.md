# Journal de la session d'analyse (2026-10-27 → 2026-10-28)

Chronologie complète, pour comprendre d'où viennent les décisions.

## Jour 1 (2026-10-27) — la piste Convex

1. Setup d'un workspace Convex (template bare, RBAC @vllnt/convex-permissions,
   skills Convex installées).
2. Recherche massive (31 agents, sources primaires) : Convex évalué
   profondeur (self-hosting, auth customJwt/Keycloak, composants, limites,
   bugs ouverts) + comparatif 11 plateformes + moteurs de sync + état du
   marché 2024-2026.
3. Verdict rendu : Convex « noyau réactif retenu » avec conditions
   (Postgres obligatoire en prod, fenêtres de déploiement, mono-réplica).
4. Pages de référence publiées pour l'utilisateur.

## Jour 1→2 (nuit) — construction du socle Convex

5. Keycloak 26.4 déployé (Docker, port 8180, realm lastarter, client convex +
   Audience mapper, users de test alice/bob, presets idempotents).
6. Socle Convex construit : auth customJwt Keycloak, RBAC, registre d'apps,
   rate-limiting, HTTP healthz, app Kanban complète (boards/columns/cards,
   drag & drop), frontend Next.js 16 + Auth.js v5.
7. Vérification : suite E2E Playwright 6/6 (login Keycloak réel, RBAC,
   realtime bidirectionnel 2 sessions), plusieurs fois de suite.
8. Revue de sécurité adversaire (10 agents, 4 angles + réfutation) :
   2 vrais problèmes corrigés (secrets gitignorés, refresh token manquant)
   + garde-fous appliqués.

## Jour 2 (2026-10-28) — le cap

9. L'utilisateur précise l'intention réelle : reprendre les apps du catalogue
   LaStarter (La Suite) et remplacer LEUR backend — pas recréer des apps.
10. Exploration du catalogue v1 (SCHEMA.md TOML, exemples = suitenumerique :
    projects/Sails+React, drive/Django+Next…) ; analyse du portage (client
    projects : 479 fichiers, 34 300 lignes, axios+sagas+socket.io v2).
11. **Pivot Frappe** (initiative de l'utilisateur) : découverte de l'org
    frappe (236 dépôts) et de Frappe Suite.
12. Analyse sincère demandée et livrée ; décision : **100 % Frappe, Convex
    stoppé, Frappe = IdP universel**.
13. Clonage des 59 dépôts actifs + INVENTAIRE.md (licences).
14. Audit workflow (3 agents) : OIDC/Keycloak profondeur, apps, stack cloud.
15. **Ce dossier de documentation** : consolidation de tout, pour un agent
    neuf.

## Le motif du pivot (pour mémoire)

Ce n'est pas que Convex était mauvais : c'est que Frappe apporte un socle
applicatif complet (apps + identité + admin + realtime + cloud) là où Convex
n'apportait qu'un runtime à tout construire soi-même. Le coût du détour est
réel ; la méthode de vérification apprise pendant le détour est le gain.
