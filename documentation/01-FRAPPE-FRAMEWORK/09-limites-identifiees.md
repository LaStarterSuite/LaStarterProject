# Limites identifiées dans le framework (audit v17.0.0-dev)

**Ces limites sont des faits de code, pas des suppositions.** Chacune a une
atténuation documentée.

## 1. Pas de mapping rôles/claims IdP → rôles Frappe

- Le provisioning OIDC crée le user à la volée en **« Website User » codé en
  dur** (utils/oauth.py:466), avec au mieux `Portal Settings.default_role`
  (l.508-510). Aucune lecture des claims roles/groups. Les claims ne sont
  même pas exposés au hook `on_login` (hooks.py:118).
- Ironie utile : **LDAP a ce sync complet** (groupes → rôles à chaque login,
  ldap_settings.py:190-208) — non porté à OIDC.
- **Atténuation LaStarter** : app custom `lastarter_core` qui surcharge
  `frappe.utils.oauth.login_oauth_user` (ou patch) pour élever le user
  (System User + rôles) selon son profil. Quelques jours de dev.

## 2. Pas de déconnexion unique (SLO)

- Logout Frappe = destruction du cookie local (sessions.py). Zéro appel au
  `end_session_endpoint`, zéro back-channel/front-channel logout (grep négatif
  sur tout le framework).
- Session Frappe indépendante de l'IdP après login (pas d'introspection,
  auth.py:626+).
- Atténuation : quand Frappe EST l'IdP, ce défaut devient la norme homogène
  (sessions par monde Frappe) ; documenter le comportement aux clients.

## 3. OAuth consommateur : pas de PKCE, pas de discovery

- Social Login Key : URLs saisies (preset fourni), pas de code_challenge.
- Atténuation : presets complets + TLS partout (passerelle) ; le callback
  utilise un state single-use 600 s + cookie de binding HttpOnly (correct).

## 4. id_token décodé sans vérification de signature sur un chemin

- `login_via_oauth2_id_token` : `{"verify_signature": False}` (utils/oauth.py:338) ;
  seul le preset Office 365 vérifie JWKS+aud+tenant (utils/oauth.py:22-76).
- Atténuation : utiliser le chemin userinfo (preset Keycloak), ne jamais
  baser la sécurité sur l'id_token décodé.

## 5. 2FA — à confirmer

- Module 2FA TOTP historique non localisé dans le checkout v17-dev (find sans
  résultat). À re-vérifier (déplacé ? app séparée ? supprimé ?) AVANT la
  mise en prod de l'IdP. Si absent : l'ajouter au périmètre `lastarter_core`
  ou réévaluer.

## 6. MariaDB obligatoire

- Pas de support Postgres. Les ops et backups suivent le modèle MariaDB de
  bench (mysqldump/frappe backup).

## 7. Suite = 0.0.1

- Frappe Suite (7 apps) est WIP, Python >= 3.14 : suivre, ne pas épingler en
  prod tant que non stabilisée (voir `02-APPS/10-suite.md`).
