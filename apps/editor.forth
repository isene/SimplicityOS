0 {editor-x} !
0 {editor-y} !
0 {editor-mode} !
0 {text-buffer} !
0 {file-num} !

"white-on-black" [ 7 ] define
"black-on-white" [ 112 ] define

"init-buffer" [
  1920 allot {text-buffer} !
  0 begin dup 1920 < while 32 over {text-buffer} @ + c! 1 + repeat drop
] define

"buf-addr" [ {text-buffer} @ + ] define
"buf@" [ buf-addr c@ ] define
"buf!" [ buf-addr c! ] define
"xy-to-offset" [ 80 * + ] define

"draw-char-at" [
  over over xy-to-offset buf@
  rot rot
  white-on-black
  rot rot screen-char
] define

"move-cursor" [ {editor-x} @ {editor-y} @ screen-set ] define

"file-sector" [ {file-num} @ 4 * 300 + ] define

"save-file" [
  {text-buffer} @ file-sector disk-write
  {text-buffer} @ 512 + file-sector 1 + disk-write
  {text-buffer} @ 1024 + file-sector 2 + disk-write
  {text-buffer} @ 1536 + file-sector 3 + disk-write
] define

"load-file" [
  file-sector {text-buffer} @ disk-read
  file-sector 1 + {text-buffer} @ 512 + disk-read
  file-sector 2 + {text-buffer} @ 1024 + disk-read
  file-sector 3 + {text-buffer} @ 1536 + disk-read
] define

"redraw-line" [
  0 swap begin over 80 < while over over draw-char-at swap 1 + swap repeat drop drop
] define

"redraw-all" [
  0 redraw-line 1 redraw-line 2 redraw-line 3 redraw-line
  4 redraw-line 5 redraw-line 6 redraw-line 7 redraw-line
  8 redraw-line 9 redraw-line 10 redraw-line 11 redraw-line
  12 redraw-line 13 redraw-line 14 redraw-line 15 redraw-line
  16 redraw-line 17 redraw-line 18 redraw-line 19 redraw-line
  20 redraw-line 21 redraw-line 22 redraw-line 23 redraw-line
] define

"clear-status" [
  0 begin dup 80 < while 32 black-on-white over 24 screen-char 1 + repeat drop
] define

"draw-mode" [ {editor-mode} @ if 73 else 78 then black-on-white 1 24 screen-char ] define

"draw-file-num" [
  {file-num} @ 48 + black-on-white 10 24 screen-char
] define

"status-line" [
  clear-status
  45 black-on-white 0 24 screen-char
  draw-mode
  45 black-on-white 2 24 screen-char
  70 black-on-white 8 24 screen-char
  58 black-on-white 9 24 screen-char
  draw-file-num
  move-cursor
] define

"clear-editor" [ white-on-black screen-clear 0 {editor-x} ! 0 {editor-y} ! init-buffer ] define

"editor-left" [ {editor-x} @ 0 > if {editor-x} @ 1 - {editor-x} ! then status-line ] define
"editor-right" [
  {editor-x} @ 79 < if
    {editor-x} @ 1 + {editor-x} !
  else
    {editor-y} @ 23 < if
      0 {editor-x} !
      {editor-y} @ 1 + {editor-y} !
    then
  then
  status-line
] define
"editor-up" [ {editor-y} @ 0 > if {editor-y} @ 1 - {editor-y} ! then status-line ] define
"editor-down" [ {editor-y} @ 23 < if {editor-y} @ 1 + {editor-y} ! then status-line ] define

"insert-char" [
  {editor-x} @ {editor-y} @ xy-to-offset buf!
  {editor-x} @ {editor-y} @ draw-char-at
  {editor-x} @ 79 < if {editor-x} @ 1 + {editor-x} ! then
  status-line
] define

"editor-enter" [
  {editor-y} @ 23 < if
    0 {editor-x} !
    {editor-y} @ 1 + {editor-y} !
  then
  status-line
] define

"enter-insert" [ 1 {editor-mode} ! status-line ] define
"exit-insert" [ 0 {editor-mode} ! status-line ] define

"handle-insert" [
  dup key-escape = if drop exit-insert
  else dup 96 = if drop exit-insert
  else dup 10 = if drop editor-enter
  else dup key-left = if drop editor-left
  else dup key-right = if drop editor-right
  else dup key-up = if drop editor-up
  else dup key-down = if drop editor-down
  else dup 32 >= over 126 <= and if insert-char
  else drop
  then then then then then then then then
] define

"file-next" [ {file-num} @ 9 < if {file-num} @ 1 + {file-num} ! then status-line ] define
"file-prev" [ {file-num} @ 0 > if {file-num} @ 1 - {file-num} ! then status-line ] define

"do-save" [ save-file 83 black-on-white 15 24 screen-char move-cursor ] define
"do-load" [ load-file redraw-all 76 black-on-white 15 24 screen-char move-cursor ] define

"handle-normal" [
  dup 113 = if drop 0
  else dup 105 = if drop enter-insert 1
  else dup 115 = if drop do-save 1
  else dup 111 = if drop do-load 1
  else dup 43 = if drop file-next 1
  else dup 45 = if drop file-prev 1
  else dup 104 = if drop editor-left 1
  else dup 108 = if drop editor-right 1
  else dup 106 = if drop editor-down 1
  else dup 107 = if drop editor-up 1
  else dup key-left = if drop editor-left 1
  else dup key-right = if drop editor-right 1
  else dup key-up = if drop editor-up 1
  else dup key-down = if drop editor-down 1
  else drop 1
  then then then then then then then then then then then then then then
] define

"editor-loop" [ begin key {editor-mode} @ if handle-insert 1 else handle-normal then 0 = until ] define

"editor" [ app-enter clear-editor status-line move-cursor editor-loop white-on-black screen-clear 0 0 screen-set app-exit ] define
