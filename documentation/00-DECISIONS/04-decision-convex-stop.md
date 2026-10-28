# Décision — Arrêt de Convex

**Date : 2026-10-28. Statut : ACTÉ (stop définitif du chantier).**

## Historique en trois temps

1. **Évaluation** (2026-10-27) : Convex évalué comme noyau réactif — verdict
   « retenu avec conditions » après 31 agents de recherche et un comparatif de
   11 plateformes (Supabase, Firebase, Appwrite, PocketBase, Parse, Directus,
   Strapi, Keystone, Nhost, Kuzzle, Hasura + moteurs de sync).
2. **Construction** (2026-10-27/28) : socle complet construit et vérifié dans
   `C:\Users\Bastien\.t3\projects\convex` — Convex local + Keycloak 26.4
   (Docker, port 8180) + RBAC @vllnt + registre d'apps + app Kanban complète +
   revue de sécurité adversaire (10 agents) corrigée + suite E2E Playwright
   6/6 verte. Détail : `08-HISTORIQUE/02-convex-archive.md`.
3. **Pivot Frappe** (2026-10-28) : le cap 100 % Frappe rend Convex hors sujet
   pour le socle. **Stop : plus aucune ligne Convex ne sera écrite pour
   LaStarter.**

## Ce que le détour a quand même apporté

- La **méthode de vérification** : chaque affirmation appuyée sur le code,
  audits adversaires multi-agents, tests E2E avant de déclarer « ça marche ».
- Les **pièges machine** documentés (`08-HISTORIQUE/04-machines-pieges.md`),
  valables pour tout projet futur sur ce PC.
- Une **connaissance fine des alternatives** (comparatif 11 plateformes) qui
  éclaire les choix : par exemple, pourquoi Frappe + Supabase n'aurait pas de
  sens non plus.
- Keycloak 26.4 tourne toujours sur cette machine (port 8180) — réutilisable
  comme IdP de TEST pour n'importe quel POC.

## Règle pour la suite

Ne pas relire `project-convex-eval` comme un plan à suivre : c'est une archive.
Le seul livrable vivant de LaStarter est ce dossier de documentation et le
futur code Frappe.
