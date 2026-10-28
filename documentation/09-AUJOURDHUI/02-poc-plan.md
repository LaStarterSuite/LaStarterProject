# POC trancheur — plan d'exécution

**Objectif : prouver en local le socle LaStarter v2, en une demi-journée.**
Zéro code LaStarter dans ce POC — uniquement des outils officiels Frappe.

## Ce qu'il doit prouver

1. Un bench Frappe tourne en Docker (frappe_docker) avec CRM + Helpdesk.
2. **Un site Frappe est l'IdP OIDC d'un AUTRE site** (universalité).
3. Le SSO fonctionne au navigateur : login une fois, deux apps accessibles.
4. (Bonus) Keycloak 26.4 existant (port 8180) branché en Social Login Key sur
   le site — la porte inverse.

## Étapes

1. **Runtime** : frappe_docker. ⚠️ port 8080 occupé sur cette machine →
   mapper l'hôte sur 8081. MariaDB + Redis + web + workers + scheduler +
   socket.io (compose pwd.yml adapté).
2. **Site principal** `id.localhost` (l'identité) : créer le site, y créer
   les **OAuth Clients** pour les apps.
3. **Site client** `crm.localhost` : installer CRM + Helpdesk (image custom
   via images/custom/ avec apps.json), configurer Social Login Key →
   provider Custom/Keycloak pointant sur l'IdP du site principal
   (preset Keycloak = URLs openid-connect ; l'IdP étant Frappe, recopier
   authorize/token/userinfo du provider OIDC Frappe : `/social/login`,
   `/api/method/frappe.integrations.oauth2.*` — à ajuster selon v17).
4. **Vérifs** : login SSO navigué, user provisionné (Website User), rôles
   élevés manuellement (le mapping auto = travail de `lastarter_core`,
   PAS du POC), CRM et Helpdesk pleinement utilisables.
5. **Bonus Keycloak** : Social Login Key preset Keycloak →
   http://localhost:8180/realms/lastarter (client `convex` existe déjà ou en
   créer un dédié) — prouve la porte retour.
6. **Constat écrit** : chaque étape, chaque friction, chaque écart doc/réalité
   → ajouté à cette documentation.

## Critères de réussite

- Les trois preuves ci-dessus, reproductibles par script idempotent.
- Temps de provisioning mesuré (base de la CLI future).
- Liste précise de ce que `lastarter_core` devra automatiser (rôles,
  clients OIDC, branding).
