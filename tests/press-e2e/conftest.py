"""Configuration pytest pour les tests e2e press.

test_client_flow.py est un script autonome (pas un module de test pytest) :
il exécute tout son corps à l'import et frappe le serveur press live. On le
retire de la collecte pytest — le CI passe par le pont test_ci_client_flow.py
qui l'invoque en sous-processus, et il reste exécutable à la main inchangé.
"""

collect_ignore = ["test_client_flow.py"]
