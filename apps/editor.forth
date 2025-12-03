0 [editor-x] !
0 [editor-y] !
0 [editor-mode] !

: white-on-black 7 ;
: black-on-white 112 ;

: draw-char white-on-black rot rot screen-char ;

: clear-editor
  white-on-black screen-clear
  0 [editor-x] !
  0 [editor-y] ! ;

: move-cursor [editor-x] @ [editor-y] @ screen-set ;

: status-line
  32 black-on-white 0 24 screen-char
  [editor-mode] @ if
    73 black-on-white 1 24 screen-char
    78 black-on-white 2 24 screen-char
    83 black-on-white 3 24 screen-char
  else
    78 black-on-white 1 24 screen-char
    79 black-on-white 2 24 screen-char
    82 black-on-white 3 24 screen-char
  then
  32 black-on-white 4 24 screen-char
  32 black-on-white 5 24 screen-char
  88 black-on-white 6 24 screen-char
  58 black-on-white 7 24 screen-char
  [editor-x] @ 10 / 48 + black-on-white 8 24 screen-char
  [editor-x] @ 10 mod 48 + black-on-white 9 24 screen-char
  32 black-on-white 10 24 screen-char
  32 black-on-white 11 24 screen-char
  89 black-on-white 12 24 screen-char
  58 black-on-white 13 24 screen-char
  [editor-y] @ 10 / 48 + black-on-white 14 24 screen-char
  [editor-y] @ 10 mod 48 + black-on-white 15 24 screen-char
  move-cursor ;

: editor-left
  [editor-x] @ 0 > if
    [editor-x] @ 1 - [editor-x] !
  then status-line ;

: editor-right
  [editor-x] @ 78 < if
    [editor-x] @ 1 + [editor-x] !
  then status-line ;

: editor-up
  [editor-y] @ 0 > if
    [editor-y] @ 1 - [editor-y] !
  then status-line ;

: editor-down
  [editor-y] @ 22 < if
    [editor-y] @ 1 + [editor-y] !
  then status-line ;

: editor-enter
  0 [editor-x] !
  [editor-y] @ 22 < if
    [editor-y] @ 1 + [editor-y] !
  then status-line ;

: insert-char
  [editor-x] @ [editor-y] @ draw-char
  editor-right ;

: enter-insert 1 [editor-mode] ! status-line ;
: exit-insert 0 [editor-mode] ! status-line ;

: editor-loop
  begin
    key
    [editor-mode] @ if
      dup key-escape = if
        drop exit-insert
      else
        dup 13 = if
          drop editor-enter
        else
          dup 32 >= over 126 <= and if
            insert-char
          else
            drop
          then
        then
      then
      1
    else
      dup 113 = if drop 0 else
      dup 104 = if drop editor-left 1 else
      dup 106 = if drop editor-down 1 else
      dup 107 = if drop editor-up 1 else
      dup 108 = if drop editor-right 1 else
      dup 105 = if drop enter-insert 1 else
      dup key-left = if drop editor-left 1 else
      dup key-right = if drop editor-right 1 else
      dup key-up = if drop editor-up 1 else
      dup key-down = if drop editor-down 1 else
        drop 1
      then then then then then then then then then then
    then
  0 = until ;

: editor
  clear-editor
  status-line
  move-cursor
  editor-loop
  15 screen-clear
  0 0 screen-set ;
