# Règles de rebranding et de contribution amont

## Ce que permet Frappe

Le framework est **MIT** (copyright Frappe Technologies Pvt Ltd). Autorisé :
utiliser, modifier, commercialiser, rebrander, distribuer — en conservant les
notices de copyright et la licence. C'est exactement le modèle « proposer sous
notre nom en citant Frappe » visé par LaStarter.

## Charte LaStarter de rebranding (proposition)

1. **Attribution visible** : page « À propos » et README mentionnant
   « Propulsé par Frappe Framework » + liens amont — bon usage ET bonne
   stratégie (crédibilité, communauté).
2. **Licences conservées** : chaque app embarquée garde son fichier LICENSE
   intact ; nos ajouts sont séparés (app `lastarter_core` + patches nominatifs).
3. **Marques** : ne pas présenter LaStarter comme un produit officiel
   Frappe ; pas de logo Frappe dans le branding client.
4. **Traçabilité** : chaque divergence amont (patch, surcharge) est listée
   dans le dépôt LaStarter (`DIVERGENCES.md` par app) — c'est ce qui permet
   de suivre les mises à jour sans douleur.

## Contribution amont (stratégie assumée)

- Les 2 000 issues du framework = un vivier de contributions utiles ET
  stratégiques : chaque fix apporté rapproche LaStarter de l'amont et réduit
  notre charge de divergence.
- Les skills officielles couvrent le flux : `fix-issue` (prendre une issue →
  PR testée), `ship-it` (PR merge-ready avec revues par subagents), et
  `deep-app-audit` (audit multi-agents d'une app).
- Conventions d'écriture : la skill `technical-writing` impose le
  Simplified Technical English pour la doc/les PR — à suivre pour être
  accepté vite.

## Seuil de décision diverger/converger

Avant de patcher amont localement : se demander si la modification
1. sert tous les clients LaStarter (→ PR amont d'abord),
2. est spécifique LaStarter (→ app `lastarter_core` via hooks, zéro fork),
3. est un contournement temporaire (→ patch nominatif épinglé + issue amont).
Règle d'or : **jamais de fork de dépôt amont** tant qu'un hook ou une
surcharge ne suffit pas.
