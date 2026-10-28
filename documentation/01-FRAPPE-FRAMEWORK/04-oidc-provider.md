# Frappe comme fournisseur OIDC (l'IdP universel de LaStarter)

**C'est la capacité qui fonde la décision identité.** Frappe n'est pas qu'un
consommateur d'OIDC : il ÉMET de l'OpenID Connect pour des applications
tierces, Frappe ou non.

## Preuves de code (frappe/frappe, v17.0.0-dev)

| Capacité | Localisation |
|---|---|
| Endpoint discovery `.well-known/openid-configuration` | `frappe/integrations/oauth2.py:232` — `get_openid_configuration()` |
| Serveur OIDC complet | import de `oauthlib.openid.connect.core.endpoints.pre_configured.Server` (oauth2.py) |
| Enregistrement des apps clientes | doctype **OAuth Client** (`integrations/doctype/oauth_client/`) |
| Flux authorization code | doctype **OAuth Authorization Code** |
| Bearer tokens | doctype **OAuth Bearer Token** (+ `token_cache`) |
| Signature des id_tokens | PyJWT (dépendance `PyJWT~=2.15.1`) |
| OpenID scope/claims | `frappe/oauth.py` (id_token userinfo claims) |

## Recette : authentifier une app tierce contre un site Frappe

1. Sur le site « identité » : créer un **OAuth Client** (grant: Authorization
   Code, redirect URI de l'app, scopes `openid email profile`, client_id/secret).
2. Dans l'app tierce (Next.js, Node, mobile…) : OIDC standard vers
   `https://<site-frappe>/api/method/frappe.integrations.oauth2.get_openid_configuration`
   (ou URL directe découverte dans la réponse).
3. L'utilisateur se connecte avec sa session Frappe (ou son login) → consent →
   redirection avec code → tokens → app identifiée.
4. Pour les appels API serveur : bearer token OAuth2, ou API key/secret.

## Ce que ça remplace

Tout ce qui motivait Keycloak dans LaStarter v1 : « un IdP universel OIDC ».
Le site Frappe identité fait le job, sans serveur supplémentaire, et les
rôles applicatifs vivent au même endroit.

## Limites connues du provider (à garder en tête)

- L'expérience de consent/admin est celle du Desk (fonctionnelle, pas un
  Keycloak UX).
- Vérifier les durées de vie des tokens et le refresh dans la version épinée
  avant prod (doctype OAuth Bearer Token, `clear_old_tokens` patch existe).
- La 2FA côté IdP reste à confirmer (voir `09-limites-identifiees.md`).
