# Funding et flux autour du paiement — rapport (jalon 1, descriptif)

**Question.** Un funding élevé est-il associé à des flux compatibles avec un débouclage autour de son paiement ? Les transactions spot et perp permettent-elles d'anticiper les mouvements de prix associés ?

**Périmètre de ce jalon.** BTCUSDT sur Binance, octobre 2026 : 58 millions de transactions, 87 paiements de funding analysés et 622 fenêtres témoins. **Étude descriptive uniquement.** La partie prédiction hors échantillon et la partie couverture ne sont **pas** encore faites.

Données et limites : voir [funding_data_notes.md](funding_data_notes.md).

---

## 1. Méthode

- **Variables** (`analysis/funding_panel.q`). Les transactions sont d'abord agrégées en barres de 1 seconde, puis en minutes. On calcule :
  - les notionnels acheteur et vendeur agressifs ;
  - le déséquilibre `(achats − ventes) / (achats + ventes)` ;
  - le nombre et la taille des transactions ;
  - le rendement et la volatilité réalisée (à partir des rendements à 1 s) ;
  - la base `perp / spot − 1` en bp ;
  - l'ancienneté des prix.

  Les prix sont alignés par **jointure as-of** (`aj`) : on ne prend que des transactions passées. Les flux sont rattachés à leur seconde exacte (`lj`) : une seconde sans transaction reste **vide**, et non à 0.
- **Événements** (`analysis/funding_events.q`). Une fenêtre va de 60 min avant à 60 min après chaque paiement.
- **Témoins (placebos).** La même fenêtre autour de **toutes les autres heures pleines** du mois. On compare toujours *paiement − témoin*.
- **Incertitude.** Bootstrap par jour (on tire des jours entiers, 2 000 tirages), intervalle à 95 %.
- **Signe du funding.**
  - Le *taux réalisé* sert de découpage descriptif seulement, puisqu'il n'est connu qu'au paiement.
  - L'*estimation à T − 60 min* est connue à l'avance. On l'utilise pour « aligner » les mesures sur le sens de l'incitation (mesures `a…`).
  - L'hypothèse prédit une asymétrie alignée **> 0** : ventes perp avant le paiement et achats après, quand le funding est positif.
- **Tests multiples.** 23 mesures ont été testées sur l'ensemble des fenêtres. Au seuil de 5 %, on attend environ **1 faux positif** par pur hasard.

## 2. Résultats (faits)

### 2.1 Tous les paiements (87) contre les témoins (622)

| Mesure | Paiement − témoin | IC 95 % | p |
|---|---|---|---|
| Variation de base, −60 min → paiement | −0,02 bp | [−0,28 ; 0,26] | 0,88 |
| **Variation de base, paiement → +60 min** | **+0,29 bp** | [0,05 ; 0,52] | 0,015 |
| **Variation de base, −5 → +5 min** | **+0,23 bp** | [0,01 ; 0,42] | 0,037 |
| Asymétrie du déséquilibre perp (après − avant, 30 min) | −0,02 | [−0,07 ; 0,02] | 0,36 |
| Asymétrie du déséquilibre spot | +0,02 | [−0,05 ; 0,08] | 0,60 |
| Volume perp, log(après / avant) | −0,02 | [−0,14 ; 0,12] | 0,81 |
| Rendement perp, 30 min après | −1,0 bp | [−6,2 ; 3,9] | 0,75 |
| Volatilité réalisée perp, 30 min après | +2,0 bp | [0,2 ; 4,5] | 0,03 |
| **Asymétrie perp alignée sur le signe du funding estimé** | **−0,046** | [−0,090 ; −0,006] | 0,014 |

Ordres de grandeur, par paiement : la variation de base après paiement a une moyenne de 0,25 bp, une médiane de 0,30 bp et un **écart-type de 0,99 bp**. L'effet moyen représente donc environ un quart du bruit d'un seul événement.

### 2.2 Selon l'heure (contrôle de l'horloge)

Variation de base, du paiement à +60 min : **+0,59 bp à 00 h**, +0,03 bp à 08 h, +0,15 bp à 16 h. Aux heures témoins, elle va de **−0,51 bp (23 h)** à +0,28 bp (14 h). Variation de −5 à +5 min : −0,19 bp à 00 h, +0,30 bp à 08 h, **+0,61 bp à 16 h**. → Le motif **n'est pas le même aux trois heures de paiement**. Voir `results/figures/funding_by_hour.png`.

### 2.3 Selon le signe et l'amplitude du funding

| Groupe | n | Base, paiement → +60 min | Asymétrie perp |
|---|---|---|---|
| Taux réalisé < 0 | 15 | **+0,56 bp** [0,26 ; 0,89] | +0,06 [−0,03 ; 0,13] |
| Taux réalisé ≥ 0 | 72 | +0,23 bp [−0,03 ; 0,47] | −0,04 [−0,08 ; 0,01] |
| Estimation, tiers bas (< 0,26 bp) | 29 | +0,39 bp [0,05 ; 0,79] | +0,01 |
| Estimation, tiers milieu | 29 | +0,31 bp [−0,04 ; 0,71] | −0,01 |
| Estimation, tiers haut (> 0,69 bp) | 29 | +0,16 bp [−0,24 ; 0,62] | −0,07 [−0,12 ; 0,00] |

### 2.4 Qui mène, perp ou spot, autour du paiement (±10 min, données 1 s)

- **Rendements** : ratio lead-lag de 5,5 aux paiements contre 4,3 aux témoins. Le perp mène le spot dans les deux cas, ce qui confirme notre analyse précédente. Rien de propre au paiement.
- **Flux nets agressifs** : ratio de 1,04 aux paiements contre 1,24 aux témoins. **Les flux ne montrent pas de meneur clair** à 1 s ; la corrélation est surtout simultanée (0,37).

### 2.5 Persistance

Variation de base après paiement (moyenne des paiements), par semaine : +0,36, +0,48, +0,24, **−0,09**, +0,19 bp. Le signe ne tient pas sur les 5 semaines.

## 3. Interprétation (nos lectures, discutables)

1. **Pas de signature de débouclage dans les flux.** Aucune asymétrie avant/après n'est significative. Celle qui est alignée sur le signe du funding va même **à l'opposé** de l'hypothèse (−0,046). Avec un funding plafonné vers 1 bp et des frais preneur d'environ 4 bp, il n'y a guère de raison économique de déplacer des positions pour le paiement. Ce résultat nul est cohérent avec cela.
2. **Un léger mouvement de base après le paiement, mais fragile.** Les +0,29 bp ne sont significatifs qu'à 5 %, parmi 23 tests. L'effet change selon l'heure : fort à 00 h sur 60 min, fort à 16 h sur ±5 min, presque nul à 08 h. Il ne tient pas toutes les semaines. Il est aussi du même ordre que le bruit du rebond des derniers prix. **Nous ne le considérons pas comme établi.**
3. Le groupe « funding négatif » montre l'effet de base le plus net (+0,56 bp). Mais il ne compte que 15 événements, et ce découpage utilise le taux **réalisé** : il ne pourrait pas servir à décider à l'avance.

## 4. Hypothèses non testées et suite proposée

- **Le funding élevé n'a pas pu être testé** : il n'existe pas en 2026 (≤ 1 bp). Il faudrait remonter à des périodes de funding élevé, ce qui suppose de vérifier que l'intervalle était bien de 8 h et que les formats de données étaient les mêmes.
- **Avant d'aller à la prédiction** : étendre à 3 ou 6 mois et à ETHUSDT, avec le même pipeline. Il faudra vérifier si l'effet de base après paiement survit, et s'il est le même aux trois heures.
- **Prédiction et couverture** (étapes 5 et 6 du plan) : seulement si un effet robuste apparaît. **À ce stade, ce n'est pas le cas.**

## Fichiers

- Scripts :
  - `src/funding_pipeline.sh`, `src/build_bars.q` : transactions → barres 1 s, jour par jour ;
  - `src/funding.q` : funding réalisé et estimation reconstruite ;
  - `src/check_klines.q` : contrôle de qualité contre les bougies officielles ;
  - `analysis/funding_panel.q`, `analysis/funding_events.q`, `analysis/funding_check_events.q`.
- Résultats : `results/funding/*.csv`.
- Graphiques : `results/figures/funding_profiles.png`, `funding_by_hour.png`, `funding_estimate.png`.
