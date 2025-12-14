0 {editor-x} !
0 {editor-y} !
0 {editor-mode} !
0 {text-buffer} !

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

"draw-mode" [ {editor-mode} @ if 73 else 78 then black-on-white 1 24 screen-char ] define

"status-line" [ 32 black-on-white 0 24 screen-char draw-mode move-cursor ] define

"clear-editor" [ white-on-black screen-clear 0 {editor-x} ! 0 {editor-y} ! init-buffer ] define

"editor-left" [ {editor-x} @ 0 > if {editor-x} @ 1 - {editor-x} ! then status-line ] define
"editor-right" [ {editor-x} @ 79 < if {editor-x} @ 1 + {editor-x} ! then status-line ] define
"editor-up" [ {editor-y} @ 0 > if {editor-y} @ 1 - {editor-y} ! then status-line ] define
"editor-down" [ {editor-y} @ 23 < if {editor-y} @ 1 + {editor-y} ! then status-line ] define

"insert-char" [
  {editor-x} @ {editor-y} @ xy-to-offset buf!
  {editor-x} @ {editor-y} @ draw-char-at
  {editor-x} @ 79 < if {editor-x} @ 1 + {editor-x} ! then
  status-line
] define

"enter-insert" [ 1 {editor-mode} ! status-line ] define
"exit-insert" [ 0 {editor-mode} ! status-line ] define

"handle-insert" [
  dup key-escape = if drop exit-insert
  else dup key-left = if drop editor-left
  else dup key-right = if drop editor-right
  else dup key-up = if drop editor-up
  else dup key-down = if drop editor-down
  else dup 32 >= over 126 <= and if insert-char
  else drop
  then then then then then then
] define

"handle-normal" [
  dup 113 = if drop 0
  else dup 105 = if drop enter-insert 1
  else dup 104 = if drop editor-left 1
  else dup 108 = if drop editor-right 1
  else dup 106 = if drop editor-down 1
  else dup 107 = if drop editor-up 1
  else dup key-left = if drop editor-left 1
  else dup key-right = if drop editor-right 1
  else dup key-up = if drop editor-up 1
  else dup key-down = if drop editor-down 1
  else drop 1
  then then then then then then then then then then
] define

"editor-loop" [ begin key {editor-mode} @ if handle-insert 1 else handle-normal then 0 = until ] define

"editor" [ clear-editor status-line move-cursor editor-loop white-on-black screen-clear 0 0 screen-set ] define
