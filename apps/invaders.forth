( Space Invaders )
( Controls: h/l or arrows move, x or space fires, q quits )
( 18 aliens in 3 rows of 6, tracked as bits 0-17 of {alive} )
( Alien index i: column = i mod 6, row = i / 6; row 0 is the top )

( --- helpers --- )
"pow2" [ 1 swap begin dup 0 > while swap 2 * swap 1 - repeat drop ] define
"absv" [ dup 0 < if 0 swap - then ] define

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
  {by} @ 1 < if 0 {bf} ! else 124 14 {bx} @ {by} @ screen-char check-hit then
] define

"bullet-tick" [ {bf} @ 1 = if move-bullet then ] define

( --- alien bomb: alternates aimed-at-ship and round-robin --- )
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
  {vn} @ 2 mod 0 = if aim-bomber else next-bomber then
] define

"erase-bomb" [ 32 0 {vx} @ {vy} @ screen-char ] define
"do-bomb" [ pick-bomber {vi} @ ax {vx} ! {gy} @ 6 + {vy} ! 1 {vf} ! 33 12 {vx} @ {vy} @ screen-char ] define

"ship-hit" [
  {lives} @ 1 - {lives} !
  0 {vf} ! 6 {vd} ! erase-bomb
  draw-boom show-hud
  0 begin 1 + dup 3000000 > until drop
  erase-ship 40 {px} ! draw-ship
  {lives} @ 1 < if 0 {run} ! then
] define

"check-ship" [ {vy} @ 23 = {vx} @ {px} @ - absv 2 < and if ship-hit then ] define

"move-bomb" [
  erase-bomb
  {vy} @ 1 + {vy} !
  {vy} @ 23 > if 0 {vf} ! 5 {vd} ! draw-ship else 33 12 {vx} @ {vy} @ screen-char check-ship then
] define

"maybe-bomb" [ {nalive} @ 0 > if do-bomb then ] define
"bomb-wait" [ {vd} @ 0 > if {vd} @ 1 - {vd} ! else maybe-bomb then ] define
"bomb-tick" [ {vf} @ 1 = if move-bomb then {vf} @ 0 = if bomb-wait then ] define

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
  0 {bf} ! 0 {vf} ! 8 {vd} !
  speed-set
  celebrate
  show-hud draw-ship draw-aliens
] define

( --- input --- )
( Arrows arrive two ways: scancode constants, or ANSI ESC [ D/C/A )
( character sequences under QEMU's curses display )
"left?" [ {k} @ 104 = {k} @ key-left = or {k} @ 68 = or ] define
"right?" [ {k} @ 108 = {k} @ key-right = or {k} @ 67 = or ] define
"fire?" [ {k} @ 120 = {k} @ 32 = or {k} @ 65 = or {k} @ key-up = or {bf} @ 0 = and ] define

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
  0 {bf} ! 0 {vf} ! 8 {vd} ! 0 {vi} ! 0 {vn} !
  0 {t} ! 0 {bt} ! 0 {vt} ! 1 {run} !
  speed-set
  show-hud draw-ship draw-aliens

  begin {run} @ while
    key? {k} !
    {k} @ 113 = if 0 {run} ! then
    left? {px} @ 2 > and if erase-ship {px} @ 1 - {px} ! draw-ship then
    right? {px} @ 77 < and if erase-ship {px} @ 1 + {px} ! draw-ship then
    fire? if do-fire then
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
