# Étude funding — note sur les données et leurs limites

BTCUSDT, Binance, octobre 2026 (premier jalon). Vérifié le 11 novembre 2026.

## 1. Sources

| Donnée | Source | Contenu | Horodatage |
|---|---|---|---|
| Transactions spot | data.binance.vision `spot/daily/aggTrades/BTCUSDT` | une ligne = les exécutions d'un ordre preneur à un prix | **microsecondes** depuis 1970 (spot, depuis le 1er janvier 2025, d'après le README `binance-public-data`) |
| Transactions perp | `futures/um/daily/aggTrades/BTCUSDT` | idem | **millisecondes** |
| Funding réalisé | `futures/um/monthly/fundingRate/BTCUSDT` (colonnes `calc_time`, `funding_interval_hours`, `last_funding_rate`) | taux payé à chaque échéance | ms ; `calc_time` = l'heure prévue + 0 à 7 ms |
| Indice de prime | `futures/um/monthly/premiumIndexKlines/BTCUSDT/1m` | OHLC à la minute de l'indice de prime (12 échantillons de 5 s par minute) | ms |
| Bougies 1 min perp / spot | `futures/um/monthly/klines/…/1m`, `spot/monthly/klines/…/1m` | volume en USDT et volume acheteur preneur | ms (perp), µs (spot) |

Chaque fichier est contrôlé avec la somme SHA-256 publiée par Binance. Le fichier de funding a été recoupé avec l'API `GET /fapi/v1/fundingRate` : 93 échéances, taux identiques.

## 2. Ce que disent (et ne disent pas) les champs

- **Côté agressif.** Binance documente `m` / `is_buyer_maker` comme « Was the buyer the maker? ». Le côté preneur n'est pas écrit explicitement. On en déduit que `true` signifie que **le vendeur était preneur**, donc une vente agressive. C'est une déduction, pas une citation.
- **Nombre de transactions.** Un aggTrade regroupe toutes les exécutions d'un même ordre preneur à un même prix. « Nombre de transactions » signifie donc ici « nombre d'aggTrades ».
- **Notionnel comparable.** Prix × quantité en USDT, sur les deux marchés (BTCUSDT spot et perp USDⓈ-M sont tous deux cotés en USDT pour 1 BTC).
- **Prix.** On n'a que le prix de la dernière transaction : ce n'est **ni un milieu de carnet, ni un prix exécutable**. La base spot/perp hérite donc du rebond entre prix acheteur et prix vendeur.

## 3. Funding : calendrier et information disponible avant le paiement

- **Calendrier observé en octobre 2026** : 93 paiements, toujours à **00:00, 08:00 et 16:00 UTC**, avec un intervalle de 8 h constant (`funding_interval_hours = 8`). `GET /fapi/v1/fundingInfo` donne aujourd'hui BTCUSDT à 8 h, avec un plafond et un plancher de ±0,3 %. La FAQ Binance indique que l'intervalle peut changer : il faut le revérifier pour toute autre période.
- **Qui paie, et quand** (FAQ Binance) : si le taux est positif, les longs paient les shorts. Seules les positions ouvertes **à l'instant de l'échéance** paient ou reçoivent. L'exécution réelle peut décaler de ±15 s.
- **Formule** (FAQ) : moyenne pondérée dans le temps de l'indice de prime sur l'intervalle (poids 1, 2, …, n : les derniers échantillons pèsent plus), plus `clamp(0,01 % − P, ±0,05 %)`, puis plafond et plancher.
- **Estimation avant paiement.** Binance ne fournit **aucun historique** du taux estimé (le champ `lastFundingRate` de `premiumIndex` n'existe qu'en temps réel). Nous l'avons **reconstruite** à partir des bougies 1 min de l'indice de prime, en approximant la moyenne de chaque minute par (ouverture + clôture) / 2 :

  | Estimation calculée… | Corrélation avec le taux payé | Erreur absolue moyenne | Même signe |
  |---|---|---|---|
  | sur tout l'intervalle (= ce que calcule Binance) | 0,997 | 0,02 bp | — |
  | 15 min avant | 0,992 | 0,04 bp | — |
  | **60 min avant** | **0,954** | **0,09 bp** | **92 %** |

  → Classer les événements selon le **taux réalisé** est descriptif : on ne connaît ce taux qu'au paiement. Seule l'**estimation à T − 60 min** pourra servir à prédire.

- **Niveau du funding.** En octobre, le taux va de −0,41 à +1,00 bp par 8 h (médiane 0,46 bp). 15 taux sont négatifs, et 12 sont au niveau de référence de 1 bp. Sur toute l'année 2026, le funding BTCUSDT **n'a jamais dépassé 1 bp** par 8 h. Il n'y a donc **pas de régime de funding élevé** dans les données disponibles. L'incitation financière est très faible : 1 bp, contre environ 4 bp de frais preneur sur le perp.

## 4. Contrôles de qualité

- **Volume** : 25,7 millions de transactions spot et 32,5 millions perp. Aucun prix manquant, horodatages triés, aucune transaction hors de son jour (`data/hdb_1s_audit.csv`).
- **Comparaison avec les bougies officielles** (`src/check_klines.q`) : notionnel total et notionnel acheteur, minute par minute.
  - **Spot** : identique sur les 44 640 minutes.
  - **Perp** : 266 minutes diffèrent de plus de 1 %. Les écarts vont dans les deux sens et se compensent sur le mois (334,80 contre 334,91 milliards USDT). C'est probablement une attribution à la minute voisine autour des frontières de minute (non vérifié).
  - **Trou** : aucune transaction perp dans le fichier aggTrades entre **00:03 et 00:29 UTC le 27 octobre**, alors que les bougies Binance montrent environ 1 000 transactions par minute. **C'est un trou du fichier, pas un arrêt du marché.**
- **Règle d'exclusion** : on écarte toute fenêtre de ±60 min contenant une minute où l'écart dépasse 10 %. Cela retire 5 paiements et 29 placebos. On retire aussi le paiement du 1er octobre à 00:00, dont la fenêtre commence en septembre. Il reste **87 paiements**.
- **Ancienneté des prix** : au 99ᵉ centile, le prix utilisé pour la base date de 3,4 s. Une base calculée sur un prix de plus de 60 s est mise à null (27 minutes, toutes dans le trou du 27 octobre).
- **Vérifications manuelles** (`analysis/funding_check_events.q`) : sur 3 paiements (taux le plus négatif, médian, le plus positif), les flux de la minute précédant le paiement et la base au paiement, recalculés directement depuis les barres 1 s, sont identiques au panel.

## 5. Limites à garder en tête

1. **Pas de carnet d'ordres.** Pas de spread, pas de profondeur, pas de prix exécutable. Les mouvements de base de quelques dixièmes de bp sont du même ordre que le rebond entre prix acheteur et vendeur.
2. **Pas d'intentions.** Une vente agressive peut ouvrir un short ou fermer un long. On parle donc de flux **compatibles** avec un débouclage, jamais de débouclages observés.
3. **Un seul mois, funding faible.** 87 paiements, c'est peu. Et l'absence de funding élevé empêche de tester la partie « funding élevé » de l'hypothèse.
4. **Heure confondue.** Les paiements tombent toujours à 00, 08 et 16 h UTC. Les placebos (toutes les autres heures pleines) contrôlent l'effet « heure pleine » et l'effet jour, mais pas un effet propre à ces trois heures, comme l'ouverture de la bougie journalière à 00:00.
5. **Dépendance temporelle.** L'unité d'observation est la fenêtre, pas la transaction. Les intervalles de confiance viennent d'un bootstrap par jour.
