# Frappe Suite (frappe/suite) — la vision produit de Frappe

**Licence : AGPLv3** (license.txt). Version **0.0.1** — WIP assumé. Verdict
LaStarter : **la brique drive/docs cible, pas encore épinglable**.

## Ce que c'est (README officiel)

« Frappe Suite brings seven collaboration products into one Frappe app » :
**Drive** (fichiers), **Writer** (docs collaboratifs), **Sheets**
(spreadsheets), **Slides** (présentations), **Meet** (visio), **Mail**
(client email moderne), **Calendar**. Une seule app Frappe, un espace
connecté.

## Détails techniques vérifiés (pyproject.toml, README)

- Requiert **frappe >=16.0.0,<18.0.0** et **Python >=3.14** (très récent).
- Dépendances lourdes qui racontent l'ambition : pycrdt (CRDT, édition
  collaborative), tantivy (recherche), jmaplib (mail JMAP), boto3 (S3),
  pymupdf/av (prévisualisations).
- **Mail** : Suite n'administre pas de serveur — clusters **Stalwart** gérés
  à part, les users parlent JMAP au cluster avec des app passwords ; section
  « Suite Cloud » au README.
- Dossiers `realtime/` (service dédié), `e2e/`, `specs/`, `frontend/`
  (frappe-ui), `license.txt`.

## Position LaStarter

1. **Suivre de près** : c'est exactement le besoin drive/docs/calendrier du
   catalogue, unifié.
2. **Ne pas épingler en prod** avant stabilisation (0.0.1, Python 3.14).
3. **S'en inspirer structurellement** : le concept « une app = plusieurs
   produits cohérents » est le modèle de LaStarter Suite — notre catalogue
   élargit ce principe à TOUTES les briques (CRM, helpdesk…) avec sélection
   par le client.
4. L'ancien frappe/drive autonome reste la référence de comparaison.
