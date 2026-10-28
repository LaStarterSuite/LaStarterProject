# La stack de Frappe Cloud — rôles, licences, réutilisabilité

**Audit des dépôts clonés (code + licence). Tous AGPLv3 sauf mention.**

| Composant | Rôle | Réutilisabilité LaStarter |
|---|---|---|
| **press** | Frappe Cloud v1 : control plane Frappe auto-hébergeable — dashboard client (Vue), marketplace, facturation, orchestration de benches/sites | Trop couplé (IAM/facturation dans les DocTypes, tout pilote des benches) — patterns à imiter seulement |
| **central** | Control plane global v2 (successeur de press) : équipes, permissions, serveurs, sites, services managés, facturation ; « front door » | À adapter : le vocabulaire capacités/grants scopés par serveur se transpose presque tel quel (`server` → `instance client`) |
| **agent** | Déployé sur chaque serveur : API Flask (port 25052) + workers RQ qui exécutent réellement les opérations, callbacks vers le control plane | **À adapter** : l'architecture « agent local + file de jobs + callbacks » est exactement le besoin serveur-client de LaStarter Cloud |
| **atlas** | Gestionnaire de VM de Cloud v2 (pré-prod) : Firecracker + ZFS + WireGuard + « Metal » ; SPEC.md au dépôt | Frappe-spécifique aujourd'hui, conceptuellement le plus intéressant (isolation VM) — surdimensionné pour démarrer |
| **pilot** | « Frappe Server Manager » : successeur moderne du CLI bench, vit dans chaque VM client (CLI + Admin API Flask + UI Vue) | À adopter SI socle Frappe retenu : il pilote sites/apps/migrate — candidat à industrialiser |
| **bench** (GPLv3) | CLI historique : benches, sites, apps, migrations, backups, multi-tenant | Indispensable au socle ; à connaître à fond (concept site = base + hostname) |
| **frappe_docker** (MIT) | Conteneurisation officielle : images production, images custom (bench + nos apps), compose | **Réutilisable tel quel** — le composant le plus portable |
| **helm** (MIT) | Chart `erpnext` v8.0.89 (appVersion v16.52.1) : déploiement K8s « bench-like » | **À adapter** : patron « 1 client = 1 namespace/release » avec jobs de provisionnement |

## Le verdict d'audit

Les six composants de contrôle sont trop frappe-spécifiques à embarquer tels
quels ; **frappe_docker et helm se valorisent immédiatement**, et les
patterns de central/agent/pilot donnent l'ossature d'un control plane
LaStarter maison (AGPL : si on copie du code, on publie — cohérent avec le
projet ; sinon on s'inspire des patterns en réécrivant).
