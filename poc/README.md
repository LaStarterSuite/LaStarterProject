# POC trancheur LaStarter v2

Preuve en local du socle LaStarter v2, uniquement avec des outils officiels
Frappe (aucun code LaStarter). Plan d'exécution de référence :
`documentation/09-AUJOURDHUI/02-poc-plan.md`.

## Ce qu'il doit prouver

1. Un bench Frappe tourne en Docker (frappe_docker) avec CRM + Helpdesk.
2. Un site Frappe (`id.localhost`) est l'IdP OIDC d'un AUTRE site
   (`crm.localhost`) — universalité de l'identité.
3. Le SSO fonctionne au navigateur : un login, deux apps accessibles.
4. (Bonus) Keycloak 26.4 existant (port 8180) branché en Social Login Key.

## Fichiers

| Fichier | Rôle |
|---|---|
| `apps.json` | Apps embarquées dans l'image bench (frappe version-16 + crm@main + helpdesk@main, comme le marketplace Frappe Cloud) |
| `build.sh` | Construit l'image `lasarter-bench:poc` (apps.json passé en secret de build) |
| `compose.yml` | Stack complète adaptée de `pwd.yml` : port hôte 8081, deux sites, Host-based routing |
| `oidc-setup.sh` | Câble l'OIDC : OAuth Client côté IdP, Social Login Key côté consommateur (idempotent) |
| `verify.sh` | Vérifications HTTP et présence des objets OIDC |

## Exécution

```sh
sh poc/build.sh            # 15-30 min la première fois
docker compose -f poc/compose.yml up -d   # crée les sites (oneshot create-sites)
sh poc/oidc-setup.sh       # câble l'OIDC quand les sites répondent
sh poc/verify.sh           # vérifications
# Navigateur : http://id.localhost:8081 (login admin/admin)
#              http://crm.localhost:8081/crm -> « Login with Frappe » -> SSO
```

## Choix notables

- **Port 8081** : le 8080 est occupé sur cette machine
  (`documentation/08-HISTORIQUE/04-machines-pieges.md`).
- **`FRAPPE_SITE_NAME_HEADER=$$host`** : le Host de la requête désigne le
  site (multi-sites sur un seul nginx).
- **`extra_hosts: host-gateway`** sur le backend : l'échange de tokens OIDC
  est fait côté serveur, et glibc ne résout pas `*.localhost` (les conteneurs
  joignent l'IdP via l'hôte, qui publie 8081).
- **Secrets en clair (admin/admin, secret client POC)** : acceptable en POC
  local, interdit au-delà (règle : secrets dans site_config/coffre, jamais
  dans git).
- **crm@main / helpdesk@main** : c'est ce que déploie Frappe Cloud en
  production (`documentation/06-CATALOGUE/03-pins-frappe-cloud.md`) ;
  l'épinglage par release tag est l'affaire du catalogue v2.
