0 {editor-x} !
0 {editor-y} !
0 {editor-mode} !
0 {text-buffer} !
0 {filename} !
0 {dir-buffer} !
0 {file-sector} !
0 {cmd-buffer} !
0 {cmd-pos} !
0 {str-ptr} !
0 {src-ptr} !
0 {dst-ptr} !
0 {copy-len} !

"white-on-black" [ 7 ] define
"black-on-white" [ 112 ] define
"white-on-green" [ 39 ] define

"status-color" [ {editor-mode} @ 1 = if white-on-green else black-on-white then ] define

"init-buffer" [
  {text-buffer} @ 0 = if 2048 allot {text-buffer} ! then
  0 begin dup 1920 < while 32 over {text-buffer} @ + c! 1 + repeat drop
] define

"init-dir-buffer" [
  {dir-buffer} @ 0 = if 512 allot {dir-buffer} ! then
] define

"init-cmd-buffer" [
  {cmd-buffer} @ 0 = if 80 allot {cmd-buffer} ! then
  0 {cmd-pos} !
] define

"cmd-buf@" [ {cmd-buffer} @ + c@ ] define
"cmd-buf!" [ {cmd-buffer} @ + c! ] define

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

( Editor disk area: directory at 450, files from 460 )
( Apps own 200-399, saved definitions own 400-407 )
"read-dir" [ 450 {dir-buffer} @ disk-read ] define
"write-dir" [ {dir-buffer} @ 450 disk-write ] define

"entry-addr" [ 32 * {dir-buffer} @ + ] define
"entry-name" [ entry-addr ] define
"entry-sector" [ entry-addr 16 + ] define

"get-entry-sector" [ entry-sector dup c@ swap 1 + c@ 256 * + ] define

0 {set-entry} !
0 {set-sector} !
"set-entry-sector" [
  {set-entry} !
  {set-sector} !
  {set-sector} @ 255 and {dir-buffer} @ {set-entry} @ 32 * + 16 + c!
  {set-sector} @ 256 / {dir-buffer} @ {set-entry} @ 32 * + 17 + c!
] define

0 {cmp-a} !
0 {cmp-b} !
0 {match-entry} !
0 {cmp-i} !

"cmp-one" [
  {cmp-a} @ 0 = if
    {match-entry} @ entry-name {cmp-i} @ + c@
    dup 0 = if
      drop
    else
      {filename} @ 16 + {cmp-i} @ + c@
      <> if 1 {cmp-a} ! then
    then
  then
] define

"name-match" [
  {match-entry} !
  0 {cmp-a} !
  0 {cmp-i} ! cmp-one
  1 {cmp-i} ! cmp-one
  2 {cmp-i} ! cmp-one
  3 {cmp-i} ! cmp-one
  4 {cmp-i} ! cmp-one
  5 {cmp-i} ! cmp-one
  6 {cmp-i} ! cmp-one
  7 {cmp-i} ! cmp-one
  8 {cmp-i} ! cmp-one
  9 {cmp-i} ! cmp-one
  10 {cmp-i} ! cmp-one
  11 {cmp-i} ! cmp-one
  12 {cmp-i} ! cmp-one
  13 {cmp-i} ! cmp-one
  14 {cmp-i} ! cmp-one
  15 {cmp-i} ! cmp-one
  {cmp-a} @ 0 =
] define

0 {find-i} !
"find-one" [
  {find-i} @ entry-name c@ 0 <> if
    {find-i} @ name-match if
      {find-i} @ get-entry-sector {file-sector} !
    then
  then
] define

"find-file" [
  read-dir
  0 {file-sector} !
  0 {find-i} ! find-one
  1 {find-i} ! find-one
  2 {find-i} ! find-one
  3 {find-i} ! find-one
  4 {find-i} ! find-one
  5 {find-i} ! find-one
  6 {find-i} ! find-one
  7 {find-i} ! find-one
  8 {find-i} ! find-one
  9 {find-i} ! find-one
  10 {find-i} ! find-one
  11 {find-i} ! find-one
  12 {find-i} ! find-one
  13 {find-i} ! find-one
  14 {find-i} ! find-one
  15 {find-i} ! find-one
  {file-sector} @
] define

0 {nfs-max} !
"check-entry-sector" [
  dup entry-name c@ 0 <> if
    get-entry-sector 4 +
    dup {nfs-max} @ > if {nfs-max} ! else drop then
  else
    drop
  then
] define

"next-free-sector" [
  460 {nfs-max} !
  0 check-entry-sector
  1 check-entry-sector
  2 check-entry-sector
  3 check-entry-sector
  4 check-entry-sector
  5 check-entry-sector
  6 check-entry-sector
  7 check-entry-sector
  8 check-entry-sector
  9 check-entry-sector
  10 check-entry-sector
  11 check-entry-sector
  12 check-entry-sector
  13 check-entry-sector
  14 check-entry-sector
  15 check-entry-sector
  {nfs-max} @
] define

0 {copy-src} !
0 {copy-dst} !

0 {copy-i} !
"copy-one-char" [
  {copy-i} @ {copy-src} @ + c@
  {copy-i} @ {copy-dst} @ + c!
] define

"copy-name-to-entry" [
  {filename} @ 16 + {copy-src} !
  entry-name {copy-dst} !
  0 {copy-i} ! copy-one-char
  1 {copy-i} ! copy-one-char
  2 {copy-i} ! copy-one-char
  3 {copy-i} ! copy-one-char
  4 {copy-i} ! copy-one-char
  5 {copy-i} ! copy-one-char
  6 {copy-i} ! copy-one-char
  7 {copy-i} ! copy-one-char
  8 {copy-i} ! copy-one-char
  9 {copy-i} ! copy-one-char
  10 {copy-i} ! copy-one-char
  11 {copy-i} ! copy-one-char
  12 {copy-i} ! copy-one-char
  13 {copy-i} ! copy-one-char
  14 {copy-i} ! copy-one-char
  15 {copy-i} ! copy-one-char
] define

0 {create-entry} !
0 {create-done} !
"try-create-entry" [
  {create-done} @ 0 = if
    dup entry-name c@ 0 = if
      {create-entry} !
      next-free-sector {create-entry} @ set-entry-sector
      {create-entry} @ copy-name-to-entry
      {create-entry} @ get-entry-sector {file-sector} !
      write-dir
      1 {create-done} !
    else
      drop
    then
  else
    drop
  then
] define

"create-file" [
  read-dir
  0 {create-done} !
  0 try-create-entry
  1 try-create-entry
  2 try-create-entry
  3 try-create-entry
  4 try-create-entry
  5 try-create-entry
  6 try-create-entry
  7 try-create-entry
  8 try-create-entry
  9 try-create-entry
  10 try-create-entry
  11 try-create-entry
  12 try-create-entry
  13 try-create-entry
  14 try-create-entry
  15 try-create-entry
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
  {file-sector} @ {text-buffer} @ disk-read
  {file-sector} @ 1 + {text-buffer} @ 512 + disk-read
  {file-sector} @ 2 + {text-buffer} @ 1024 + disk-read
  {file-sector} @ 3 + {text-buffer} @ 1536 + disk-read
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

0 {fn-ptr} !
0 {fn-i} !
"draw-fn-char" [
  {fn-ptr} @ {fn-i} @ + c@ dup 0 <> if
    status-color {fn-i} @ 10 + 24 screen-char
  else
    drop
  then
] define

"draw-filename" [
  {filename} @ 0 <> if
    {filename} @ 16 + {fn-ptr} !
    0 {fn-i} ! draw-fn-char
    1 {fn-i} ! draw-fn-char
    2 {fn-i} ! draw-fn-char
    3 {fn-i} ! draw-fn-char
    4 {fn-i} ! draw-fn-char
    5 {fn-i} ! draw-fn-char
    6 {fn-i} ! draw-fn-char
    7 {fn-i} ! draw-fn-char
    8 {fn-i} ! draw-fn-char
    9 {fn-i} ! draw-fn-char
    10 {fn-i} ! draw-fn-char
    11 {fn-i} ! draw-fn-char
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

"editor-backspace" [
  {editor-x} @ 0 > if
    {editor-x} @ 1 - {editor-x} !
    32 {editor-x} @ {editor-y} @ xy-to-offset buf!
    {editor-x} @ {editor-y} @ draw-char-at
    status-line
  then
] define

"handle-insert" [
  dup key-escape = if drop exit-insert
  else dup 3 = if drop exit-insert
  else dup 10 = if drop editor-enter
  else dup 127 = if drop editor-backspace
  else dup 8 = if drop editor-backspace
  else dup key-left = if drop editor-left
  else dup key-right = if drop editor-right
  else dup key-up = if drop editor-up
  else dup key-down = if drop editor-down
  else dup 32 >= over 126 <= and if insert-char
  else drop
  then then then then then then then then then then
] define

"do-save" [ save-file 83 status-color 22 24 screen-char move-cursor ] define
"do-load" [ load-file redraw-all 76 status-color 22 24 screen-char move-cursor ] define

"draw-cmd-char" [ status-color swap 1 + 24 screen-char ] define

"enter-command" [
  2 {editor-mode} !
  clear-status
  58 status-color 0 24 screen-char
  1 24 screen-set
] define

"exit-command" [
  0 {editor-mode} !
  0 {cmd-pos} !
  status-line
] define

"cmd-add-char" [
  dup {cmd-pos} @ cmd-buf!
  {cmd-pos} @ draw-cmd-char
  {cmd-pos} @ 1 + {cmd-pos} !
  {cmd-pos} @ 1 + 24 screen-set
] define

"cmd-backspace" [
  {cmd-pos} @ 0 > if
    {cmd-pos} @ 1 - {cmd-pos} !
    32 {cmd-pos} @ draw-cmd-char
    {cmd-pos} @ 1 + 24 screen-set
  then
] define

0 {msc-i} !
"copy-cmd-char" [
  {msc-i} @ {copy-len} @ < if
    {msc-i} @ {src-ptr} @ + c@
    {msc-i} @ {dst-ptr} @ + c!
  then
] define

"make-string-from-cmd" [
  {cmd-pos} @ 2 - {copy-len} !
  {copy-len} @ 17 + allot {str-ptr} !
  1 {str-ptr} @ !
  {copy-len} @ {str-ptr} @ 8 + !
  {cmd-buffer} @ 2 + {src-ptr} !
  {str-ptr} @ 16 + {dst-ptr} !
  0 {msc-i} ! copy-cmd-char
  1 {msc-i} ! copy-cmd-char
  2 {msc-i} ! copy-cmd-char
  3 {msc-i} ! copy-cmd-char
  4 {msc-i} ! copy-cmd-char
  5 {msc-i} ! copy-cmd-char
  6 {msc-i} ! copy-cmd-char
  7 {msc-i} ! copy-cmd-char
  8 {msc-i} ! copy-cmd-char
  9 {msc-i} ! copy-cmd-char
  10 {msc-i} ! copy-cmd-char
  11 {msc-i} ! copy-cmd-char
  12 {msc-i} ! copy-cmd-char
  13 {msc-i} ! copy-cmd-char
  14 {msc-i} ! copy-cmd-char
  15 {msc-i} ! copy-cmd-char
  0 {dst-ptr} @ {copy-len} @ + c!
  {str-ptr} @
] define

"exec-cmd-w" [
  {cmd-pos} @ 2 > if
    make-string-from-cmd {filename} !
  then
  {filename} @ 0 <> if
    find-file 0 = if create-file drop then
    save-file
  then
  exit-command
] define

"exec-cmd-q" [
  0
] define

"exec-cmd-wq" [
  {filename} @ 0 <> if
    find-file 0 = if create-file drop then
    save-file
  then
  0
] define

"exec-command" [
  0 {cmd-pos} @ cmd-buf!
  0 cmd-buf@ 119 = if
    1 cmd-buf@ 113 = if
      exec-cmd-wq
    else
      exec-cmd-w 1
    then
  else 0 cmd-buf@ 113 = if
    exec-cmd-q
  else
    exit-command 1
  then then
] define

"handle-command" [
  dup key-escape = if drop exit-command 1
  else dup 10 = if drop exec-command
  else dup 127 = if drop cmd-backspace 1
  else dup 8 = if drop cmd-backspace 1
  else dup 32 >= over 126 <= and if cmd-add-char 1
  else drop 1
  then then then then then
] define

"handle-normal" [
  dup 113 = if drop 0
  else dup 105 = if drop enter-insert 1
  else dup 115 = if drop do-save 1
  else dup 111 = if drop do-load 1
  else dup 58 = if drop enter-command 1
  else dup 104 = if drop editor-left 1
  else dup 108 = if drop editor-right 1
  else dup 106 = if drop editor-down 1
  else dup 107 = if drop editor-up 1
  else dup key-left = if drop editor-left 1
  else dup key-right = if drop editor-right 1
  else dup key-up = if drop editor-up 1
  else dup key-down = if drop editor-down 1
  else drop 1
  then then then then then then then then then then then then then
] define

"dispatch-mode" [
  {editor-mode} @ 0 = if handle-normal
  else {editor-mode} @ 1 = if handle-insert 1
  else handle-command
  then then
] define

"editor-loop" [ begin key dispatch-mode 0 = until ] define

"try-load" [
  {filename} @ 0 <> if
    find-file 0 <> if
      load-file redraw-all
    then
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

"editor" [
  {filename} !
  init-dir-buffer
  init-cmd-buffer
  editor-start
] define
