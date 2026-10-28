# frappe_docker — le déploiement conteneurisé officiel (MIT)

**Le composant le plus portable de toute la stack cloud. Réutilisable tel quel.**

## Ce que le dépôt fournit

- **Images de production** (`images/production/`) : runtime Frappe
  conteneurisé (web, workers, scheduler, socket.io).
- **Images custom** (`images/custom/`) : la méthode officielle pour construire
  une image « bench » contenant frappe + NOS apps — c'est ainsi que naîtra
  l'image LaStarter.
- **Compose prêt à l'emploi** : `pwd.yml` (« pass-with-docker ») fait tourner
  un site complet en une commande (le README officiel donne
  Administrator/admin comme credentials par défaut — à changer).
- Configs par variables d'environnement (DB, Redis, backends S3).

## Recette LaStarter (phase self-host)

1. Construire `lasarter-bench:<version>` depuis `images/custom/` avec
   apps.json = frappe + crm + helpdesk + wiki + nos apps épinglées.
2. Compose par client : ce bench + MariaDB + Redis + creation site +
   install-apps (oneshot) + nginx/Caddy en passerelle TLS.
3. Healthchecks + single replica web (le runtime Frappe ne scale pas
   horizontalement comme un service stateless ; on scale par serveurs).

## Rappels d'ops

- MariaDB obligatoire (pas de Postgres).
- Les jobs = workers RQ + Redis + scheduler (conteneurs dédiés dans le compose).
- socket.io conteneur séparé, exposé derrière la passerelle (upgrade WS).
- Backups : `bench backup` / jobs planifiés + stockage S3.
