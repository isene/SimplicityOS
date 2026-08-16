( XRPN runtime: the HP-41 machine model as Simplicity words )
( X Y Z T L are float variables; 100 numbered registers; flags )
( Programs translated from .xrpn by tools/xrpn2forth call these )

( --- state --- )
800 allot {hpreg} !
0 {hpflg} !

"xf2" [ 1 swap begin dup 0 > while swap 2 * swap 1 - repeat drop ] define
"regaddr" [ 8 * {hpreg} @ + ] define

( --- stack model: lift and roll --- )
"xn" [ {zr} @ {tr} ! {yr} @ {zr} ! {xr} @ {yr} ! {xr} ! ] define
"enter" [ {zr} @ {tr} ! {yr} @ {zr} ! {xr} @ {yr} ! ] define
"rdn" [ {xr} @ {yr} @ {xr} ! {zr} @ {yr} ! {tr} @ {zr} ! {tr} ! ] define
"rup" [ {tr} @ {zr} @ {tr} ! {yr} @ {zr} ! {xr} @ {yr} ! {xr} ! ] define
"xy" [ {xr} @ {yr} @ {xr} ! {yr} ! ] define
"clx" [ 0.0 {xr} ! ] define
"clst" [ 0.0 {xr} ! 0.0 {yr} ! 0.0 {zr} ! 0.0 {tr} ! ] define
"lastx" [ {lr} @ xn ] define

( --- binary ops: Y op X to X, stack drops, L gets old X --- )
"hp+" [ {xr} @ {lr} ! {yr} @ {xr} @ f+ {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define
"hp-" [ {xr} @ {lr} ! {yr} @ {xr} @ f- {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define
"hp*" [ {xr} @ {lr} ! {yr} @ {xr} @ f* {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define
"hp/" [ {xr} @ {lr} ! {yr} @ {xr} @ f/ {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define
"hppow" [ {xr} @ {lr} ! {yr} @ {xr} @ fpow {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define

( --- unary on X, L = old X --- )
"hpchs" [ {xr} @ fneg {xr} ! ] define
"hpabs" [ {xr} @ {lr} ! {xr} @ fabs {xr} ! ] define
"hpsqrt" [ {xr} @ {lr} ! {xr} @ fsqrt {xr} ! ] define
"hpsq" [ {xr} @ {lr} ! {xr} @ {xr} @ f* {xr} ! ] define
"hpinv" [ {xr} @ {lr} ! 1.0 {xr} @ f/ {xr} ! ] define
"hpsin" [ {xr} @ {lr} ! {xr} @ fsin {xr} ! ] define
"hpcos" [ {xr} @ {lr} ! {xr} @ fcos {xr} ! ] define
"hptan" [ {xr} @ {lr} ! {xr} @ ftan {xr} ! ] define
"hpatan" [ {xr} @ {lr} ! {xr} @ fatan {xr} ! ] define
"hpln" [ {xr} @ {lr} ! {xr} @ fln {xr} ! ] define
"hplog" [ {xr} @ {lr} ! {xr} @ flog {xr} ! ] define
"hpexp" [ {xr} @ {lr} ! {xr} @ fexp {xr} ! ] define

( --- registers, taking n from the stack --- )
"hpsto" [ regaddr {xr} @ swap ! ] define
"hprcl" [ regaddr @ xn ] define
"hpst+" [ regaddr dup @ {xr} @ f+ swap ! ] define
"hpst-" [ regaddr dup @ {xr} @ f- swap ! ] define
"hpst*" [ regaddr dup @ {xr} @ f* swap ! ] define
"hpst/" [ regaddr dup @ {xr} @ f/ swap ! ] define
"clrg" [ 0 {i2} ! begin {i2} @ 100 < while 0.0 {i2} @ regaddr ! {i2} @ 1 + {i2} ! repeat ] define

( --- dse: decrement reg, true while loop continues --- )
"hpdse" [ regaddr dup @ 1.0 fneg f+ dup rot ! 0.0 f> ] define

( --- flags, taking n from the stack --- )
"hpsf" [ xf2 {hpflg} @ or {hpflg} ! ] define
"hpfs?" [ xf2 {hpflg} @ and ] define
"hpcf" [ dup hpfs? if xf2 {hpflg} @ xor {hpflg} ! else drop then ] define

( --- predicates returning flags for skip-next translation --- )
"hpx=0?" [ {xr} @ 0.0 f= ] define
"hpx!=0?" [ {xr} @ 0.0 f= not ] define
"hpx<0?" [ {xr} @ 0.0 f< ] define
"hpx>0?" [ {xr} @ 0.0 f> ] define
"hpx<=0?" [ {xr} @ 0.0 f> not ] define
"hpx>=0?" [ {xr} @ 0.0 f< not ] define
"hpx=y?" [ {xr} @ {yr} @ f= ] define
"hpx!=y?" [ {xr} @ {yr} @ f= not ] define
"hpx<y?" [ {xr} @ {yr} @ f< ] define
"hpx>y?" [ {xr} @ {yr} @ f> ] define
"hpx<=y?" [ {xr} @ {yr} @ f> not ] define
"hpx>=y?" [ {xr} @ {yr} @ f< not ] define


( --- alpha register: a STRING object or 0 --- )
"aset" [ {hpa} ! ] define
"cla" [ 0 {hpa} ! ] define
"aview" [ {hpa} @ 0 = not if {hpa} @ . cr then ] define
"aleng" [ {hpa} @ 0 = if 0.0 xn else {hpa} @ len s>f xn then ] define

( --- indirect addressing: register number taken from reg n --- )
"hpstoi" [ regaddr @ f>s hpsto ] define
"hprcli" [ regaddr @ f>s hprcl ] define

( --- isg: increment reg, true while value stays negative --- )
"hpisg" [ regaddr dup @ 1.0 f+ dup rot ! 0.0 f< ] define

( --- statistics in registers 11-16, HP-41 layout --- )
"cls" [
  0.0 11 regaddr ! 0.0 12 regaddr ! 0.0 13 regaddr !
  0.0 14 regaddr ! 0.0 15 regaddr ! 0.0 16 regaddr !
] define

"splus" [
  11 hpst+
  12 regaddr dup @ {xr} @ {xr} @ f* f+ swap !
  13 regaddr dup @ {yr} @ f+ swap !
  14 regaddr dup @ {yr} @ {yr} @ f* f+ swap !
  15 regaddr dup @ {xr} @ {yr} @ f* f+ swap !
  16 regaddr dup @ 1.0 f+ swap !
  16 regaddr @ {xr} !
] define

"sminus" [
  11 hpst-
  12 regaddr dup @ {xr} @ {xr} @ f* f- swap !
  13 regaddr dup @ {yr} @ f- swap !
  14 regaddr dup @ {yr} @ {yr} @ f* f- swap !
  15 regaddr dup @ {xr} @ {yr} @ f* f- swap !
  16 regaddr dup @ 1.0 f- swap !
  16 regaddr @ {xr} !
] define

"mean" [ 11 regaddr @ 16 regaddr @ f/ xn ] define

"sdev" [
  12 regaddr @
  11 regaddr @ 11 regaddr @ f* 16 regaddr @ f/ f-
  16 regaddr @ 1.0 f- f/ fsqrt xn
] define

( --- display --- )
"prx" [ {xr} @ f. cr ] define
"prst" [ {tr} @ f. {zr} @ f. {yr} @ f. {xr} @ f. cr ] define

( --- init --- )
"xrpn-init" [ clst clrg 0 {hpflg} ! 0.0 {lr} ! ] define

( --- run an editor file as source: write programs on the OS --- )
2056 allot {fbuf} !

"nl2sp" [ begin dup c@ 0 = not while dup c@ 10 = over c@ 13 = or if 32 over c! then 1 + repeat drop ] define

"runfile" [
  init-dir-buffer
  {filename} !
  find-file {fsec} !
  {fsec} @ 0 = if "(file not found)" . cr else
    {fsec} @ {fbuf} @ disk-read
    {fsec} @ 1 + {fbuf} @ 512 + disk-read
    {fsec} @ 2 + {fbuf} @ 1024 + disk-read
    {fsec} @ 3 + {fbuf} @ 1536 + disk-read
    0 {fbuf} @ 2048 + c!
    {fbuf} @ nl2sp
    {fbuf} @ eval
  then
] define
( mkdemo: write a program file from code, rftest: run it )
"mkdemo" [
  init-dir-buffer
  "prog" {filename} !
  find-file 0 = if create-file drop then
  "9.0 xn hpsqrt prx" {ps} !
  {ps} @ len {pn} !
  0 {i3} ! begin {i3} @ {pn} @ < while
    {ps} @ 16 + {i3} @ + c@ {fbuf} @ {i3} @ + c!
    {i3} @ 1 + {i3} ! repeat
  0 {fbuf} @ {pn} @ + c!
  {fbuf} @ {file-sector} @ disk-write
  {fbuf} @ 512 + {file-sector} @ 1 + disk-write
  {fbuf} @ 1024 + {file-sector} @ 2 + disk-write
  {fbuf} @ 1536 + {file-sector} @ 3 + disk-write
] define

"rftest" [ "prog" runfile ] define

( --- interactive calculator REPL: type FOCAL, numbers enter X --- )
"lc@" [ {ln} @ 16 + + c@ ] define
"arg2" [ {ln} @ len 6 = if 4 lc@ 48 - 10 * 5 lc@ 48 - + else 4 lc@ 48 - then ] define
"sto?" [ {ln} @ len 4 > 0 lc@ 115 = and 1 lc@ 116 = and 2 lc@ 111 = and 3 lc@ 32 = and ] define
"rcl?" [ {ln} @ len 4 > 0 lc@ 114 = and 1 lc@ 99 = and 2 lc@ 108 = and 3 lc@ 32 = and ] define
"fix?" [ {ln} @ len 4 > 0 lc@ 102 = and 1 lc@ 105 = and 2 lc@ 120 = and 3 lc@ 32 = and ] define

"xnum" [
  app-depth {d0} !
  {ln} @ eval
  app-depth {d0} @ - 0 > if
    dup type 1 = if aset else
      dup 4294967296 < over -4294967296 > and if s>f then xn
    then
  then
] define

"xstep" [
  0 {hd} !
  {ln} @ "+" str= if hp+ 1 {hd} ! then
  {ln} @ "-" str= if hp- 1 {hd} ! then
  {ln} @ "*" str= if hp* 1 {hd} ! then
  {ln} @ "/" str= if hp/ 1 {hd} ! then
  {ln} @ "pow" str= if hppow 1 {hd} ! then
  {ln} @ "chs" str= if hpchs 1 {hd} ! then
  {ln} @ "abs" str= if hpabs 1 {hd} ! then
  {ln} @ "sqrt" str= if hpsqrt 1 {hd} ! then
  {ln} @ "sin" str= if hpsin 1 {hd} ! then
  {ln} @ "cos" str= if hpcos 1 {hd} ! then
  {ln} @ "tan" str= if hptan 1 {hd} ! then
  {ln} @ "atan" str= if hpatan 1 {hd} ! then
  {ln} @ "ln" str= if hpln 1 {hd} ! then
  {ln} @ "log" str= if hplog 1 {hd} ! then
  {ln} @ "exp" str= if hpexp 1 {hd} ! then
  {ln} @ "1/x" str= if hpinv 1 {hd} ! then
  {ln} @ "x^2" str= if hpsq 1 {hd} ! then
  {ln} @ "enter" str= if enter 1 {hd} ! then
  {ln} @ "swap" str= if xy 1 {hd} ! then
  {ln} @ "xy" str= if xy 1 {hd} ! then
  {ln} @ "rdn" str= if rdn 1 {hd} ! then
  {ln} @ "rup" str= if rup 1 {hd} ! then
  {ln} @ "clx" str= if clx 1 {hd} ! then
  {ln} @ "clst" str= if clst 1 {hd} ! then
  {ln} @ "clrg" str= if clrg 1 {hd} ! then
  {ln} @ "lastx" str= if lastx 1 {hd} ! then
  {ln} @ "prst" str= if prst 1 {hd} ! then
  {ln} @ "mean" str= if mean 1 {hd} ! then
  {ln} @ "sdev" str= if sdev 1 {hd} ! then
  {ln} @ "splus" str= if splus 1 {hd} ! then
  {ln} @ "sminus" str= if sminus 1 {hd} ! then
  {ln} @ "cls" str= if cls 1 {hd} ! then
  {ln} @ "cla" str= if cla 1 {hd} ! then
  {ln} @ "aview" str= if aview 1 {hd} ! then
  sto? if arg2 hpsto 1 {hd} ! then
  rcl? if arg2 hprcl 1 {hd} ! then
  fix? if arg2 fix 1 {hd} ! then
  {hd} @ 0 = if xnum then
] define

( --- dashboard: full stack always visible at the top --- )
"clrline" [ {cy} ! 0 {cx} ! begin {cx} @ 80 < while 32 0 {cx} @ {cy} @ screen-char {cx} @ 1 + {cx} ! repeat ] define
"dline" [ {dy} ! {da} ! {dy} @ clrline 0 {dy} @ screen-set {da} @ color! . ] define

"show-xrpn" [
  "a: " 10 0 dline {hpa} @ 0 = not if {hpa} @ . then
  "l: " 13 1 dline {lr} @ f.
  "T: " 11 2 dline {tr} @ f.
  "Z: " 11 3 dline {zr} @ f.
  "Y: " 11 4 dline {yr} @ f.
  "X: " 14 5 dline {xr} @ f.
  0 {cx} ! begin {cx} @ 80 < while 45 8 {cx} @ 6 screen-char {cx} @ 1 + {cx} ! repeat
] define

"xrpn" [
  screen-clear
  begin
    show-xrpn
    7 clrline 8 clrline 9 clrline
    0 7 screen-set 15 color! "> " .
    read-line {ln} !
    {ln} @ "q" str= not {ln} @ "off" str= not and while
    0 8 screen-set
    xstep
  repeat
  14 color! screen-clear
] define
