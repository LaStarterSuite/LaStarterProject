# Social Login Key — consommer un IdP externe (Keycloak inclus)

Le doctype `Social Login Key` (`frappe/integrations/doctype/social_login_key/`)
permet à un site Frappe de déléguer sa connexion à un IdP externe. Utile si
LaStarter doit un jour se brancher sur le SSO d'un client (la porte ouverte).

## Champs du doctype (extraits du JSON)

`social_login_provider` (preset : Google, Facebook, GitHub, GitLab, Keycloak,
Office 365, Fairlogin, Custom…), `client_id`, `client_secret` (Password),
`base_url`, `custom_base_url`, `authorize_url`, `access_token_url`,
`api_endpoint` (userinfo), `api_endpoint_args`, `auth_url_data` (JSON libre :
scope, response_type), `user_id_property`, `sign_ups` (Allow/Deny/Ask),
`trust_email_without_verified_claim`, `redirect_url`, `icon`,
`show_in_resource_metadata`, `tenant_id` (O365).

## Le preset Keycloak (social_login_key.py:234-246)

```
custom_base_url = 1
authorize_url     = /protocol/openid-connect/auth
access_token_url  = /protocol/openid-connect/token
api_endpoint      = /protocol/openid-connect/userinfo
user_id_property  = preferred_username
scope             = openid   (⚠ à étendre : "openid email profile" via auth_url_data,
                              sinon userinfo ne rend pas l'email → "Email not verified")
callback          = /api/method/frappe.integrations.oauth2_logins.login_via_keycloak
```

## Recette complète (audit, testable en 10 min)

1. Keycloak : client confidentiel, Standard Flow, **pas d'exigence PKCE**
   (Frappe n'en envoie pas), redirect URI ci-dessus déclaré.
2. Frappe : Social Login Key, provider=Keycloak, Base URL =
   `https://kc.example.com/realms/<realm>` (les chemins se complètent),
   client_id/secret, `auth_url_data = {"response_type":"code","scope":"openid email profile"}`.
3. Se connecter : le user est provisionné JIT (email vérifié requis, sinon
   `trust_email_without_verified_claim=1`).

## Limites auditées (important)

- Flux = pur OAuth2 authorization-code via **rauth** (~0.7.3) ; claims pris au
  userinfo (pas de vérification JWS nécessaire).
- **Pas de discovery** .well-known (URLs saisies — le preset les pré-remplit).
- **Pas de PKCE** généré.
- **Pas de mapping rôles/claims → rôles Frappe** (seul
  Portal Settings.default_role s'applique au provisioning ; user_type codé
  « Website User »). LDAP, lui, a un sync de rôles complet — non porté à OIDC.
- **Pas de SLO** : déconnexion locale uniquement, aucune session liée.
- Callback générique disponible : `/api/method/frappe.integrations.oauth2_logins.custom/<provider>`.
