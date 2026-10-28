# Prochaines étapes — la feuille de route pour l'agent qui reprend

**Lire d'abord : `README.md` (racine), `00-DECISIONS/*`, puis ce fichier.**

## Étape 0 — Mise en place (½ journée)

- [ ] Installer les skills officielles : `npx skills add frappe/skills`
- [ ] Parcourir les dépôts clonés (`../frappe/`) avec `frappe-app-dev` comme
      base de connaissance.
- [ ] Re-générer l'inventaire (dates fraîches) — voir `01-etat-des-clones.md`.

## Étape 1 — POC trancheur (1 journée) — `02-poc-plan.md`

- [ ] frappe_docker opérationnel (port 8081 côté hôte).
- [ ] Site identité + site client (CRM + Helpdesk), SSO OIDC entre eux.
- [ ] (Bonus) Social Login Key → Keycloak 8180.
- [ ] Constat écrit → mise à jour de cette documentation.

## Étape 2 — Vérifications ouvertes (½ journée)

- [ ] **2FA** : localiser/éliminer le doute dans v17 (module absent du
      checkout audité). Bloquant pour la prod de l'IdP.
- [ ] Durées de vie des tokens OAuth provider (expiration/refresh).
- [ ] Test de charge léger : 1 bench, N sites (mesurer la densité).

## Étape 3 — `lastarter_core` (l'app maison, 2-4 jours)

- [ ] Élévation des users OIDC (System User + rôles selon profil) — le gap
      `01-FRAPPE-FRAMEWORK/09-limites-identifiees.md` §1.
- [ ] Branding/white-label (thème, BRAND_NAME).
- [ ] Audit + réglages communs aux briques.
- Développée avec la skill `frappe-app-dev`, revue avec `frappe-code-review`.

## Étape 4 — Catalogue v2 + CLI (1-2 semaines)

- [ ] `catalogue/*.toml` par brique (format doc dans
      `05-DEPLOIEMENT/03-cli-lastarter.md`).
- [ ] Image bench LaStarter par CI (frappe_docker images/custom).
- [ ] CLI : `init`, `deploy`, `apps add/remove`, `doctor` (spec complète au
      même doc). Réutiliser la mécanique secrets/tokens de la CLI v1.

## Étape 5 — Suite et arbitrages produits

- [ ] Suivre frappe/suite (drive/writer/sheets/meet/mail/calendar) — épingler
      dès stabilité.
- [ ] Trancher chat : Raven vs Matrix (Raven = intégration totale ; Matrix =
      fédération).
- [ ] Gameplan post-refonte pour les discussions.

## Étape 6 — LaStarter Cloud (après self-host solide)

- [ ] Control plane : assistant « lien de configuration » + provisionnement
      + DNS automatique (Cloudflare d'abord).
- [ ] Patrons : central/agent/pilot (patterns) + frappe_docker/helm (exécution).
- [ ] 1 client = 1 site ; bench dédié premium ; 1 client = 1 namespace en K8s.

## Rappels permanents

- Toute affirmation d'auth/permissions se vérifie dans le code.
- Épinglage strict, gate licence à chaque bump, jamais main/latest.
- Contribuer amont (les skills fix-issue/ship-it) avant de diverger.
- Pièges machine : `08-HISTORIQUE/04-machines-pieges.md`.
