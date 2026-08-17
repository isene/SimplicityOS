( Snake Game for SimplicityOS )
( Controls: h/j/k/l or arrow keys to move, q to quit )

( --- Variables --- )
0 {s-buf} !
0 {s-grid} !
0 {s-head} !
0 {s-tail} !
0 {s-dir} !
0 {s-fx} !
0 {s-fy} !
0 {s-score} !
0 {s-run} !
0 {s-dead} !
0 {s-t} !
0 {s-speed} !
0 {s-k} !
0 {s-nx} !
0 {s-ny} !
0 {s-rng} !
0 {s-gc} !
0 {s-px} !
0 {s-py} !
0 {s-i} !
0 {s-hy} !
0 {s-vx} !

( --- Grid: 80x25 cells, 0=empty 1=wall 2=snake 3=food --- )
"s-grid@" [ 80 * + {s-grid} @ + c@ ] define
"s-grid!" [ 80 * + {s-grid} @ + c! ] define

( --- Ring buffer: max 400 segments, 2 bytes each --- )
"s-bx@" [ 2 * {s-buf} @ + c@ ] define
"s-by@" [ 2 * 1 + {s-buf} @ + c@ ] define
"s-bset" [ 2 * {s-buf} @ + dup rot swap 1 + c! c! ] define
"s-wrap" [ dup 400 >= if 400 - then ] define

( --- Pseudo-random number generator --- )
"s-next-rng" [ {s-rng} @ 31421 * 6927 + 65536 mod dup {s-rng} ! ] define
"s-rand-x" [ s-next-rng 78 mod 1 + ] define
"s-rand-y" [ s-next-rng 22 mod 1 + ] define

( --- Drawing helpers --- )
"s-put-wall" [
  {s-py} ! {s-px} !
  1 {s-px} @ {s-py} @ s-grid!
  35 8 {s-px} @ {s-py} @ screen-char
] define

"s-put-body" [
  {s-py} ! {s-px} !
  2 {s-px} @ {s-py} @ s-grid!
  111 2 {s-px} @ {s-py} @ screen-char
] define

"s-put-head" [
  {s-py} ! {s-px} !
  2 {s-px} @ {s-py} @ s-grid!
  64 10 {s-px} @ {s-py} @ screen-char
] define

"s-clear" [
  {s-py} ! {s-px} !
  0 {s-px} @ {s-py} @ s-grid!
  32 0 {s-px} @ {s-py} @ screen-char
] define

( --- Border drawing --- )
"s-draw-hline" [
  {s-hy} !
  0 {s-i} !
  begin {s-i} @ 80 < while
    {s-i} @ {s-hy} @ s-put-wall
    {s-i} @ 1 + {s-i} !
  repeat
] define

"s-draw-vline" [
  {s-vx} !
  0 {s-i} !
  begin {s-i} @ 24 < while
    {s-vx} @ {s-i} @ s-put-wall
    {s-i} @ 1 + {s-i} !
  repeat
] define

"s-draw-borders" [
  0 s-draw-hline
  23 s-draw-hline
  0 s-draw-vline
  79 s-draw-vline
] define

( --- Initialization --- )
"s-init-grid" [
  {s-grid} @ 0 = if 2000 allot {s-grid} ! then
  0 {s-i} !
  begin {s-i} @ 2000 < while
    0 {s-i} @ {s-grid} @ + c!
    {s-i} @ 1 + {s-i} !
  repeat
] define

"s-init-buf" [
  {s-buf} @ 0 = if 800 allot {s-buf} ! then
] define

"s-init-snake" [
  0 {s-dir} !
  0 {s-score} !
  0 {s-dead} !
  30000 {s-speed} !
  0 {s-t} !
  38 12 0 s-bset
  39 12 1 s-bset
  40 12 2 s-bset
  0 {s-tail} !
  2 {s-head} !
  38 12 s-put-body
  39 12 s-put-body
  40 12 s-put-head
] define

( --- Food placement at random empty cell --- )
"s-place-food" [
  begin
    s-rand-x {s-fx} !
    s-rand-y {s-fy} !
    {s-fx} @ {s-fy} @ s-grid@ 0 =
  until
  3 {s-fx} @ {s-fy} @ s-grid!
  42 12 {s-fx} @ {s-fy} @ screen-char
] define

( --- Score display on row 24 --- )
"s-draw-score" [
  83 15 2 24 screen-char
  99 15 3 24 screen-char
  111 15 4 24 screen-char
  114 15 5 24 screen-char
  101 15 6 24 screen-char
  58 15 7 24 screen-char
  32 15 8 24 screen-char
  {s-score} @ 100 / 48 + 15 9 24 screen-char
  {s-score} @ 10 / 10 mod 48 + 15 10 24 screen-char
  {s-score} @ 10 mod 48 + 15 11 24 screen-char
] define

( --- Key handling with 180-degree turn prevention --- )
"s-handle-key" [
  key? {s-k} !
  {s-k} @ 104 = {s-dir} @ 0 <> and if 2 {s-dir} ! then
  {s-k} @ 108 = {s-dir} @ 2 <> and if 0 {s-dir} ! then
  {s-k} @ 107 = {s-dir} @ 1 <> and if 3 {s-dir} ! then
  {s-k} @ 106 = {s-dir} @ 3 <> and if 1 {s-dir} ! then
  {s-k} @ key-left  = {s-dir} @ 0 <> and if 2 {s-dir} ! then
  {s-k} @ key-right = {s-dir} @ 2 <> and if 0 {s-dir} ! then
  {s-k} @ key-up    = {s-dir} @ 1 <> and if 3 {s-dir} ! then
  {s-k} @ key-down  = {s-dir} @ 3 <> and if 1 {s-dir} ! then
  {s-k} @ 113 = if 0 {s-run} ! then
] define

( --- Movement --- )
"s-calc-new" [
  {s-head} @ s-bx@ {s-nx} !
  {s-head} @ s-by@ {s-ny} !
  {s-dir} @ 0 = if {s-nx} @ 1 + {s-nx} ! then
  {s-dir} @ 1 = if {s-ny} @ 1 + {s-ny} ! then
  {s-dir} @ 2 = if {s-nx} @ 1 - {s-nx} ! then
  {s-dir} @ 3 = if {s-ny} @ 1 - {s-ny} ! then
] define

"s-move" [
  s-calc-new
  {s-nx} @ {s-ny} @ s-grid@ {s-gc} !
  {s-gc} @ 1 = {s-gc} @ 2 = or if
    0 {s-run} !
    1 {s-dead} !
  else
    {s-head} @ s-bx@ {s-head} @ s-by@ s-put-body
    {s-head} @ 1 + s-wrap {s-head} !
    {s-nx} @ {s-ny} @ {s-head} @ s-bset
    {s-nx} @ {s-ny} @ s-put-head
    {s-gc} @ 3 = if
      {s-score} @ 1 + {s-score} !
      {s-speed} @ 3000 > if {s-speed} @ 1000 - {s-speed} ! then
      s-place-food
      s-draw-score
    else
      {s-tail} @ s-bx@ {s-tail} @ s-by@ s-clear
      {s-tail} @ 1 + s-wrap {s-tail} !
    then
  then
] define

( --- Game loop --- )
"s-loop" [
  begin {s-run} @ while
    s-handle-key
    {s-t} @ 1 + {s-t} !
    {s-t} @ {s-speed} @ > if
      0 {s-t} !
      s-move
    then
  repeat
] define

( --- Game over display --- )
"s-game-over" [
  71 12 35 12 screen-char
  65 12 36 12 screen-char
  77 12 37 12 screen-char
  69 12 38 12 screen-char
  32 0 39 12 screen-char
  79 12 40 12 screen-char
  86 12 41 12 screen-char
  69 12 42 12 screen-char
  82 12 43 12 screen-char
  begin key? until
] define

( --- Title screen: seeds RNG from keypress timing --- )
"s-title" [
  83 14 37 11 screen-char
  78 14 38 11 screen-char
  65 14 39 11 screen-char
  75 14 40 11 screen-char
  69 14 41 11 screen-char
  0 begin 1 + key? until {s-rng} !
  32 0 37 11 screen-char
  32 0 38 11 screen-char
  32 0 39 11 screen-char
  32 0 40 11 screen-char
  32 0 41 11 screen-char
] define

( --- Main entry point --- )
"snake" [
  app-enter
  screen-clear
  s-init-grid
  s-init-buf
  s-draw-borders
  s-title
  s-init-snake
  1 {s-run} !
  s-place-food
  s-draw-score
  s-loop
  {s-dead} @ if s-game-over then
  screen-clear
  0 0 screen-set
  app-exit
] define
