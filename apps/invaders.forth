( Space Invaders - Simple version for Simplicity OS )

( ===== Constants ===== )
"player-row" [ 22 ] define
"color-green" [ 10 ] define
"color-cyan" [ 11 ] define
"color-yellow" [ 14 ] define
"color-white" [ 15 ] define

( ===== Variables ===== )
0 {player-x} !
0 {score} !
3 {lives} !
0 {bullet-x} !
0 {bullet-y} !
0 {bullet-active} !
0 {game-running} !

( ===== Drawing ===== )
"draw-char" [ screen-char ] define

"draw-player" [
  65 color-green {player-x} @ player-row draw-char
] define

"erase-at" [
  32 0 rot rot draw-char
] define

"draw-score-line" [
  83 color-white 2 0 draw-char
  67 color-white 3 0 draw-char
  79 color-white 4 0 draw-char
  82 color-white 5 0 draw-char
  69 color-white 6 0 draw-char
  58 color-white 7 0 draw-char
] define

"draw-aliens-row" [
  77 color-cyan 20 3 draw-char
  77 color-cyan 26 3 draw-char
  77 color-cyan 32 3 draw-char
  77 color-cyan 38 3 draw-char
  77 color-cyan 44 3 draw-char
  77 color-cyan 50 3 draw-char
  77 color-cyan 56 3 draw-char
  87 color-yellow 20 5 draw-char
  87 color-yellow 26 5 draw-char
  87 color-yellow 32 5 draw-char
  87 color-yellow 38 5 draw-char
  87 color-yellow 44 5 draw-char
  87 color-yellow 50 5 draw-char
  87 color-yellow 56 5 draw-char
] define

"draw-bullet" [
  {bullet-active} @ if
    124 color-white {bullet-x} @ {bullet-y} @ draw-char
  then
] define

"draw-game" [
  draw-score-line
  draw-aliens-row
  draw-player
  draw-bullet
] define

( ===== Input ===== )
"move-left" [
  {player-x} @ 1 > if
    {player-x} @ player-row erase-at
    {player-x} @ 1 - {player-x} !
  then
] define

"move-right" [
  {player-x} @ 78 < if
    {player-x} @ player-row erase-at
    {player-x} @ 1 + {player-x} !
  then
] define

"fire" [
  {bullet-active} @ 0 = if
    {player-x} @ {bullet-x} !
    player-row 1 - {bullet-y} !
    1 {bullet-active} !
  then
] define

"update-bullet" [
  {bullet-active} @ if
    {bullet-x} @ {bullet-y} @ erase-at
    {bullet-y} @ 1 - {bullet-y} !
    {bullet-y} @ 1 < if 0 {bullet-active} ! then
  then
] define

"handle-key" [
  key
  dup key-left = if move-left then
  dup key-right = if move-right then
  dup 104 = if move-left then
  dup 108 = if move-right then
  dup 32 = if fire then
  dup 113 = if 0 {game-running} ! then
  drop
] define

( ===== Game Loop ===== )
"game-step" [
  key? if handle-key then
  update-bullet
  draw-game
] define

"game-loop" [
  1 {game-running} !
  begin
    game-step
    {game-running} @
  while repeat
] define

( ===== Entry Point ===== )
"invaders" [
  screen-clear
  40 {player-x} !
  0 {score} !
  0 {bullet-active} !
  draw-game
  game-loop
  screen-clear
] define
