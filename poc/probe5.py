import frappe
frappe.init(site='crm.localhost')
frappe.connect()
try:
    import mail.api.admin
    print('import dans le contexte frappe : OK')
    print('attribut admin :', hasattr(mail.api, 'admin'))
    res = frappe.get_attr('mail.api.admin.get_domains')()
    print('get_domains :', json.dumps(res, ensure_ascii=False)[:200] if (json and res) else res)
except Exception as e:
    import traceback
    tb = traceback.format_exc().splitlines()
    print('ECHEC :')
    for l in tb[-10:]:
        print(' ', l[:170])
