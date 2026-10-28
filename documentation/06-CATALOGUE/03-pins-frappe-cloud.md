# Les pins réels du marketplace Frappe Cloud (relevé du 2026-10-28)

**Source : relevé terrain sur cloud.frappe.io (dashboard, liste d'install des
apps). C'est la référence d'épinglage utilisée par Frappe lui-même en
production — la meilleure base pour nos propres pins.**

## Le tableau relevé (app → repo@branche)

| App | Repo | Branche installée par Frappe Cloud |
|---|---|---|
| ERPNext | frappe | version-16-hotfix |
| HR & Payroll | frappe | version-16-hotfix |
| India Compliance | resilient-tech | version-16 |
| Insights | frappe | version-3 |
| **Drive** | frappe | **main** |
| **Helpdesk** | frappe | **main** |
| **CRM** | frappe | **main** |
| Telephony | frappe | develop |
| Print Designer | frappe | main |
| Frappe Non Profit | frappe | develop |
| **Raven** | **The-Commit-Company** (pas frappe org !) | main |
| Builder | frappe | master |
| Wiki | frappe | version-3 |
| Blog / Newsletter / Lending / Payments / Offsite Backups / Telephony | frappe | version-16 (selon app) |
| Education | frappe | version-16 |
| Gameplan | frappe | develop |
| + ~20 apps tierces de compliance/locale (Allemagne, Inde, Kenya, Mexique…) | tiers | divers |

## Enseignements pour le catalogue v2

1. **Frappe Cloud lui-même installe ses apps récentes depuis `main`**
   (crm, helpdesk, drive). Leur CI/marketplace absorbe le risque. Pour
   LaStarter, on garde la règle « release épinglée » en prod, mais on sait
   que `main` des apps frappe est de qualité déployable (c'est leur prod).
2. **Raven est maintenu par The-Commit-Company** (tiers, pas l'org frappe) —
   vérifier le suivi et la licence à chaque bump (AGPL confirmé côté clone
   frappe/raven, mais la source installée est le fork du mainteneur).
3. **Suite (writer/sheets/slides/mail/calendar) n'est PAS encore au
   marketplace** — seul Drive y est (via main). Confirme : Suite à suivre,
   pas à épingler.
4. **Branches de maintenance par version** : `version-16` / `version-16-hotfix`
   pour le socle ERPNext/HRMS, `version-3` pour Insights/Wiki — le schéma de
   branches stables à réutiliser dans nos pins.
5. Le marketplace est installable « gratuitement » (l'app s'ajoute au site,
   la facturation reste le plan d'hébergement) — modèle tarifaire à reprendre
   pour LaStarter Cloud : **on facture l'hébergement, pas les apps open source**.

## Écosystème tiers signalé (liste complète conservée dans ce relevé)

Compliance locales (ZATCA, KRA eTIMS, e-Invoice EU/Mexique, Allemagne,
Indonésie, Malaisie, Singapour…), Marley Healthcare, Webshop, Ekyc India,
Ecommerce Integrations, WhatsApp (shridarpatil), Blog, Newsletter. La
marketplace Frappe Cloud est aussi un MODELE de distribution d'apps tierces
à étudier pour LaStarter Cloud.
