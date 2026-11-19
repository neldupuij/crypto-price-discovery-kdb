/ ============================================================
/ src/route_lib.q
/ Cost of the two routes on ONE set of order books (rules: docs/routing_protocol.md)
/ Prices/amounts are lists over the 25 visible levels, best level first.
/ ============================================================

STEP_BTC:0.00001          / BTCUSDC / BTCUSDT LOT_SIZE stepSize
STEP_USDC:1f              / USDCUSDT LOT_SIZE stepSize (whole USDC)

/ round UP to a multiple of step (tiny tolerance against float noise)
roundUp:{[x;step] step*ceiling (x%step)-1e-9}

/ buy quantity q on the asks (p ascending, s amounts): returns (cost; feasible)
/ fill on each level = what is still missing, capped by the level amount
buyCost:{[p;s;q]
  fill:s & 0|q-0^prev sums s;
  (sum p*fill; q<=sum[s]+1e-12)}

/ sell base units on the bids to RECEIVE r in quote currency: returns (units; feasible)
/ v = quote value of each level; on a level we sell (what is still missing) / price
sellFor:{[p;s;r]
  v:p*s;
  fill:s & 0|(r-0^prev sums v)%p;
  (sum fill; r<=sum[v]+1e-9)}

/ quote proceeds of selling x base units on the bids
proceeds:{[p;s;x] sum p*s & 0|x-0^prev sums s}

/ DIRECT: USDC -> BTC on BTCUSDC. Fee fd charged in BTC (asset received).
/ a = (asks prices; asks amounts; best bid) of BTCUSDC
/ returns `cost`ok`gross`excessBtc  (cost in USDC, net of the credit for excess BTC)
direct:{[a;q;fd]
  g:roundUp[q%1-fd; STEP_BTC];                         / gross BTC to buy
  c:buyCost[a 0; a 1; g];
  ex:(g*1-fd)-q;                                        / BTC received above the target
  `cost`ok`gross`excessBtc!(c[0]-ex*a 2; c 1; g; ex)}

/ INDIRECT: USDC -> USDT on USDCUSDT (sell USDC, bids), then USDT -> BTC on BTCUSDT (asks)
/ b = (asks prices; asks amounts) of BTCUSDT
/ u = (bids prices; bids amounts; best ask) of USDCUSDT
/ bbUSDC = BTCUSDC best bid (to credit the excess BTC, same convention as direct)
/ fb fee on BTCUSDT (in BTC), fs fee on USDCUSDT (in USDT)
indirect:{[b;u;bbUSDC;q;fb;fs]
  g:roundUp[q%1-fb; STEP_BTC];
  c:buyCost[b 0; b 1; g];                               / USDT needed
  r:c[0]%1-fs;                                          / gross USDT proceeds needed
  x:sellFor[u 0; u 1; r];                               / USDC to sell (before rounding)
  xr:roundUp[x 0; STEP_USDC];                           / whole USDC
  okx:xr<=sum[u 1]+1e-9;
  netUsdt:(1-fs)*proceeds[u 0; u 1; xr];
  left:netUsdt-c 0;                                     / USDT left over after buying BTC
  ex:(g*1-fb)-q;
  / credits: leftover USDT at the USDC ask, excess BTC at the BTCUSDC bid.
  / q reads right to left: xr-(a+b) subtracts BOTH credits (xr-a-b would not)
  cost:xr-(left%u 2)+ex*bbUSDC;
  `cost`ok`gross`usdt`usdcSold`leftUsdt`excessBtc!(cost; (c 1) & (x 1) & okx; g; c 0; xr; left; ex)}

/ ------------------------------------------------------------
/ VECTORIZED versions: same rules, but P/S are LISTS of books (one 25-level
/ list per decision instant). Used on the full day; checked against the
/ scalar versions above in analysis/route_toy_check.q.
/ ------------------------------------------------------------
buyCostV:{[P;S;q]
  cs:sums each S;
  fill:S & 0|q-0^prev each cs;
  (sum each P*fill; q<=1e-12+last each cs)}
sellForV:{[P;S;r]
  cv:sums each P*S;
  fill:S & 0|(r-0^prev each cv)%P;
  (sum each fill; r<=1e-9+last each cv)}
proceedsV:{[P;S;x] sum each P*S & 0|x-0^prev each sums each S}

/ a = (askP list; askQ list; bestBid list), q and fd atoms
directV:{[a;q;fd]
  g:roundUp[q%1-fd; STEP_BTC];
  c:buyCostV[a 0; a 1; g];
  ex:(g*1-fd)-q;
  `cost`ok!(c[0]-ex*a 2; c 1)}
/ b = (askP; askQ) BTCUSDT ; u = (bidP; bidQ; bestAsk) USDCUSDT ; bb = BTCUSDC best bid list
indirectV:{[b;u;bb;q;fb;fs]
  g:roundUp[q%1-fb; STEP_BTC];
  c:buyCostV[b 0; b 1; g];
  r:c[0]%1-fs;
  x:sellForV[u 0; u 1; r];
  xr:roundUp[x 0; STEP_USDC];
  okx:xr<=1e-9+sum each u 1;
  left:((1-fs)*proceedsV[u 0; u 1; xr])-c 0;
  ex:(g*1-fb)-q;
  `cost`ok`usdcSold`leftUsdt!(xr-(left%u 2)+ex*bb; (c 1)&(x 1)&okx; xr; left)}
