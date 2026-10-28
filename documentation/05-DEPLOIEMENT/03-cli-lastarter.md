# Conception de la CLI LaStarter (v2)

**Spécification de principe — zéro code écrit.** Le point de départ est le
retour d'expérience du CLI v1 (Python, catalogue TOML, secrets, passerelle)
documenté dans `06-CATALOGUE/02-ancien-catalogue.md`.

## Commandes visées

```sh
lastarter init                      # wizard : domaine, registrar, apps choisies
lastarter deploy                    # provisionne site + apps (frappe_docker/helm)
lastarter apps add <brique>         # installe + active une app du catalogue
lastarter apps remove <brique>
lastarter users <import|sync>       # users/rôles
lastarter backup / restore
lastarter doctor                    # diagnostics (DNS, TLS, versions, disque)
```

## Le catalogue v2 (source de vérité de la CLI)

Format simple (TOML, comme v1) par brique :

```toml
[brick]
name = "crm"
upstream_repo = "https://github.com/frappe/crm"
pin = "v1.x.y"                       # release exacte, JAMAIS main
license = "AGPLv3"                   # gate docs/licences.md

[apps]
install = ["crm"]                    # app(s) frappe installées par la brique

[requires]
bricks = ["identity"]                # dépendances vers d'autres briques

[env]
BRAND_NAME = "{brand_name}"
```

Champs à conserver de la v1 : épinglage strict (jamais latest), gate licence,
secrets via coffre (`{secret:KEY}`), substitution `{domain}`/`{origin}`,
notes d'installation. Nouveautés v2 : `requires` entre briques, l'identité
est une brique (le site Frappe principal), la passerelle n'a plus à router
des stacks hétérogènes.

## Flux de provisionnement (ce que fait `deploy`)

1. Vérifs : DNS du domaine, ports, TLS.
2. Image bench LaStarter déjà construite (CI) — la CLI n'installe jamais
   depuis main.
3. Création du site Frappe + installation des apps choisies (frappe_docker
   oneshot / Helm jobs).
4. Config identité : le site est son propre IdP ; clients OIDC déclarés pour
   chaque app front.
5. Branding : injection du thème (CSS/JSON) + BRAND_NAME.
6. Sortie : les URLs des apps + le récap des accès.

## Ce que la v1 apporte au code v2

- La mécanique secrets/coffre et la substitution de tokens (réutilisable).
- Le modèle passerelle (TLS partout, upgrades WebSocket, theme.css).
- Les leçons anti-collisions d'environnement (préfixage par brique) — moins
  critique avec le modèle bench, mais valable pour les services annexes.
