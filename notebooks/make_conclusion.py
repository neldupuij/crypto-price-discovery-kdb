"""
Builds conclusion.pdf at the project root: a short French summary of the three studies
(lead-lag, funding, USDC -> BTC routing), with the main figures.

Writes an HTML page in a temporary folder, then prints it with headless Chrome.
Run from anywhere:  python3 notebooks/make_conclusion.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import pandas as pd
from datetime import date

ROOT = Path(__file__).resolve().parent.parent
FIG = ROOT / "results" / "figures"
OUT = ROOT / "conclusion.pdf"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# numbers read from the result files, not typed by hand
md = pd.read_csv(ROOT / "results" / "multiday_summary.csv")
llr100 = (md.llr100.min(), md.llr100.max())
llr10 = (md.llr10.min(), md.llr10.max())
c0 = (md.corr0_100.min(), md.corr0_100.max())
n_perp_jumps, n_spot_jumps = int(md.nPerpJumps.sum()), int(md.nSpotJumps.sum())
rs = pd.read_csv(ROOT / "results" / "routing" / "2026-11-01" / "summary.csv")


def row(sc, size):
    return rs[(rs.scenario == sc) & (rs["size"] == size)].iloc[0]


def fr(x, d=1, sign=False):
    return (f"{x:+.{d}f}" if sign else f"{x:.{d}f}").replace(".", ",").replace("-", "−")


def pct(sc, size, d=0):
    return fr(100 * row(sc, size).shareIndirectCheaper, d) + " %"


def cell(sc, size):
    return (f'<span class="nw">{fr(row(sc, size).bpsMed, 2, sign=True)} bp</span><br>'
            f'<span class="nw small">({pct(sc, size)})</span>')


def cover(size):
    r = row("F0", size)
    return f"{100 * r.both / r.instants:.0f} %"


def size_label(s):
    return '<span class="nw">' + fr(s, 2 if s < 0.1 else 1 if s < 1 else 0) + " BTC</span>"


rows = "".join(
    f"<tr><td>{size_label(s)}</td><td>{cell('F0', s)}</td><td>{cell('U1', s)}</td>"
    f"<td>{cell('U10', s)}</td><td>{fr(row('U10', s).bpsMax, 1, sign=True)} bp</td>"
    f"<td>{cell('Astable', s)}</td><td>{cover(s)}</td></tr>"
    for s in (0.01, 0.1, 1.0, 5.0))

# seconds where the indirect route still wins with 2.5 and 5 bp per leg
u25_5 = 100 * row("U2_5", 5.0).shareIndirectCheaper
u25_small = max(100 * row("U2_5", s).shareIndirectCheaper for s in (0.01, 0.1, 1.0))
u5_n = {s: round(row("U5", s).shareIndirectCheaper * row("U5", s).both) for s in (0.01, 0.1, 1.0, 5.0)}
u10_any = rs[rs.scenario == "U10"].shareIndirectCheaper.max()
u10_max = rs[rs.scenario == "U10"].bpsMax.max()
assert u10_any == 0 and u10_max < 0, "the 10 bp statement below would be false"
f0_1, f0_5 = row("F0", 1.0), row("F0", 5.0)
cov5 = 100 * f0_5.both / f0_5.instants


MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
        "septembre", "octobre", "novembre", "décembre"]
d = date.today()
TODAY = f"{d.day} {MOIS[d.month - 1]} {d.year}"


def img(name, w="100%"):
    return f'<img src="{(FIG / name).as_uri()}" style="width:{w}">'


html = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Conclusion</title>
<style>
@page {{ size: A4; margin: 16mm 15mm; }}
body {{ font-family: -apple-system, "Helvetica Neue", Arial, sans-serif; color:#0b0b0b; font-size:10.5pt; line-height:1.45; }}
h1 {{ font-size:20pt; margin:0 0 2mm; }}
h2 {{ font-size:13.5pt; margin:7mm 0 2mm; border-bottom:1px solid #e4e3df; padding-bottom:1mm; }}
h3 {{ font-size:11pt; margin:4mm 0 1mm; }}
.sub {{ color:#52514e; margin-bottom:5mm; }}
.box {{ break-inside:avoid; background:#f3f2ee; border-left:3px solid #1baf7a; padding:3mm 4mm; margin:3mm 0; }}
.no {{ border-left-color:#eb6834; }}
.lim {{ border-left-color:#8a8984; }}
.nw {{ white-space:nowrap; }}
table {{ break-inside:avoid; border-collapse:collapse; width:100%; font-size:9pt; margin:2mm 0; }}
th, td {{ border-bottom:1px solid #e4e3df; padding:1.3mm 1.6mm; text-align:left; vertical-align:top; }}
th {{ background:#f3f2ee; }}
ul {{ margin:1mm 0; padding-left:5mm; }} li {{ margin:0.6mm 0; }}
.pb {{ page-break-before:always; }}
.small {{ font-size:8.5pt; color:#52514e; }}
img {{ margin:2mm 0; }}
</style></head><body>

<h1>Microstructure crypto en kdb+/q — synthèse</h1>
<div class="sub">Projet <code>crypto-price-discovery-kdb</code> · étude de microstructure et de faisabilité économique sur données historiques Binance · {TODAY}</div>

<div class="box"><b>En bref.</b>
<ul>
<li><b>Lead-lag</b> : sur les huit jours étudiés (1er–8 novembre 2026), les variations du prix de transaction du perpétuel BTCUSDT précèdent celles du spot, chacun des huit jours. C'est une relation observée sur des prix de transaction ; elle ne démontre pas une opportunité exploitable à quelques millisecondes.</li>
<li><b>Funding</b> : l'effet exploratoire d'octobre est <b>non répliqué selon le protocole</b> (0 réplication sur 5, aucune contradiction ; écarts de +0,01 à +0,25 bp, tous les intervalles à 95 % contiennent 0). Cette étude n'a pas établi de signal de prix ou de flux stable sur les échantillons et horizons testés.</li>
<li><b>Routage USDC → BTC</b> (une journée, économies <b>estimées sur les carnets</b>, frais en scénarios) : sans frais, la médiane favorise l'indirect de moins de 1 bp à 1 et 5 BTC. À 1 bp par opération, la médiane devient négative, mais l'indirect reste moins cher dans {pct('U1', 1.0)} des secondes à 1 BTC et {pct('U1', 5.0)} à 5 BTC. À 10 bp par opération, aucun gain n'est observé sur la journée, parmi les comparaisons évaluables.</li>
</ul>
Les calculs principaux sont écrits en q (HDB partitionnée, as-of joins, parcours des niveaux de carnet, bootstrap par jour) ; Python sert aux téléchargements et aux graphiques.</div>

<h2>1. Lead-lag spot / perpétuel</h2>
<p><b>Question.</b> Entre les prix de transaction du spot BTCUSDT et du perpétuel USDⓈ-M, lesquels varient en premier ?</p>
<p><b>Méthode.</b> Trades agrégés Binance (<code>aggTrades</code>) du 1er au 8 novembre 2026, chargés dans une HDB partitionnée par date. Prix sur une grille = dernier trade à cet instant ou avant (as-of join). Corrélation croisée des rendements à 100 ms et 10 ms, puis étude d'événements autour des grands sauts de chaque marché.</p>
<ul>
<li>Le ratio lead-lag (corrélations quand le perpétuel précède / quand le spot précède) est supérieur à 1 chacun des 8 jours : de <b>{fr(llr100[0])} à {fr(llr100[1])}</b> à 100 ms et de {fr(llr10[0])} à {fr(llr10[1])} à 10 ms.</li>
<li>L'essentiel du co-mouvement est contemporain à 100 ms (corrélation {fr(c0[0], 2)}–{fr(c0[1], 2)}). Dans l'étude d'événements, la réponse moyenne du spot aux sauts du perpétuel apparaît surtout dans les premières dizaines de millisecondes.</li>
</ul>
<p><b>Contrôles réalisés.</b> Calcul refait séparément sur chacun des 8 jours ; deux résolutions (100 ms et 10 ms) ; étude d'événements dans les deux sens ({n_perp_jumps} sauts du perpétuel et {n_spot_jumps} du spot, plus de 3 bp en 10 ms, espacés d'au moins 1 s, 8 jours regroupés).<br>
<b>Non réalisés</b> : test sur séries décalées ou permutées, correction de la différence de fréquence des transactions, mesure sur les meilleurs prix des carnets, vérification de la synchronisation des horodatages spot et perpétuel.</p>
<div class="box lim"><b>Limites.</b>
<ul>
<li><b>Fréquence des transactions et prix anciens</b> : entre deux trades, le prix retenu est celui du dernier trade. Le marché qui traite le moins souvent paraît mécaniquement « en retard », ce qui peut gonfler le ratio.</li>
<li><b>Alignement temporel</b> : spot et perpétuel sont deux moteurs d'appariement distincts ; l'alignement de leurs horodatages à la milliseconde n'a pas été vérifié.</li>
<li><b>Exploitabilité</b> : aucune latence, aucun frais, aucun prix exécutable n'est pris en compte. Le résultat ne démontre pas une opportunité exploitable à quelques millisecondes.</li>
<li>Huit jours consécutifs, un seul instrument, une seule plateforme.</li>
</ul></div>
{img("multiday.png", "92%")}

<h2 class="pb">2. Funding et flux autour des paiements</h2>
<p><b>Question.</b> Les paiements de funding (toutes les 8 h) s'accompagnent-ils de flux compatibles avec un débouclage de positions, et d'un mouvement de prix mesurable ?</p>
<p><b>Méthode.</b> Exploration sur BTCUSDT octobre 2026, puis <b>protocole de réplication figé</b> (empreinte SHA conservée) appliqué sans retouche à 5 nouveaux échantillons rétrospectifs : BTC août–septembre, ETH août–octobre. Fenêtres ±60 min, comparaison aux heures placebo, bootstrap par jour.</p>
<table><tr><th>Échantillon</th><th>Effet base, paiement − placebo</th><th>IC 95 %</th><th>Verdict</th></tr>
<tr><td>BTC oct. (exploratoire)</td><td>+0,29 bp</td><td>[0,05 ; 0,52]</td><td>exploratoire</td></tr>
<tr><td>BTC août</td><td>+0,01 bp</td><td>[−0,30 ; 0,34]</td><td>non concluant</td></tr>
<tr><td>BTC sept.</td><td>+0,04 bp</td><td>[−0,21 ; 0,29]</td><td>non concluant</td></tr>
<tr><td>ETH août</td><td>+0,15 bp</td><td>[−0,08 ; 0,39]</td><td>non concluant</td></tr>
<tr><td>ETH sept.</td><td>+0,25 bp</td><td>[−0,03 ; 0,53]</td><td>non concluant</td></tr>
<tr><td>ETH oct.</td><td>+0,02 bp</td><td>[−0,26 ; 0,27]</td><td>non concluant</td></tr></table>
<div class="box no">
<ul>
<li><b>Effet non répliqué selon le protocole</b> : 0 réplication sur 5, aucune contradiction, 5 non concluants.</li>
<li><b>Amplitudes</b> : les 5 écarts sont positifs mais petits, +0,10 bp en moyenne (de +0,01 à +0,25 bp), contre +0,29 bp dans l'échantillon exploratoire ; écart-type par fenêtre 1,0 à 1,2 bp. +0,10 bp représente environ 10 USD par million de notionnel.</li>
<li><b>Flux</b> : les mesures secondaires d'asymétrie des flux du perpétuel ne répliquent dans aucun échantillon (0 sur 5 dans chaque sens).</li>
<li>Cette étude n'a pas établi de signal de prix ou de flux stable sur les échantillons et horizons testés. Le taux de funding lui-même est bien estimé une heure avant le paiement (corrélation 0,96, bon signe 96 % du temps), ce qui ne dit rien d'un mouvement de prix.</li>
<li><b>Limites</b> : prix de dernière transaction, analyse descriptive ; funding resté entre −1,4 et +1 bp par 8 h, le régime de funding élevé n'est pas couvert.</li>
</ul></div>
{img("funding_replication.png", "92%")}

<h2 class="pb">3. Routage USDC → BTC</h2>
<p><b>Question.</b> Pour la même quantité nette de BTC, acheter via USDC → USDT → BTC est-il moins cher qu'USDC → BTC directement ?</p>
<p><b>Méthode.</b> Carnets Tardis (25 niveaux) des trois paires le 1er novembre 2026 (un dimanche), fichiers vérifiés par MD5. Une décision par seconde (86 399), as-of join sur l'heure d'arrivée, parcours des niveaux visibles par un ordre au marché, frais prélevés dans la devise reçue, pas et minimums Binance. Aucune hypothèse 1 USDC = 1 USDT (le taux a varié de 1,00094 à 1,00126). Règles écrites avant tout calcul ; exemple vérifié à la main.</p>
<table><tr><th>Taille</th><th>Sans frais</th><th>1 bp / opération</th><th>10 bp / opération</th><th>Meilleure seconde à 10 bp</th><th>USDC/USDT gratuit, BTC à 10 bp</th><th>Secondes comparables</th></tr>
{rows}</table>
<p class="small">Médiane de <code>economie_bps</code> (positif = route indirecte moins chère) et, entre parenthèses, part des secondes où l'indirect est moins cher, parmi les secondes où les deux routes sont évaluables. Tous les niveaux de frais sont des scénarios : le barème du 1er novembre n'a pas été vérifié (10 bp = barème VIP 0 publié aujourd'hui).</p>
<div class="box no">
<ul>
<li><b>Sans frais</b> (borne optimiste) : la médiane favorise l'indirect de {fr(f0_1.bpsMed, 2, sign=True)} bp à 1 BTC et {fr(f0_5.bpsMed, 2, sign=True)} bp à 5 BTC. L'avantage « inférieur à 1 bp » concerne ces médianes, pas chaque observation : le 95<sup>e</sup> centile est de {fr(f0_1.bpsP95, 1, sign=True)} bp à 1 BTC et {fr(f0_5.bpsP95, 1, sign=True)} bp à 5 BTC, et la meilleure seconde atteint {fr(f0_1.bpsMax, 1, sign=True)} bp à 1 BTC.</li>
<li><b>1 bp par opération</b> : la médiane devient négative ({fr(row('U1', 1.0).bpsMed, 2, sign=True)} bp à 1 BTC, {fr(row('U1', 5.0).bpsMed, 2, sign=True)} bp à 5 BTC), mais l'indirect reste moins cher dans {pct('U1', 1.0)} des secondes à 1 BTC et {pct('U1', 5.0)} à 5 BTC.</li>
<li><b>2,5 et 5 bp par opération</b> : seules des secondes isolées restent favorables ({fr(u25_5, 1)} % des secondes à 5 BTC pour 2,5 bp, au plus {fr(u25_small, 2)} % aux autres tailles ; {u5_n[1.0]} seconde à 1 BTC pour 5 bp).</li>
<li><b>10 bp par opération</b> : aucun gain de la route indirecte sur la journée étudiée, parmi les comparaisons évaluables ; même la meilleure seconde reste négative (au mieux {fr(u10_max, 1, sign=True)} bp).</li>
<li><b>Seuil d'environ 0,7 bp</b> : c'est le niveau de frais par opération où la <b>médiane</b> à 5 BTC change de signe (environ 0,2 bp à 1 BTC). Au-delà, des économies restent possibles sur une partie des secondes, comme le montrent les lignes précédentes.</li>
<li><b>Couverture</b> : à 5 BTC, seuls {cov5:.0f} % des instants permettent d'évaluer les deux routes avec les 25 niveaux disponibles ; rien n'est extrapolé.</li>
</ul></div>
<div class="box lim"><b>Économie estimée ou économie exécutable.</b> Tous les chiffres ci-dessus sont des économies <b>estimées sur les carnets observés</b>. Une économie <b>exécutable</b> n'a pas été mesurée :
<ul>
<li>le carnet peut changer entre l'instantané et l'arrivée de l'ordre ;</li>
<li>les deux opérations de la route indirecte ne sont pas atomiques : le prix peut bouger entre elles, sur des montants du même ordre que l'avantage médian ;</li>
<li>les frais historiques ne sont pas vérifiés : chaque niveau de frais reste un scénario.</li>
</ul></div>
{img("routing_2026-11-01_fees.png")}

<h2>4. Ce que le projet contient</h2>
<ul>
<li><b>Trois résultats, chacun avec ses limites écrites</b> : une relation lead-lag observée sur huit jours de prix de transaction ; un effet de funding non répliqué selon le protocole ; un avantage de routage estimé petit et très dépendant des frais.</li>
<li><b>Une méthode</b> : audit des données d'abord, règles fixées avant les résultats, protocole figé puis réplication, contrôles indépendants (exemple à la main, recalcul Python des cas extrêmes).</li>
<li><b>Techniques mises en œuvre en kdb+/q</b>, sur des volumes réels (19 à 36 millions de trades par mois et par marché, centaines de milliers d'instantanés de carnet par jour) :
<ul>
<li>HDB partitionnée par date (<code>.Q.dpft</code>) ;</li>
<li>alignement sur une grille de temps et entre carnets par as-of join (<code>aj</code>) ;</li>
<li>corrélations croisées par décalage de listes (<code>xprev</code>) et études d'événements ;</li>
<li>parcours vectorisé des niveaux de carnet pour un montant donné, avec frais, pas et minimums ;</li>
<li>bootstrap par jour pour les intervalles de confiance.</li>
</ul></li>
</ul>
<h3>Suites possibles (non lancées)</h3>
<ul>
<li>Lead-lag : refaire la mesure sur les meilleurs prix des carnets et avec un test sur séries décalées, puis ajouter d'autres plateformes (Coinbase, OKX, Bybit) et mesurer les markouts.</li>
<li>Funding : tester une période de funding élevé (2024–2025), ou garder la période réservée à partir du 12 novembre 2026 pour une nouvelle hypothèse.</li>
<li>Routage : seulement si des frais vérifiés rendent la conversion USDC/USDT nettement moins chère que les paires BTC ; il faudrait alors d'autres journées, le carnet complet et une mesure du délai entre les deux opérations.</li>
</ul>
<p class="small">Détails : docs/funding_replication_report.md, docs/routing_note.md, README.md. Exercice guidé (1 BTC, direct ou via USDT) : docs/exercise_route_1btc.md.</p>
</body></html>"""

with tempfile.TemporaryDirectory() as tmp:
    page = Path(tmp) / "conclusion.html"
    page.write_text(html, encoding="utf-8")
    r = subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                        "--allow-file-access-from-files", f"--print-to-pdf={OUT}", page.as_uri()],
                       capture_output=True, text=True, timeout=120)
if not OUT.exists():
    sys.exit("PDF not written:\n" + r.stderr)
print(f"Saved {OUT}")
