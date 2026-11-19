# Protocole de réplication — étude funding (v2, 11 novembre 2026, 17:10 UTC)

**Statut.** Cette version **remplace la v1 pour la suite**. La v1 est conservée sans modification : `docs/funding_preregistration.md` et sa copie `docs/funding_preregistration.frozen.md`, toutes deux d'empreinte SHA-256 `cfd44894…dd56f`.

**Rédaction.** La v2 a été écrite **avant tout examen des résultats** sur les nouveaux échantillons. Au moment où elle est écrite, la transformation des transactions en barres de 1 s est encore en cours : BTC septembre et tout ETH ne sont pas traités. **Aucune** mesure autour des paiements n'a été calculée sur ces échantillons.

**Changements par rapport à la v1 :**
1. Le document s'appelle désormais « protocole de réplication ».
2. Nouvelle date de début de la période réservée.
3. Le critère de réplication est défini précisément.
4. On affiche systématiquement les effectifs par catégorie, l'amplitude et l'importance économique.

**Le code n'est pas modifié** : mêmes fichiers, mêmes empreintes que dans la v1, section 6.

---

## 1. Échantillons

| Rôle | Échantillon |
|---|---|
| **Exploratoire** | BTCUSDT, octobre 2026. Tous les choix et seuils viennent de lui. |
| **Validation rétrospective** (5 échantillons, chacun analysé séparément avec ses propres témoins) | BTCUSDT 2026-08, BTCUSDT 2026-09, ETHUSDT 2026-08, ETHUSDT 2026-09, ETHUSDT 2026-10 |
| **Test final réservé** | **à partir du 12 novembre 2026, 00:00 UTC**, BTCUSDT et ETHUSDT. Aucune donnée de cette période n'existe encore à la date de ce document. |

**Pourquoi le 12 novembre.** Novembre n'est pas vierge : les transactions BTC du 1er au 8 novembre ont servi à l'étude lead-lag. On réserve donc une période qui commence après tout ce qui a déjà été examiné. Les jours du 1er au 11 novembre 2026 ne servent **ni** à la validation **ni** au test final.

La validation sur août à octobre est **rétrospective** : elle vérifie la stabilité dans le passé. Ce n'est **pas** une évaluation chronologique. Seule la période réservée pourra en tenir lieu.

## 2. Analyse appliquée

Elle est inchangée par rapport à la v1, sections 2 et 3 : mêmes fenêtres (±60 min autour de 00, 08 et 16 h UTC ; témoins autour de chaque autre heure pleine), mêmes mesures, même règle de qualité (10 %), même règle de prix trop ancien (60 s), même bootstrap par jour (2 000 tirages, graine 42).

## 3. Variable principale et critère de réplication

### 3.1 Constat principal à répliquer (un seul, décidé maintenant)

- **Variable principale** : `dBasisPost`, c'est-à-dire la variation de la base `1e4 × (perp / spot − 1)` entre la fin de la minute qui précède le paiement (prix as-of à T) et la fin de la minute T + 59.
- **Statistique** : moyenne sur les fenêtres de paiement **moins** moyenne sur les fenêtres témoins du **même échantillon**.
- **Sens attendu** : **positif**, comme sur l'échantillon exploratoire (+0,29 bp, IC à 95 % [0,05 ; 0,52]).
- **Critère par échantillon** : un échantillon **réplique** si la différence est **positive et** si son intervalle de confiance à 95 % (bootstrap par jour) est **entièrement au-dessus de 0**. Il **contredit** si l'intervalle est entièrement en dessous de 0. Sinon, il est **non concluant**.
- **Critère global** : le constat est déclaré **stable** si **au moins 4 échantillons sur 5 répliquent** et **qu'aucun ne contredit**. S'il y en a moins de 4, il est déclaré **non répliqué**, même si les signes sont majoritairement positifs. On rapportera tout de même le nombre de signes positifs, à titre descriptif.
- **Remarque sur la puissance**, écrite avant les résultats : chaque échantillon compte environ 85 à 90 paiements. L'effet exploratoire n'était que juste significatif sur un mois. Ce critère est donc **exigeant** : un effet réel mais petit peut ne pas le satisfaire. Un échec sera rapporté tel quel, sans assouplir le critère.

### 3.2 Constats secondaires

Ils sont rapportés avec le même critère, mais **ne décident pas** de la conclusion :

| # | Variable | Fenêtre | Sens attendu |
|---|---|---|---|
| S1 | `dBasis10` : variation de base | −5 → +5 min | > 0 (exploratoire : +0,23 bp) |
| S2 | `aPerpImbAsym` : déséquilibre perp (après − avant), × signe du funding estimé à T − 60 | 30 min avant / 30 min après | < 0 (exploratoire : −0,046) |
| H | même variable que S2 | idem | **> 0** (hypothèse de débouclage) |

## 4. Ce qui sera présenté pour chaque échantillon (y compris l'exploratoire, pour comparer)

- **Données** : nombre de transactions, de paiements, de témoins, de fenêtres exclues et pourquoi.
- **Pour chaque variable** : moyenne et médiane aux paiements, moyenne et médiane aux témoins, écart-type par fenêtre, nombre de fenêtres, différence paiement − témoin, IC à 95 %, p bootstrap.
- **Contrôle horaire** : la mesure principale pour chacune des 24 heures pleines.
- **Catégories de funding** :
  - les seuils sur l'estimation ex ante sont **ceux de BTC octobre**, appliqués tels quels, y compris sur ETH (0,25824645 et 0,68922646 bp par 8 h) ;
  - on affiche les **effectifs par catégorie** pour chaque échantillon, ce qui teste la transférabilité des seuils ;
  - des groupes déséquilibrés, voire vides, sont attendus et seront signalés, **sans** recalculer les seuils.

## 5. Importance économique (convention fixée maintenant)

Pour la variable principale, on exprimera l'effet :
- en **bp** et en **USD pour 1 million USD de notionnel** (1 bp = 100 USD) ;
- rapporté à l'**écart-type par fenêtre** de la même mesure (le bruit d'un seul événement) ;
- comparé à deux références :
  - les **frais de transaction** : barème public standard de Binance USDⓈ-M, environ 2 bp maker / 5 bp taker par côté ; ces valeurs sont à confirmer et servent d'ordre de grandeur, pas de coût exécutable ;
  - le **funding lui-même** : au plus 1 bp par 8 h en 2026.
- Le prix utilisé est le dernier prix de transaction. Cela **n'est pas un PnL réalisable** : pas de spread, pas de profondeur, pas d'exécution.

## 6. Interdits (inchangés)

Aucune modification de fenêtre, de mesure, de seuil, de règle d'exclusion ou de graine après avoir vu les résultats. Aucun accès à la période réservée. Tout écart imposé par les données sera signalé comme tel.
