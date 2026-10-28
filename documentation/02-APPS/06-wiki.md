# Wiki (frappe/wiki)

**Licence : MIT** — la seule app du lot sous licence permissive. 452 étoiles,
push 2026-10-27. Verdict LaStarter : **utile**.

## Qu'est-ce que c'est

Wiki public/interne construit sur Frappe : espaces, révisions, éditions web,
recherche. 7 doctypes, 72 .vue. Bien outillé (ARCHITECTURE.md, docs/, specs/,
e2e Playwright).

## Authentification (audit)

Framework pour le login utilisateur. Le flux OAuth GitHub présent est une
intégration « connect-account » (wiki/www/github/authorize.py), pas du SSO —
ne pas confondre.

## Pourquoi elle compte pour LaStarter

- **Brique docs/wiki du catalogue**, la plus souple licence-wise : MIT, donc
  modifiable et rebrandable sans obligation de réciprocité (contrairement
  aux AGPL). Si une brique LaStarter nécessite des modifs qu'on ne veut pas
  publier, c'est ici que c'est possible — la règle maison restant de publier.
- Base idéale pour l'espace documentation des clients (intranet public).
