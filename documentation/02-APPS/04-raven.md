# Raven (frappe/raven) — chat et appels d'équipe

**Licence : AGPLv3.** 831 étoiles, push 2026-10-28. Verdict LaStarter : **utile**.

## Qu'est-ce que c'est

Messagerie d'équipe + **appels** (audio/visio) dans Frappe : channels, DMs,
threads, réactions. v3 en monorepo : `apps/web` (React 19 +
`frappe-react-sdk`), `apps/native` (React Native). 47 doctypes, 240 .py.

## Authentification (audit)

Délègue au framework mais avec **la plus grosse glue propre du lot** :
API de login guest lisant le Social Login Key du site
(raven/api/login.py:14-69) et **provisionnement automatique d'un OAuth Client
framework** pour ses apps web/native. Utile comme modèle quand nos propres
frontends auront besoin d'un login programmatique contre le site.

## Arbitrage LaStarter (à trancher)

La v1 avait choisi **Matrix/Synapse/Element** pour le chat. Raven couvre le
même besoin avec trois avantages Frappe : même users/rôles, même realtime,
zéro serveur supplémentaire. Contrepartie : pas de fédération Matrix, écosystème
client plus restreint. Décision ouverte — le catalogue v2 peut proposer Raven
par défaut et garder Matrix en brique optionnelle pour les clients qui veulent
la fédération.
