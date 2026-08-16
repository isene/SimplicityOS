( UAC: the Ultimate Alarm Clock, ported from hp-41_uac )
( Native rewrite of the alarm engine; the FOCAL original is )
( key-assignment driven, which has no batch translation. )
( Keys: a set alarm  8 alarm in 8h  p alarm in 30m )
(       c clear      h hear the time  s snooze 30m  q quit )

0 {ua-set} !
0 {ua-min} !

( minutes of day right now )
"ua-now" [ rtc {u3} ! {u2} ! drop {u3} @ 60 * {u2} @ + ] define

"ua-2d" [ dup 10 < if 48 emit then . ] define

"ua-clock" [
  0 2 screen-set 15 color!
  rtc {u3} ! {u2} ! {u1} !
  "    " . {u3} @ ua-2d 58 emit {u2} @ ua-2d 58 emit {u1} @ ua-2d "    " .
] define

"ua-alarm-line" [
  0 4 screen-set 13 color!
  {ua-set} @ 1 = if
    "Alarm: " . {ua-min} @ 60 / ua-2d 58 emit {ua-min} @ 60 mod ua-2d "   " .
  else
    "Alarm: off      " .
  then
] define

"ua-menu" [
  0 6 screen-set 11 color!
  "a set  8 in-8h  p in-30m  c clear" . cr
  "h hear time  s snooze-30m  q quit" .
] define

"ua-arm" [ 1440 mod {ua-min} ! 1 {ua-set} ! ] define

( a: read HH.MM, arm )
"ua-seta" [
  0 9 screen-set 14 color! "Alarm HH.MM: " .
  read-line aset anum
  {xr} @ f>s 60 *
  {xr} @ dup f>s s>f f- 100.0 f* 0.5 f+ f>s +
  ua-arm hpdrop
  0 9 screen-set "                    " .
] define

( hear the time: hours high, minute-tens mid, minute-units low )
"ua-nbeep" [ {u5} ! {u6} ! begin {u6} @ 0 > while {u5} @ 6 beep 8 {u7} ! begin {u7} @ 0 > while waittick {u7} @ 1 - {u7} ! repeat {u6} @ 1 - {u6} ! repeat ] define
"ua-hear" [
  rtc {u3} ! {u2} ! drop
  {u3} @ 523 ua-nbeep
  18 {u7} ! begin {u7} @ 0 > while waittick {u7} @ 1 - {u7} ! repeat
  {u2} @ 10 / 392 ua-nbeep
  18 {u7} ! begin {u7} @ 0 > while waittick {u7} @ 1 - {u7} ! repeat
  {u2} @ 10 mod 262 ua-nbeep
] define

( ring until a key; s snoozes 30m, anything else clears )
"ua-ring" [
  0 9 screen-set 12 color! "*** ALARM ***  s snooze, other stop" .
  0 {ua-set} !
  begin
    880 3 beep 660 3 beep
    key? {u4} !
  {u4} @ 0 = not until
  {u4} @ 115 = if ua-now 30 + ua-arm then
  0 9 screen-set "                                        " .
] define

"ua-key" [
  {u4} !
  {u4} @ 97 = if ua-seta then
  {u4} @ 56 = if ua-now 480 + ua-arm then
  {u4} @ 112 = if ua-now 30 + ua-arm then
  {u4} @ 99 = if 0 {ua-set} ! then
  {u4} @ 104 = if ua-hear then
  {u4} @ 115 = if {ua-set} @ 1 = if {ua-min} @ 30 + ua-arm then then
] define

"uac" [
  screen-clear cursor-hide
  0 0 screen-set 10 color! "UAC  Ultimate Alarm Clock" .
  1 {run2} !
  begin {run2} @ 1 = while
    ua-clock ua-alarm-line ua-menu
    waittick
    {ua-set} @ 1 = if ua-now {ua-min} @ = if ua-ring then then
    key? {u4} !
    {u4} @ 113 = if 0 {run2} ! then
    {u4} @ 0 = not {u4} @ 113 = not and if {u4} @ ua-key then
  repeat
  cursor-show 14 color! screen-clear
] define
