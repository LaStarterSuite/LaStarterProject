# CRM (frappe/crm)

**Licence : AGPLv3.** 3 873 étoiles, push 2026-10-28. Verdict LaStarter : **cœur**.

## Qu'est-ce que c'est

CRM moderne : leads, deals, pipeline, contacts, campagnes, appels. Frontend
Vue (379 fichiers .vue) sur frappe-ui, backend Python (315 fichiers), 10
doctypes métier. La plus mature du lot avec Helpdesk. E2E Playwright incluse,
dossier skills/ et docs/.

## Authentification (audit)

Délègue entièrement au framework : le SPA redirige vers `/login?redirect-to=/crm`
(`frontend/src/stores/session.js:35`, `router.js:213`). Un petit endpoint guest
`oauth_providers` lit le Social Login Key du site (crm/api/auth.py:10-43) mais
n'a plus de consommateur actif — glue vestigiale, pas une couche SSO propre.
→ La config SSO se fait **au niveau du site** (Social Login Key ou Frappe IdP),
jamais dans l'app.

## Utilisation LaStarter

- Brique CRM du catalogue v2, épinglée sur une release tag.
- Installation : app Frappe classique dans le bench du client.
- Branding : frappe-ui + CSS (le thème passerelle v1 est transposable).
