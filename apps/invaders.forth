( Space Invaders - Levels version )
( Controls: h=left l=right x=fire q=quit )
( Up to 12 aliens in 3 rows of 4 )

( Ship )
"do-erase-ship" [ 32 0 {px} @ 23 screen-char ] define
"do-draw-ship" [ 94 10 {px} @ 23 screen-char ] define

( HUD )
"show-score" [ 83 14 0 0 screen-char 99 14 1 0 screen-char 111 14 2 0 screen-char 114 14 3 0 screen-char 101 14 4 0 screen-char 58 14 5 0 screen-char {score} @ 48 + 15 7 0 screen-char ] define
"show-level" [ 76 14 10 0 screen-char 118 14 11 0 screen-char 58 14 12 0 screen-char {level} @ 48 + 15 14 0 screen-char ] define
"show-hud" [ show-score show-level ] define

( Draw rows )
"draw-r0" [
  {alive} @ 1 and if 87 14 {gx} @ {gy} @ screen-char then
  {alive} @ 2 and if 87 14 {gx} @ 8 + {gy} @ screen-char then
  {alive} @ 4 and if 87 14 {gx} @ 16 + {gy} @ screen-char then
  {alive} @ 8 and if 87 14 {gx} @ 24 + {gy} @ screen-char then
] define

"draw-r1" [
  {alive} @ 16 and if 77 13 {gx} @ {gy} @ 2 + screen-char then
  {alive} @ 32 and if 77 13 {gx} @ 8 + {gy} @ 2 + screen-char then
  {alive} @ 64 and if 77 13 {gx} @ 16 + {gy} @ 2 + screen-char then
  {alive} @ 128 and if 77 13 {gx} @ 24 + {gy} @ 2 + screen-char then
] define

"draw-r2" [
  {alive} @ 256 and if 86 12 {gx} @ {gy} @ 4 + screen-char then
  {alive} @ 512 and if 86 12 {gx} @ 8 + {gy} @ 4 + screen-char then
  {alive} @ 1024 and if 86 12 {gx} @ 16 + {gy} @ 4 + screen-char then
  {alive} @ 2048 and if 86 12 {gx} @ 24 + {gy} @ 4 + screen-char then
] define

( Erase rows )
"erase-r0" [
  {alive} @ 1 and if 32 0 {gx} @ {gy} @ screen-char then
  {alive} @ 2 and if 32 0 {gx} @ 8 + {gy} @ screen-char then
  {alive} @ 4 and if 32 0 {gx} @ 16 + {gy} @ screen-char then
  {alive} @ 8 and if 32 0 {gx} @ 24 + {gy} @ screen-char then
] define

"erase-r1" [
  {alive} @ 16 and if 32 0 {gx} @ {gy} @ 2 + screen-char then
  {alive} @ 32 and if 32 0 {gx} @ 8 + {gy} @ 2 + screen-char then
  {alive} @ 64 and if 32 0 {gx} @ 16 + {gy} @ 2 + screen-char then
  {alive} @ 128 and if 32 0 {gx} @ 24 + {gy} @ 2 + screen-char then
] define

"erase-r2" [
  {alive} @ 256 and if 32 0 {gx} @ {gy} @ 4 + screen-char then
  {alive} @ 512 and if 32 0 {gx} @ 8 + {gy} @ 4 + screen-char then
  {alive} @ 1024 and if 32 0 {gx} @ 16 + {gy} @ 4 + screen-char then
  {alive} @ 2048 and if 32 0 {gx} @ 24 + {gy} @ 4 + screen-char then
] define

"draw-aliens" [ draw-r0 draw-r1 draw-r2 ] define
"erase-aliens" [ erase-r0 erase-r1 erase-r2 ] define

( Movement state machine: state 0=horizontal, 1=descend )
( Horizontal move - check if edge reached, set state=1 if so )
"move-horiz" [
  erase-aliens
  {gx} @ {dir} @ + {gx} !
  {gx} @ 54 > if 54 {gx} ! 1 {ms} ! then
  {gx} @ 1 < if 1 {gx} ! 1 {ms} ! then
  draw-aliens
] define

( Descend one row, reverse direction, resume horizontal )
"move-descend" [
  erase-aliens
  {gy} @ 1 + {gy} !
  0 {dir} @ - {dir} !
  0 {ms} !
  draw-aliens
] define

( Bullet )
"can-fire?" [ {k} @ 120 = {bf} @ 0 = and ] define
"do-fire" [ {px} @ {bx} ! 21 {by} ! 1 {bf} ! 0 {bt} ! 124 15 {bx} @ {by} @ screen-char ] define
"do-move-bullet" [ 32 0 {bx} @ {by} @ screen-char {by} @ 1 - {by} ! 124 15 {bx} @ {by} @ screen-char ] define

( Hit detection - row 0 )
"hit0?" [ {bx} @ {gx} @ = {by} @ {gy} @ = and {alive} @ 1 and and {bf} @ 1 = and ] define
"hit1?" [ {bx} @ {gx} @ 8 + = {by} @ {gy} @ = and {alive} @ 2 and and {bf} @ 1 = and ] define
"hit2?" [ {bx} @ {gx} @ 16 + = {by} @ {gy} @ = and {alive} @ 4 and and {bf} @ 1 = and ] define
"hit3?" [ {bx} @ {gx} @ 24 + = {by} @ {gy} @ = and {alive} @ 8 and and {bf} @ 1 = and ] define
( Hit detection - row 1 )
"hit4?" [ {bx} @ {gx} @ = {by} @ {gy} @ 2 + = and {alive} @ 16 and and {bf} @ 1 = and ] define
"hit5?" [ {bx} @ {gx} @ 8 + = {by} @ {gy} @ 2 + = and {alive} @ 32 and and {bf} @ 1 = and ] define
"hit6?" [ {bx} @ {gx} @ 16 + = {by} @ {gy} @ 2 + = and {alive} @ 64 and and {bf} @ 1 = and ] define
"hit7?" [ {bx} @ {gx} @ 24 + = {by} @ {gy} @ 2 + = and {alive} @ 128 and and {bf} @ 1 = and ] define
( Hit detection - row 2 )
"hit8?" [ {bx} @ {gx} @ = {by} @ {gy} @ 4 + = and {alive} @ 256 and and {bf} @ 1 = and ] define
"hit9?" [ {bx} @ {gx} @ 8 + = {by} @ {gy} @ 4 + = and {alive} @ 512 and and {bf} @ 1 = and ] define
"hit10?" [ {bx} @ {gx} @ 16 + = {by} @ {gy} @ 4 + = and {alive} @ 1024 and and {bf} @ 1 = and ] define
"hit11?" [ {bx} @ {gx} @ 24 + = {by} @ {gy} @ 4 + = and {alive} @ 2048 and and {bf} @ 1 = and ] define

( Kill helpers )
"kill0" [ {alive} @ 1 xor {alive} ! ] define
"kill1" [ {alive} @ 2 xor {alive} ! ] define
"kill2" [ {alive} @ 4 xor {alive} ! ] define
"kill3" [ {alive} @ 8 xor {alive} ! ] define
"kill4" [ {alive} @ 16 xor {alive} ! ] define
"kill5" [ {alive} @ 32 xor {alive} ! ] define
"kill6" [ {alive} @ 64 xor {alive} ! ] define
"kill7" [ {alive} @ 128 xor {alive} ! ] define
"kill8" [ {alive} @ 256 xor {alive} ! ] define
"kill9" [ {alive} @ 512 xor {alive} ! ] define
"kill10" [ {alive} @ 1024 xor {alive} ! ] define
"kill11" [ {alive} @ 2048 xor {alive} ! ] define

"do-kill-common" [ 0 {bf} ! 32 0 {bx} @ {by} @ screen-char {score} @ 1 + {score} ! show-score ] define

"check-hits-r01" [
  hit0? if kill0 do-kill-common then
  hit1? if kill1 do-kill-common then
  hit2? if kill2 do-kill-common then
  hit3? if kill3 do-kill-common then
  hit4? if kill4 do-kill-common then
  hit5? if kill5 do-kill-common then
  hit6? if kill6 do-kill-common then
  hit7? if kill7 do-kill-common then
] define

"check-hits-r2" [
  hit8? if kill8 do-kill-common then
  hit9? if kill9 do-kill-common then
  hit10? if kill10 do-kill-common then
  hit11? if kill11 do-kill-common then
] define

"check-hits" [ check-hits-r01 check-hits-r2 ] define

( Celebration )
"celebrate" [
  screen-clear
  76 10 35 10 screen-char
  69 10 36 10 screen-char
  86 10 37 10 screen-char
  69 10 38 10 screen-char
  76 10 39 10 screen-char
  {level} @ 48 + 14 41 10 screen-char
  33 10 42 10 screen-char
  42 14 33 12 screen-char 42 14 37 12 screen-char
  42 14 41 12 screen-char 42 14 45 12 screen-char
  42 14 35 8 screen-char 42 14 39 8 screen-char 42 14 43 8 screen-char
  0 begin 1 + dup 800000 > until drop
  screen-clear
] define

( Next level )
"next-level" [
  {level} @ 1 + {level} !
  {speed} @ 8000 - {speed} !
  {speed} @ 5000 < if 5000 {speed} ! then
  {level} @ 2 < if 255 {alive} ! then
  {level} @ 1 > if 4095 {alive} ! then
  15 {gx} !
  3 {gy} !
  1 {dir} !
  0 {ms} !
  0 {bf} !
  celebrate
  show-hud
  do-draw-ship
  draw-aliens
] define

( Tick handler - avoids nested if/then in main loop )
"do-tick" [ 0 {t} ! {ms} @ 0 = if move-horiz then {ms} @ 1 = if move-descend then ] define

"invaders" [
  screen-clear
  cursor-hide
  40 {px} !
  15 {gx} !
  3 {gy} !
  1 {dir} !
  1 {run} !
  0 {t} !
  0 {bt} !
  0 {bx} !
  21 {by} !
  0 {bf} !
  0 {score} !
  1 {level} !
  30000 {speed} !
  255 {alive} !
  0 {ms} !

  show-hud
  do-draw-ship
  draw-aliens

  begin {run} @ while
    key? {k} !
    {k} @ 113 = if 0 {run} ! then
    {k} @ 108 = if do-erase-ship {px} @ 1 + {px} ! do-draw-ship then
    {k} @ 104 = if do-erase-ship {px} @ 1 - {px} ! do-draw-ship then
    can-fire? if do-fire then
    {bf} @ 1 = if {bt} @ 1 + {bt} ! then
    {bt} @ 6000 > if 0 {bt} ! do-move-bullet then
    {by} @ 2 < if 0 {bf} ! 32 0 {bx} @ {by} @ screen-char then
    check-hits
    {alive} @ 0 = if next-level then
    {t} @ 1 + {t} !
    {t} @ {speed} @ > if do-tick then
    {gy} @ 19 > if 0 {run} ! then
  repeat
  cursor-show
  screen-clear
  "Final score: " type {score} @ . cr
] define
