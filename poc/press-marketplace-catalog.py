# Catalogue marketplace press (idempotent) - a executer via :
#   bench --site press.wardhive.app console < press-marketplace-catalog.py
# Cree App + App Source (public, versions 15/16) + App Release (status
# Approved, ce que l'auto-approbation Marketplace Settings produit) +
# Marketplace App (status Published, show_for_site_creation).
import json
import urllib.request

import frappe

TEAM = "9lmv8o2jtq"
FALLBACK = "https://github.com/frappe.png?size=100"
APPS = [
 {"slug": "crm", "title": "Frappe CRM", "branch": "main", "image": "https://raw.githubusercontent.com/frappe/crm/main/crm/public/images/logo.svg", "description": "Gestion des leads, des opportunites et du pipeline de vente."},
 {"slug": "helpdesk", "title": "Frappe Helpdesk", "branch": "main", "image": FALLBACK, "description": "Tickets, SLA et support client."},
 {"slug": "raven", "title": "Raven", "branch": "main", "image": FALLBACK, "description": "Messagerie d'equipe sur le site."},
 {"slug": "lms", "title": "Frappe LMS", "branch": "main", "image": "https://raw.githubusercontent.com/frappe/lms/main/lms/public/images/lms-logo.png", "description": "Formations, cours et certifications."},
 {"slug": "erpnext", "title": "ERPNext", "branch": "version-16", "image": "https://raw.githubusercontent.com/frappe/erpnext/version-16/erpnext/public/images/erpnext-logo.svg", "description": "ERP complet : comptabilite, achats, ventes, stock, production."},
 {"slug": "hrms", "title": "Frappe HR", "branch": "version-16", "image": "https://raw.githubusercontent.com/frappe/hrms/version-16/hrms/public/images/frappe-hr-logo.svg", "description": "RH : employes, conges, paie."},
 {"slug": "webshop", "title": "Webshop", "branch": "version-16", "image": FALLBACK, "description": "Boutique en ligne connectee a l'ERP."},
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
frappe.db.commit()
print("CREATED apps:", n_app, "sources:", n_src, "releases:", n_rel, "marketplace:", n_mp)
print("TOTALS apps:", frappe.db.count("App"), "sources:", frappe.db.count("App Source"), "releases:", frappe.db.count("App Release"), "marketplace:", frappe.db.count("Marketplace App"))
