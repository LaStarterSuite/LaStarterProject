# Décision — partir sur Frappe Framework

**Date : 2026-10-28. Statut : ACTÉE.**

## Pourquoi

- **20 ans de maintenance**, framework MIT, ~11 000 étoiles, poussé ce
  mois-ci ; apps à forte adoption (CRM 3 873★, Helpdesk 3 451★, LMS 3 351★).
- **Couverture directe du catalogue LaStarter** : CRM, tickets, drive, chat,
  visio d'équipe, wiki, BI, LMS — tout existe et est actif.
- **Un seul langage de déploiement** : fini le mille-feuille Django + Sails +
  PHP du catalogue v1 ; un bench, des apps, un modèle de données commun.
- **IdP intégré** : Frappe émet de l'OIDC (voir
  `01-FRAPPE-FRAMEWORK/04-oidc-provider.md`) — l'identité universelle ne
  nécessite plus un serveur séparé.
- **Stack cloud complète en open source** : Press, Central, Agent, Atlas,
  Pilot, bench, frappe_docker, Helm — le code de Frappe Cloud est étudiable et
  partiellement réutilisable (voir `04-CLOUD/02-stack-frappe-cloud.md`).
- **Communauté et contribution** : ~2 000 issues ouvertes sur le framework ;
  la stratégie LaStarter « contribuer amont » est réaliste et bien vue.

## Ce qu'on accepte de perdre (décision consciente)

- **Keycloak comme IdP central** : remplacé par Frappe IdP ; Keycloak redevient
  branchable en option (preset natif) si la doctrine rechange.
- **TypeScript/Postgres/Prisma comme socle** : le socle est Python/MariaDB ;
  les compétences Next.js restent utiles pour les frontends custom éventuels
  (frappe-ui est Vue).
- **Convex** : abandonné (voir `04-decision-convex-stop.md`).
- **Matrix/LiveKit comme briques imposées** : Raven (chat + appels) couvre une
  partie du besoin côté Frappe ; l'arbitrage chat/visio reste ouvert.

## Alternatives écartées (et pourquoi)

| Option | Verdict |
|---|---|
| Poursuivre catalogue v1 (La Suite) | Apps de très bonne facture mais hétérogènes (3 backends différents, 3 modèles d'users), SSO à câbler par app, theming inégal |
| Portage des frontends La Suite sur Convex | 34 000 lignes rien que pour projects ; socket.io client v2 incompatible avec le modèle Convex ; coût énorme pour refaire ce que Frappe fournit |
| Supabase comme socle | Bon plan B v1, mais pas de suite applicative prête — on aurait tout codé |
| Frappe + Convex hybride | Rejeté : une app Frappe vient avec son backend ; deux plateformes = double ops sans gain |

## Risques acceptés

- Dépendance au rythme et aux choix de Frappe Technologies (mitigé : MIT,
  épinglage des versions, contribution amont).
- MariaDB uniquement (pas de Postgres).
- Frappe Suite (drive/writer/sheets/slides/meet/mail/calendar) en **v0.0.1** :
  à suivre, ne pas épingler en prod avant stabilisation.
