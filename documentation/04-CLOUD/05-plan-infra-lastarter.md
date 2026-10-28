# Plan d'hebergement LaStarter-as-a-service (2026-10-28)

Reponse aux questions de Bastien : ou heberger, comment isoler les clients,
combien ca coute, comment encaisser, et que faire des depots de l'ecosysteme.
Source : criblage de 18 depots frappe (agents, 2026-10-28) + code local.

## 1. Le modele Frappe, d'abord (ca change tout)

- L'unite de mutualisation n'est PAS le conteneur : c'est le **bench**.
  Un bench = un groupe de conteneurs (backend, workers, scheduler, websocket,
  frontend, une MariaDB, deux Redis) qui heberge **plusieurs sites**.
- L'unite de client = le **site** (une base MariaDB par client, un hostname).
  Frappe Cloud fait tourner des dizaines de sites par bench et plusieurs
  benches par serveur ; un proxy frontal route les hostnames.
- Consequence : « un conteneur par client » serait un gachis massif. Le
  bon gradient d'isolation est : site sur bench mutualise (partage) >
  bench dedie sur VM (premium) > serveur dedie (entreprise) — le meme
  compose frappe_docker aux trois paliers.

## 2. Recommandation par paliers

| Palier | Cible | Infrastructure | Cout infra |
|---|---|---|---|
| Mutualise | PME/TPE, 2-4 apps | 2 serveurs dedies (Hetzner AX41-NVMe 64 GB ~46 EUR/mois ou OVH Advance), 2-3 benches chacun, nginx frontal + TLS, backups offsite quotidiens | ~1,5-3 EUR/client/mois |
| Premium | isolation, IP dediee | 1 VM 8 GB par client (Hetzner CPX41 ~16 EUR/mois, ou instance CloudStack chez son fournisseur, marque blanche) | ~16-26 EUR/mois |
| Entreprise | SLA, region, conformite | serveur dedie du client (ou achete-revendu), exploitation via frappe/pilot, ou press+agent plus tard | au cout + forfait gestion |

- **CloudStack chez son fournisseur** : bon choix pour le palier premium
  (IaaS blanc, VMs a la demande, sous le nom de sa societe, locations UE).
  Le dedie Hetzner/OVH reste imbattable en EUR/GB pour le mutualise.
- **AWS/GCP** : 3 a 8 fois plus cher a service equivalent ; eviter au
  demarrage (sauf demande expresse d'un client).
- **Kubernetes** : pas maintenant. L'unite de deploiement reste le compose
  frappe_docker a tous les paliers ; frappe/helm existe quand la densite le
  justifiera. Les « clusters » de Bastien = a terme, un serveur frontal par
  location qui route vers les serveurs de la region, pas du K8s.

## 3. HA, zero downtime, SLA (la verite terrain)

- MariaDB est le SPOF. « Le meme client actif sur 2 serveurs avec les
  memes donnees » (actif/actif) n'existe pas simplement dans Frappe :
  une base a un primaire. L'offre correcte est **actif/passif** :
  - standard : backups offsite + restauration TESTEE (RTO ~1 h) ;
  - premium : replication MariaDB primaire/secondaire + bascule, LB nginx
    entre 2 serveurs, site primaire sur un bench, secondaire a chaud ;
  - entreprise : region au choix, sauvegardes horaires, SLA contractuel.
- SLA proposables des le jour 1 : 99,5 % standard, 99,9 % premium
  (double serveur + bascule). Le 100 % n'existe pas ; l'engagement se
  construit sur la restauration testee, pas sur la promesse.

## 4. Paiements (proposition progressive)

1. **Jour 1** : vitrine faite avec Builder + Stripe Payment Links. Le
   paiement declenche une notification ; la mise en service reste humaine
   (logos, comptes masters, relecture) — les 400-600 EUR de setup SONT ce
   travail humain, il est honnete de le facturer et de le faire a la main.
2. **Phase 2** : abonnements Stripe geres par l'app payments (deja dans
   notre image, requise par LMS) + webhook -> file de provisionnement
   (bench new-site + lastarter_core) facon press-lite.
3. **Ne pas construire** le provisionnement 100 % automatique avant les
   10 premiers clients payants.

## 5. Prix proposes (benchmark inclus)

| Offre | Prix | Contenu |
|---|---|---|
| Essentiel | 5 EUR/app/mois, plancher 3 apps (15 EUR/mois) + 400-600 EUR de mise en service | apps au choix, bench mutualise, backups quotidiens |
| Business | 59 EUR/mois | toutes les apps, bench dedie ou VM partagee dediee, IP dediee |
| Entreprise | 149-249 EUR/mois | VM/serveur dedie, region au choix, SLA 99,9 %, backups horaires, onboarding complete |

Benchmarks : Neeto ~5-8 USD/utilisateur/mois (le modele cite par Bastien) ;
Google Workspace 6-14,50 EUR/utilisateur/mois ; Zoho One ~37 EUR/mois tout
inclus. Notre tarification par SITE (pas par utilisateur) est plus
previsible pour un B2B et reste tres competitive : un client a 20 salaries
paie 15-59 EUR/mois la ou Workspace couterait 120-290 EUR.

## 6. Page de statut

Aucune app officielle dans l'org frappe (recherche API du 28/10 : 0
resultat). Jour 1 : uptime-kuma auto-heberge, page publique. Contribution
future : une petite app « status » (sante par app + page publique) est un
bon premier ticket a proposer en PR upstream, dans l'esprit du projet.

## 7. Criblage des depots listes (agents, 2026-10-28)

| Depot | Type | Verdict LaStarter |
|---|---|---|
| builder | app v16 | DEJA dans l'image : la vitrine se construit avec |
| payments | app v16 | DEJA dans l'image (requise par LMS) + Stripe pour la vitrine |
| bench | CLI | deja utilise partout ; pas une app |
| frappe_docker | outils | notre methode de build/deploy (layered + compose) |
| frappe-ui | lib Vue | dependance des SPAs ; pas une app |
| newsletter | app version-16 (>=16,<17) | INSTALLABLE, route /newsletters ; exige Python >=3.14 (notre image l'a) |
| blog | app version-16 (>=16,<17) | INSTALLABLE, route /blog/<categorie> |
| whatsapp | app main (>=16-dev,<18-dev) | INSTALLABLE mais webhook Meta = site joignable publiquement ; jeune, pin de commit obligatoire |
| Letters | app main (0.1.0, jeune) | builder d'emails visuel drag-and-drop ; installable, jeune |
| print_designer | app main (>=15) | README : V15/develop uniquement, remplace le moteur PDF (paquets Chromium) ; a valider en POC isole, pas au catalogue stable |
| meet | ARCHIVE | absorbe par frappe/suite — ne pas ressusciter |
| suite | app develop (>=16,<18) | Drive+Writer+Sheets+Slides+Meet+Mail+Calendar en UNE app ; WIP 0.0.1 ; exige des services annexes (SFU Mediasoup, collab). A suivre de tres pres, POC isole plus tard |
| pilot | OUTIL « Frappe Server Manager » | curl+bash, systemd/nginx/TLS pour SES serveurs : candidat serieux pour exploiter nos dedies a l'ere Suite |
| press | control plane Frappe Cloud | self-hostable mais lourd (agent+Ansible) : blueprint de notre cloud (etape 6), pas maintenant |
| agent | daemon serveur de press | la brique « serveur gere » ; utile avec press |
| atlas | gestion de VM d'une region FC | bare-metal/ZFS/WireGuard, pre-production : hors de notre echelle |
| datum | telemetrie FC (FastAPI+ClickHouse) | observabilite de flotte, plus tard |
| suite_cloud | futur control plane Suite | required_apps=insights (telemetrie) ; push du jour ; a suivre |
| grove | nom RECYCLE | c'est maintenant la plateforme d'inference LLM de Frappe, plus l'ancien grove d'hebergement |

## 8. Marque et liens du bureau (sans fork)

- Liens d'aide du navbar : doctype **Navbar Settings**
  (frappe/core/doctype/navbar_settings, table enfant help_links) :
  configurable par documents sur chaque site -> remplacer « Support
  Frappe » par notre helpdesk. Matiere lastarter_core.
- Dialogue « A propos » : affiche les versions -> informatif, a laisser.
- Regle : tout ce qui est un document (Navbar Settings, Website Settings,
  System Settings) se configure par lastarter_core, jamais par fork.

## 9. Onboarding (verifie dans le code)

- Framework present dans le core : Module Onboarding, Onboarding Step,
  Onboarding Step Map, Onboarding Permission (frappe/desk/doctype) ; CRM
  en declare un (crm/hooks.py, crm/api/onboarding.py).
- Le wizard de premier demarrage pose langue/pays/fuseau/devise mais est
  reserve au System Manager ; les questions a la creation de site vues sur
  Frappe Cloud viennent de LEUR couche SaaS, pas du framework.
- Notre flux cible : lastarter_core initialise le site et les users ;
  l'utilisateur final voit l'onboarding de chaque app. Note, pas aujourd'hui.

## 10. Feuille de route hebergement

1. P1 : demo publique (stack actuelle + donnees d'exemple + comptes visiteurs).
2. P2 : serveur pilote dedie (Hetzner/OVH), stack identique en production,
   1er client pilote au tarif mutualise.
3. P3 : vitrine Builder + Stripe Payment Links.
4. P4 : exploitation des dedies avec pilot ; offsite_backups.
5. P5 : contributions upstream (issues/PR) ; app « status ».
6. P6 : suite (bureautique+visio) en POC isole quand stable ; press/agent
   pour l'automatisation complete du cloud.
