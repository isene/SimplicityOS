: test-inv 72 emit 73 emit ;

: ship-char 65 ;
: alien-char 77 ;
: bullet-char 124 ;
: empty-char 32 ;

0 [ship-x] !
0 [score] !
0 [game-over] !
0 [bullet-x] !
0 [bullet-y] !
0 [bullet-active] !

: game-color 10 ;
: ship-color 14 ;
: alien-color 12 ;
: bullet-color 15 ;

: draw-ship
  ship-char ship-color [ship-x] @ 23 screen-char ;

: erase-ship
  empty-char game-color [ship-x] @ 23 screen-char ;

: draw-bullet
  [bullet-active] @ if
    bullet-char bullet-color
    [bullet-x] @ [bullet-y] @
    screen-char
  then ;

: erase-bullet
  [bullet-active] @ if
    empty-char game-color
    [bullet-x] @ [bullet-y] @
    screen-char
  then ;

: ship-left
  erase-ship
  [ship-x] @ 1 > if
    [ship-x] @ 1 - [ship-x] !
  then
  draw-ship ;

: ship-right
  erase-ship
  [ship-x] @ 77 < if
    [ship-x] @ 1 + [ship-x] !
  then
  draw-ship ;

: fire
  [bullet-active] @ 0 = if
    [ship-x] @ [bullet-x] !
    22 [bullet-y] !
    1 [bullet-active] !
  then ;

: move-bullet
  [bullet-active] @ if
    erase-bullet
    [bullet-y] @ 1 - [bullet-y] !
    [bullet-y] @ 0 < if
      0 [bullet-active] !
    else
      draw-bullet
    then
  then ;

: draw-score
  83 15 0 0 screen-char
  67 15 1 0 screen-char
  58 15 2 0 screen-char
  [score] @ 10 / 48 + 15 4 0 screen-char
  [score] @ 10 mod 48 + 15 5 0 screen-char ;

: init-game
  game-color screen-clear
  40 [ship-x] !
  0 [score] !
  0 [game-over] !
  0 [bullet-active] !
  draw-ship ;

: invaders
  init-game
  begin
    key
    dup 113 = if 1 [game-over] ! then
    dup key-left = if ship-left then
    dup key-right = if ship-right then
    dup 32 = if fire then
    drop
    move-bullet
    draw-score
    50 ms
  [game-over] @ until
  15 screen-clear
  0 0 screen-set ;
