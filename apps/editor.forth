0 {editor-x} !
0 {editor-y} !
0 {editor-mode} !
0 {text-buffer} !
0 {line-lens} !

"white-on-black" [ 7 ] define
"black-on-white" [ 112 ] define

"init-buffer" [
  1920 allot {text-buffer} !
  24 allot {line-lens} !
  1920 begin 1 - dup 0 >= while 32 over {text-buffer} @ + c! repeat drop
  24 begin 1 - dup 0 >= while 0 over {line-lens} @ + c! repeat drop
] define

"buf-addr" [ 80 * + {text-buffer} @ + ] define
"buf@" [ buf-addr c@ ] define
"buf!" [ buf-addr c! ] define
"line-len@" [ {line-lens} @ + c@ ] define
"line-len!" [ {line-lens} @ + c! ] define

"draw-buf-char" [
  over over buf@
  white-on-black
  rot rot screen-char
] define

"draw-line" [
  0 swap
  begin
    over 80 < while
    over over draw-buf-char
    swap 1 + swap
  repeat
  drop drop
] define

"draw-all" [
  0 begin
    dup 24 < while
    dup draw-line
    1 +
  repeat
  drop
] define

"move-cursor" [ {editor-x} @ {editor-y} @ screen-set ] define

"draw-mode" [ {editor-mode} @ if 73 black-on-white 1 24 screen-char 78 black-on-white 2 24 screen-char 83 black-on-white 3 24 screen-char else 78 black-on-white 1 24 screen-char 79 black-on-white 2 24 screen-char 82 black-on-white 3 24 screen-char then ] define
"draw-x" [ 88 black-on-white 6 24 screen-char 58 black-on-white 7 24 screen-char {editor-x} @ 10 / 48 + black-on-white 8 24 screen-char {editor-x} @ 10 mod 48 + black-on-white 9 24 screen-char ] define
"draw-y" [ 89 black-on-white 12 24 screen-char 58 black-on-white 13 24 screen-char {editor-y} @ 10 / 48 + black-on-white 14 24 screen-char {editor-y} @ 10 mod 48 + black-on-white 15 24 screen-char ] define
"fill-one" [ 32 black-on-white rot 24 screen-char ] define
"fill-status" [ 80 begin 1 - dup fill-one dup 0 = until drop ] define
"status-line" [ move-cursor fill-status draw-mode draw-x draw-y move-cursor ] define

"clear-editor" [ white-on-black screen-clear 0 {editor-x} ! 0 {editor-y} ! init-buffer draw-all ] define

"editor-left" [
  {editor-x} @ 0 > if
    {editor-x} @ 1 - {editor-x} !
  else
    {editor-y} @ 0 > if
      {editor-y} @ 1 - {editor-y} !
      {editor-y} @ line-len@ {editor-x} !
    then
  then
  status-line
] define

"editor-right" [
  {editor-x} @ {editor-y} @ line-len@ < if
    {editor-x} @ 1 + {editor-x} !
  else
    {editor-y} @ 23 < if
      0 {editor-x} !
      {editor-y} @ 1 + {editor-y} !
    then
  then
  status-line
] define

"editor-up" [ {editor-y} @ 0 > if {editor-y} @ 1 - {editor-y} ! {editor-x} @ {editor-y} @ line-len@ > if {editor-y} @ line-len@ {editor-x} ! then then status-line ] define
"editor-down" [ {editor-y} @ 23 < if {editor-y} @ 1 + {editor-y} ! {editor-x} @ {editor-y} @ line-len@ > if {editor-y} @ line-len@ {editor-x} ! then then status-line ] define

"shift-line-right" [
  {editor-y} @ line-len@ 79 < if
    79 begin
      dup {editor-x} @ > while
      dup 1 - {editor-y} @ buf@ over {editor-y} @ buf!
      1 -
    repeat
    drop
    {editor-y} @ line-len@ 1 + {editor-y} @ line-len!
  then
] define

"shift-line-left" [
  {editor-x} @ begin
    dup 78 < while
    dup 1 + {editor-y} @ buf@ over {editor-y} @ buf!
    1 +
  repeat
  drop
  32 79 {editor-y} @ buf!
  {editor-y} @ line-len@ 0 > if
    {editor-y} @ line-len@ 1 - {editor-y} @ line-len!
  then
] define

"insert-char" [
  shift-line-right
  {editor-x} @ {editor-y} @ buf!
  {editor-y} @ draw-line
  {editor-x} @ {editor-y} @ line-len@ < if
    {editor-x} @ 1 + {editor-x} !
  then
  status-line
] define

"editor-enter" [
  0 {editor-x} !
  {editor-y} @ 23 < if {editor-y} @ 1 + {editor-y} ! then
  status-line
] define

"editor-backspace" [
  {editor-x} @ 0 > if
    {editor-x} @ 1 - {editor-x} !
    shift-line-left
    {editor-y} @ draw-line
  then
  status-line
] define

"editor-delete" [
  shift-line-left
  {editor-y} @ draw-line
  status-line
] define

"enter-insert" [ 1 {editor-mode} ! status-line ] define
"exit-insert" [ 0 {editor-mode} ! status-line ] define

"handle-insert" [ dup key-escape = if drop exit-insert else dup 27 = if drop exit-insert else dup 10 = if drop editor-enter else dup 8 = if drop editor-backspace else dup key-delete = if drop editor-delete else dup key-left = if drop editor-left else dup key-right = if drop editor-right else dup key-up = if drop editor-up else dup key-down = if drop editor-down else dup 32 >= over 126 <= and if insert-char else drop then then then then then then then then then then ] define

"handle-normal" [ dup 113 = if drop 0 else dup 104 = if drop editor-left 1 else dup 106 = if drop editor-down 1 else dup 107 = if drop editor-up 1 else dup 108 = if drop editor-right 1 else dup 105 = if drop enter-insert 1 else dup key-left = if drop editor-left 1 else dup key-right = if drop editor-right 1 else dup key-up = if drop editor-up 1 else dup key-down = if drop editor-down 1 else drop 1 then then then then then then then then then then ] define

"editor-loop" [ begin key {editor-mode} @ if handle-insert 1 else handle-normal then 0 = until ] define

"editor" [ clear-editor status-line move-cursor editor-loop 15 screen-clear 0 0 screen-set ] define
