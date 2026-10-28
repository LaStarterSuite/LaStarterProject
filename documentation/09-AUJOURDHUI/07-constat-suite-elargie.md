# Constat : suite elargie (2026-10-28, apres-midi)

**Verdict : VERT avec 2 apps bloquees amont.** L'image `lasarter-bench:full`
embarque 13 apps (frappe + 12). Douze sont utilisables et verifiees au
navigateur derriere le SSO, avec alice, en francais. Gameplan a du etre
desinstalle du site (incompatible v16 amont) et Drive n'a jamais pu etre
construit (packaging amont casse le jour meme).

## Ce que Bastien a demande et ce qui a ete corrige

- **`/desk/setup-wizard` -> « Not permitted »** : normal, la page exige le
  role System Manager (setup_wizard.json) et alice ne l'a pas. La vraie
  question etait la redirection du desk vers ce wizard, voir ci-dessous.
- **`/crm.localhost/docs` -> « Page not found »** : l'espace Wiki etait
  publie mais ses DOCUMENTS non (`Wiki Document.is_published = 0` sur la
  page d'accueil et le groupe racine). Le renderer v3 (WikiDocumentRenderer,
  page_renderer) exige une feuille publiee a cette route, sinon redirection
  vers la premiere page publiee, sinon 404. Page d'accueil publiee cote
  serveur -> `/docs` redirige vers `/docs/welcome-to-frappe-wiki`. Regle
  gravée : espace ouvert = lisible par tout utilisateur CONNECTE, pas par
  les invités (wiki/permissions.py can_read_space) ; publier un document se
  fait depuis l'editeur du wiki (flux normal) ou cote serveur.
- **Francais par defaut** : pose sur les deux sites (System Settings.language
  = fr, langue utilisateur alice/bob = fr, purges de cache). Les traductions
  sont embarquees par app (fr.csv) : couverture partielle selon l'app, c'est
  l'etat amont.

## Le mecanisme setup-wizard (piege majeur, matiere lastarter_core)

- La redirection du desk ne lit PAS System Settings.setup_complete (le flag
  pose par le wizard officiel) mais `frappe.is_setup_complete()`
  (frappe/__init__.py:1537) : toutes les lignes `Installed Application` des
  apps `frappe` ET `erpnext` doivent avoir `is_setup_complete = 1`.
- `install-app` cree les lignes a 0 ; le module setup wizard d'ERPNext
  reecrit System Settings.setup_complete pendant les installations. Donc :
  poser les flags APRES les installs/migrates, jamais avant.
- Correctif POC : Installed Application.is_setup_complete = 1 pour frappe +
  erpnext (+ hrms, webshop, builder) sur crm.localhost, et frappe sur
  id.localhost. Le desk charge alors directement (verifie navigateur).

## Applications verifiees au navigateur (session SSO alice, FR)

| App | Route reelle | Etat constate |
|---|---|---|
| ERPNext 16.52.1 | `/desk` (modules) | bureau 8 apps, FR |
| Frappe HR 16.52.0 | `/hrms` (SPA, PAS `/desk/hr`) | « Bonjour, Alice », self-service complet |
| Webshop 0.0.1 | `/all-products` | vitrine FR, catalogue vide (etat initial) |
| Builder 1.0.0-dev | `/builder` | liste de pages, Nouveau, gabarits charges |
| CRM, Helpdesk, Insights, Raven, LMS, Wiki | inchangees | re-verifiees derriere le SSO |

Rôles ajoutes a alice : Accounts User, Stock User, Projects User (ERPNext),
HR User (HRMS), Website Manager (Builder : Builder Page n'accorde
l'ecriture qu'a System Manager et Website Manager).

Donnees de reference semées a la main (le site cree en CLI n'a PAS les
donnees que le setup wizard pose normalement) : Gender « Female »,
Warehouse Type « Transit », Company « Lastarter Demo », Employee alice
(sans Employee, la SPA HR renvoie vers /hrms/invalid-employee : verrou
metier attendu).

## Les deux blocages amont (a re-surveiller, pas a hacker)

- **Drive** : `bench init` echoue sur son `yarn install` — le depot vient de
  migrer vers pnpm et son packaging est incoherent avec pnpm 12
  (ERR_PNPM_IGNORED_BUILDS fatal sur esbuild/canvas/swc/core-js ;
  « pnpm.overrides no longer read »). 13 autres apps passent le meme chemin.
  Retiré du catalogue, a re-tester quand l'amont corrige.
- **Gameplan** : construit puis installe, mais `can_access_gameplan`
  importe `get_modules_from_all_apps_for_user` depuis `frappe.config`,
  emplacement supprime en v16 -> ImportError -> 500 sur `/desk` pour tout
  utilisateur connecte (hook has_permission non tolere a la construction du
  bureau). Branche amont `agent/frappe-v16-compat` en cours. Desinstalle
  proprement (`uninstall-app`, tables GP supprimees). A re-tester apres
  fusion amont ; en prod, pinner un commit, jamais main.

## Pieges graves pour lastarter_core

- **`bench execute` n'imprime que les valeurs truthy** (ret = "" par defaut,
  echo conditionnel) : silence n'est pas panne. Compter/verifier avec des
  valeurs non vides. De plus, en cas d'exception, il re-evalue la methode
  via eval (2e tentative qui peut produire un faux 1062 Duplicate).
- Sites crees en CLI : Gender, Warehouse Type et autres references sont
  VIDES (le wizard officiel les seme) -> lastarter_core devra semer ces
  references avant ERPNext/HRMS.
- HRMS : rôles ne suffisent pas, il faut un Employee lie au user.
- La SPA HRMS tente un socket.io en `https://` derriere notre passerelle
  http (ERR_CONNECTION_REFUSED, non bloquant).
- Le secret OAuth POC « poc-secret-dev » declenche un warning HMAC < 32
  octets (JWT) : POC only, jamais en prod.
- Build : pipeline `| tail` masque le code de sortie de docker build ;
  le cwd du shell persiste entre les appels (chemins absolus partout).

## Etat des dépots du projet

poc/apps-full.json = 13 apps (drive retire). Commits POC/architecture
precedes ; commit de ce constat a suivre.

## Correctifs du soir (28/10, session 2)

- **Temps reel casse partout (bandeau Raven « Realtime events aren't
  working »)** : cause racine lue dans le code — l'authentification du
  serveur temps reel (apps/frappe/realtime/middlewares/authenticate.js)
  fait un fetch vers l'ORIGINE du client (http://crm.localhost/api/...) ;
  le conteneur websocket ne resolvait pas *.localhost (glibc) -> chaque
  connexion rejetee « Unauthorized: TypeError: fetch failed ». Correctif :
  extra_hosts id.localhost/crm.localhost -> host-gateway sur le service
  websocket du compose (symetrique du backend). Verifie : handshake avec
  sid en 200, zero erreur console apres correction, sockets Raven actifs.
- **Interface administrateur en francais** : User Administrator passe en
  fr sur les deux sites.
- **Raven premiere main** : alice a le role mais pas d'espace de travail :
  creer le workspace en admin (Raven -> New Workspace) puis l'ajouter.
- **Permissions (question de Bastien)** : tout se gere depuis le bureau
  central : doctype User (table roles) + roles par app (Raven User,
  LMS Student...) ; les pages d'admin des apps renvoient au User du desk
  maitre et exigent System Manager pour l'editer.
- **Criblage ecosysteme + plan d'hebergement** : voir
  documentation/04-CLOUD/05-plan-infra-lastarter.md (18 depots veriffies ;
  meet archive au profit de frappe/suite ; grove recycle en plateforme IA ;
  pilot = gestionnaire de serveurs dedies ; aucune app de page de statut
  dans l'org frappe).

## Donnees de demonstration (28/10, session 2, demande de Bastien)

Semees sur crm.localhost, idempotents, verifiees par comptages :
- Raven : espace « LaStarter » (membres Administrator/alice/demo), canaux
  publics lastarter-general et lastarter-support-clients, messages.
- CRM : 3 leads (Boulangerie Martin, Cooperative Aurore, Cabinet Durand).
- Helpdesk : 4 tickets de demonstration (sla Standard applique).
- LMS : cours publie « Prise en main de la suite » + chapitre + lecon.
- Compte visiteur : demo@example.com / demo-password-1234 (roles Sales
  User, Agent, Raven User, LMS Student ; existe aussi sur l'IdP avec
  Desk User pour le SSO). Interface en francais.
Pieges semis : CRM Lead exige first_name ; en lms 2.63 les doctypes sont
« Course Chapter »/« Course Lesson » (les noms LMS Chapter/Lesson donnent
une erreur de module trompeuse) ; Raven ajoute automatiquement le createur
comme admin de l'espace (membre refuse en doublon = normal) et prefixe les
canaux avec l'espace (lastarter-general).

## Boucle setup-wizard (2e forme, 28/10 soir 2)

Symptome : /desk redirige en boucle vers /desk/build/setup-wizard/0 (route
assemblee par le client, INEXISTANTE dans tout le code serveur). Cause : une
ligne DefaultValue setup_complete="0" (parent __default) infectait
bootinfo.defaults pendant que sysdefaults.setup_complete restait vrai ; le
routeur du desk et l'assistant lisaient des valeurs contradictoires et se
renvoyaient la balle (wizard -> /apps -> 301 -> /desk -> wizard). Present sur
LES DEUX sites. Correctif : supprimer la ligne (frappe.db.delete DefaultValue),
frappe.clear_cache, puis RE-LOGIN. Verifie en navigateur connecte :
frappe.boot.setup_complete = true, desk stable. A retenir pour
lastarter_core : apres tout semis de setup, controler l'absence de
DefaultValue setup_complete.

## Comptes (etat final du 28/10 soir)

- admin@example.com / admin-LaStarter-2026 : VRAI compte admin (System
  Manager + rôles Manager), les deux sites, SSO compris. LA page de login
  exige un format email : c'est CE compte qu'il faut utiliser.
- Administrator / admin : marche uniquement via API (son identite de
  connexion est son NOM, pas son email) ; la page de login le refuse.
- alice@example.com / poc-password-1234 : tous rôles + System Manager
  (ajoute le soir, pour supprimer les erreurs ERPNext comme
  « Accounting Dimension », lisible par Accounts Manager/System Manager
  uniquement).
- demo@example.com / demo-password-1234 : visiteur de demonstration.
