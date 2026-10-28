# Clés d'accès et tokens — ce qui existe et comment s'en servir

## 1. API key / API secret (par utilisateur)

- Champs sur le DocType User ; génération depuis le Desk.
- Appel : `Authorization: token <api_key>:<api_secret>` (brut ou base64).
- Code : `frappe/auth.py` — `validate_auth_via_api_keys` (l.637, 727-743),
  `validate_api_key_secret`.
- Usage LaStarter : la CLI, les intégrations serveur-à-serveur, l'agent cloud.

## 2. Bearer tokens OAuth2 (provider intégré)

- Doctype `OAuth Bearer Token` (avec patch `clear_old_tokens` = cycle de vie).
- Émis par le flux authorization code du provider OIDC (voir 04).
- Usage : apps tierces qui appellent l'API REST au nom d'un user.

## 3. Session cookie (usage app Web)

- Automatique côté navigateur ; voir `03-auth-sessions.md`.

## 4. Secrets hors base

- `site_config.json` accepte les secrets (ex. `<provider>_login` pour les
  Social Login Keys, `get_oauth_keys` utils/oauth.py) — pattern à suivre pour
  tout secret LaStarter (pas de secrets dans la base).

## Tableau de décision

| Besoin | Mécanisme |
|---|---|
| App Frappe → API du même site | session cookie (SPA sur le même domaine) |
| Script/CLI → API | API key:secret |
| App tierce au nom d'un user | OAuth2 bearer (Authorization Code) |
| Service → service permanent | API key:secret dédiée (compte de service) |
