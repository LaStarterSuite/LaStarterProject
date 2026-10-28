# Helm / Kubernetes

**frappe/helm (MIT)** : chart officiel `erpnext` v8.0.89 (appVersion
v16.52.1, vérifiée).

## Ce que le chart fait

Déploie un environnement « bench-like » sur Kubernetes : deployment web,
workers RQ, scheduler, socket.io, ConfigMaps (common_site_config),
PVC pour les sites, jobs (migrate), Ingress par hostname.

## Comment LaStarter l'utilise

Le chart est orienté ERPNext/1-bench, mais c'est **le patron idéal pour
« 1 client = 1 namespace / 1 release Helm »** :

- `values.yaml` LaStarter : liste des apps (image bench LaStarter), hostname,
  taille, apps à activer.
- Jobs de provisionnement (équivaut `bench new-site` + `install-apps`)
  déclenchés par la CLI/le control plane.
- Ingress : un host par app du client (crm.client.tld, helpdesk.client.tld…)
  pointant toutes vers le même web backend, routées par hostname côté Frappe.

## Position vs frappe_docker

| Phase | Outil |
|---|---|
| POC + self-host simple | frappe_docker (compose) |
| Cloud / clients exigeants | Helm sur K8s |

Les deux utilisent la MÊME image bench LaStarter — zéro divergence de code.
