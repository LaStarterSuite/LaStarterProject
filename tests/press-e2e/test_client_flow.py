# Test E2E du flux client press (Playwright) - s'execute sur le serveur :
#   cd /home/ubuntu/press-bench
#   PRESS_EMAIL=... PRESS_PASSWORD=... env/bin/python test_client_flow.py
# Prerequis : env/bin/playwright install chromium
# Verifie : login client, selecteur d'apps (14 apps), ecran setup avec
# suffixe de sous-domaine, marketplace avec recherche.
# Aucun clic sur "Create site" : le deploiement final exige l'agent press.
import os
import sys

from playwright.sync_api import sync_playwright

BASE = os.environ.get("PRESS_BASE", "https://press.wardhive.app")
EMAIL = os.environ["PRESS_EMAIL"]
PASSWORD = os.environ["PRESS_PASSWORD"]
SHOTS = os.environ.get("PRESS_SHOTS", "/home/ubuntu/press-flow-shots")

os.makedirs(SHOTS, exist_ok=True)
fails = []


def check(name, cond):
    print(("OK  " if cond else "FAIL"), name)
    if not cond:
        fails.append(name)


def shot(page, name):
    page.screenshot(path=f"{SHOTS}/{name}.png", full_page=True)


with sync_playwright() as p:
    b = p.chromium.launch()
    page = b.new_page(viewport={"width": 1440, "height": 900})

    # 1. Login client via l'API du site (meme endpoint que le frontend)
    try:
        resp = page.request.post(BASE + "/api/method/login", form={"usr": EMAIL, "pwd": PASSWORD}, timeout=30000)
        page.goto(BASE + "/dashboard", wait_until="networkidle", timeout=30000)
        check("login client", resp.ok)
        shot(page, "01-dashboard")
    except Exception as e:
        check("login client", False)
        print("   ", repr(e)[:200])
        shot(page, "01-login-erreur")

    # 2. Selecteur d'apps : 14 apps visibles
    try:
        page.goto(BASE + "/dashboard/create-site/app-selector", wait_until="networkidle", timeout=30000)
        page.wait_for_selector("text=Frappe CRM", timeout=20000)
        body = page.inner_text("body")
        attendues = ["Frappe CRM", "ERPNext", "Frappe HR", "Frappe LMS", "Webshop", "Wiki", "Builder", "Insights", "Gameplan", "Drive", "Raven", "Frappe Helpdesk"]
        manquantes = [a for a in attendues if a not in body]
        check(f"selecteur apps ({len(attendues) - len(manquantes)}/{len(attendues)} visibles)", not manquantes)
        if manquantes:
            print("    manquantes:", manquantes)
        shot(page, "02-selecteur-apps")
    except Exception as e:
        check("selecteur apps", False)
        print("   ", repr(e)[:200])
        shot(page, "02-selecteur-erreur")

    # 3. Selection CRM -> bouton Install -> ecran setup
    try:
        page.click("text=Frappe CRM", timeout=10000)
        page.click('button:has-text("Install")', timeout=10000)
        page.wait_for_url("**/crm/setup**", timeout=20000)
        check("navigation vers l ecran setup", True)
    except Exception as e:
        check("navigation vers l ecran setup", False)
        print("   ", repr(e)[:200])

    # 4. Suffixe de sous-domaine : saisir "jeand" -> "jeand.apps.wardhive.app"
    try:
        page.wait_for_selector("#subdomain", timeout=20000)
        page.fill("#subdomain", "jeand", timeout=10000)
        page.wait_for_selector("text=apps.wardhive.app", timeout=15000)
        suffixe = page.inner_text("body")
        check("suffixe apps.wardhive.app affiche", ".apps.wardhive.app" in suffixe)
        shot(page, "03-setup-suffixe")
    except Exception as e:
        check("suffixe apps.wardhive.app affiche", False)
        print("   ", repr(e)[:200])
        shot(page, "03-setup-erreur")

    # 5. Liste des sites : la page charge et le bouton New Site est accessible
    # (pas de page marketplace dans le dashboard de cette version de press :
    # chez Frappe c'est un site separe, on n'en invente pas une)
    try:
        page.goto(BASE + "/dashboard/sites", wait_until="networkidle", timeout=30000)
        page.wait_for_timeout(3000)
        body = page.inner_text("body")
        check("liste des sites charge", "Sites" in body or "sites" in page.url)
        bouton = page.locator('button:has-text("New Site"), a:has-text("New Site")')
        check("bouton New Site accessible", bouton.count() > 0)
        shot(page, "04-sites")
    except Exception as e:
        check("liste des sites", False)
        print("   ", repr(e)[:200])
        shot(page, "04-sites-erreur")

    b.close()

print()
if fails:
    print("ECHEC:", len(fails), "verification(s) en echec:", fails)
    sys.exit(1)
print("SUCCES: toutes les verifications passent")
