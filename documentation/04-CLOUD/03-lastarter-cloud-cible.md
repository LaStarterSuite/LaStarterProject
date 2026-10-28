# LaStarter Cloud — la cible (spécification de principe)

## L'expérience client (actée)

1. Le client reçoit un **lien de configuration** unique.
2. Ce lien ouvre un assistant : **choix des applications** du catalogue
   (CRM, tickets, drive/docs, chat, wiki, BI…), nom du domaine, branding.
3. Déploiement automatique : provisioning du site Frappe, installation des
   apps sélectionnées, DNS vérifié — **bouton d'automatisation si le DNS est
   chez un registrar compatible (Cloudflare d'abord)**, sinon liste exacte des
   enregistrements à créer avec vérification en continu.
4. À la fin : les URLs des apps choisies, toutes authentifiées par le même
   site identité.

## Architecture cible (v0)

```
Control plane LaStarter (portail SaaS, Next.js ou frappe-ui)
├── catalogue.json         apps épinglées (nom, version, licence, dépendances)
├── orchestrateur          crée site Frappe + installe les apps choisies
│   ├── exécution          frappe_docker (phase 1) / Helm (phase 2)
│   └── serveur client     agent maison (pattern central/agent : API + jobs RQ)
├── DNS                    vérification + API registrar (Cloudflare d'abord)
└── identité               le site Frappe du client EST son IdP (OIDC)
```

## Les choix structurants

- **1 client = 1 site** (partage de bench sur les serveurs managés) ;
  bench dédié pour les clients premium.
- **Identité** : le site principal du client fait IdP (voir
  `00-DECISIONS/03-decision-identite.md`) — pas de service d'identité séparé.
- **AGPL assumé** : le control plane LaStarter sera publié (AGPL).
- **Pas de Firecracker/Atlas** pour démarrer : Docker puis K8s suffisent.

## Ce qu'il faut prouver avant d'écrire le control plane

Le POC self-host (`09-AUJOURDHUI/02-poc-plan.md`) : un frappe_docker + un
site + CRM/Helpdesk installés par script, OIDC entre deux sites. Tout le
reste du cloud n'est que l'industrialisation de ces commandes.
