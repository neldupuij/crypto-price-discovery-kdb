# Étude funding — pré-enregistrement des choix d'analyse

**Date :** 11 novembre 2026, avant tout calcul de résultat sur les nouveaux échantillons.

**À ce stade, on a seulement :**
- téléchargé et agrégé en barres de 1 s les transactions de BTC (août, septembre) et d'ETH (août à octobre) ;
- téléchargé les fichiers mensuels (funding, indice de prime, bougies).

**Ce qu'on a déjà vu des nouveaux échantillons :** uniquement le **niveau** mensuel du funding (minimum, moyenne, maximum, via l'API), en choisissant les mois. **Aucune** mesure de base, de flux ou de rendement autour des paiements n'a été calculée sur ces échantillons.

## 1. Statut des échantillons

| Rôle | Échantillon |
|---|---|
| **Exploratoire** (choix faits en le regardant) | BTCUSDT, octobre 2026 |
| **Validation rétrospective** (même analyse, sans réglage) | BTCUSDT août 2026, BTCUSDT septembre 2026, ETHUSDT août, septembre et octobre 2026 |
| **Réservé, non examiné** | à partir du **1er novembre 2026**, BTCUSDT et ETHUSDT |

Pour l'échantillon réservé : les transactions BTC du 1er au 8 novembre ont été téléchargées pour l'étude lead-lag. Elles n'ont **jamais** servi à l'étude funding, et elles ne seront pas utilisées tant qu'une évaluation chronologique n'aura pas été décidée.

La validation sur les mois d'août à octobre est **rétrospective** : ces mois sont antérieurs ou contemporains de l'échantillon exploratoire. Ce n'est donc pas une évaluation chronologique. Seule la période réservée pourra jouer ce rôle.

## 2. Données et traitement (identiques pour tous les échantillons)

- **Sources.** aggTrades spot et perp USDⓈ-M de data.binance.vision, fichiers mensuels `fundingRate`, `premiumIndexKlines` 1m et `klines` 1m (perp et spot). Chaque fichier est contrôlé avec sa somme SHA-256.
- **Côté agressif.** `is_buyer_maker = true` est lu comme une vente agressive.
- **Barres 1 s.** Une barre n'existe que pour une seconde avec au moins une transaction.
- **Prix.** Dernier prix de transaction, porté en avant par jointure as-of (`aj`, passé uniquement). Son ancienneté est conservée.
- **Flux.** Rattachés à leur seconde exacte (`lj`), jamais remplis.
- **Agrégation à la minute :**
  - volume = somme (0 si aucune transaction) ;
  - déséquilibre `(achats − ventes) / (achats + ventes)`, **nul (null) si le volume est nul** ;
  - rendement = somme des rendements logarithmiques à 1 s, en bp ;
  - volatilité réalisée = racine de la somme des carrés.
- **Base.** `1e4 × (perp / spot − 1)` à la fin de chaque minute. **Mise à null si l'un des deux prix a plus de 60 s** (`STALEMAX`).
- **Interruptions et qualité.** Le notionnel total et le notionnel acheteur sont comparés, minute par minute, aux bougies officielles. Une minute est « sévère » si l'écart dépasse **10 %** (`QMAXGAP`). **Toute fenêtre contenant une minute sévère est exclue**, qu'il s'agisse d'un paiement ou d'un témoin.
- **Estimation ex ante du funding.** Moyenne pondérée (poids 1 à n) de l'indice de prime à la minute ((ouverture + clôture) / 2), sur `[T − 8 h, t)`, plus l'écrêtage à ±0,05 % autour de 0,01 %, puis plafond et plancher à ±0,3 %. On l'évalue à **T − 60 min**.

## 3. Fenêtres, mesures et inférence

- **Fenêtre de paiement** : de T − 60 min à T + 59 min, pour chaque paiement (00, 08 et 16 h UTC).
- **Fenêtres témoins** : la même fenêtre autour de **chaque autre heure pleine**.
- **Une fenêtre doit tenir entièrement dans le mois analysé.** Chaque couple symbole/mois est analysé **séparément**, avec ses propres témoins.
- **Mesures par fenêtre** (même code, `analysis/funding_events.q`) :
  - variations de base : −60 → paiement, paiement → +60, −5 → +5 min ;
  - déséquilibres spot et perp sur 30 min avant et après, et perp sur 5 min, avec leurs asymétries (après − avant) ;
  - log du ratio de volume après/avant ;
  - rendements sur 30 min avant et après ;
  - volatilité réalisée perp ;
  - versions « alignées » : multipliées par le signe de l'estimation ex ante.
- **Groupes de funding.**
  - Signe du taux réalisé : descriptif uniquement.
  - Tiers de l'estimation ex ante, avec des **seuils fixés sur l'échantillon exploratoire** et appliqués tels quels à tous les échantillons, ETH compris : **0,25824645 bp et 0,68922646 bp** par 8 h (`EST_T1`, `EST_T2`).
  - Convention : tout seuil qui dépend des données est calculé sur BTC octobre uniquement.
- **Inférence.** Différence paiement − témoin, bootstrap par jour (on tire des jours entiers), 2 000 tirages, graine 42 (`NREP`, `SEED`).
- **Contrôle horaire.** Les mêmes mesures sont calculées pour chacune des 24 heures pleines.

## 4. Ce qui comptera comme une réplication (décidé maintenant)

Constats de l'échantillon exploratoire à tester :

| # | Constat sur BTC octobre | Réplication si… |
|---|---|---|
| E1 | Variation de base, paiement → +60 min : paiement − témoin **> 0** (+0,29 bp) | même signe **et** IC à 95 % qui exclut 0 |
| E2 | Variation de base, −5 → +5 min : **> 0** (+0,23 bp) | idem |
| E3 | Asymétrie perp alignée sur le funding estimé : **< 0** (−0,046), donc **contraire** à l'hypothèse de débouclage, qui prédit > 0 | idem |
| H | Hypothèse de départ : asymétrie alignée **> 0** | IC à 95 % entièrement au-dessus de 0 |

Pour chaque constat, on donne en plus le **nombre d'échantillons de validation de même signe**, sur 5. Si les signes étaient tirés au hasard, obtenir 5 signes identiques sur 5 aurait une probabilité de 1/32 dans une direction donnée. Avec 5 échantillons et 4 constats, on attend des résultats significatifs isolés par pur hasard : un constat ne sera dit **stable** que s'il réplique dans **au moins 4 échantillons sur 5**, sans contradiction significative.

## 5. Ce qui est interdit

- Changer une fenêtre, une mesure, un seuil, une règle d'exclusion ou une graine après avoir vu les nouveaux résultats.
- Ajouter ou retirer une mesure du bilan selon son résultat.
- Regarder la période réservée (à partir de novembre 2026).

Tout écart rendu nécessaire par un problème de données sera **signalé comme tel**, avec sa raison, dans le bilan.

## 6. Empreinte du code gelé

Le code ci-dessous est celui qui produira les résultats de validation. Empreintes SHA-256 :

```
b7a6db0a4793c82250c943105dac17c3bc581525bfcda4f79ebf6a91c5b02278  src/params.q
2319e17270c7035244d382fc1df339e15d7ef4e355b7b29cd320c26d0f1dd56f  src/binance.q
53029568aba2ab16cef36314dd40e73db1326b965f62b6d4ec181b8ab7ad21cc  src/build_bars.q
bbe670ef6f715d6a2f410e81214c2161df751d2070480fcf66eb850c2db946d2  src/download.sh
e5bb3457574a8e54c0199f642ff513610cb540c19b816342e5e270cb2dccf056  src/download_monthly.sh
4dc77c158759bc64b3f25644f6a19060dd458924da4bc7e176fb8a0caace6426  src/funding_pipeline.sh
1c2b702c619b044f9c0f32fd74680020baf2844144211af7f430288e9e6ca46f  src/funding.q
6fabaa6a76d355f4fb3fcac71fc9d4fc42f43777e9097ce41e396a7018b80be7  src/check_klines.q
4994ae81513f07c605845cb8c461bcf8e5cd8fa6310dc27c25e7612a53cb7d70  analysis/funding_panel.q
fba0e915ed0ea31ca00c92fe0558812b2bfb5d65cff48a635522a7502347f106  analysis/funding_events.q
6ecbfed387210b6f15b9e8cfef3cc32ecc6f8ae35d8676408ba61a62c19ff7e6  analysis/funding_check_events.q
bf005df93351e139af252c68230b05f7bda50fa6d037692943829e87fcaaa94d  notebooks/plot_funding.py
02c5a3f29dcd888fd5cb0a5af43295977b425ae808a0a30f3ff891f717b239dd  notebooks/plot_funding_compare.py
```

Commandes, pour chaque SYM dans {BTCUSDT, ETHUSDT} :

```
q src/funding.q        -sym SYM -months 2026-08 2026-09 2026-10 -q
q analysis/funding_panel.q -sym SYM -months 2026-08 2026-09 2026-10 -q
q src/check_klines.q   -sym SYM -months 2026-08 2026-09 2026-10 -q
q analysis/funding_events.q -sym SYM -months <MOIS> -q        # un mois à la fois
```
