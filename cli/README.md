# lastarter

Installation assistée de la **suite LaStarter** (Frappe v16, SSO OIDC, mail
Stalwart optionnel) sur un serveur Linux. Un seul fichier Python, zéro
dépendance : `python3` suffit.

## Usage

```bash
curl -O https://raw.githubusercontent.com/LaStarterSuite/LaStarterProject/main/cli/lastarter.py
python3 lastarter.py
```

La CLI vérifie le serveur (docker, ports 80/443, RAM, disque), pose les
questions (domaines, liste d'applications, administrateur, données de
démonstration, HTTPS), génère la pile docker avec des versions épinglées,
construit l'image, installe les deux sites (identité + bureau), câble le SSO
entre eux, sème les données de démonstration et imprime la checklist DNS.

Prérequis : Ubuntu 22.04/24.04 ou Debian 12, 4 Go de RAM, 20 Go de disque,
Docker + Compose v2, git, curl (la CLI donne les commandes s'ils manquent).

## Ce qui est déployé

- Un bench Frappe v16 multi-sites : le site d'identité (le SSO OIDC) et le
  site bureau (les applications), derrière un Caddy à certificats
  automatiques (ou en HTTP pour les tests internes).
- Le pack complet (14 apps épinglées, les forks LaStarterSuite) ou le pack
  démo commerciale (CRM + Helpdesk + Raven + LMS).
- Stalwart (v0.16.27, la ligne éprouvée) pour le courrier interne, en option.
- Les données de démonstration : leads, tickets, cours LMS, espace de chat.
- Le bureau (`/desk`) comme page d'accueil de tous les utilisateurs.

## Après l'installation

- Bureau : `https://<ton-domaine>/desk` — le sélecteur d'applications.
- Identité : `https://id.<ton-domaine>` — la connexion SSO unique.
- Webmail (si Stalwart) : `https://mail.<ton-domaine>`.
- Reprise après arrêt : `cd <répertoire> && docker compose up -d`.
- Tout réinstaller de zéro : `bash provision.sh` (idempotent).

## Pourquoi ce format

Un seul fichier sans dépendance : il tourne sur un serveur nu, se copie où
tu veux, se lit avant de s'exécuter. Le code généré t'appartient (MIT).
