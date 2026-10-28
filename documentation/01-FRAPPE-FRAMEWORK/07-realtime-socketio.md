# Realtime — socket.io intégré

## Ce que c'est

Frappe embarque un serveur **socket.io** (Node) branché sur Redis : les
événements serveur (DocType modifié, message, progress de job) sont poussés
aux clients connectés. Les apps modernes (crm, helpdesk, lms, raven,
gameplan) s'en servent pour leurs vues live ; `frappe-ui` fournit le
data-fetching réactif côté client.

## Ce que ça implique pour LaStarter

- **Pas besoin de WebSocket maison** : le temps réel inter-apps est déjà là,
  piloté par le même modèle de permissions.
- L'exposition passerelle doit router les upgrades WebSocket (la structure
  catalogue v1 documentait déjà cela pour projects : location `/` avec
  Upgrade — même principe).
- La CLI LaStarter exposer `/socket.io` derrière le sous-domaine du site.

## Realtime et apps (notes d'audit)

- `suite/` (Frappe Suite) a même un dossier `realtime/` dédié (service
  séparé pour les produits drive/writer/sheets).
- Raven pousse plus loin (son propre SDK React, `frappe-react-sdk`).
- Aucune app auditée n'utilise un realtime alternatif : tout passe par le
  framework.
