( Space Invaders - minimal test version )

( Helper words for alien movement )
"alien-right" [ {ax} @ 75 > if 0 1 - {dir} ! {ay} @ 1 + {ay} ! then ] define
"alien-left" [ {ax} @ 5 < if 1 {dir} ! {ay} @ 1 + {ay} ! then ] define
"alien-reset" [ {ay} @ 20 > if 3 {ay} ! 10 {ax} ! then ] define

"invaders" [
  screen-clear
  40 {px} !
  10 {ax} !
  3 {ay} !
  1 {dir} !
  1 {run} !
  0 {t} !

  94 10 {px} @ 22 screen-char
  87 14 {ax} @ {ay} @ screen-char

  begin {run} @ while
    key? {k} !
    {k} @ 113 = if 0 {run} ! then
    {k} @ 108 = if
      32 0 {px} @ 22 screen-char
      {px} @ 1 + {px} !
      94 10 {px} @ 22 screen-char
    then
    {k} @ 104 = if
      32 0 {px} @ 22 screen-char
      {px} @ 1 - {px} !
      94 10 {px} @ 22 screen-char
    then
    {t} @ 1 + {t} !
    {t} @ 5000 > if
      0 {t} !
      32 0 {ax} @ {ay} @ screen-char
      {ax} @ {dir} @ + {ax} !
      alien-right
      alien-left
      alien-reset
      87 14 {ax} @ {ay} @ screen-char
    then
  repeat
  screen-clear
] define
