# Helpdesk (frappe/helpdesk) — la brique Tickets

**Licence : AGPLv3.** 3 451 étoiles, push 2026-10-27. Verdict LaStarter : **cœur**.

## Qu'est-ce que c'est

Logiciel de support client : tickets, SLA, équipes, FAQ/portal, notifications.
Monorepo : `desk/` (302 fichiers .vue), `shared/`, `studio/` ; 37 doctypes,
304 fichiers Python. Très actif, e2e Playwright.

## Authentification (audit)

Framework only. `helpdesk/auth.py` est une simple allowlist de chemins guest,
branchée via `auth_hooks = ["helpdesk.auth.authenticate"]` (hooks.py:220).
Aucune couche SSO propre : la config SSO est celle du site.

## Utilisation LaStarter

- Brique tickets du catalogue v2.
- Le portal client (FAQ + tickets publics) est un plus pour l'offre cloud :
  le client final peut ouvrir des tickets sans compte desk.
- Se combine naturellement avec l'audit : chaque ticket = DocType → API,
  realtime et permissions gratuits.
