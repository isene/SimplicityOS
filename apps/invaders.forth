( Space Invaders - simplified )

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

    ( Quit )
    {k} @ 113 = if 0 {run} ! then

    ( Right - simple version )
    {k} @ 108 = if
      32 0 {px} @ 22 screen-char
      {px} @ 1 + {px} !
      94 10 {px} @ 22 screen-char
    then

    ( Left )
    {k} @ 104 = if
      32 0 {px} @ 22 screen-char
      {px} @ 1 - {px} !
      94 10 {px} @ 22 screen-char
    then

    ( Tick for alien movement )
    {t} @ 1 + {t} !
    {t} @ 5000 > if
      0 {t} !
      32 0 {ax} @ {ay} @ screen-char
      {ax} @ {dir} @ + {ax} !
      87 14 {ax} @ {ay} @ screen-char
    then
  repeat
] define
