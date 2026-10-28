# Gameplan (frappe/gameplan)

**Licence : AGPLv3.** 520 étoiles, push 2026-10-27. Verdict LaStarter : **marginal** (en transition).

## Qu'est-ce que c'est

Plateforme de discussions pour équipes : forums, threads, **pages/docs
légers**, tâches. 30 doctypes, 163 .vue, 220 .py. Signes d'une refonte
outillée en cours : CODEBASE_ANALYSIS.md, SHELL_EXTRACTION_PLAN.md,
HANDOFF-mutation.md, TEST_SUITE_PLAN.

## Authentification (audit)

Framework only — les mentions OAuth dans le code sont des commentaires
décrivant le comportement du framework (gameplan/api.py:183,255).

## Pourquoi « marginal » aujourd'hui

- La refonte en cours rend l'épinglage inconfortable (l'app va bouger).
- Son périmètre (discussions + docs légers + tâches) chevauche Wiki et Suite.
- À réévaluer à la sortie de la refonte : potentiellement la brique
  « discussions » du catalogue v2.
