# Retour terrain — test réel de Frappe Cloud (2026-10-28)

**L'utilisateur a déployé et testé Frappe Cloud en conditions réelles.**
Ce document capture les observations de première main qui valident (et
affinent) la cible LaStarter Cloud.

## Ce qui a été testé et validé

- **Déploiement du LMS** via le marketplace : installation de l'app, URL du
  site, provisioning du site — « ça fonctionne très très bien ».
- **Marketplace d'apps** : ~40+ apps installables directement depuis le
  dashboard (liste complète relevée : voir
  `06-CATALOGUE/03-pins-frappe-cloud.md`), affichage propre, installation
  gratuite (on paie l'hébergement).
- **SSO entre apps automatique** : un lien mène au cloud, l'utilisateur est
  connecté partout — l'expérience « une identité, toutes les apps » attendue
  de LaStarter existe déjà chez eux.
- **Intégrations inter-apps natives** : le LMS propose « Automatically add
  your students and staff to Raven channels, by your own rules » — les apps
  du même site se découvrent et coopèrent. C'est le bénéfice structurel du
  modèle Frappe (users/rôles partagés) confirmé en production.
- **i18n** : les apps sont traduites (qualité variable mais la couche existe).
- **Prix relevés** : Sites partagés dès **5 $/mois**, serveurs dédiés dès
  **40 $/mois** ; multi-cloud (Hetzner pour dev/demo, AWS/OCI dédié pour la
  prod critique) ; essai 14 jours ; facturation à l'usage + prépaid.

## Ce que LaStarter Cloud reprend (et ce qu'il fait différemment)

**Reprendre** : le modèle Sites (partagé, entrée de gamme) / Serveurs (VM
dédiée, montée en gamme) ; le marketplace d'apps one-click ; le SSO
automatique inter-apps ; les intégrations inter-apps par règles ; la
multi-région plus tard ; l'essai gratuit.

**Différencier (position B2B assumée)** :
- Cible PME/collectivités francophones (fr, règlementation, données UE).
- Catalogue curaté et épinglé (pas 150 apps : le catalogue LaStarter
  validé licence par licence).
- Assistant « lien de configuration » avec sélection d'apps + DNS
  automatisé (Cloudflare d'abord) — le différenciant onboarding.
- Branding white-label par client.
- Support en français.

## Notes techniques vues sur le terrain

- Toutes les apps n'apparaissent pas dans le marketplace (certaines absentes
  alors qu'elles existent) — notre catalogue curaté est justement un avantage.
- La traduction fonctionne par couches (crowdin) — nos apps devront déclarer
  leurs fichiers de traduction.
- Le dashboard cloud expose : Sites, Servers, Hybrid hosting, apps
  installées, monitoring, backups offsite, SSH audité, analytics — la liste
  des features minimum de notre control plane.
