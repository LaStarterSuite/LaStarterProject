# Enseignements méthodologiques de la session

Ce qui a marché, ce qui a coûté — à réutiliser pour le projet Frappe.

## Ce qui a fait gagner du temps

1. **Vérifier dans le code, toujours.** Les audits (Convex puis Frappe) ont
   trouvé à chaque fois des écarts entre la doc et la réalité : rôle mapping
   OIDC absent de Frappe malgré LDAP qui l'a ; id_token décodé sans signature
   ; RateLimiter vs Ratelimiter (nom réel) ; `client.close()` inexistant.
   La doc Frappe actuelle ne remplacera pas cette vérification.
2. **Audits adversaires multi-agents.** 4 angles + réfutation forcée : les
   findings survivants étaient tous réels (0 faux positif dans le lot
   confirmé). Reproduire ce schéma sur chaque app embarquée (la skill
   `deep-app-audit` officielle suit la même philosophie).
3. **Tests avant déclaration de victoire.** La suite E2E verte « plusieurs
   fois de suite » (fenêtre de recompilation du 1er run ignorée) est le seul
   critère accepté.
4. **Idempotence de tout script d'infra** (Keycloak setup ré-exécutable,
   secrets resynchronisés automatiquement).

## Ce qui a coûté (à ne pas refaire)

1. **Construire avant d'avoir exploré l'existant** : la Kanban verte alors
   que la demande était de porter les apps du catalogue. Leçon : lister le
   périmètre réel (catalogue, exemples) AVANT d'écrire.
2. **Itération à l'aveugle sur des échecs E2E** : les snapshots
   d'erreur-context + logs serveur ont résolu en un coup des heures de
   théorie. Toujours capturer console + page snapshot au 1er échec.
3. **Cycles d'arrière-plan de 2 h** : les process longs (dev servers,
   watchdogs) meurent tous les 2 h dans la session ; les relancer est
   mécanique mais il faut le savoir (voir `04-machines-pieges.md`).

## Pattern de vérification à reproduire (recette gagnante)

1. Clone shallow du code réel.
2. Lecture ciblée des fichiers qui décident (auth, permissions, endpoints).
3. Grep négatif pour prouver l'ABSENCE (ex. zéro SLO, zéro mapping rôles).
4. POC exécutable minime pour la preuve dynamique.
5. Audit adversaire multi-agents avant de croire au résultat.
