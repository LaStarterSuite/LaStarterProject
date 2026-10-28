# Auto-heberger press (le systeme Frappe Cloud) sur ses serveurs — runbook (2026-10-28)

Reponse a la demande de Bastien : installer « leur stack a eux » sur des
serveurs payes par lui, avec le bouton « nouvelle app » vu sur Frappe Cloud.
Source : lecture du code de frappe/press (clone local, commit fa19598,
develop) par 3 agents + guide officiel docs.frappe.io/cloud/local-fc-setup.

## 0. Reponses courtes

- **Licence** : press et agent sont AGPL-3.0 integraux. Usage commercial
  AUTORISE. Obligation : copyleft reseau (section 13) — si on modifie press,
  on publie les sources aux utilisateurs du service. C'est exactement la
  doctrine open source du projet : aucun obstacle.
- **Le panneau vu par Bastien** (bouton nouveau site, liste d'apps,
  installation en un clic) = le repertoire `dashboard/` de press (Vue),
  servi sur /dashboard. Auto-heberger press = retrouver ce panneau.
- **Un conteneur par client ? NON.** Un bench (groupe de conteneurs autour
  d'une base) est PARTAGE par plusieurs sites ; un site = une base MariaDB
  + un hostname. Un bench par (groupe d'apps, serveur), jamais par client
  (bench/README.md : « Multiple sites share a single bench »).
- **Un client reparti sur 2 serveurs ? NON en actif/actif.** Un site vit
  sur un seul bench + une base. Le code prevoit : repartition des CLIENTS
  sur plusieurs serveurs (Release Group multi-serveurs, migration de site
  par backup), replication MariaDB primaire/replica (playbook
  mariadb_prepare_replica.yml), et Site Replication = copie ponctuelle
  depuis un backup (sites standby). C'est de l'actif/passif.

## 1. Les composants et leurs roles

| Composant | Role |
|---|---|
| Control plane press | un bench Frappe standard (sa propre VM) avec l'app press installee ; abrite le dashboard client ; frappe >=15,<17 (v16 OK), Python >=3.10, ansible 3.4, docker 7.1 |
| frappe/agent | daemon Flask sur CHAQUE serveur cible (127.0.0.1:25052 derriere son nginx 443) ; press l'appelle en HTTPS + bearer token ; chaque operation = AgentJob trace |
| Ansible (playbooks press/playbooks/) | preparation et mise a jour des serveurs via SSH root ; joue server.yml / database.yml / proxy.yml / unified_server.yml / self_hosted.yml |
| Proxy Server | nginx + ProxySQL + docker ; route les hostnames vers les app servers ; obligatoire |
| Database Server | MariaDB 10.6 + agent ; un par cluster (replicas possibles) |
| Server (app) | nginx + redis + docker + durcissement (fail2ban, auditd...) ; les benches tournent en conteneurs Docker, gunicorn/workers partages par bench |
| Release Group (« Bench group ») | la liste d'apps ependlee par le client ; chaque deploy construit des images Docker (Deploy Candidate) puis cree un bench par serveur cible |
| Site | le client : base + hostname, rangé sur un bench actif du groupe |
| Virtual Machine | provisionnement par API cloud : AWS EC2, OCI, Hetzner, DigitalOcean, Frappe Compute (PAS de CloudStack) |
| Self Hosted Server | doctype « Hybrid Cloud » : serveur EXISTANT relie par SSH seul (le cas de Bastien) |
| Registry Docker | requis pour les images des benches (externe ou dedie) |

## 2. Topologies minimales (deduites du code : bootstrap.py, Cluster.base_servers, unified_server.yml)

- Standard : 1 VM press + 1 Proxy + 1 Database + 1 App (4 VM) + registry.
- Unifie (recommande pour demarrer) : 1 VM press + 1 Proxy + 1 VM
  app+base (unified_server.yml) = **3 VM + registry**.
- Specs minimales CONTROLEES par le code (Self Hosted Server) :
  RAM >= 4 GB, vCPU >= 2, stockage >= 40 GB par serveur.
- Production reelle de Frappe ajoute Registry/Log/Monitor/Trace dedies :
  optionnels dans le code.

## 3. Ordre d'installation (bootstrap.py + guide local-fc-setup)

1. **Control plane** : bench classique (mariadb+redis+press) sur sa VM ;
   `bench get-app https://github.com/frappe/press` puis install-app ;
   after_install cree l'equipe Administrator et le Cluster « Default ».
   Mise a jour = git pull master + bench migrate (JAMAIS bench update).
2. **Press Settings** : domaine racine, cluster par defaut, webroot +
   repertoire certbot, **registry Docker**, agent_repository_owner.
3. **Root Domain** : + certificat TLS wildcard ACTIF (bootstrap attend) —
   le guide officiel suppose Route53/certbot-dns-route53 : substituer NOTRE
   DNS (wildcard *.domaine pointe vers le proxy).
4. **Proxy Server** -> action « Setup Server » (playbook proxy.yml).
5. **Database Server** -> « Setup Server » (database.yml, noter le mot de
   passe root MariaDB).
6. **Server (app)** -> « Setup Server » (server.yml) puis « Add to Proxy ».
7. **Catalogue** : Site Plan (gratuit), App « frappe » (1re, sensible a la
   casse), App Source (repo + branche), App Release (Draft -> Approved),
   Release Group (serveur cible) -> **Deploy** (build Docker) -> **Site**.
   C'est LA que le bouton « nouvelle app » du dashboard apparait pour les
   clients : ils installent une app de la liste dans LEUR site.

## 4. Relier SES serveurs (dedies achetes, VM CloudStack)

- Doctype **Self Hosted Server** (SHS-#####) : on donne IP/port/user SSH +
  cle ; press joue ping.yml (inventaire, controle specs), puis
  self_hosted.yml qui installe l'agent ; ensuite boutons ordonnes :
  creer Proxy/Database/App Server avec is_self_hosted=1. Zero API cloud.
- Pour un serveur DEJA installe a la main : new_server=False +
  is_server_setup=True (press saute le provisionnement).
- Gating : equipe avec self_hosted_servers_enabled (« Hybrid Cloud ») ;
  un cluster hybride exige un proxy.
- Une VM CloudStack existante s'enregistre DONC sans ecrire de provider.
- Un provider CloudStack complet (provisionnement auto par API) = diff
  transversal lourd (~15 fichiers, pas d'abstraction provider) :
  contribution upstream plausible mais pas maintenant. Le chemin sans fork
  = Self Hosted Server ; on garde CloudStack comme SOURCE de VMs (IP,
  snapshots), press comme plan de controle.

## 5. Risques et travail reel a prevoir

- **Aucun guide production officiel** : local-fc-setup est un setup de
  dev/test (domaine fc.frappe.dev, Route53, registre DO). Prevoir 1 a 2
  semaines d'ingenierie sur 3 VM de test avant la moindre offre.
- Couplages Frappe Cloud a neutraliser : singletons Registry/Log (Kibana)/
  Monitor/Trace, facturation Stripe, marketplace — inutiles mais presents.
- Chaine ependlee vieillissante : ansible 3.4, MariaDB 10.6, depot Docker
  « focal » code en dur meme sur jammy, agent installe depuis master non
  verrouille (figer agent_repository_owner/branch dans Press Settings).
- Nos jobs planifies specifiques doivent exclure les serveurs self-hosted
  (le code de press le fait deja pour les siens).

## 6. Recommandation LaStarter (double voie)

- **Jour 1 (prouve aujourd'hui)** : offre mutualisee sur notre compose
  frappe_docker + lastarter_core, sur des VMs (CloudStack ou ailleurs).
  Le client achete, on provisionne, ca tourne ; pas de dépendance press.
- **En parallele** : POC press sur 3 VM de test (2-3 jours de montage +
  1-2 semaines de mise au point). Objectifs de validation : installer une
  app en un clic, enregistrer un serveur self-hosted, backups offsite,
  dashboard client. Bascule de l'offre vers press quand ce POC passe.
- **Etapes press dans l'ordre** : VM control plane -> 2 VM cluster
  (proxy + unifie) -> DNS + wildcard -> Press Settings + registry ->
  Setup des 3 serveurs -> Release Group « lasarter-v16 » (nos 13 apps
  epingles) -> 1er site de test -> puis Self Hosted Server (VM CloudStack).

## 7. Offres (rappel acte avec Bastien)

- Mise en service : 500 EUR (logo, comptes masters, relecture) — travail
  humain facture, fait a la main au debut.
- Abonnements Stripe via l'app payments + provisionnement automatique :
  PAS avant 10 clients payants.
- Petit plan 5 EUR/app/mois (particuliers) : viable seulement sur du
  mutualise dense (le modele bench/site le permet) — a ouvrir apres le
  pilote B2B.
