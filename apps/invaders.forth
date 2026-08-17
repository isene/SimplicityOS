( Space Invaders )
( Controls: h/l or arrows move, x or space fires, q quits )
( 18 aliens in 3 rows of 6, tracked as bits 0-17 of {alive} )
( Alien index i: column = i mod 6, row = i / 6; row 0 is the top )
( Up to 3 alien bombs in the air; 4 shields that shots erode )

( --- helpers --- )
"pow2" [ 1 swap begin dup 0 > while swap 2 * swap 1 - repeat drop ] define
"absv" [ dup 0 < if 0 swap - then ] define

( read the character at x y straight from VGA memory )
"cell@" [ 80 * + 2 * 753664 + c@ ] define

( Alien geometry: 6 columns spaced 6 apart, rows 2 apart )
"ax" [ 6 mod 6 * {gx} @ + ] define
"ay" [ 6 / 2 * {gy} @ + ] define
"alive?" [ pow2 {alive} @ and ] define

( Row 0: V magenta 30pts, row 1: M cyan 20pts, row 2: W green 10pts )
"aglyph" [ {r} ! 87 {r} @ 0 = if drop 86 then {r} @ 1 = if drop 77 then ] define
"acolor" [ {r} ! 10 {r} @ 0 = if drop 13 then {r} @ 1 = if drop 11 then ] define

( --- drawing --- )
"draw-alien" [ {i} @ 6 / aglyph {i} @ 6 / acolor {i} @ ax {i} @ ay screen-char ] define
"erase-alien" [ 32 0 {i} @ ax {i} @ ay screen-char ] define
"draw-aliens" [ 0 {i} ! begin {i} @ 18 < while {i} @ alive? if draw-alien then {i} @ 1 + {i} ! repeat ] define
"erase-aliens" [ 0 {i} ! begin {i} @ 18 < while {i} @ alive? if erase-alien then {i} @ 1 + {i} ! repeat ] define

( Shields: 4 bunkers of # on rows 20-21; the screen is the state )
( Bombs and bullets erode the cell they hit; aliens marching )
( through wipe cells as they pass )
"draw-bunker" [ {sx} ! 0 {si} ! begin {si} @ 6 < while
  35 10 {sx} @ {si} @ + 20 screen-char
  35 10 {sx} @ {si} @ + 21 screen-char
  {si} @ 1 + {si} ! repeat ] define
"draw-shields" [ 10 draw-bunker 28 draw-bunker 46 draw-bunker 64 draw-bunker ] define

"draw-ship" [ 47 15 {px} @ 1 - 23 screen-char 94 15 {px} @ 23 screen-char 92 15 {px} @ 1 + 23 screen-char ] define
"erase-ship" [ 32 0 {px} @ 1 - 23 screen-char 32 0 {px} @ 23 screen-char 32 0 {px} @ 1 + 23 screen-char ] define
"draw-boom" [ 42 14 {px} @ 1 - 23 screen-char 42 14 {px} @ 23 screen-char 42 14 {px} @ 1 + 23 screen-char ] define

( Lives shown as ship icons top right )
"life-icon" [ {s} ! {s} @ {lives} @ < if 94 15 else 32 0 then {s} @ 2 * 70 + 0 screen-char ] define
"show-lives" [ 0 life-icon 1 life-icon 2 life-icon ] define
"show-hud" [ 0 0 screen-set "Score " . {score} @ . "  Level " . {level} @ . show-lives ] define

( --- alien movement: state 0 = horizontal, 1 = descend --- )
"speed-set" [
  {nalive} @ 4000 * 8000 +
  {level} @ 1 - 6000 * - {speed} !
  {speed} @ 10000 < if 10000 {speed} ! then
] define

"move-horiz" [
  erase-aliens
  {gx} @ {dir} @ + {gx} !
  {gx} @ 43 > if 43 {gx} ! 1 {ms} ! then
  {gx} @ 1 < if 1 {gx} ! 1 {ms} ! then
  draw-aliens
] define

"move-descend" [
  erase-aliens
  {gy} @ 1 + {gy} !
  0 {dir} @ - {dir} !
  0 {ms} !
  draw-aliens
] define

( --- player bullet --- )
"erase-bullet" [ 32 0 {bx} @ {by} @ screen-char ] define
"do-fire" [ {px} @ {bx} ! 22 {by} ! 1 {bf} ! 124 14 {bx} @ {by} @ screen-char ] define

"do-kill" [
  {hi} @ pow2 {alive} @ xor {alive} !
  {nalive} @ 1 - {nalive} !
  0 {bf} ! erase-bullet
  32 0 {hi} @ ax {hi} @ ay screen-char
  30 {hi} @ 6 / 10 * - {score} @ + {score} !
  speed-set
  show-hud
] define

"try-kill" [
  {hy} @ 2 / 6 * {hx} @ 6 / + {hi} !
  {hi} @ alive? if do-kill then
] define

"check-hit" [
  {bx} @ {gx} @ - {hx} !
  {by} @ {gy} @ - {hy} !
  {hx} @ 0 >= {hx} @ 30 <= and {hx} @ 6 mod 0 = and
  {hy} @ 0 >= and {hy} @ 4 <= and {hy} @ 2 mod 0 = and
  if try-kill then
] define

"move-bullet" [
  erase-bullet
  {by} @ 1 - {by} !
  {by} @ 1 < if 0 {bf} ! else
    {bx} @ {by} @ cell@ 35 = if
      32 0 {bx} @ {by} @ screen-char 0 {bf} !
    else
      124 14 {bx} @ {by} @ screen-char check-hit
    then
  then
] define

"bullet-tick" [ {bf} @ 1 = if move-bullet then ] define

( --- alien bombs: up to 3 in the air, aimed or round-robin --- )
"next-bomber" [
  18 {j} !
  begin {j} @ 0 > while
    {vi} @ 1 + 18 mod {vi} !
    {j} @ 1 - {j} !
    {vi} @ alive? if 0 {j} ! then
  repeat
] define

"aim-one" [
  {j} @ ax {px} @ - absv {ad} !
  {ad} @ {bd} @ < if {ad} @ {bd} ! {j} @ {vi} ! then
] define

"aim-bomber" [
  99 {bd} !
  0 {j} !
  begin {j} @ 18 < while
    {j} @ alive? if aim-one then
    {j} @ 1 + {j} !
  repeat
] define

"pick-bomber" [
  {vn} @ 1 + {vn} !
  {vn} @ 3 mod 0 = if aim-bomber else next-bomber then
] define

( Bomb slot {j}: position and active flag live in 3-cell arrays )
"vbx" [ {vxa} @ {j} @ at ] define
"vby" [ {vya} @ {j} @ at ] define
"vbf" [ {vfa} @ {j} @ at ] define
"vb-draw" [ 33 12 vbx vby screen-char ] define
"vb-erase" [ 32 0 vbx vby screen-char ] define
"vb-off" [ 0 {vfa} @ {j} @ put ] define

"clear-bombs" [ 0 {j} ! begin {j} @ 3 < while
  vbf 1 = if vb-erase then vb-off {j} @ 1 + {j} ! repeat ] define

( clear-bombs leaves {j} at 3, so a move loop that called us )
( exits early; harmless since every bomb is gone )
"ship-hit" [
  {lives} @ 1 - {lives} !
  clear-bombs
  draw-boom show-hud
  0 begin 1 + dup 3000000 > until drop
  erase-ship 40 {px} ! draw-ship
  8 {vd} !
  {lives} @ 1 < if 0 {run} ! then
] define

"check-ship" [ vby 23 = vbx {px} @ - absv 2 < and if ship-hit then ] define

"move-bomb" [
  vb-erase
  vby 1 + {vya} @ {j} @ put
  vby 23 > if vb-off draw-ship else
    vbx vby cell@ 35 = if 32 0 vbx vby screen-char vb-off else
      vb-draw check-ship
    then
  then
] define

"move-bombs" [ 0 {j} ! begin {j} @ 3 < while
  vbf 1 = if move-bomb then {j} @ 1 + {j} ! repeat ] define

"free-slot" [ 9 {fs} ! 0 {j} ! begin {j} @ 3 < while
  vbf 0 = if {j} @ {fs} ! then {j} @ 1 + {j} ! repeat ] define

"do-bomb" [
  free-slot
  {fs} @ 9 < if
    pick-bomber
    {fs} @ {j} !
    {vi} @ ax {vxa} @ {j} @ put
    {gy} @ 6 + {vya} @ {j} @ put
    1 {vfa} @ {j} @ put
    vb-draw
  then
] define

( fire faster as aliens thin out )
"spawn-tick" [
  {vd} @ 0 > if {vd} @ 1 - {vd} ! else
    {nalive} @ 0 > if do-bomb 3 {nalive} @ 3 / + {vd} ! then
  then
] define

"bomb-tick" [ move-bombs spawn-tick ] define

( --- level flow --- )
"celebrate" [
  screen-clear
  33 11 screen-set "Wave cleared!" .
  0 begin 1 + dup 6000000 > until drop
  screen-clear
] define

"next-level" [
  {level} @ 1 + {level} !
  262143 {alive} ! 18 {nalive} !
  6 {gx} ! 2 {gy} ! 1 {dir} ! 0 {ms} !
  0 {bf} ! 8 {vd} !
  0 {vfa} @ 0 put 0 {vfa} @ 1 put 0 {vfa} @ 2 put
  speed-set
  celebrate
  show-hud draw-shields draw-ship draw-aliens
] define

( --- input --- )
( Arrows arrive two ways: scancode constants, or ANSI ESC [ D/C/A )
( character sequences under QEMU's curses display )
"left?" [ {k} @ 104 = {k} @ key-left = or {k} @ 68 = or ] define
"right?" [ {k} @ 108 = {k} @ key-right = or {k} @ 67 = or ] define
"fire?" [ {k} @ 120 = {k} @ 32 = or {k} @ 65 = or {k} @ key-up = or {bf} @ 0 = and ] define

( Repeats and buffered backlog are indistinguishable from a held )
( key; a gap over 4 ticks starts a new episode, and one episode )
( moves the ship at most 8 cells, so releases stop it )
"epcheck" [ ticks {nk} ! {nk} @ {lastk} @ - 4 > if 0 {ep} ! then {nk} @ {lastk} ! ] define

"do-tick" [
  {ms} @ 0 = if move-horiz then
  {ms} @ 1 = if move-descend then
  {bf} @ 1 = if check-hit then
] define

( --- main --- )
"invaders" [
  screen-clear cursor-hide
  40 {px} ! 6 {gx} ! 2 {gy} ! 1 {dir} ! 0 {ms} !
  262143 {alive} ! 18 {nalive} !
  0 {score} ! 3 {lives} ! 1 {level} !
  0 {bf} ! 8 {vd} ! 0 {vi} ! 0 {vn} !
  3 array {vxa} ! 3 array {vya} ! 3 array {vfa} !
  0 {vfa} @ 0 put 0 {vfa} @ 1 put 0 {vfa} @ 2 put
  0 {t} ! 0 {bt} ! 0 {vt} ! 0 {mv} ! 0 {mt} ! 1 {run} !
  0 {ep} ! ticks {lastk} !
  speed-set
  show-hud draw-shields draw-ship draw-aliens

  begin {run} @ while
    ( drain all pending keys; movement collapses to one intent, )
    ( applied at a capped rate, so buffered repeats cannot queue )
    begin key? {k} ! {k} @ 0 = not while
      {k} @ 113 = if 0 {run} ! then
      left? if epcheck 1 {mv} ! then
      right? if epcheck 2 {mv} ! then
      fire? if do-fire then
    repeat
    {mt} @ 0 > if {mt} @ 1 - {mt} ! then
    {mv} @ 1 = {mt} @ 0 = and if 0 {mv} ! {ep} @ 8 < if {ep} @ 1 + {ep} !
      {px} @ 2 > if erase-ship {px} @ 1 - {px} ! draw-ship then 16000 {mt} ! then then
    {mv} @ 2 = {mt} @ 0 = and if 0 {mv} ! {ep} @ 8 < if {ep} @ 1 + {ep} !
      {px} @ 77 < if erase-ship {px} @ 1 + {px} ! draw-ship then 16000 {mt} ! then then
    {bf} @ 1 = if {bt} @ 1 + {bt} ! then
    {bt} @ 3500 > if 0 {bt} ! bullet-tick then
    {vt} @ 1 + {vt} !
    {vt} @ 30000 > if 0 {vt} ! bomb-tick then
    {t} @ 1 + {t} !
    {t} @ {speed} @ > if 0 {t} ! do-tick then
    {nalive} @ 0 = if next-level then
    {gy} @ 18 > if 0 {run} ! then
  repeat

  screen-clear
  35 10 screen-set "GAME OVER" .
  30 12 screen-set "Final score: " . {score} @ .
  30 14 screen-set "Press any key" .
  key drop
  cursor-show screen-clear
] define
