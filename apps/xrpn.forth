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

( --- angle mode: HP boots in degrees --- )
1 {degm} !
"deg" [ 1 {degm} ! ] define
"rad" [ 0 {degm} ! ] define
"torad" [ {degm} @ 1 = if fpi f* 180.0 f/ then ] define
"fromrad" [ {degm} @ 1 = if 180.0 f* fpi f/ then ] define

( --- unary on X, L = old X --- )
"hpchs" [ {xr} @ fneg {xr} ! ] define
"hpabs" [ {xr} @ {lr} ! {xr} @ fabs {xr} ! ] define
"hpsqrt" [ {xr} @ {lr} ! {xr} @ fsqrt {xr} ! ] define
"hpsq" [ {xr} @ {lr} ! {xr} @ {xr} @ f* {xr} ! ] define
"hpinv" [ {xr} @ {lr} ! 1.0 {xr} @ f/ {xr} ! ] define
"hpsin" [ {xr} @ {lr} ! {xr} @ torad fsin {xr} ! ] define
"hpcos" [ {xr} @ {lr} ! {xr} @ torad fcos {xr} ! ] define
"hptan" [ {xr} @ {lr} ! {xr} @ torad ftan {xr} ! ] define
"hpatan" [ {xr} @ {lr} ! {xr} @ fatan fromrad {xr} ! ] define
"hpasin" [ {xr} @ {lr} ! {xr} @ dup dup f* 1.0 swap f- fsqrt f/ fatan fromrad {xr} ! ] define
"hpacos" [ {xr} @ {lr} ! {xr} @ dup dup f* 1.0 swap f- fsqrt f/ fatan fpi 2.0 f/ swap f- fromrad {xr} ! ] define
"hpcube" [ {xr} @ {lr} ! {xr} @ dup dup f* f* {xr} ! ] define
"hpfact" [ {xr} @ {lr} ! {xr} @ f>s {fi} ! 1.0 {fa} ! begin {fi} @ 1 > while {fa} @ {fi} @ s>f f* {fa} ! {fi} @ 1 - {fi} ! repeat {fa} @ {xr} ! ] define
"hpmod" [ {xr} @ {lr} ! {yr} @ {xr} @ f/ f>s s>f {xr} @ f* {yr} @ swap f- {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define
"hpperc" [ {xr} @ {lr} ! {yr} @ {xr} @ f* 100.0 f/ {xr} ! ] define
"hpint" [ {xr} @ {lr} ! {xr} @ f>s s>f {xr} ! ] define
"hpfrc" [ {xr} @ {lr} ! {xr} @ dup f>s s>f f- {xr} ! ] define
"hprnd" [ {xr} @ {lr} ! {xr} @ 10000.0 f* dup 0.0 f< if 0.5 f- else 0.5 f+ then f>s s>f 10000.0 f/ {xr} ! ] define
"hpdrop" [ {yr} @ {xr} ! {zr} @ {yr} ! {tr} @ {zr} ! ] define
"hpdropy" [ {zr} @ {yr} ! {tr} @ {zr} ! ] define
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
"hpfs?c" [ dup hpfs? swap hpcf ] define

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

( --- alpha building: new string objects on the heap --- )
16 allot {hbuf} !
"anew" [ dup 17 + allot {ns} ! 1 {ns} @ ! {ns} @ 8 + ! {ns} @ ] define
"alen0" [ {hpa} @ 0 = if 0 else {hpa} @ len then ] define

"acat-ch" [ {ch} ! alen0 {n1} ! {n1} @ 1 + anew {na} !
  0 {i4} ! begin {i4} @ {n1} @ < while
    {hpa} @ 16 + {i4} @ + c@ {na} @ 16 + {i4} @ + c!
    {i4} @ 1 + {i4} ! repeat
  {ch} @ {na} @ 16 + {n1} @ + c!
  0 {na} @ 16 + {n1} @ 1 + + c!
  {na} @ {hpa} ! ] define

"acat-str" [ {as} ! {as} @ len {n2} ! alen0 {n1} !
  {n1} @ {n2} @ + anew {na} !
  0 {i4} ! begin {i4} @ {n1} @ < while
    {hpa} @ 16 + {i4} @ + c@ {na} @ 16 + {i4} @ + c!
    {i4} @ 1 + {i4} ! repeat
  0 {i4} ! begin {i4} @ {n2} @ < while
    {as} @ 16 + {i4} @ + c@ {na} @ 16 + {n1} @ {i4} @ + + c!
    {i4} @ 1 + {i4} ! repeat
  0 {na} @ 16 + {n1} @ {n2} @ + + c!
  {na} @ {hpa} ! ] define

"xtoa" [ {xr} @ f>s acat-ch ] define

"atox" [ alen0 0 = if 0.0 xn else
  {hpa} @ 16 + c@ s>f xn
  alen0 1 - {n1} ! {n1} @ anew {na} !
  0 {i4} ! begin {i4} @ {n1} @ < while
    {hpa} @ 17 + {i4} @ + c@ {na} @ 16 + {i4} @ + c!
    {i4} @ 1 + {i4} ! repeat
  0 {na} @ 16 + {n1} @ + c!
  {na} @ {hpa} ! then ] define

"arot" [ alen0 {n1} ! {n1} @ 0 = if else
  {xr} @ f>s {n1} @ mod dup 0 < if {n1} @ + then {r0} !
  {n1} @ anew {na} !
  0 {i4} ! begin {i4} @ {n1} @ < while
    {hpa} @ 16 + {i4} @ {r0} @ + {n1} @ mod + c@ {na} @ 16 + {i4} @ + c!
    {i4} @ 1 + {i4} ! repeat
  0 {na} @ 16 + {n1} @ + c!
  {na} @ {hpa} ! then ] define

"asto" [ regaddr {hpa} @ swap ! ] define
"arcl" [ regaddr @ dup type 1 = if acat-str else drop then ] define

( --- arcl x: append X as text, FIX-4 style --- )
"acat-int" [ {av} !
  0 {hn} ! begin {av} @ 9 > while
    {av} @ 10 mod {hbuf} @ {hn} @ + c!
    {av} @ 10 / {av} !
    {hn} @ 1 + {hn} ! repeat
  {av} @ {hbuf} @ {hn} @ + c!
  begin {hn} @ 0 < not while
    {hbuf} @ {hn} @ + c@ 48 + acat-ch
    {hn} @ 1 - {hn} ! repeat ] define

"arclx" [
  {xr} @ 0.0 f< if 45 acat-ch then
  {xr} @ fabs dup f>s {ai} !
  {ai} @ s>f f- 10000.0 f* 0.5 f+ f>s {af} !
  {af} @ 9999 > if {ai} @ 1 + {ai} ! 0 {af} ! then
  {ai} @ acat-int
  46 acat-ch
  {af} @ 1000 / 10 mod 48 + acat-ch
  {af} @ 100 / 10 mod 48 + acat-ch
  {af} @ 10 / 10 mod 48 + acat-ch
  {af} @ 10 mod 48 + acat-ch ] define

( --- base conversion: result text goes to alpha --- )
"decbase" [ {bb} ! cla {xr} @ f>s dup 0 < if 0 swap - then {hv} !
  0 {hn} ! begin {hv} @ {bb} @ 1 - > while
    {hv} @ {bb} @ mod {hbuf} @ {hn} @ + c!
    {hv} @ {bb} @ / {hv} !
    {hn} @ 1 + {hn} ! repeat
  {hv} @ {hbuf} @ {hn} @ + c!
  begin {hn} @ 0 < not while
    {hbuf} @ {hn} @ + c@ dup 9 > if 55 + else 48 + then acat-ch
    {hn} @ 1 - {hn} ! repeat ] define

"basedec" [ {bb} ! 0 {hv} ! 0 {i4} ! alen0 {n1} !
  begin {i4} @ {n1} @ < while
    {hpa} @ 16 + {i4} @ + c@ {hc} !
    {hc} @ 48 - {hd2} !
    {hc} @ 64 > if {hc} @ 55 - {hd2} ! then
    {hc} @ 96 > if {hc} @ 87 - {hd2} ! then
    {hv} @ {bb} @ * {hd2} @ + {hv} !
    {i4} @ 1 + {i4} ! repeat
  {hv} @ s>f xn ] define

"dechex" [ 16 decbase ] define
"hexdec" [ 16 basedec ] define
"decbin" [ 2 decbase ] define
"bindec" [ 2 basedec ] define
"decoct" [ 8 decbase ] define
"octdec" [ 8 basedec ] define

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
"arg-at" [ {ap} ! {ln} @ len {ap} @ 2 + = if {ap} @ lc@ 48 - 10 * {ap} @ 1 + lc@ 48 - + else {ap} @ lc@ 48 - then ] define
"arg2" [ 4 arg-at ] define
"sto?" [ {ln} @ len 4 > 0 lc@ 115 = and 1 lc@ 116 = and 2 lc@ 111 = and 3 lc@ 32 = and ] define
"rcl?" [ {ln} @ len 4 > 0 lc@ 114 = and 1 lc@ 99 = and 2 lc@ 108 = and 3 lc@ 32 = and ] define
"fix?" [ {ln} @ len 4 > 0 lc@ 102 = and 1 lc@ 105 = and 2 lc@ 120 = and 3 lc@ 32 = and ] define
"stoi?" [ {ln} @ len 8 > 0 lc@ 115 = and 1 lc@ 116 = and 2 lc@ 111 = and 3 lc@ 32 = and 4 lc@ 105 = and 5 lc@ 110 = and 6 lc@ 100 = and 7 lc@ 32 = and ] define
"rcli?" [ {ln} @ len 8 > 0 lc@ 114 = and 1 lc@ 99 = and 2 lc@ 108 = and 3 lc@ 32 = and 4 lc@ 105 = and 5 lc@ 110 = and 6 lc@ 100 = and 7 lc@ 32 = and ] define
"asto?" [ {ln} @ len 5 > 0 lc@ 97 = and 1 lc@ 115 = and 2 lc@ 116 = and 3 lc@ 111 = and 4 lc@ 32 = and ] define
"arcl?" [ {ln} @ len 5 > 0 lc@ 97 = and 1 lc@ 114 = and 2 lc@ 99 = and 3 lc@ 108 = and 4 lc@ 32 = and ] define

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
  {ln} @ "RIGHT" str= if xy 1 {hd} ! then
  {ln} @ "LEFT" str= if xy 1 {hd} ! then
  {ln} @ "right" str= if xy 1 {hd} ! then
  {ln} @ "left" str= if xy 1 {hd} ! then
  {ln} @ "DOWN" str= if hpdrop 1 {hd} ! then
  {ln} @ "down" str= if hpdrop 1 {hd} ! then
  {ln} @ "UP" str= if rup 1 {hd} ! then
  {ln} @ "up" str= if rup 1 {hd} ! then
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
  {ln} @ "asin" str= if hpasin 1 {hd} ! then
  {ln} @ "acos" str= if hpacos 1 {hd} ! then
  {ln} @ "mod" str= if hpmod 1 {hd} ! then
  {ln} @ "fact" str= if hpfact 1 {hd} ! then
  {ln} @ "%" str= if hpperc 1 {hd} ! then
  {ln} @ "cube" str= if hpcube 1 {hd} ! then
  {ln} @ "drop" str= if hpdrop 1 {hd} ! then
  {ln} @ "dropy" str= if hpdropy 1 {hd} ! then
  {ln} @ "xtoa" str= if xtoa 1 {hd} ! then
  {ln} @ "atox" str= if atox 1 {hd} ! then
  {ln} @ "arot" str= if arot 1 {hd} ! then
  {ln} @ "deg" str= if deg 1 {hd} ! then
  {ln} @ "rad" str= if rad 1 {hd} ! then
  {ln} @ "dechex" str= if dechex 1 {hd} ! then
  {ln} @ "hexdec" str= if hexdec 1 {hd} ! then
  {ln} @ "decbin" str= if decbin 1 {hd} ! then
  {ln} @ "bindec" str= if bindec 1 {hd} ! then
  {ln} @ "decoct" str= if decoct 1 {hd} ! then
  {ln} @ "octdec" str= if octdec 1 {hd} ! then
  {ln} @ "int" str= if hpint 1 {hd} ! then
  {ln} @ "frc" str= if hpfrc 1 {hd} ! then
  {ln} @ "rnd" str= if hprnd 1 {hd} ! then
  {ln} @ "r^" str= if rup 1 {hd} ! then
  {ln} @ "arcl x" str= if arclx 1 {hd} ! then
  stoi? if 8 arg-at hpstoi 1 {hd} ! then
  rcli? if 8 arg-at hprcli 1 {hd} ! then
  asto? if 5 arg-at asto 1 {hd} ! then
  arcl? if 5 arg-at arcl 1 {hd} ! then
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
    {ln} @ "q" str= not
    {ln} @ "off" str= not and
    {ln} @ "end" str= not and
    {ln} @ "END" str= not and while
    0 8 screen-set
    xstep
  repeat
  14 color! screen-clear
] define
