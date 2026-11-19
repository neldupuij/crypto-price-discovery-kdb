# Exercice guidé : acheter 1 BTC net, en direct ou via USDT

**Instant** : 1er novembre 2026, **16:43:00** (UTC). **Objectif** : recevoir **1 BTC net** (après frais) en partant d'USDC.
- **Route directe** : USDC → BTC sur BTC/USDC.
- **Route indirecte** : USDC → USDT sur USDC/USDT, puis USDT → BTC sur BTC/USDT.

Pourquoi cet instant : les deux routes y sont évaluables à 1 BTC, et l'économie sans frais (+0,19 bp) est presque exactement la médiane de la journée. C'est un cas typique, pas un cas extrême.

Script : [`analysis/exercise_route_1btc.q`](../analysis/exercise_route_1btc.q). Il refait le calcul étape par étape, puis vérifie qu'il retombe sur `src/route_lib.q` et sur `results/routing/2026-11-01/economie_F0_U10.csv`.

```bash
q analysis/exercise_route_1btc.q -fee 0 -exit -q
```

```bash
q analysis/exercise_route_1btc.q -fee 10 -exit -q
```

`-fee` est le frais par opération en bp, le même sur les trois paires. Sans `-exit`, q reste ouvert et tu peux taper tes propres requêtes.

**Méthode conseillée.** Pour chaque étape, fais d'abord le calcul à la main ou au tableur avec les carnets de l'étape 2. Lance ensuite les lignes q correspondantes (Cmd+D dans VS Code) pour comparer. Les solutions sont repliées : ouvre-les seulement après avoir essayé.

---

## Règles (rappel de `docs/routing_protocol.md`)

1. **Ordre au marché** : on consomme les niveaux visibles du carnet, du meilleur prix vers le moins bon. On n'extrapole jamais au-delà des 25 niveaux.
2. **Frais prélevés dans l'actif reçu** : en BTC quand on achète du BTC, en USDT quand on vend de l'USDC contre de l'USDT.
3. **Pas de cotation** : la quantité de BTC est arrondie **au-dessus** à 0,00001 BTC, et la vente d'USDC se fait en USDC entiers (arrondi au-dessus).
4. **Reliquats crédités** : un excès de BTC est valorisé au meilleur bid BTC/USDC ; un reste d'USDT au meilleur ask USDC/USDT (prix pour racheter de l'USDC). Les deux routes sont ainsi comparées pour **exactement** 1 BTC net.
5. **Coût final en USDC**, et `economie_bps = 10 000 × (coût direct − coût indirect) / coût direct`. Une valeur positive signifie que la route indirecte est moins chère.

---

## Étape 1 — Quel carnet connaît-on à 16:43:00 ?

On prend, pour chaque paire, le **dernier instantané arrivé** à 16:43:00 ou avant (heure d'arrivée Tardis `lt`). Rien de postérieur n'est utilisé.

```q
ld:{get hsym `$"data/routing/2026-11-01/",x}
bU:ld "BTCUSDC"; bT:ld "BTCUSDT"; uU:ld "USDCUSDT"
snap:{[t] t t[`lt] bin T}          / index du dernier lt <= T, puis la ligne correspondante
sD:snap bU; sB:snap bT; sU:snap uU
```

- `t[`lt] bin T` : `lt` est trié, et `bin` renvoie l'indice du dernier élément ≤ T. C'est la logique de `aj` (as-of join) dans `analysis/route_costs.q`, appliquée ici à un seul instant.
- `t i` : la ligne i d'une table, sous forme de dictionnaire. `sD`ap` est la liste des 25 prix ask.

**Résultat** : âges de 66 ms (BTC/USDC), 84 ms (BTC/USDT) et 61 ms (USDC/USDT), bien sous la limite de 10 s.

> **À toi.** Pourquoi utiliser l'heure d'**arrivée** (`lt`) et non l'heure de la plateforme (`et`) ? Quelle erreur commettrait-on avec `et` ?

<details><summary>Réponse</summary>

À 16:43:00, on ne peut décider qu'avec ce qui est déjà **reçu**. Un instantané horodaté 16:42:59,99 par la plateforme mais arrivé à 16:43:00,05 n'est pas encore connu. Utiliser `et` reviendrait à regarder légèrement dans le futur (biais d'anticipation).
</details>

---

## Étape 2 — Les carnets (6 premiers niveaux)

| BTC/USDC asks (USDC par BTC × BTC) | BTC/USDT asks (USDT par BTC × BTC) | USDC/USDT bids (USDT par USDC × USDC) |
|---|---|---|
| 78 017,58 × 0,46247 | **78 096,88 × 1,83211** | **1,00099 × 384 416** |
| 78 022,53 × 0,00517 | 78 096,89 × 0,00056 | 1,00098 × 1 809 524 |
| 78 022,54 × 0,02 | 78 097,50 × 0,00014 | 1,00097 × 740 994 |
| 78 023,44 × 0,10144 | 78 098,00 × 0,00021 | 1,00096 × 977 420 |
| 78 024,16 × 0,25634 | 78 098,01 × 0,024 | 1,00095 × 524 997 |
| 78 024,82 × 0,00129 | 78 098,50 × 0,00007 | 1,00094 × 263 658 |

Niveaux 6 et 7 de BTC/USDC, utiles pour la suite : 78 024,90 × 0,1021 et 78 024,96 × 0,0522.
Meilleur bid BTC/USDC : **78 017,57**. Meilleur ask USDC/USDT : **1,00100**.

> **À toi, avant tout calcul.** En lisant seulement ces chiffres :
> 1. Combien coûte 1 BTC sur BTC/USDT, exprimé en USDC, au meilleur prix ? (indice : 78 096,88 USDT ÷ 1,00099 USDT par USDC)
> 2. Pourquoi la route directe ne peut-elle pas acheter 1 BTC entier au meilleur ask ?

<details><summary>Réponse</summary>

1. 78 096,88 / 1,00099 ≈ **78 019,64 USDC par BTC**. C'est un peu plus cher que le meilleur ask direct (78 017,58).
2. Le meilleur niveau BTC/USDC n'offre que 0,46247 BTC. Il faut descendre jusqu'au niveau 7 du carnet. Côté BTC/USDT, le premier niveau (1,83 BTC) suffit à lui seul.

C'est toute l'histoire de cet instant : le **prix affiché** favorise la route directe, la **profondeur** favorise l'indirecte.
</details>

---

## Étape 3 — Route directe, sans frais

```q
gD:roundUp[Q%1-FD; STEP_BTC]                      / BTC bruts à acheter
fillD:sD[`aq] & 0|gD-0^prev sums sD`aq            / quantité prise à chaque niveau
costGrossD:sum sD[`ap]*fillD                      / USDC payés
exD:(gD*1-FD)-Q                                   / BTC reçus en trop
costD:costGrossD-exD*first sD`bp                  / coût net en USDC
```

**Comment lire `fillD`** (q se lit de droite à gauche) :
- `sums sD`aq` : quantités cumulées 0,46247 ; 0,46764 ; 0,48764 ; …
- `prev …` : cumul **avant** chaque niveau (`0N` au premier, d'où le `0^`, qui remplace le null par 0).
- `gD - …` : ce qui manque encore en arrivant à chaque niveau.
- `0| …` : négatif mis à 0 (une fois l'objectif atteint, on ne prend plus rien).
- `sD[`aq] & …` : plafonné par la quantité disponible au niveau.

> **À toi.** Avec FD = 0, donc gD = 1 BTC :
> 1. Combien de BTC prend-on au niveau 7 ?
> 2. Quel est le coût total en USDC ?

<details><summary>Réponse</summary>

1. Niveaux 0 à 6 cumulés : 0,46247 + 0,00517 + 0,02 + 0,10144 + 0,25634 + 0,00129 + 0,1021 = 0,94881 BTC. Il reste **0,05119 BTC** au niveau 7, à 78 024,96.
2. Somme des prix × quantités : **78 021,12 USDC**. Le prix moyen (78 021,12 / 1) est 3,54 USDC au-dessus du meilleur ask : c'est le coût de la profondeur.
</details>

---

## Étape 4 — Route indirecte, sans frais

On raisonne **à rebours**, depuis le BTC voulu.

```q
gB:roundUp[Q%1-FB; STEP_BTC]                      / BTC bruts à acheter sur BTC/USDT
fillB:sB[`aq] & 0|gB-0^prev sums sB`aq
usdtNeeded:sum sB[`ap]*fillB                      / USDT nécessaires
usdtGross:usdtNeeded%1-FS                         / USDT bruts à recevoir (frais de vente en USDT)
valU:sU[`bp]*sU`bq                                / valeur en USDT de chaque niveau de bids
fillU:sU[`bq] & 0|(usdtGross-0^prev sums valU)%sU`bp   / USDC vendus à chaque niveau
usdcSold:roundUp[sum fillU; STEP_USDC]            / USDC entiers
usdtNet:(1-FS)*sum sU[`bp]*sU[`bq] & 0|usdcSold-0^prev sums sU`bq
leftUsdt:usdtNet-usdtNeeded                       / reste d'USDT
exB:(gB*1-FB)-Q
costI:usdcSold-(leftUsdt%first sU`ap)+exB*first sD`bp
```

**Piège q** : `usdcSold-(leftUsdt%ask)+exB*bid` se lit `usdcSold − ((leftUsdt/ask) + exB×bid)`, car q évalue de droite à gauche, sans priorité des opérateurs. C'est voulu : on retranche les **deux** crédits. Écrire `usdcSold-(leftUsdt%ask)-exB*bid` donnerait `usdcSold − (leftUsdt/ask − exB×bid)`, donc le mauvais signe sur le second crédit. C'est l'erreur qu'avait détectée l'exemple fait à la main (`docs/routing_toy_example.md`).

> **À toi.** Sans frais :
> 1. Combien d'USDT faut-il pour 1 BTC ?
> 2. Combien d'USDC faut-il vendre, avant puis après arrondi ?
> 3. Combien d'USDT reste-t-il, et combien vaut ce reste en USDC ?
> 4. Quel est le coût indirect final ?

<details><summary>Réponse</summary>

1. 1 BTC au premier niveau : **78 096,88 USDT**.
2. 78 096,88 / 1,00099 = **78 019,6406 USDC**, arrondi à **78 020 USDC**. Tout se fait au premier niveau de bids (384 416 USDC disponibles).
3. 78 020 × 1,00099 = 78 097,2398 USDT reçus, donc un reste de **0,3598 USDT**. Racheté au meilleur ask USDC/USDT : 0,3598 / 1,001 = **0,3594 USDC** de crédit.
4. 78 020 − 0,3594 = **78 019,64 USDC**.
</details>

---

## Étape 5 — Comparaison sans frais

| | Coût (USDC) |
|---|---|
| Direct | 78 021,12 |
| Indirect | 78 019,64 |
| **Économie de l'indirect** | **+1,48 USDC = +0,19 bp** |

L'arrondi à l'USDC entier ne coûte rien ici : le reste d'USDT est recrédité. L'écart vient entièrement de la profondeur (étape 2).

---

## Étape 6 — Même instant avec frais

Relance avec `-fee 1` puis `-fee 10`.

| Frais par opération | Direct (USDC) | Indirect (USDC) | Économie |
|---|---|---|---|
| 0 bp | 78 021,12 | 78 019,64 | **+1,48 USDC (+0,19 bp)** |
| 1 bp | 78 028,92 | 78 035,25 | −6,32 USDC (−0,81 bp) |
| 10 bp | 78 099,22 | 78 175,92 | −76,69 USDC (−9,82 bp) |

> **À toi.**
> 1. Avec 10 bp, pourquoi achète-t-on 1,00101 BTC bruts et non 1,001 ?
> 2. La route indirecte paie combien de frais, et la directe combien ? Retrouve l'ordre de grandeur de −9,82 bp sans q.
> 3. À partir de quel frais par opération la route indirecte cesse-t-elle d'être moins chère **à cet instant** ?

<details><summary>Réponse</summary>

1. 1 / 0,999 = 1,001001…, arrondi **au-dessus** au pas de 0,00001 : **1,00101 BTC**. On reçoit 1,00101 × 0,999 = 1,00000899 BTC, et l'excès de 0,00000899 BTC est crédité au bid (≈ 0,70 USDC).
2. Direct : 1 frais (achat de BTC). Indirect : 2 frais (vente d'USDC, puis achat de BTC). La différence est d'environ un frais, soit ≈ −10 bp, auquel on ajoute l'avantage brut de +0,19 bp : ≈ **−9,8 bp**.
3. Environ là où un frais compense l'avantage brut : **≈ 0,19 bp par opération**, à cet instant. Ce n'est pas un seuil général : sur la journée, la médiane à 1 BTC bascule vers 0,2 bp, celle à 5 BTC vers 0,7 bp, et certaines secondes restent favorables au-delà.
</details>

---

## Étape 7 — Vérifications à faire toi-même

Le script affiche à la fin :
- `route_lib direct` / `route_lib indirect` : les mêmes coûts calculés par les fonctions du projet (`diff=0`) ;
- `saved economie_bps` : la valeur enregistrée dans le CSV de la journée (+0,189677 sans frais, −9,819783 à 10 bp).

Essaie aussi :
1. Change `Q:1f` en `Q:5f`. Quelle route n'a pas assez de niveaux (`ok=0`) ? Pourquoi le coût affiché pour cette route n'a-t-il alors aucun sens, et pourquoi la seconde ne compte-t-elle pas dans les statistiques ?
2. Change `T` pour `2026.11.01D12:00:00`. Quelle route n'est pas évaluable à 1 BTC, et pourquoi ? (Regarde `ok` dans `libI`.)
3. Refais l'étape 3 au tableur et vérifie le coût au centime.

---

## Ce que ce calcul permet de défendre, et ce qu'il ne permet pas

- **Il permet de défendre** : le coût **estimé** des deux routes sur les carnets **connus** à 16:43:00, avec des règles fixées à l'avance (frais dans l'actif reçu, pas de cotation, reliquats crédités), et vérifié de trois façons (à la main, par `route_lib.q`, par le CSV de la journée).
- **Il ne permet pas d'affirmer** une économie **exécutable**. Le carnet peut changer entre l'instantané et l'ordre (60 à 85 ms d'âge ici, plus la latence d'envoi). Les deux opérations indirectes ne sont pas atomiques. Le barème de frais du 1er novembre n'est pas vérifié : 0, 1 et 10 bp sont des scénarios.
- **Ordre de grandeur à garder en tête** : +1,48 USDC sur 78 020, c'est 0,19 bp. Un seul frais de 1 bp sur ce montant coûte déjà environ 7,8 USDC.
