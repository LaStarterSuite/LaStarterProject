# Drive (frappe/drive) — et sa reprise dans Frappe Suite

**Licence : AGPLv3.** 738 étoiles. Verdict LaStarter : **cœur, mais archivé**.

## État réel (vérifié)

- Le README du dépôt : « Frappe Drive is archived and is now part of Suite »
  (drive/README.md:1-3). Le flag GitHub isArchived est repassé à false car le
  code vit désormais dans **frappe/suite** (v0.0.1, Python >= 3.14).
- Suite = 7 produits dans UNE app Frappe : Drive, Slides, Writer, Sheets,
  Meet, Mail, Calendar (`suite/pyproject.toml` : description officielle).
  Mail sur clusters **Stalwart** (JMAP), dossier `realtime/` dédié,
  CRDT (pycrdt) pour l'édition collaborative.

## Conséquences pour LaStarter

- Le besoin « drive » est couvert **aujourd'hui** par deux voies :
  1. **Suite** (la cible) : suivre les releases, tester tôt, épingler dès
     stabilité. Attention : Python 3.14 requis, très jeune.
  2. L'ancien drive autonome si besoin d'un point de comparaison.
- Le dossier drive/writer/sheets est aussi l'inspiration déclarée du produit
  LaStarter : même philosophie d'app unique multi-produits, à élargir à tout
  le catalogue.
- Visio : Suite propose Meet (intégré) — l'arbitrage avec LiveKit et la
  brique Matrix change de dimension (voir `08-raven.md` et le catalogue v2).
