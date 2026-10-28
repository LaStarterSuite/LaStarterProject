# Desk — le back-office universel de Frappe

**Observé en conditions réelles sur un site Frappe Cloud (LMS déployé,
2026-10-28) : `/desk/lms/learning`, `/desk/build`, gestion des comptes,
logs, users.**

## Ce qu'est le Desk

Le Desk (`/app`, historiquement `/desk`) est l'**interface d'administration
auto-générée** du site : chaque DocType déclaré y obtient gratuitement sa
liste (filtres, tri, colonnes, exports), son formulaire, ses rapports et ses
vues. C'est le cœur du système :

- **Utilisateurs et rôles** : comptes, rôles, profils de rôle, permissions
  par rôle et par document (user permissions / partage).
- **Administration technique** : comptes email (Email Accounts), logs
  (Error Log, Activity Log, Background Jobs), workflows, print formats,
  integrations, custom fields.
- **Espaces par app** : chaque app ajoute son ou ses workspaces
  (`/desk/lms/learning`, `/desk/build` pour Builder…) — l'utilisateur ne voit
  que les workspaces autorisés par ses rôles.

## Le modèle de permissions en pratique

Tout est filtré par rôle, à trois niveaux : par DocType (CRUD : lecture,
écriture, création, suppression, soumission), par niveau d'accès (ses propres
documents / son organisation / tout), et par document (partages individuels
via user permissions). Un compte peu privilégié ne voit qu'une fraction du
Desk ; un « Administrator » voit tout — exactement le comportement constaté
en test.

## Sans écrire de code, le Desk se customise

Customize Form (ajouter/retrancher des champs, masquer), Client Scripts et
Server Scripts (comportement), Workspaces (composer des espaces par public),
Number Cards et Dashboards (indicateurs), Workflows (validation en étapes).

## Implication LaStarter (majeure)

Le **« panel d'administration custom » prévu dans la v1 existe déjà** :
c'est le Desk, par app, filtré par permissions. Pour LaStarter il reste :

1. Définir les rôles clients (ex. « Client Admin », « Client Support ») et
   leurs permissions DocType précises — la matrice d'accès par client.
2. Composer des **workspaces** dédiés (espace « Administration client »)
   plutôt que donner le Desk complet.
3. Optionnel : un portail client frappe-ui pour les non-techniciens, au-dessus
   du Desk.

À garder en tête : le Desk est puissant mais d'allure « outil » — le
white-label visuel (thème, logo) se règle, et l'assistant de configuration
LaStarter devra pré-configurer ces espaces et rôles pour que l'admin client
reçoive un back-office lisible dès le premier login.
