# Cycle de vie d'une app Frappe

## Création et installation

```sh
bench get-app <url-ou-nom>       # clone l'app dans apps/ + installe ses deps
bench new-site <host>            # crée le site (base MariaDB + site_config)
bench --site <host> install-app <app>
bench --site <host> migrate      # applique les migrations de schéma
```

En Docker, tout cela est encapsulé par **frappe_docker** (voir
`05-DEPLOIEMENT/01-frappe-docker.md`) : on construit une image « bench »
contenant frappe + nos apps (`images/custom/`), puis les entrypoints créent
les sites et installent les apps.

## Structure d'une app (ce que l'agent DOIT connaître)

| Élément | Rôle |
|---|---|
| `hooks.py` | LA colle : `doc_events`, `auth_hooks`, `scheduler_events`, `website_route_rules`, `override_whitelisted_methods`… |
| `<app>/<module>/doctype/<x>/x.json` | Définition du DocType (champs, permissions) |
| `<app>/<module>/doctype/<x>/x.py` | Contrôleur (validate, on_update…) |
| `api/*.py` | Endpoints `@frappe.whitelist()` (API manuelle) |
| `patches/` | Migrations de données versionnées |
| `public/` + `www/` | Assets et pages serveur |

## Les hooks qui nous importeront (app `lastarter_core`)

- `auth_hooks` : brancher notre logique à l'authentification (ex. élever un
  user OIDC provisionné en « System User » selon son domaine/rôle).
- `doc_events` : audit, sync inter-apps.
- `override_whitelisted_methods` : durcir ou remplacer des endpoints.
- `scheduler_events` : syncs périodiques (ex. licences, health-checks).

## Migrations et épinglage

- Le schéma est **déclaratif** (JSON des DocTypes) ; `bench migrate` le
  synchronise, `patches.txt` liste les patches de données ordonnés.
- La règle anti-dérive : **épingler chaque app à une version exacte**
  (`pyproject.toml` / tag git), bump = décision de roadmap. Les releases
  Frappe suivent des branches de maintenance (ex. v16.x).

## Contribution amont (stratégie LaStarter)

1. Reproduire l'issue sur une version épinglée.
2. Fix + test dans une branche dédiée, PR vers le dépôt amont.
3. En attendant la release : la PR est épinglée via `bench get-app
   <notre-fork>#<branche>` puis retirée au merge.
Cette boucle est exactement celle documentée dans les skills officielles
(`07-SKILLS/01-frappe-skills.md` : `fix-issue`, `ship-it`).
