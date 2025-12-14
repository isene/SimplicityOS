0 {editor-x} !
0 {editor-y} !
0 {editor-mode} !
0 {text-buffer} !
0 {filename} !
0 {dir-buffer} !
0 {file-sector} !

"white-on-black" [ 7 ] define
"black-on-white" [ 112 ] define
"white-on-green" [ 39 ] define

"status-color" [ {editor-mode} @ if white-on-green else black-on-white then ] define

"init-buffer" [
  1920 allot {text-buffer} !
  0 begin dup 1920 < while 32 over {text-buffer} @ + c! 1 + repeat drop
] define

"init-dir-buffer" [
  512 allot {dir-buffer} !
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

"read-dir" [ 250 {dir-buffer} @ disk-read ] define
"write-dir" [ {dir-buffer} @ 250 disk-write ] define

"entry-addr" [ 32 * {dir-buffer} @ + ] define
"entry-name" [ entry-addr ] define
"entry-sector" [ entry-addr 16 + ] define

"get-entry-sector" [ entry-sector dup c@ swap 1 + c@ 256 * + ] define
"set-entry-sector" [ over 255 and over entry-sector c! swap 256 / swap entry-sector 1 + c! drop ] define

0 {cmp-a} !
0 {cmp-b} !

"name-match" [
  1
  0 begin dup 16 < while
    dup entry-name + c@ {cmp-a} !
    dup {filename} @ 16 + + c@ {cmp-b} !
    {cmp-a} @ {cmp-b} @ <> if swap drop 0 swap 16 else
      {cmp-a} @ 0 = if 16 else 1 + then
    then
  repeat
  drop
] define

"find-file" [
  read-dir
  0 {file-sector} !
  0 begin dup 16 < while
    dup entry-name c@ 0 <> if
      dup name-match if
        dup get-entry-sector {file-sector} !
      then
    then
    1 +
  repeat drop
  {file-sector} @
] define

"next-free-sector" [
  300
  0 begin dup 16 < while
    dup entry-name c@ 0 <> if
      dup get-entry-sector 4 +
      rot over over < if drop else swap drop then
      swap
    then
    1 +
  repeat drop
] define

0 {copy-src} !
0 {copy-dst} !

"copy-name-to-entry" [
  {filename} @ 16 + {copy-src} !
  entry-name {copy-dst} !
  0 begin dup 16 < while
    dup {copy-src} @ + c@
    over {copy-dst} @ + c!
    1 +
  repeat drop
] define

"create-file" [
  read-dir
  0 begin dup 16 < while
    dup entry-name c@ 0 = if
      next-free-sector over set-entry-sector
      dup copy-name-to-entry
      dup get-entry-sector {file-sector} !
      write-dir
      16
    else
      1 +
    then
  repeat drop
  {file-sector} @
] define

"save-file" [
  {filename} @ 0 <> if
    find-file
    0 = if create-file drop then
    {file-sector} @ 0 = if else
      {text-buffer} @ {file-sector} @ disk-write
      {text-buffer} @ 512 + {file-sector} @ 1 + disk-write
      {text-buffer} @ 1024 + {file-sector} @ 2 + disk-write
      {text-buffer} @ 1536 + {file-sector} @ 3 + disk-write
    then
  then
] define

"load-file" [
  {filename} @ 0 <> if
    find-file
    0 = if else
      {file-sector} @ {text-buffer} @ disk-read
      {file-sector} @ 1 + {text-buffer} @ 512 + disk-read
      {file-sector} @ 2 + {text-buffer} @ 1024 + disk-read
      {file-sector} @ 3 + {text-buffer} @ 1536 + disk-read
    then
  then
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
  0 begin dup 80 < while
    dup 32 swap status-color swap 24 screen-char
  1 + repeat drop
] define

"draw-normal" [
  78 status-color 1 24 screen-char
  111 status-color 2 24 screen-char
  114 status-color 3 24 screen-char
  109 status-color 4 24 screen-char
  97 status-color 5 24 screen-char
  108 status-color 6 24 screen-char
] define

"draw-insert" [
  73 status-color 1 24 screen-char
  110 status-color 2 24 screen-char
  115 status-color 3 24 screen-char
  101 status-color 4 24 screen-char
  114 status-color 5 24 screen-char
  116 status-color 6 24 screen-char
] define

"draw-mode" [ {editor-mode} @ if draw-insert else draw-normal then ] define

"draw-filename" [
  {filename} @ 0 <> if
    {filename} @ 16 +
    0 begin dup 12 < while
      over over + c@ dup 0 <> if
        status-color over 10 + 24 screen-char
      else
        drop
      then
      1 +
    repeat drop drop
  then
] define

"status-line" [
  clear-status
  draw-mode
  draw-filename
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
  else dup 3 = if drop exit-insert
  else dup 10 = if drop editor-enter
  else dup key-left = if drop editor-left
  else dup key-right = if drop editor-right
  else dup key-up = if drop editor-up
  else dup key-down = if drop editor-down
  else dup 32 >= over 126 <= and if insert-char
  else drop
  then then then then then then then then
] define

"do-save" [ save-file 83 status-color 22 24 screen-char move-cursor ] define
"do-load" [ load-file redraw-all 76 status-color 22 24 screen-char move-cursor ] define

"handle-normal" [
  dup 113 = if drop 0
  else dup 105 = if drop enter-insert 1
  else dup 115 = if drop do-save 1
  else dup 111 = if drop do-load 1
  else dup 104 = if drop editor-left 1
  else dup 108 = if drop editor-right 1
  else dup 106 = if drop editor-down 1
  else dup 107 = if drop editor-up 1
  else dup key-left = if drop editor-left 1
  else dup key-right = if drop editor-right 1
  else dup key-up = if drop editor-up 1
  else dup key-down = if drop editor-down 1
  else drop 1
  then then then then then then then then then then then then
] define

"editor-loop" [ begin key {editor-mode} @ if handle-insert 1 else handle-normal then 0 = until ] define

"try-load" [
  {filename} @ 0 <> if
    find-file 0 <> if load-file redraw-all then
  then
] define

"editor-start" [
  app-enter
  clear-editor
  try-load
  status-line
  move-cursor
  editor-loop
  white-on-black screen-clear 0 0 screen-set
  app-exit
] define

"editor" [ {filename} ! init-dir-buffer editor-start ] define
