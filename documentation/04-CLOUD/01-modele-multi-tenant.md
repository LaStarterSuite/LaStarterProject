# Le modèle multi-tenant de Frappe (et de Frappe Cloud)

**C'est LA chose à comprendre avant de dessiner LaStarter Cloud.**

## L'unité de mutualisation : le BENCH, pas le conteneur

```
Serveur
└── bench
    ├── apps/           frappe + crm + helpdesk + … (partagés par les sites)
    ├── sites/
    │   ├── client-a.example.com/   ← 1 base MariaDB dédiée + ses apps activées
    │   ├── client-b.example.com/   ← 1 autre base, MÊME code d'apps
    │   └── common_site_config.json
    └── config/nginx    ← routing par hostname (server_name par site)
```

- **1 bench = N sites** ; chaque site choisit les apps installées.
- Isolation = par BASE de données (et par hostname), pas par machine.
- nginx route le hostname vers le bench ; le web worker gère tous les sites.
- Un site peut activer/désactiver des apps installées (dépendances gérées).

## Ce que ça change vs LaStarter v1

La v1 déployait **un stack Docker complet par brique** (base + app + workers
par client). Frappe mutualise : **1 serveur porte N clients** avec des bases
séparées — densité économique bien meilleure, backups et migrations par site.

## Les trois étages de Frappe Cloud (audit)

1. **bench** : mutualisation logicielle (ci-dessus).
2. **serveurs** : machines physiques/VM hébergeant des benches.
3. **contrôle global** : press (v1) puis central (v2) — équipes, facturation,
   provisioning, pilotage via agent/pilot dans chaque VM.

## Conséquence de design pour LaStarter Cloud

« 1 client = 1 site Frappe » (ou 1 bench dédié pour les clients premium).
Le choix d'apps du client = la liste des apps installées/activées sur SON
site — exactement le sélecteur du lien de configuration visé.
