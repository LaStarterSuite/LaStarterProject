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

- admin@example.com / admin : VRAI compte admin (mot de passe simple possible : politique password_minimum_score = 0 posee le 28/10 soir) (System
  Manager + rôles Manager), les deux sites, SSO compris. LA page de login
  exige un format email : c'est CE compte qu'il faut utiliser.
- Administrator / admin : marche uniquement via API (son identite de
  connexion est son NOM, pas son email) ; la page de login le refuse.
- alice@example.com / Alice : tous rôles + System Manager
  (ajoute le soir, pour supprimer les erreurs ERPNext comme
  « Accounting Dimension », lisible par Accounts Manager/System Manager
  uniquement).
- demo@example.com / demo : visiteur de demonstration. Bob : bob (IdP). Mot de passe simples voulu par Bastien (POC local uniquement, JAMAIS en production).

## Reset complet + provisionnement automatise (28/10, soiree 3)

Sur demande de Bastien (etat trop pollue), remise a zero totale via le
nouveau script poc/reset-and-provision.sh : down -v (volumes detruits),
recration des deux sites, installation des 8 apps restantes, marqueurs de
setup APRES les installs, OIDC, utilisateurs (admin/alice/bob/demo),
references ERP/HR (Gender, Warehouse Type, Company, Employee), wiki publie,
donnees de demonstration, verification finale. Resultat : tout vert (login
200, /docs 302, /all-products 200, aucune DefaultValue polluee).

Pieges de l'automatisation consignes :
- create-sites ecrit sites/<site>/site_config.json TOT alors que
  l'installation des apps continue : attendre la SORTIE du conteneur
  (docker inspect poc-create-sites-1 State.Status/ExitCode ; docker
  compose ps --format template ne rend rien) + precondition list-apps
  (frappe, crm, helpdesk) avant toute autre commande ;
- les pipes (| tail) sur les install-app masquent les codes de sortie ;
- le service worker de helpdesk (registerSW.js) peut servir du vieux
  contenu au navigateur : deinstaller le SW + vider les donnees du site
  apres un reset serveur.

## Auto-nettoyage navigateur : en-tete Clear-Site-Data (28/10, soiree 3)

La boucle de Bastien persistait car son navigateur relisait un boot en
cache (localStorage + service worker helpdesk registerSW.js) alors que le
serveur servait un boot sain. Solution serveur : en-tete Clear-Site-Data
"cache, storage, serviceWorkers" sur toutes les reponses du frontal —
le navigateur du visiteur se vide tout seul des son prochain chargement.
Implementation durable : template nginx edite
(poc/nginx-template/frappe.conf.template, en-tete ajoute apres le vrai
bloc server) monte en lecture seule sur /templates/nginx/frappe.conf.template.
Pieges : le substring "server {" matche AUSSI "upstream socketio-server {"
(inserrer par regex ^server {) ; MSYS_NO_PATHCONV=1 casse le chemin -f du
compose dans la meme commande (utiliser docker exec direct) ; docker cp
vers /etc/nginx cree un fichier que l'entrypoint ne peut plus ecrire
(crash-loop, reparer par --force-recreate).

## Cause racine FINALE de la boucle desk (28/10, soiree 3, verifie code amont)

Ce n'est PAS une regression de notre part : mecanisme amont latent. A
l'installation fraiche, frappe/utils/install.py:48-49 pose
desktop:home_page = "setup-wizard" ; la bascule vers "workspace" n'arrive
que SI quelqu'un TERMINE l'assistant (setup_wizard.py:410, patch v13
reset_corrupt_defaults.py : workspace si setup_complete sinon
setup-wizard). Notre provisioning par script cree les comptes sans
terminer l'assistant : home_page reste setup-wizard, et comme nos
marqueurs disent setup_complete, l'assistant se renvoie vers /apps ->
301 -> /desk -> home_page = setup-wizard -> boucle. Le HAR de Bastien
(84 Mo) l'a prouve : boot.home_page = "setup-wizard" + boot.setup_complete
= true dans la MEME page. Correctif aligne sur l'amont :
frappe.db.set_default("desktop:home_page", "workspace") sur les deux
sites (valeur exacte du wizard complete). Verifie : boot.home_page =
"desktop", login 200, desk 200. L'en-tete Clear-Site-Data a ete RETIRE
(inutile une fois la cause serveur corrige ; retour au conf amont pur).
Le script de provisionnement pose desormais le defaut workspace apres
les installs. Dernier piege : le substring "server {" matche aussi
"upstream socketio-server {" (template nginx).

## Permissions ERPNext (28/10, soiree 4)

Erreur « Autorisation insuffisante pour Purchase Order » sur
/desk/setup/home : cause — System Manager ne couvre PAS tous les
doctypes ERPNext ; Purchase Order n'accorde la lecture qu'a Purchase
Manager, Purchase User et Stock User (DocPerm verifies). Alice passait
via Stock User + System Manager ; admin@example.com n'avait ni Purchase
User/Manager ni Stock User. Corrige : roles metier explicites ajoutes a
admin (Purchase Manager/User, Stock User, Accounts User, Sales User,
Projects User, Employee). Le script de provisionnement integre desormais
la liste complete. Lecon lastarter_core : pour un compte « tout voir »,
attribuer les roles metier User+Manager de chaque app, System Manager ne
suffit pas ; verifier par frappe.has_permission(doctype, user=...).

## Emails : envoi demontre, client Mail = suite (28/10, soiree 5)

- frappe/mail est ARCHIVE (absorbe par frappe/suite, comme Meet) : le
  client mail complet de la suite attendra Suite (0.0.1, WIP).
- L'envoi et la reception d'emails sont NATIFS (doctype Email Account,
  SMTP + IMAP) : rien a installer. Demo posee : conteneur Mailpit dans le
  compose (UI http://localhost:8025, SMTP 1025) + Email Account « Demo
  Mailpit » (smtp mailpit:1025, default_outgoing). Email de test envoye :
  Email Queue -> Sent, message visible dans Mailpit. L'Email Account
  exige une imap_folder (table enfant) si enable_incoming.
- PIEGE : la build axllent/mailpit:latest du jour n'a PAS d'IMAP (le
  drapeau --enable-imap est rejete comme unknown alors que l'aide des
  logs le liste ; 86 lignes d'aide, zero mention IMAP) : la reception
  de demo attendra une vraie boite (IMAP du client) ou un autre serveur.
- Le flush de la file (frappe.email.queue.flush) livre immediatement ;
  sinon les workers prennent l'email a leur rythme.

## Mail v16 : portage impossible en l'etat, app desinstallee (28/10, soiree 5, suite)

L'app mail (0.2.1, clone du depot archive) s'installe mais ne fonctionne
pas sur v16 : page blanche. Deux incompatibilites prouvees :
1. les workers gunicorn ne rechargent pas l'app apres install (bench
   restart requis) puis AttributeError is_ajax sur les requetes API ;
2. le binaire stalwart-cli telecharge par l'app ne comprend pas le schema
   du Stalwart courant (unknown variant 'sieve') : desynchronisation
   CLI/serveur.
D'ou desinstallation propre (retour aux 14 apps saines, desk verifie 200).

## Comparaison demandee par Bastien : archive vs suite

- frappe/mail (archive) : dernier commit 2026-08-10, gelee depuis.
- frappe/suite, dossier suite/mail : commits du 2026-10-23 (fix + feat
  mail) : le code VIVANT est dans suite, 2,5 mois plus frais.
Conclusion : les deux codes bases ont DIVERGE — la base a reprendre est
suite/mail, pas le fossil archive. Plan de revival pour l'org LaStarter :
forker frappe/suite, suivre son evolution, extraire mail en app autonome
quand il stabilise (ou maintenir l'extraction), brancher sur notre
Stalwart. Stalwart reste dans la pile (il servira aussi la reception
IMAP reelle via Email Account).

## Bug amont decouvert au passage (candidat contribution)

frappe v16.54 : app.py:199 pose frappe.local.is_ajax APRES certains chemins
seulement ; le gestionnaire d'erreurs (app.py:366) lit frappe.local.is_ajax
qui n'existe pas si la requete a echoue avant -> AttributeError pendant la
gestion d'erreur -> reponse VIDE (page blanche) au lieu de l'erreur
propre. Candidat PR upstream : initialiser is_ajax = False des le debut
de la requete.
