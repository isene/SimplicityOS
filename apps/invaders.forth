( Space Invaders )

"can-fire?" [ {k} @ 120 = {bf} @ 0 = and ] define
"do-fire" [ {px} @ {bx} ! 20 {by} ! 1 {bf} ! 124 15 {bx} @ {by} @ screen-char ] define
"tick-bullet?" [ {t} @ 2000 > {bf} @ 1 = and ] define
"do-tick-bullet" [ 32 0 {bx} @ {by} @ screen-char {by} @ 1 - {by} ! 124 15 {bx} @ {by} @ screen-char ] define

"invaders" [
  screen-clear
  40 {px} !
  10 {ax} !
  3 {ay} !
  1 {dir} !
  1 {run} !
  0 {t} !
  0 {bx} !
  20 {by} !
  0 {bf} !

  94 10 {px} @ 22 screen-char
  87 14 {ax} @ {ay} @ screen-char

  begin {run} @ while
    key? {k} !
    {k} @ 113 = if 0 {run} ! then
    {k} @ 108 = if 32 0 {px} @ 22 screen-char {px} @ 1 + {px} ! 94 10 {px} @ 22 screen-char then
    {k} @ 104 = if 32 0 {px} @ 22 screen-char {px} @ 1 - {px} ! 94 10 {px} @ 22 screen-char then
    can-fire? if do-fire then
    tick-bullet? if do-tick-bullet then
    {t} @ 1 + {t} !
    {t} @ 2000 > if 0 {t} ! 32 0 {ax} @ {ay} @ screen-char {ax} @ {dir} @ + {ax} ! 87 14 {ax} @ {ay} @ screen-char then
  repeat
] define
