( Space Invaders - Complete Game )
( Controls: h=left l=right x=fire q=quit )

( Ship helpers )
"do-erase-ship" [ 32 0 {px} @ 22 screen-char ] define
"do-draw-ship" [ 94 10 {px} @ 22 screen-char ] define

( Alien movement with boundary handling built in )
"do-bounce-right" [ 32 0 {ax} @ {ay} @ screen-char 78 {ax} ! -1 {dir} ! {ay} @ 1 + {ay} ! 87 14 {ax} @ {ay} @ screen-char ] define
"do-bounce-left" [ 32 0 {ax} @ {ay} @ screen-char 1 {ax} ! 1 {dir} ! {ay} @ 1 + {ay} ! 87 14 {ax} @ {ay} @ screen-char ] define
"do-move-alien" [ 32 0 {ax} @ {ay} @ screen-char {ax} @ {dir} @ + {ax} ! 87 14 {ax} @ {ay} @ screen-char ] define

( Bullet helpers )
"can-fire?" [ {k} @ 120 = {bf} @ 0 = and ] define
"do-fire" [ {px} @ {bx} ! 20 {by} ! 1 {bf} ! 0 {bt} ! 124 15 {bx} @ {by} @ screen-char ] define
"do-move-bullet" [ 32 0 {bx} @ {by} @ screen-char {by} @ 1 - {by} ! 124 15 {bx} @ {by} @ screen-char ] define

( Collision )
"hit?" [ {bx} @ {ax} @ = {by} @ {ay} @ = and {bf} @ 1 = and ] define
"do-kill" [ 0 {bf} ! 32 0 {bx} @ {by} @ screen-char 32 0 {ax} @ {ay} @ screen-char {score} @ 1 + {score} ! 10 {ax} ! 3 {ay} ! 1 {dir} ! 87 14 {ax} @ {ay} @ screen-char ] define

"invaders" [
  screen-clear
  40 {px} !
  10 {ax} !
  3 {ay} !
  1 {dir} !
  1 {run} !
  0 {t} !
  0 {bt} !
  0 {bx} !
  20 {by} !
  0 {bf} !
  0 {score} !

  do-draw-ship
  87 14 {ax} @ {ay} @ screen-char

  begin {run} @ while
    key? {k} !
    {k} @ 113 = if 0 {run} ! then
    {k} @ 108 = if do-erase-ship {px} @ 1 + {px} ! do-draw-ship then
    {k} @ 104 = if do-erase-ship {px} @ 1 - {px} ! do-draw-ship then
    can-fire? if do-fire then
    {bf} @ 1 = if {bt} @ 1 + {bt} ! then
    {bt} @ 300 > if 0 {bt} ! do-move-bullet then
    {by} @ 1 < if 0 {bf} ! 32 0 {bx} @ {by} @ screen-char then
    hit? if do-kill then
    {t} @ 1 + {t} !
    {t} @ 30000 > if 0 {t} ! do-move-alien then
    {ax} @ 78 > if do-bounce-right then
    {ax} @ 1 < if do-bounce-left then
    {ay} @ 20 > if 0 {run} ! then
  repeat
  screen-clear
  {score} @ . " aliens destroyed!" type cr
] define
