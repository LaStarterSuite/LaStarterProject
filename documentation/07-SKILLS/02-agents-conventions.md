# Conventions de travail pour l'agent LaStarter

## Règles de fond

1. **Zéro fork amont tant qu'un hook suffit** (voir
   `03-LICENCES/02-regles-rebrand.md` — seuil diverger/converger).
2. **Épinglage strict** : toute app référence une release exacte ; main =
   interdit en prod.
3. **Sécurité avant confort** : toute affirmation d'auth/permissions se
   vérifie dans le code ou par un test — jamais par la doc seule (les
   audits de cette documentation ont prouvé l'écart doc/réalité à plusieurs
   reprises).
4. **Contribuer amont** : issue → `fix-issue` → PR ; divergence locale
   minimale et documentée pendant l'attente du merge.

## Conventions techniques

- App custom unique : `lastarter_core` (hooks.py comme seule colle —
  auth_hooks pour l'élévation des users OIDC, doc_events pour l'audit,
  scheduler_events pour les syncs).
- Secrets dans `site_config.json` / coffre, jamais en base ni dans git.
- Branding par CSS injecté + variables (pattern catalogue v1 + frappe-ui).
- Tests : chaque app Frappe moderne embarque e2e Playwright — s'appuyer sur
  leurs suites, ajouter les nôtres au niveau catalogue.
- Français pour la documentation produit, Simplified Technical English pour
  la doc/PR amont (skill technical-writing).

## Les 2 000 issues du framework comme levier

- Chercher l'issue AVANT de coder un contournement : elle existe souvent.
- Corriger amont = régler le problème pour nous ET crédibiliser LaStarter.
- Garder un fichier `CONTRIBUTIONS.md` par app : issues ouvertes, PRs
  soumises, merges — c'est la carte de divergence de LaStarter.
