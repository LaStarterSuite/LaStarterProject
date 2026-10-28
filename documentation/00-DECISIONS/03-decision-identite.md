# Décision — Identité : Frappe comme IdP universel

**Date : 2026-10-28. Statut : ACTÉE (sous réserve de vérification 2FA).**

## La doctrine v2

> **Frappe authentifie et autorise.** Un site Frappe « identité » de LaStarter
> émet des identités OIDC pour TOUTES les applications — Frappe ou non.

## Les faits vérifiés dans le code (frappe/frappe)

1. Frappe est un **fournisseur OpenID Connect complet** :
   - `frappe/integrations/oauth2.py:232` : `get_openid_configuration()` — le
     `.well-known/openid-configuration` standard que toute app sait consommer.
   - Le fichier importe `oauthlib.openid.connect.core.endpoints.pre_configured.Server`
     (serveur OIDC complet d'oauthlib).
   - Doctypes dédiés : `OAuth Client`, `OAuth Bearer Token`,
     `OAuth Authorization Code`, `Token Cache`, `Connected App`.
   - Bibliothèques : oauthlib ~4.0, PyJWT ~2.15, requests-oauthlib ~2.0
     (pyproject.toml) — standard du monde Python, auditées.
2. **Clés d'accès** : chaque user a un couple API key / API secret consommé via
   `Authorization: token <key>:<secret>` (`auth.py:637,727-743`,
   `validate_auth_via_api_keys`).
3. **Social login entrant** (pour brancher un IdP externe si besoin) :
   doctype `Social Login Key` avec un preset **Keycloak natif**
   (`social_login_key.py:234-246` : URLs `/protocol/openid-connect/auth|token|userinfo`,
   `user_id_property=preferred_username`, callback `login_via_keycloak`).

## Pourquoi Frappe IdP plutôt que Keycloak (audit 2026-10-28)

| Critère | Keycloak | Frappe IdP |
|---|---|---|
| Authentification des apps Frappe | Preset natif, OK | Natif, session framework directe |
| OIDC émis pour apps tierces | Oui | Oui (endpoint standard) |
| Rôles pilotés par l'IdP | Oui — mais Frappe ne lit PAS les claims (absent du code, voir limites) | Les rôles SONT le modèle Frappe — cohérence totale |
| Déconnexion unique (SLO) | Frappe ne la consomme pas de toute façon | Homogène : un seul monde |
| Ops supplémentaires | 1 serveur de plus (JVM) | Aucun — le site Frappe identité EST un site Frappe |

Le point décisif : **Keycloak sans mapping de rôles n'apporte que moitié moins,
et Frappe ne lit pas les claims de toute façon**. Deux mondes d'identité
(Keycloak + Frappe) auraient doublé les ops pour un SSO au final moins intégré.

## Ce que la doctrine implique

- Un site Frappe dédié (ou le site principal) joue le rôle d'IdP : les clients
  OIDC de chaque app LaStarter y sont déclarés (`OAuth Client`).
- Les utilisateurs, rôles et permissions vivent dans Frappe — c'est la source
  de vérité, assumée.
- La porte reste ouverte : rebrancher Keycloak = configurer un Social Login
  Key (10 min), sans réécriture.
- **Avant production : vérifier la présence/état du 2FA** dans la version
  épinglée (module non localisé dans le checkout audité — action ouverte,
  voir `09-AUJOURDHUI/03-prochaines-etapes.md`).

## Limites assumées du SSO Frappe (toutes documentées dans 09-limites)

Provisioning JIT par email vérifié uniquement ; user_type « Website User » au
premier login (à élever par app custom) ; pas de SLO inter-apps ; sessions
serveur indépendantes après login.
