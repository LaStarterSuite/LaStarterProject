# LMS (frappe/lms)

**Licence : AGPLv3** (fichier `license.txt`, pas de LICENSE à la racine).
3 351 étoiles, push 2026-10-27. Verdict LaStarter : **hors catalogue actuel, à garder en réserve**.

## Qu'est-ce que c'est

Learning Management System complet : cours, chapitres, leçons, quiz,
certificats, batches, paiements. 75 doctypes, 269 .vue, 508 .py. Très mature,
e2e, SECURITY.md, docs d'installation bench + docker.

## Authentification (audit)

Framework only — même pattern que Helpdesk : `lms/auth.py` = allowlist guest
branchée via `auth_hooks` (hooks.py:366), listant explicitement
`login_via_keycloak` et les chemins `oauth2.*`.

## Utilisation LaStarter

Pas dans le périmètre v1 (CRM, tickets, drive, docs, visio, calendrier).
Pourquoi le garder documenté : c'est la preuve que l'écosystème couvre
facilement des extensions futures de l'offre (formation clients) avec la
même intégration SSO.
