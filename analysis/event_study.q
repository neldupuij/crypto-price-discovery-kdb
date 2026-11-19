/ ============================================================
/ analysis/event_study.q
/ Event study: when one market makes a big jump,
/ how (and how fast) does the other market follow?
/ --
/ Run from the project folder:  q analysis/event_study.q
/ or in VS Code: Cmd+Shift+D (whole file) / Cmd+D (line by line)
/ Output: results/event_perp_jumps.csv, results/event_spot_jumps.csv
/ ============================================================

root:system "cd"
\l data/hdb

day:2026.11.08


/ ------------------------------------------------------------
/ STEP 1. Prices every 10 ms (same method as leadlag.q)
/ ------------------------------------------------------------

step:0D00:00:00.01                                   / 10 ms
grid:([] time:(day+0D)+step*til `long$1D%step)      / 8 640 000 points

onGrid:{[v] exec price from aj[`time; grid; select time, price from trade where date=day, venue=v]}
pPerp:onGrid`BINANCE_PERP
pSpot:onGrid`BINANCE_SPOT

/ Returns in basis points (1 bp = 0.01% ; on BTC at 75 000 $, 1 bp = 7.5 $)
bps:{0^ 1e4*log x % prev x}
rPerp:bps pPerp
rSpot:bps pSpot


/ ------------------------------------------------------------
/ STEP 2. Find the "events" = big jumps
/ ------------------------------------------------------------
/ An event = a 10 ms step where the price moves by more than 3 bp (~22 $).
/ To keep events independent, we keep a jump only if the previous kept
/ jump on that market is at least 1 second (100 steps) earlier.

threshold:3                                          / in bp
gap:100                                              / 100 steps = 1 s

/ positions of all big jumps
findJumps:{[r] where threshold<abs r}

/ keep only jumps at least `gap` steps after the previous kept one
/ (a small loop: {...}/ goes through the list once)
spaced:{[idx] {[kept;i] $[(i-last kept)>=gap; kept,i; kept]}/[enlist first idx; 1_idx]}

evPerp:spaced findJumps rPerp
evSpot:spaced findJumps rSpot
count evPerp                                         / number of perp jumps
count evSpot                                         / number of spot jumps


/ ------------------------------------------------------------
/ STEP 3. Average path of both prices around the events
/ ------------------------------------------------------------
/ For each event at step i, with direction s (+1 up, -1 down):
/   move(k) = s * (price[i+k] / price[i-1] - 1), in bp
/ for k from -20 (200 ms before) to +100 (1 s after).
/ Multiplying by s puts up-jumps and down-jumps on the same side.
/ Then we average over all events.

ks:-20+til 121                                       / -200 ms .. +1 000 ms

/ path[p; ev; s] -> one row per event, one column per k
path:{[p;ev;s] s * 1e4 * -1 + p[ev +\: ks] % p ev-1}

/ average path of BOTH markets around the jumps of one market
eventStudy:{[ev;r]
  ev:ev where (ev>20) & ev<count[r]-100;             / drop events too close to the edges
  s:signum r ev;                                     / direction of each jump
  mPerp:avg path[pPerp; ev; s];                      / avg over events, for each k
  mSpot:avg path[pSpot; ev; s];
  ([] lagms:10*ks; perp:mPerp; spot:mSpot)
  }

perpJumps:eventStudy[evPerp; rPerp]                  / the perp jumps: does the spot follow?
spotJumps:eventStudy[evSpot; rSpot]                  / the spot jumps: does the perp follow?

/ Look around the jump
select from perpJumps where lagms within -30 100
select from spotJumps where lagms within -30 100


/ ------------------------------------------------------------
/ STEP 4. Summary numbers
/ ------------------------------------------------------------
/ How long until the follower has covered 50% / 90% of the leader's move?
/ The leader's move is measured at +1 s.

catchUp:{[t;leader;follower;pct]
  target:pct * last t leader;
  l:t`lagms; f:t follower;
  first l where (l>=0) & f>=target
  }

/ Text for a catch-up time (null = never reached within 1 s)
msTxt:{$[null x;"never within 1 s";string[x]," ms"]}

-1 "";
-1 "PERP jumps: ",string[count evPerp]," events";
-1 "  perp move after 1 s: ",string[last perpJumps`perp]," bp";
-1 "  spot move after 1 s: ",string[last perpJumps`spot]," bp";
-1 "  spot reaches 50% of the perp move: ",msTxt catchUp[perpJumps;`perp;`spot;0.5];
-1 "  spot reaches 90% of the perp move: ",msTxt catchUp[perpJumps;`perp;`spot;0.9];
-1 "  spot move in the 200 ms BEFORE the perp jump: ",string[neg first perpJumps`spot]," bp";
-1 "";
-1 "SPOT jumps: ",string[count evSpot]," events";
-1 "  spot move after 1 s: ",string[last spotJumps`spot]," bp";
-1 "  perp move after 1 s: ",string[last spotJumps`perp]," bp";
-1 "  perp reaches 50% of the spot move: ",msTxt catchUp[spotJumps;`spot;`perp;0.5];
-1 "  perp reaches 90% of the spot move: ",msTxt catchUp[spotJumps;`spot;`perp;0.9];
-1 "  perp move in the 200 ms BEFORE the spot jump: ",string[neg first spotJumps`perp]," bp";
-1 "  -> before a spot jump, the perp has often ALREADY moved: the spot is catching up.";


/ ------------------------------------------------------------
/ STEP 5. Save for the chart
/ ------------------------------------------------------------

save1:{[name;t] (hsym `$root,"/results/",name) 0: csv 0: t}
save1["event_perp_jumps.csv"; perpJumps]
save1["event_spot_jumps.csv"; spotJumps]
-1 "Saved results/event_perp_jumps.csv and results/event_spot_jumps.csv";
