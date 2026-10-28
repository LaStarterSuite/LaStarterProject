# frappe-ui — le design system commun

**frappe-ui** (MIT, v1.0.2, 1 343 étoiles, poussé ce mois-ci) est le toolkit
frontend officiel : « The all-in-one toolkit for modern frontends ».

## Contenu vérifié

- **58 composants** dans `frappe-ui/src/components` (boutons, dialogs, list
  views, formulaires…).
- Charts, composables (useQuery-like), utilitaires de data-fetching resource.
- TypeScript.

## Qui l'utilise

CRM, Helpdesk, LMS, Raven, Gameplan, Insights, Suite — **toutes les apps
modernes de l'org**. C'est ce qui garantit la cohérence visuelle entre les
briques LaStarter (là où le catalogue v1 mélangeait des designs La Suite
hétérogènes).

## Implication pour LaStarter

- Les apps qu'on embarque arrivent avec leur UI frappe-ui : pas de refonte.
- Pour nos écrans à nous (portail, panel admin, pages branding), frappe-ui
  est le choix par défaut — cohérence immédiate avec les apps embarquées.
- Le white-label se fait par CSS/thème au-dessus de frappe-ui (le catalogue v1
  injectait un theme.css par la passerelle : mécanisme transposable).
