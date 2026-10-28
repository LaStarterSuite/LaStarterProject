# Les skills officielles Frappe (frappe/skills)

**Dépôt cloné ici : `../../frappe/skills/`** — collection officielle de skills
pour agents de développement Frappe. Installation :

```sh
npx skills add frappe/skills            # toutes
npx skills add frappe/skills --skill frappe-app-dev   # une seule
```

## Les 10 skills (README vérifié)

| Skill | Ce qu'elle couvre | Invocation |
|---|---|---|
| `frappe-app-dev` | **La référence** : DocTypes, controllers, APIs, ORM/base, hooks, permissions, jobs, realtime, caching, tests, setup d'app, frontend (Desk/Vue/portal), bench CLI + gestion de sites | auto |
| `frappe-code-review` | Checklist de revue Frappe : correction, sécurité, performance, concurrence, lisibilité, API design, tests | auto |
| `code-style` | Règles générales de style | auto |
| `technical-writing` | Doc, READMEs, commits, PR et release notes en Simplified Technical English | auto |
| `ui-design` | Principes UI/UX | auto |
| `draft-security-advisory` | Rédiger une GHSA prête à publier (CVSS, CWE) | `/draft-security-advisory` |
| `deep-app-audit` | Audit multi-agents d'une app Frappe : sécurité, correction, défauts de customization — chaque candidat vérifié, un seul rapport | `/deep-app-audit <chemin app>` |
| `ship-it` | Travaux finis → PR merge-ready : revue par subagents frais, test en live, docs+lint, PR avec preuves, suivi CI | `/ship-it` |
| `fix-issue` | Prendre une issue amont → branche → fix testé → PR | (voir dépôt) |
| `resolve-backport-conflicts` | Résoudre les conflits de backport entre branches de release | (voir dépôt) |

## Comment l'agent LaStarter doit les utiliser

1. **Installer les skills** en tout premier (commande ci-dessus) — elles
   contiennent la connaissance Frappe actuelle que CE document ne duplique pas.
2. `frappe-app-dev` est la base pour écrire `lastarter_core` (l'app Frappe
   maison : rôles, branding, glue identité).
3. `deep-app-audit` sur chaque app embarquée au moment de l'épinglage
   (crm, helpdesk…) — même méthode d'audit adversaire que celle utilisée
   pour produire cette documentation.
4. `fix-issue` + `ship-it` = le flux de contribution amont (stratégie
   actée : les 2 000 issues du framework sont un vivier).
5. `technical-writing` pour toute la doc/PR : anglais technique simplifié.
