# Décision — LaStarter Cloud

**Date : 2026-10-28. Statut : ACTÉE (principe). L'implémentation vient après le POC self-host.**

## La promesse produit

Le client (ou nous pour lui) installe LaStarter en trois gestes :
1. Il reçoit un **lien de configuration**.
2. Sur ce lien, il **choisit les applications** qu'il veut dans le catalogue.
3. Le déploiement part : domaine provisionné, enregistrements DNS vérifiés —
   et si son DNS est chez un registrar compatible (ex. Cloudflare), **un
   bouton automatise tout** ; sinon la liste exacte des enregistrements à
   créer lui est présentée.

## Le modèle à suivre : celui de Frappe Cloud, mais simplifié et rebrandé

Frappe Cloud est hiérarchique et **le multi-tenant est le BENCH, pas le
conteneur** : un bench porte N sites, chaque site = une base MariaDB + un
hostname routé par nginx (voir `04-CLOUD/01-modele-multi-tenant.md`). Les
composants press/central/agent/pilot ne se réutilisent pas tels quels (trop
couplés aux DocTypes Frappe, IAM et facturation coulés dedans) mais leurs
**patterns** sont validés par la production :

| Pattern repris | Source Frappe | Usage LaStarter |
|---|---|---|
| Control plane qui orchestre des serveurs via un agent | press + central | Control plane LaStarter (équipes, instances, apps activées) |
| Agent local + file de jobs + callbacks | agent (Flask + RQ) | Exécution réelle sur le serveur client (install app, migrate, backups) |
| CLI de gestion par instance | pilot (« Server Manager », successeur de bench) | CLI embarquée dans l'instance LaStarter |
| Site = base + hostname | bench | 1 client LaStarter = 1 site Frappe (+ ses apps activées) |
| Images de runtime reproductibles | frappe_docker images/custom | Image LaStarter = bench pré-emballé avec nos apps |

## Les briques concrètes retenues

- **frappe_docker (MIT)** : réutilisable tel quel — le moyen officiel de faire
  tourner le runtime, avec images custom incluant les apps LaStarter.
- **Chart Helm (MIT)** : patron « 1 client = 1 namespace/release », à adapter
  à notre topologie d'apps.
- **Central/Agent** : à imiter (vocabulaire capacités/grants scopés) plutôt
  qu'à embarquer.

## Ce qu'on n'embarque pas

- Press (facturation/marketplace coulées dans les DocTypes, dashboard piloté
  bench) : inspirant, pas embarquable.
- Atlas (Firecracker + ZFS + WireGuard, pré-production) : surdimensionné pour
  un premier cloud ; Docker/K8s suffisent.

## Séquence

Self-host d'abord (POC → CLI → catalogue), cloud ensuite — le cloud n'est
qu'une industrialisation du même flux de provisionnement.
