# Vision — LaStarter Suite

## Mission

LaStarter est une **suite collaborative souveraine, open source, white-label** :
le client choisit les applications qu'il veut (CRM, tickets, drive, docs, chat,
visio, LMS…), un CLI les déploie derrière une identité unique, et une
plateforme cloud permet de consommer la même chose en SaaS.

## Principes non négociables

1. **Open source** — le code est public, les contributions remontent amont.
2. **Souveraineté** — self-hostable de bout en bout (Docker/K8s/Dokploy).
3. **Un IdP universel** — un seul point d'authentification pour toutes les
   apps (désormais : Frappe, voir `03-decision-identite.md`).
4. **Catalogue** — les apps sont des briques épinglées, activables une par une
   ; jamais un monolithe où tout est imposé.
5. **Portage amont** — on ne fork pas : on épingle, on contribue, on suit.

## Ce qui change avec Frappe (par rapport à la v1)

La v1 assemblait des briques hétérogènes (La Suite Numérique : Django, Sails,
PHP… ; Matrix ; LiveKit) derrière Keycloak, chacune avec son modèle
d'utilisateurs et son intégration SSO à câbler. Frappe résout ce problème par
construction : **un seul runtime (bench), un seul modèle users/rôles/permissions
partagé par toutes les apps, un admin intégré, une API REST auto-générée, du
realtime socket.io natif**, et une famille d'apps qui couvre déjà une grande
partie du catalogue.

## Nom et packaging

La structure retenue est celle de Frappe elle-même : un dépôt par application
(comme `frappe/crm`, `frappe/helpdesk`…), installables dans un bench, avec un
catalogue LaStarter qui référence les apps épinglées. LaSuite ou le nom
définitif reste à trancher ; ce qui compte : reprendre la structure qui fait
leurs preuves, rebrander par-dessus en respectant les licences (voir
`03-LICENCES/02-regles-rebrand.md`).

## Cible triple

1. **Self-host** : le client installe via CLI + Docker (frappe_docker).
2. **Managed** : nous déployons pour lui (flux « lien de configuration »,
   choix des apps, DNS automatisé).
3. **Cloud LaStarter** : plateforme multi-tenant inspirée de Frappe Cloud
   (Press/Central), en version rebrandée et simplifiée.
