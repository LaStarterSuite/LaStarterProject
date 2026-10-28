# Catalogue v1 (La Suite) — ce qui existe, ce qu'on en retient

**L'état v1 du projet : `lastarter/catalogue/*.toml` + `examples/*` (checkouts
des amont). Documenté ici comme référence — la v2 remplace ce socle.**

## Ce que la v1 avait construit

- **CLI Python** (`lastarter-cli`) consommant un catalogue TOML : init
  (domaine, secrets), provisionnement compose par brique, passerelle Caddy
  (TLS partout, sous-domaine par app, `/__lastarter/` branding), coffre de
  secrets (`{secret:KEY}`), substitution de tokens (`{domain}`, `{origin}`…).
- **Schéma de brique rigoureux** (SCHEMA.md) : name/title/category/license
  (gate docs/licences.md), upstream_repo + upstream_pin (jamais latest),
  requires entre briques, oidc (provisionnement client Keycloak), branding
  (theme.css + JSON natif), compose (profil, services, oneshots,
  migrate_service, route_label, extra_servers), notes.
- **11 briques définies** : drive, projects (Kanban La Suite), docs,
  calendars, meet, discussions, crm (libredesk), gatus (monitoring), keycloak
  (core), mcp.
- **Examples** : checkouts des dépôts amont (suitenumerique/*, openintranet
  PHP…) pour comparaison/patches.

## Les enseignements qui survivent au pivot

1. **Le format catalogue TOML était bon** — à reprendre quasi tel quel (v2).
2. **L'épinglage strict + gate licence** : toujours la bonne règle.
3. **Le branding par passerelle** (theme.css servi sur /__lastarter/) :
   transposable aux sites Frappe.
4. **La passerelle TLS + WebSocket + sous-domaines** : même besoin côté
   Frappe (socket.io).
5. **La découverte qui a tout changé** : les apps hétérogènes (Django, Sails,
   PHP) exigeaient 3 modèles d'utilisateurs et 3 intégrations SSO ; c'est
   l'argument massue du pivot Frappe — un seul monde, users/rôles/API/realtime
   partagés.
6. **Matrix/LiveKit/gatus/libredesk** : restent documentés comme briques
   optionnelles hors-Frappe si le besoin resurgit.

## Où c'est

- `lastarter/catalogue/` (TOML + SCHEMA.md) et `examples/` — dans ce projet,
  conservés pour référence.
- Les apps La Suite (suitenumerique) restent une alternative crédible si un
  client exige un design précis de La Suite : la porte n'est pas fermée, le
  socle change simplement de priorité.
