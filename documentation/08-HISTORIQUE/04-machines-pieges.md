# Pièges de la machine de développement (Windows 11 / Git Bash)

Réflexes à avoir sur CETTE machine (constatés en session, tous reproductibles).

## Git Bash / MSYS

- **Git Bash convertit les chemins POSIX en chemins Windows dans les
  arguments** : `docker exec <c> /opt/keycloak/bin/kcadm.sh` devient
  `C:/Program Files/Git/opt/...` → exit 127 silencieux.
  Fix : `export MSYS_NO_PATHCONV=1` AVANT la commande (ou l'exporter en tête
  des scripts, comme docker/keycloak-setup.sh).
- `/tmp` de Git Bash ≠ `/tmp` vu par node : ne pas écrire un fichier temporaire
  dans /tmp pour le relire depuis node — écrire dans le workspace.
- Les heredocs `<< 'EOF'` fonctionnent, mais une commande de plusieurs
  centaines de lignes finit par casser au parsing : préférer l'écriture de
  fichiers par l'outil dédié pour les gros contenus.

## Docker

- **Une automation de la machine stoppe/supprime périodiquement des
  conteneurs** (observé 2× en une soirée, synchronisé avec les redémarrages
  d'autres projets de l'utilisateur). Conséquences :
  - toujours déclarer les services en compose (recréables) + volume persistant ;
  - prévoir un watchdog `docker compose up -d --wait` en arrière-plan ;
  - une régénération de secret client ⇒ re-synchroniser les fichiers .env des
    apps (le script keycloak-setup.sh le fait) et redémarrer les apps.
- **Port 8080 déjà occupé** (autre projet) : Keycloak tourne sur **8180**,
  le POC frappe_docker devra mapper 8080→8081 côté hôte.
- Port 5432 occupé (lms-postgres) : ne pas y toucher, MariaDB n'en a pas
  besoin.

## Sessions d'agent

- Les process d'arrière-plan ont une **limite de 2 h** : dev servers,
  watchers et watchdogs meurent périodiquement — relance mécanique
  (tuer l'orphelin sur le port, redémarrer).
- Un process tué peut laisser un **orphelin** qui garde le port : toujours
  `netstat` → `taskkill //F //PID` avant de redémarrer un serveur.
- Curl exit 0 même sur HTTP 404 : utiliser `-w "%{http_code}"`, pas le code
  de sortie, pour tester une URL.
