# Carte des licences de l'écosystème Frappe

**Vérifiées dans les fichiers LICENSE/license.txt des 59 dépôts clonés
(INVENTAIRE.md à la racine de `../frappe/`).**

## Répartition

| Licence | Où | Implication pour LaStarter |
|---|---|---|
| **MIT** | frappe (framework), frappe-ui, frappe_docker, helm, wiki, builder, charts, datatable | Liberté totale : usage commercial, rebranding, modifications privées possibles. Garder le copyright + la licence |
| **AGPLv3** | crm, helpdesk, lms, gameplan, raven, drive, suite, insights, press, central, agent, atlas, pilot, bench | Copyleft RÉSEAU : si on modifie et qu'on héberge pour des tiers, on doit offrir la source modifiée aux utilisateurs de ce service |
| **GPLv3** | erpnext, hrms, education, lending | Copyleft distribution : modifications publiées si redistribuées (SaaS sans redistribution : pas d'obligation) |

## Les trois règles qui en découlent pour LaStarter

1. **Le projet LaStarter est open source** (décision actée) → les conditions
   AGPL/GPL sont alignées avec la stratégie, pas contre elle : on publie nos
   modifications de toute façon.
2. **Forks d'apps AGPL** (ex. rebranding de crm) : le code modifié reste
   AGPL — on publie, on garde les notices. Le rebranding commercial est
   autorisé ; la marque « Frappe » ne doit pas être détournée (trademark ≠
   licence).
3. **Les apps MIT** (wiki, builder) sont les seules où des modifications
   pourraient rester privées — la règle maison reste néanmoins de tout
   publier.

## Pièges pratiques

- Le nom du fichier varie : `LICENSE`, `license.txt` (hrms, lms, insights,
  suite, press, central…), `LICENSE.md` (helm). Le script d'inventaire gère
  les deux.
- GitHub affiche la licence détectée sous l'onglet licence (permissions/
  conditions) — source rapide mais toujours confirmer dans le fichier.
- Les licences peuvent changer entre versions : re-vérifier à chaque bump de
  pin (gate « licence » à ajouter à la CLI LaStarter, comme le faisait le
  catalogue v1 avec docs/licences.md).
