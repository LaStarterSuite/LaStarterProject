# Catalogue marketplace + machinerie trial press (idempotent) - a executer via :
#   bench --site press.wardhive.app console < press-marketplace-catalog.py
# 1) App + App Source (public, versions 15/16) + App Release (status Approved,
#    exigee par le validateur de publication) + Marketplace App (Published,
#    show_for_site_creation) pour le selecteur d'apps.
# 2) Root Domain + Press Settings.domain + Product Trial (domain, apps,
#    trial_plan) pour le suffixe de sous-domaine de l'ecran setup.
# Zero code modifie : uniquement des documents dans leurs mecanismes.
import json
import urllib.request

import frappe

TEAM = "9lmv8o2jtq"
ROOT_DOMAIN = "apps.wardhive.app"
TRIAL_PLAN = "Standard LaStarter"
FALLBACK = "https://github.com/frappe.png?size=100"
APPS = [
 {"slug": "crm", "title": "Frappe CRM", "branch": "main", "image": "https://raw.githubusercontent.com/frappe/crm/main/crm/public/images/logo.svg", "description": "Gestion des leads, des opportunites et du pipeline de vente."},
 {"slug": "helpdesk", "title": "Frappe Helpdesk", "branch": "main", "image": FALLBACK, "description": "Tickets, SLA et support client."},
 {"slug": "raven", "title": "Raven", "branch": "main", "image": FALLBACK, "description": "Messagerie d'equipe sur le site."},
 {"slug": "lms", "title": "Frappe LMS", "branch": "main", "image": "https://raw.githubusercontent.com/frappe/lms/main/lms/public/images/lms-logo.png", "description": "Formations, cours et certifications."},
 {"slug": "erpnext", "title": "ERPNext", "branch": "version-16", "image": "https://raw.githubusercontent.com/frappe/erpnext/version-16/erpnext/public/images/erpnext-logo.svg", "description": "ERP complet : comptabilite, achats, ventes, stock, production."},
 {"slug": "hrms", "title": "Frappe HR", "branch": "version-16", "image": "https://raw.githubusercontent.com/frappe/hrms/version-16/hrms/public/images/frappe-hr-logo.svg", "description": "RH : employes, conges, paie."},
 {"slug": "webshop", "title": "Webshop", "branch": "version-16", "image": FALLBACK, "description": "Boutique en ligne connectee a l'ERP."},
 {"slug": "wiki", "title": "Wiki", "branch": "version-3", "image": "https://raw.githubusercontent.com/frappe/wiki/version-3/wiki/public/images/wiki-logo.png", "description": "Base de connaissances collaborative."},
 {"slug": "builder", "title": "Builder", "branch": "develop", "image": "https://raw.githubusercontent.com/frappe/builder/develop/builder/public/images/fallback.png", "description": "Constructeur de sites web visuel."},
 {"slug": "insights", "title": "Insights", "branch": "version-3", "image": FALLBACK, "description": "Analyse de donnees et tableaux de bord."},
 {"slug": "gameplan", "title": "Gameplan", "branch": "main", "image": FALLBACK, "description": "Discussions et espaces d'equipe."},
 {"slug": "telephony", "title": "Telephony", "branch": "develop", "image": FALLBACK, "description": "Appels telephoniques integres au CRM."},
 {"slug": "payments", "title": "Payments", "branch": "version-16", "image": FALLBACK, "description": "Paiements Stripe, Razorpay et autres."},
 {"slug": "drive", "title": "Drive", "branch": "main", "image": FALLBACK, "description": "Stockage de documents en equipe."},
]

def head_commit(slug, branch):
    try:
        with urllib.request.urlopen("https://api.github.com/repos/frappe/" + slug + "/commits/" + branch, timeout=15) as r:
            return json.load(r)["sha"]
    except Exception:
        return "0000000000000000000000000000000000000000"

n_app = n_src = n_rel = n_mp = 0
for spec in APPS:
    slug = spec["slug"]
    if not frappe.db.exists("App", slug):
        frappe.get_doc({"doctype": "App", "name": slug, "title": spec["title"], "frappe": 1, "public": 1, "enabled": 1, "team": TEAM, "url": "https://github.com/frappe/" + slug, "repo": slug, "repo_owner": "frappe", "branch": spec["branch"]}).insert(ignore_permissions=True)
        n_app += 1
    src_name = frappe.db.get_value("App Source", {"app": slug, "branch": spec["branch"], "team": TEAM})
    if not src_name:
        src = frappe.get_doc({"doctype": "App Source", "app": slug, "app_title": spec["title"], "frappe": 1, "public": 1, "enabled": 1, "team": TEAM, "repository_url": "https://github.com/frappe/" + slug, "branch": spec["branch"], "versions": [{"version": "Version 15"}, {"version": "Version 16"}]})
        src.insert(ignore_permissions=True)
        src_name = src.name
        n_src += 1
    rel_name = frappe.db.get_value("App Release", {"source": src_name, "status": "Approved"})
    if not rel_name:
        rel = frappe.get_doc({"doctype": "App Release", "app": slug, "source": src_name, "team": TEAM, "public": 1, "status": "Approved", "hash": head_commit(slug, spec["branch"]), "timestamp": frappe.utils.now_datetime()})
        rel.insert(ignore_permissions=True)
        rel_name = rel.name
        n_rel += 1
    mp_name = frappe.db.get_value("Marketplace App", {"app": slug})
    if not mp_name:
        frappe.get_doc({"doctype": "Marketplace App", "app": slug, "title": spec["title"], "description": spec["description"], "image": spec["image"], "status": "Published", "published": 1, "published_on": frappe.utils.today(), "show_for_site_creation": 1, "frappe_approved": 1, "bypass_automated_audit": 1, "team": TEAM, "subscription_type": "Free", "sources": [{"version": "Version 15", "source": src_name}, {"version": "Version 16", "source": src_name}]}).insert(ignore_permissions=True)
        n_mp += 1

n_pt = 0
if not frappe.db.exists("Site Plan", TRIAL_PLAN):
    frappe.get_doc({"doctype": "Site Plan", "name": TRIAL_PLAN, "plan_title": TRIAL_PLAN, "enabled": 1, "document_type": "Site", "interval": "Monthly", "price_inr": 600, "price_usd": 6.5, "is_trial_plan": 1}).insert(ignore_permissions=True)
    n_pt += 1
if not frappe.db.get_value("Site Plan", TRIAL_PLAN, "is_trial_plan"):
    frappe.db.set_value("Site Plan", TRIAL_PLAN, "is_trial_plan", 1)
if not frappe.db.exists("Root Domain", ROOT_DOMAIN):
    frappe.get_doc({"doctype": "Root Domain", "name": ROOT_DOMAIN, "enabled": 1, "dns_provider": "Generic", "default_cluster": "Default", "team": TEAM}).insert(ignore_permissions=True)
    n_pt += 1
for f, v in [("cloud_provider", "Generic"), ("status", "Active"), ("public", 1)]:
    if frappe.db.get_value("Cluster", "Default", f) != v:
        frappe.db.set_value("Cluster", "Default", f, v)
if frappe.db.get_single_value("Press Settings", "domain") != ROOT_DOMAIN:
    frappe.db.set_single_value("Press Settings", "domain", ROOT_DOMAIN)
if not frappe.db.exists("App", "frappe"):
    frappe.get_doc({"doctype": "App", "name": "frappe", "title": "Frappe Framework", "frappe": 1, "public": 1, "enabled": 1, "team": TEAM, "url": "https://github.com/frappe/frappe", "repo": "frappe", "repo_owner": "frappe", "branch": "version-15"}).insert(ignore_permissions=True)
frappe_src = frappe.db.get_value("App Source", {"app": "frappe", "branch": "version-15", "team": TEAM})
if not frappe_src:
    s = frappe.get_doc({"doctype": "App Source", "app": "frappe", "app_title": "Frappe Framework", "frappe": 1, "public": 1, "enabled": 1, "team": TEAM, "repository_url": "https://github.com/frappe/frappe", "branch": "version-15", "versions": [{"version": "Version 15"}]})
    s.insert(ignore_permissions=True)
    frappe_src = s.name
for spec in APPS:
    slug = spec["slug"]
    src_name = frappe.db.get_value("App Source", {"app": slug, "branch": spec["branch"], "team": TEAM})
    group_title = spec["title"] + " Trial"
    group = frappe.db.get_value("Release Group", {"title": group_title})
    if not group:
        g = frappe.get_doc({"doctype": "Release Group", "title": group_title, "team": TEAM, "version": "Version 15", "enabled": 1, "public": 0, "apps": [{"source": frappe_src, "app": "frappe", "title": "Frappe Framework"}, {"source": src_name, "app": slug, "title": spec["title"]}]})
        g.insert(ignore_permissions=True)
        group = g.name
        n_pt += 1
    if not frappe.db.exists("Product Trial", slug):
        frappe.get_doc({"doctype": "Product Trial", "name": slug, "title": spec["title"], "published": 1, "domain": ROOT_DOMAIN, "apps": [{"app": slug}], "trial_plan": TRIAL_PLAN, "trial_days": 14, "release_group": group, "email_subject": "Votre code de verification LaStarter"}).insert(ignore_permissions=True)
        n_pt += 1

frappe.db.commit()
print("CREATED apps:", n_app, "sources:", n_src, "releases:", n_rel, "marketplace:", n_mp, "trials+root:", n_pt)
print("TOTALS apps:", frappe.db.count("App"), "marketplace:", frappe.db.count("Marketplace App"), "trials:", frappe.db.count("Product Trial"), "root_domains:", frappe.db.count("Root Domain"), "domain_setting:", frappe.db.get_single_value("Press Settings", "domain"))
