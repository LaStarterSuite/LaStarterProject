# Authentification Frappe — sessions, tokens, mécanique interne

**Sources auditées : `frappe/auth.py`, `frappe/sessions.py`,
`frappe/utils/oauth.py`, `frappe/integrations/oauth2*.py` (v17.0.0-dev).**

## Les quatre moyens d'authentifier une requête

1. **Session cookie** (navigateur) : cookie Frappe côté serveur
   (`frappe/sessions.py`). Une fois la session ouverte, **aucune
   revalidation auprès d'un IdP** n'a lieu — la session vit jusqu'à
   expiration/lobby (`auth.py:626+`, `validate_auth`).
2. **API key + secret** : `Authorization: token <api_key>:<api_secret>`
   (`validate_auth_via_api_keys`, auth.py:637,727-743 ; base64 ou brut).
   Clés par utilisateur (champs sur le DocType User).
3. **Bearer OAuth2** : tokens émis par le provider OAuth2 intégré
   (doctype `OAuth Bearer Token`).
4. **Guest** : chemins explicitement allowlistés via `auth_hooks`
   (chaque app peut exposer du guest — ex. `helpdesk/auth.py`).

## Points de sécurité relevés (audit)

- Callback OAuth : `state` **single-use 600 s** + cookie de binding HttpOnly
  avec hash serveur (`create_oauth_state`/`consume_oauth_state`,
  utils/oauth.py) — soigné.
- ⚠️ `login_via_oauth2_id_token` décode l'id_token avec
  `{"verify_signature": False}` (utils/oauth.py:338) — seul le preset Office
  365 vérifie réellement (JWKS + audience + tenant, utils/oauth.py:22-76).
  Le chemin recommandé (userinfo sur TLS, preset Keycloak) n'est pas concerné.
- Rate limiting des tentatives de login présent (compteur
  failed_login_attempts côté desk) ; **module 2FA TOTP non localisé dans ce
  checkout v17-dev** — action ouverte de vérification avant prod.
- Les secrets peuvent vivre hors base : `site_config.json` clé
  `<provider>_login` (`get_oauth_keys`, utils/oauth.py).

## Cycle de session OIDC (le contrat complet)

1. Redirection vers l'IdP → callback Frappe → userinfo → provisioning JIT
   (email vérifié requis) → session Frappe créée.
2. Ensuite : **cookie Frappe pur**, indépendant de l'IdP (pas
   d'introspection, pas de SLO consommé). Logout Frappe = destruction du
   cookie local uniquement.
Conséquence design pour LaStarter : le cycle de session est celui de
l'instance Frappe elle-même — quand Frappe est l'IdP, cette simplicité
devient une force (un seul monde).
