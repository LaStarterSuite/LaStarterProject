# Framework Frappe — architecture générale

**Version audité : 17.0.0-dev** (clone shallow de frappe/frappe, develop).
Licence : **MIT**.

## Le modèle mental

Frappe est un framework full-stack **Python + MariaDB** où l'unité centrale
est le **DocType** : une définition de modèle (champs, permissions, vues,
API) stockée en base elle-même. Définir un DocType donne gratuitement :
l'API REST (`/api/resource/<doctype>`), les vues admin (Desk), le versioning,
les permissions par rôle, les hooks d'événements.

```
Bench (répertoire serveur)
├── apps/          ← code Python des apps (frappe, crm, helpdesk, lastarter_core…)
├── sites/         ← 1 dossier par SITE = 1 base MariaDB + 1 hostname
│   └── <host>/site_config.json
└── config/        ← nginx, supervisor/procfile, redis
```

- **1 bench = N sites** (multi-tenant par défaut).
- **1 site = les apps qui y sont installées** + ses utilisateurs + ses rôles.
- Runtime : Gunicorn (web) + workers RQ sur Redis (jobs) + socket.io
  (node, realtime) + MariaDB + nginx.
- CLI de gestion : `bench` (`bench new-site`, `bench get-app`,
  `bench install-app`, `bench migrate`, `bench backup`…).

## Ce que le framework fournit nativement (vérifié)

- **Admin Desk** complet (listes, formulaires, rapports, rôles).
- **API REST auto-générée** pour chaque DocType, avec permissions serveur.
- **Authentification** : sessions cookie serveur, API key/secret, OAuth2/OIDC
  fournisseur ET consommateur (`02..06` de ce dossier).
- **Realtime** : socket.io intégré (événements serveur → clients).
- **Permissions** : rôles Frappe, permissions par DocType/champ/valeur,
  permissions utilisateur (partage de documents), permission query scripts.
- **Jobs** : file RQ, planificateur (scheduler), hooks d'événements.
- **Frappé UI** (frappe-ui, MIT) : design system des frontends Vue modernes
  (58 composants, charts, data-fetching) — utilisé par crm/helpdesk/lms/raven.
- **MCP Server** : le framework expose un serveur MCP pour agents (découverte
  de schémas, lecture/écriture de documents, appel de méthodes) — l'agent qui
  reprendra le projet peut piloter un site Frappe directement.

## Les apps (structure canonique d'un dépôt)

```
<app>/
├── pyproject.toml        ← déclaration + dépendances (frappe = ">=16,<18" p.ex.)
├── <app>/hooks.py        ← l'interface avec le framework (events, auth_hooks…)
├── <app>/doctype/…       ← les DocTypes (JSON + .py contrôleur)
├── frontend/             ← souvent un SPA Vue (frappe-ui) pour les apps modernes
└── LICENSE
```

## Versions (état octobre 2026)

- Clone frappe/frappe develop : **17.0.0-dev**.
- Suite dépend de `frappe = ">=16.0.0,<18.0.0"` et Python >= 3.14.
- Chart Helm officiel : appVersion **v16.52.1** (dernière LTS connue stable).
- Règle LaStarter : **épingler** (jamais de main/latest ; les releases
  `v16.x` sont la base de prod jusqu'à validation de v17).
