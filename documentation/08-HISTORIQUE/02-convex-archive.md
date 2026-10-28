# Archive Convex — ce qui avait été construit (et où)

**Statut : gelé, arrêté le 2026-10-28. Rien ne dépend de cet environnement.**

## Emplacement

`C:\Users\Bastien\.t3\projects\convex` — workspace T3 « convex », git local.

## Contenu (tout fonctionnel et vérifié au moment du gel)

| Élément | Détail |
|---|---|
| Socle Convex | `convex/` : schema (apps, users, auditLog, kanban), auth customJwt Keycloak, RBAC @vllnt + rate-limiter + presence + aggregate, HTTP healthz, bootstrap seed |
| App Kanban | backend complet + frontend Next.js 16 (portal + kanban, frappe… non — Auth.js v5 + ConvexProviderWithAuth) |
| Keycloak | conteneur `lastarter-keycloak` (compose `docker/keycloak.dev.yml`, port **8180**, volume persistant, realm `lastarter`, client OIDC, alice/bob) |
| Tests | Playwright 6/6 (login réel, RBAC, CRUD, realtime 2 sessions) ; `scripts/identity-check.mjs` ; revue sécurité 10 agents corrigée |
| Docker prod | `docker/compose.yml` (Keycloak+PG, Convex+PG, dashboard, MinIO) — écrit, non exécuté |

## Comment s'en resservir (si un jour…)

- Tout le setup est documenté dans le README.md du workspace ; secrets de dev
  dans `docker/.env.secrets`.
- Le conteneur Keycloak reste utile comme IdP de TEST générique (n'importe
  quel POC peut s'y brancher : realm `lastarter`, port 8180).
- Aucune maintenance prévue ; les conteneurs peuvent être supprimés sans
  impact sur LaStarter v2.

## Ce qu'il NE faut PAS en conclure

« Convex ne marche pas » serait faux : le socle tournait et était vérifié.
La décision vient de la priorisation produit (Frappe apporte des APPS, pas
seulement un runtime), pas d'un échec technique.
