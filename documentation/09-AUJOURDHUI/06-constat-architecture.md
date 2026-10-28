# Constat : architecture complète testable (2026-10-28)

**Verdict : VERT.** Le bench `lasarter-bench:full` porte 9 apps sur le site
client `crm.localhost`, toutes accessibles derrière le SSO de l'identité
`id.localhost`, vérifiées au navigateur avec l'utilisateur alice.

## Le socle

- Image construite par `poc/build.sh` (Containerfile `layered` officiel,
  commande documentée amont) depuis `poc/apps-full.json` : crm@main,
  helpdesk@main, telephony@develop, wiki@version-3, insights@version-3,
  raven@main (The-Commit-Company, le mainteneur réel installé par Frappe
  Cloud), lms@version-16, payments@version-16. Branches vérifiées par
  `git ls-remote` avant écriture.
- Les quatre nouvelles apps ont été installées à chaud sur le site existant
  (`bench --site crm.localhost install-app wiki insights raven lms`) :
  payments s'est installé automatiquement via `required_apps` de lms (le
  piège telephony du POC, anticipé cette fois : `required_apps` vérifiés
  dans les clons AVANT le build).

## Vérifications navigateur (session SSO alice)

| App | Route réelle | Titre constaté |
|---|---|---|
| Raven | `/raven` | Raven |
| LMS | `/lms` | Frappe (SPA) |
| Insights | `/insights` | Frappe Insights |
| Wiki | `/wiki-app` (PAS `/wiki`) | All Spaces \| Frappe Wiki |

Rôles attribués à alice avant login : Raven User, LMS Student,
Insights Admin, Wiki User (+ Sales User, Agent des phases POC).

## Comportements notés (matière pour lastarter_core)

- **Les sessions survivent à la recréation du compose** (Redis persisté) :
  pour réinitialiser un utilisateur, `frappe.sessions.clear_sessions(user)`.
  Le GET `/api/method/logout` ne déconnecte pas en v16 (POST + CSRF).
- **Cache des rôles** : les rôles ajoutés après l'ouverture d'une session ne
  sont visibles qu'après un nouveau login (confirmé au POC). Automatisation :
  attribuer les rôles AVANT la première connexion de l'utilisateur, ou
  invalider le cache (`frappe.clear_cache(user=)`).
- Routes SPA spécifiques par app (`/wiki-app`, chemin Insights configurable
  par `insights_path` dans le site config) : la passerelle future doit
  connaître la route réelle de chaque brique (donnée du catalogue v2).

## Restant pour « tout tester à la main »

Premières configurations propres à chaque app (flow first-use standard) :
créer un espace/channel Raven, un space Wiki, une source de données
Insights, un cours LMS. Bonus Keycloak 8180 toujours ouvert (Étape 1).
