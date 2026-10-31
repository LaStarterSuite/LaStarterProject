"""Pont pytest vers le script e2e : le script d'origine reste la source de vérité.

Le CI joue ce test ; pytest-mergify (présent quand MERGIFY_TOKEN est défini)
envoie le résultat à Mergify Test Engine. Le script test_client_flow.py n'est
pas modifié : il garde ses propres vérifications, captures et codes de sortie.
"""
import os
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).with_name("test_client_flow.py")


@pytest.mark.skipif(
    not os.environ.get("PRESS_EMAIL") or not os.environ.get("PRESS_PASSWORD"),
    reason="PRESS_EMAIL/PRESS_PASSWORD absents : le flux client press ne peut pas être joué",
)
def test_client_flow_press():
    result = subprocess.run(
        [sys.executable, str(SCRIPT)],
        cwd=str(SCRIPT.parent),
        timeout=900,
    )
    assert result.returncode == 0, (
        "test_client_flow.py a échoué : voir la sortie du job et les captures d'écran"
    )
