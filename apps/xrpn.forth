( XRPN runtime: the HP-41 machine model as Simplicity words )
( X Y Z T L are float variables; 100 numbered registers; flags )
( Programs translated from .xrpn by tools/xrpn2forth call these )

( --- state --- )
800 allot {hpreg} !
0 {hpflg} !
11 {sbase} !
rtc + + 1 + {rs2} !

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
"grad" [ 2 {degm} ! ] define
"torad" [ {degm} @ 1 = if fpi f* 180.0 f/ then {degm} @ 2 = if fpi f* 200.0 f/ then ] define
"fromrad" [ {degm} @ 1 = if 180.0 f* fpi f/ then {degm} @ 2 = if 200.0 f* fpi f/ then ] define

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

( --- more math --- )
"hpsign" [ {xr} @ {lr} ! 0.0 {s2} ! {xr} @ 0.0 f> if 1.0 {s2} ! then {xr} @ 0.0 f< if 1.0 fneg {s2} ! then {s2} @ {xr} ! ] define
"hptenx" [ {xr} @ {lr} ! 10.0 {xr} @ fpow {xr} ! ] define
"hpexpx1" [ {xr} @ {lr} ! {xr} @ fexp 1.0 f- {xr} ! ] define
"hpln1x" [ {xr} @ {lr} ! {xr} @ 1.0 f+ fln {xr} ! ] define
"hproot" [ {xr} @ {lr} ! {yr} @ 1.0 {xr} @ f/ fpow {zr} @ {yr} ! {tr} @ {zr} ! {xr} ! ] define
"hppercch" [ {xr} @ {lr} ! {xr} @ {yr} @ f- {yr} @ f/ 100.0 f* {xr} ! ] define
"rand" [ {rs2} @ 6364136223846793005 * 1442695040888963407 + dup {rs2} ! 4294967296 / dup 0 < if 0 swap - then 2147483647 and s>f 2147483648.0 f/ xn ] define
"d_r" [ {xr} @ {lr} ! {xr} @ fpi f* 180.0 f/ {xr} ! ] define
"r_d" [ {xr} @ {lr} ! {xr} @ 180.0 f* fpi f/ {xr} ! ] define
"r_p" [ {xr} @ {lr} ! {yr} @ {xr} @ fatan2 fromrad {p1} ! {xr} @ dup f* {yr} @ dup f* f+ fsqrt {xr} ! {p1} @ {yr} ! ] define
"p_r" [ {xr} @ {lr} ! {yr} @ torad {p1} ! {xr} @ {p1} @ fcos f* {xr} @ {p1} @ fsin f* {yr} ! {xr} ! ] define

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

( arcli: append integer part of X to alpha )
"arcli" [ {xr} @ 0.0 f< if 45 acat-ch then {xr} @ fabs f>s acat-int ] define

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

( --- exchange X with registers and stack letters --- )
"hpxchg" [ regaddr dup @ {xr} @ rot ! {xr} ! ] define
"xchgz" [ {xr} @ {zr} @ {xr} ! {zr} ! ] define
"xchgt" [ {xr} @ {tr} @ {xr} ! {tr} ! ] define
"xchgl" [ {xr} @ {lr} @ {xr} ! {lr} ! ] define

( --- flag extras --- )
"hpfc?" [ hpfs? not ] define
"hpfc?c" [ dup hpfs? not swap hpcf ] define
"invf" [ {hpflg} @ -1 xor {hpflg} ! ] define
"x<>f" [ {hpflg} @ {xr} @ f>s {hpflg} ! s>f {xr} ! ] define
"stoflag" [ {xr} @ f>s {hpflg} ! ] define
"rclflag" [ {hpflg} @ s>f xn ] define

( --- X versus register predicates --- )
"hpx=nn?" [ regaddr @ {xr} @ f= ] define
"hpx!=nn?" [ regaddr @ {xr} @ f= not ] define
"hpx<nn?" [ {xr} @ swap regaddr @ f< ] define
"hpx<=nn?" [ {xr} @ swap regaddr @ f> not ] define
"hpx>nn?" [ {xr} @ swap regaddr @ f> ] define
"hpx>=nn?" [ {xr} @ swap regaddr @ f< not ] define

( --- statistics in registers 11-16, HP-41 layout --- )
"sreg" [ {sbase} ! ] define
"sra" [ {sbase} @ + regaddr ] define
"cls" [
  0.0 0 sra ! 0.0 1 sra ! 0.0 2 sra !
  0.0 3 sra ! 0.0 4 sra ! 0.0 5 sra !
] define

"splus" [
  0 sra dup @ {xr} @ f+ swap !
  1 sra dup @ {xr} @ {xr} @ f* f+ swap !
  2 sra dup @ {yr} @ f+ swap !
  3 sra dup @ {yr} @ {yr} @ f* f+ swap !
  4 sra dup @ {xr} @ {yr} @ f* f+ swap !
  5 sra dup @ 1.0 f+ swap !
  5 sra @ {xr} !
] define

"sminus" [
  0 sra dup @ {xr} @ f- swap !
  1 sra dup @ {xr} @ {xr} @ f* f- swap !
  2 sra dup @ {yr} @ f- swap !
  3 sra dup @ {yr} @ {yr} @ f* f- swap !
  4 sra dup @ {xr} @ {yr} @ f* f- swap !
  5 sra dup @ 1.0 f- swap !
  5 sra @ {xr} !
] define

"mean" [ 0 sra @ 5 sra @ f/ xn ] define

"sdev" [
  1 sra @
  0 sra @ 0 sra @ f* 5 sra @ f/ f-
  5 sra @ 1.0 f- f/ fsqrt xn
] define
"correct" [
  5 sra @ 4 sra @ f* 0 sra @ 2 sra @ f* f-
  5 sra @ 1 sra @ f* 0 sra @ dup f* f-
  5 sra @ 3 sra @ f* 2 sra @ dup f* f-
  f* fsqrt f/ xn
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

( --- alpha extras --- )
"ashf" [ alen0 {n1} ! {n1} @ 7 < if cla else
  {n1} @ 6 - {n2} ! {n2} @ anew {na} !
  0 {i4} ! begin {i4} @ {n2} @ < while
    {hpa} @ 22 + {i4} @ + c@ {na} @ 16 + {i4} @ + c!
    {i4} @ 1 + {i4} ! repeat
  0 {na} @ 16 + {n2} @ + c!
  {na} @ {hpa} ! then ] define

"posa" [ 0 {p2} ! alen0 {n1} ! 0 {i4} !
  begin {i4} @ {n1} @ < while
    {hpa} @ 16 + {i4} @ + c@ {xr} @ f>s = {p2} @ 0 = and if {i4} @ 1 + {p2} ! then
    {i4} @ 1 + {i4} ! repeat
  {xr} @ {lr} ! {p2} @ s>f {xr} ! ] define

"anum" [ 0 {i4} ! alen0 {n1} ! 0 {av} ! 0 {af} ! 0 {ac} ! 0 {am} !
  begin {i4} @ {n1} @ < while
    {hpa} @ 16 + {i4} @ + c@ {hc} !
    {hc} @ 47 > {hc} @ 58 < and if
      {am} @ 2 = if
        {ac} @ 9 < if {af} @ 10 * {hc} @ 48 - + {af} ! {ac} @ 1 + {ac} ! then
      else {av} @ 10 * {hc} @ 48 - + {av} ! 1 {am} ! then
    then
    {hc} @ 46 = {am} @ 1 = and if 2 {am} ! then
    {hc} @ 47 > {hc} @ 58 < and not {hc} @ 46 = not and {am} @ 0 > and if {n1} @ {i4} ! then
    {i4} @ 1 + {i4} ! repeat
  {av} @ s>f
  {ac} @ 0 > if {af} @ s>f begin {ac} @ 0 > while 10.0 f/ {ac} @ 1 - {ac} ! repeat f+ then
  xn ] define

( --- time: rtc-backed HP time words --- )
"hr" [ {xr} @ {lr} ! {xr} @ f>s s>f {t1} ! {xr} @ {t1} @ f- 100.0 f* {t2} !
  {t2} @ f>s s>f {t3} ! {t2} @ {t3} @ f- 100.0 f* {t4} !
  {t1} @ {t3} @ 60.0 f/ f+ {t4} @ 3600.0 f/ f+ {xr} ! ] define
"hms" [ {xr} @ {lr} ! {xr} @ f>s s>f {t1} ! {xr} @ {t1} @ f- 60.0 f* {t2} !
  {t2} @ f>s s>f {t3} ! {t2} @ {t3} @ f- 60.0 f* {t4} !
  {t1} @ {t3} @ 100.0 f/ f+ {t4} @ 10000.0 f/ f+ {xr} ! ] define
"hms+" [ hr {xr} @ {t5} ! hpdrop hr {xr} @ {t5} @ f+ {xr} ! hms ] define
"hms-" [ hr {xr} @ {t5} ! hpdrop hr {xr} @ {t5} @ f- {xr} ! hms ] define
"time" [ rtc {t3} ! {t2} ! {t1} !
  {t3} @ s>f {t2} @ s>f 100.0 f/ f+ {t1} @ s>f 10000.0 f/ f+ xn ] define
"date" [ rtcd {t3} ! {t2} ! {t1} !
  {t2} @ s>f {t1} @ s>f 100.0 f/ f+ {t3} @ s>f 1000000.0 f/ f+ xn ] define
"dow" [ rtcd {t3} ! {t2} ! {t1} !
  {t2} @ 3 < if {t2} @ 12 + {t2} ! {t3} @ 1 - {t3} ! then
  {t1} @ {t2} @ 1 + 13 * 5 / + {t3} @ + {t3} @ 4 / + {t3} @ 100 / - {t3} @ 400 / + 7 mod
  6 + 7 mod s>f xn ] define

( --- sound: HP tone numbers 0-9 --- )
"tone" [ {tn} ! 440 {tf} !
  {tn} @ 0 = if 220 {tf} ! then
  {tn} @ 1 = if 247 {tf} ! then
  {tn} @ 2 = if 262 {tf} ! then
  {tn} @ 3 = if 294 {tf} ! then
  {tn} @ 4 = if 330 {tf} ! then
  {tn} @ 5 = if 349 {tf} ! then
  {tn} @ 6 = if 392 {tf} ! then
  {tn} @ 7 = if 440 {tf} ! then
  {tn} @ 8 = if 494 {tf} ! then
  {tn} @ 9 = if 523 {tf} ! then
  {tf} @ 4 beep ] define
( aviewc: aview in VGA color X )
"aviewc" [ {xr} @ f>s 15 and color! aview 15 color! ] define
( tonexy: frequency X Hz for Y seconds )
"tonexy" [ {xr} @ f>s {yr} @ 18.0 f* f>s beep ] define
"pse" [ 18 {i5} ! begin {i5} @ 0 > while waittick {i5} @ 1 - {i5} ! repeat ] define

( --- keys --- )
"getkey" [ key s>f xn ] define
"getkeyx" [ key? s>f xn ] define

( --- display and misc --- )
"view" [ regaddr @ f. cr ] define
"cld" [ screen-clear ] define
"adv" [ cr ] define
"pra" [ aview ] define
"prregs" [ 0 {i5} ! begin {i5} @ 100 < while
  {i5} @ regaddr @ dup 0.0 f= not if {i5} @ . 58 emit 32 emit f. cr else drop then
  {i5} @ 1 + {i5} ! repeat ] define
"prflags" [ {hpflg} @ . cr ] define
"geir" [ cr "Geir Isene <g@isene.com> https://isene.com" . cr
  "Creator of the XRPN programming language." . cr ] define
"xversion" [ "XRPN on Simplicity OS" . cr ] define
"hpsize" [ drop ] define
"sizeq" [ 100.0 xn ] define


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

"tone?" [ {ln} @ len 5 > 0 lc@ 116 = and 1 lc@ 111 = and 2 lc@ 110 = and 3 lc@ 101 = and 4 lc@ 32 = and ] define
"view?" [ {ln} @ len 5 > 0 lc@ 118 = and 1 lc@ 105 = and 2 lc@ 101 = and 3 lc@ 119 = and 4 lc@ 32 = and ] define
"sreg?" [ {ln} @ len 5 > 0 lc@ 115 = and 1 lc@ 114 = and 2 lc@ 101 = and 3 lc@ 103 = and 4 lc@ 32 = and ] define
"size?" [ {ln} @ len 5 > 0 lc@ 115 = and 1 lc@ 105 = and 2 lc@ 122 = and 3 lc@ 101 = and 4 lc@ 32 = and ] define
"xchg?" [ {ln} @ len 4 > 0 lc@ 120 = and 1 lc@ 60 = and 2 lc@ 62 = and 3 lc@ 32 = and ] define
"xchgarg" [ 0 {xh} ! 4 lc@ {xc} !
  {xc} @ 121 = if xy 1 {xh} ! then
  {xc} @ 122 = if xchgz 1 {xh} ! then
  {xc} @ 116 = if xchgt 1 {xh} ! then
  {xc} @ 108 = if xchgl 1 {xh} ! then
  {xh} @ 0 = if 4 arg-at hpxchg then ] define

"sf?" [ {ln} @ len 3 > 0 lc@ 115 = and 1 lc@ 102 = and 2 lc@ 32 = and ] define
"cf?" [ {ln} @ len 3 > 0 lc@ 99 = and 1 lc@ 102 = and 2 lc@ 32 = and ] define
"fsq?" [ {ln} @ len 4 > 0 lc@ 102 = and 1 lc@ 115 = and 2 lc@ 63 = and 3 lc@ 32 = and ] define
"fcq?" [ {ln} @ len 4 > 0 lc@ 102 = and 1 lc@ 99 = and 2 lc@ 63 = and 3 lc@ 32 = and ] define
"fsqc?" [ {ln} @ len 5 > 0 lc@ 102 = and 1 lc@ 115 = and 2 lc@ 63 = and 3 lc@ 99 = and 4 lc@ 32 = and ] define
"fcqc?" [ {ln} @ len 5 > 0 lc@ 102 = and 1 lc@ 99 = and 2 lc@ 63 = and 3 lc@ 99 = and 4 lc@ 32 = and ] define
"stx?" [ {ln} @ len 4 > 0 lc@ 115 = and 1 lc@ 116 = and 3 lc@ 32 = and
  2 lc@ 43 = 2 lc@ 45 = or 2 lc@ 42 = or 2 lc@ 47 = or and ] define
"yn" [ if "YES" . else "NO" . then cr ] define

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
  {ln} @ "sign" str= if hpsign 1 {hd} ! then
  {ln} @ "tenx" str= if hptenx 1 {hd} ! then
  {ln} @ "expx1" str= if hpexpx1 1 {hd} ! then
  {ln} @ "ln1x" str= if hpln1x 1 {hd} ! then
  {ln} @ "root" str= if hproot 1 {hd} ! then
  {ln} @ "recip" str= if hpinv 1 {hd} ! then
  {ln} @ "sqr" str= if hpsq 1 {hd} ! then
  {ln} @ "percentch" str= if hppercch 1 {hd} ! then
  {ln} @ "rand" str= if rand 1 {hd} ! then
  {ln} @ "lift" str= if enter 1 {hd} ! then
  {ln} @ "grad" str= if grad 1 {hd} ! then
  {ln} @ "d_r" str= if d_r 1 {hd} ! then
  {ln} @ "r_d" str= if r_d 1 {hd} ! then
  {ln} @ "p_r" str= if p_r 1 {hd} ! then
  {ln} @ "r_p" str= if r_p 1 {hd} ! then
  {ln} @ "d-r" str= if d_r 1 {hd} ! then
  {ln} @ "r-d" str= if r_d 1 {hd} ! then
  {ln} @ "p-r" str= if p_r 1 {hd} ! then
  {ln} @ "r-p" str= if r_p 1 {hd} ! then
  {ln} @ "invf" str= if invf 1 {hd} ! then
  {ln} @ "x<>f" str= if x<>f 1 {hd} ! then
  {ln} @ "stoflag" str= if stoflag 1 {hd} ! then
  {ln} @ "rclflag" str= if rclflag 1 {hd} ! then
  {ln} @ "ashf" str= if ashf 1 {hd} ! then
  {ln} @ "anum" str= if anum 1 {hd} ! then
  {ln} @ "posa" str= if posa 1 {hd} ! then
  {ln} @ "correct" str= if correct 1 {hd} ! then
  {ln} @ "hr" str= if hr 1 {hd} ! then
  {ln} @ "hms" str= if hms 1 {hd} ! then
  {ln} @ "hms+" str= if hms+ 1 {hd} ! then
  {ln} @ "hms-" str= if hms- 1 {hd} ! then
  {ln} @ "time" str= if time 1 {hd} ! then
  {ln} @ "date" str= if date 1 {hd} ! then
  {ln} @ "dow" str= if dow 1 {hd} ! then
  {ln} @ "pse" str= if pse 1 {hd} ! then
  {ln} @ "getkey" str= if getkey 1 {hd} ! then
  {ln} @ "cld" str= if cld 1 {hd} ! then
  {ln} @ "adv" str= if adv 1 {hd} ! then
  {ln} @ "pra" str= if pra 1 {hd} ! then
  {ln} @ "prregs" str= if prregs 1 {hd} ! then
  {ln} @ "prflags" str= if prflags 1 {hd} ! then
  {ln} @ "geir" str= if geir 1 {hd} ! then
  {ln} @ "version" str= if xversion 1 {hd} ! then
  {ln} @ "sizeq" str= if sizeq 1 {hd} ! then
  {ln} @ "add" str= if hp+ 1 {hd} ! then
  {ln} @ "subtract" str= if hp- 1 {hd} ! then
  {ln} @ "multiply" str= if hp* 1 {hd} ! then
  {ln} @ "divide" str= if hp/ 1 {hd} ! then
  {ln} @ "beep" str= if 7 tone 1 {hd} ! then
  {ln} @ "pi" str= if 3.141592653589793 xn 1 {hd} ! then
  {ln} @ "arcli" str= if arcli 1 {hd} ! then
  {ln} @ "tonexy" str= if tonexy 1 {hd} ! then
  {ln} @ "aviewc" str= if aviewc 1 {hd} ! then
  {ln} @ "x=0?" str= if hpx=0? yn 1 {hd} ! then
  {ln} @ "x!=0?" str= if hpx!=0? yn 1 {hd} ! then
  {ln} @ "x#0?" str= if hpx!=0? yn 1 {hd} ! then
  {ln} @ "x<0?" str= if hpx<0? yn 1 {hd} ! then
  {ln} @ "x>0?" str= if hpx>0? yn 1 {hd} ! then
  {ln} @ "x<=0?" str= if hpx<=0? yn 1 {hd} ! then
  {ln} @ "x>=0?" str= if hpx>=0? yn 1 {hd} ! then
  {ln} @ "x=y?" str= if hpx=y? yn 1 {hd} ! then
  {ln} @ "x!=y?" str= if hpx!=y? yn 1 {hd} ! then
  {ln} @ "x#y?" str= if hpx!=y? yn 1 {hd} ! then
  {ln} @ "x<y?" str= if hpx<y? yn 1 {hd} ! then
  {ln} @ "x>y?" str= if hpx>y? yn 1 {hd} ! then
  {ln} @ "x<=y?" str= if hpx<=y? yn 1 {hd} ! then
  {ln} @ "x>=y?" str= if hpx>=y? yn 1 {hd} ! then
  tone? if 5 arg-at tone 1 {hd} ! then
  sf? if 3 arg-at hpsf 1 {hd} ! then
  cf? if 3 arg-at hpcf 1 {hd} ! then
  fsqc? if 5 arg-at hpfs?c yn 1 {hd} ! then
  fcqc? if 5 arg-at hpfc?c yn 1 {hd} ! then
  fsq? if 4 arg-at hpfs? yn 1 {hd} ! then
  fcq? if 4 arg-at hpfc? yn 1 {hd} ! then
  stx? if 4 arg-at 2 lc@ 43 = if hpst+ else 2 lc@ 45 = if hpst-
    else 2 lc@ 42 = if hpst* else hpst/ then then then 1 {hd} ! then
  view? if 5 arg-at view 1 {hd} ! then
  sreg? if 5 arg-at sreg 1 {hd} ! then
  size? if 5 arg-at hpsize 1 {hd} ! then
  xchg? if xchgarg 1 {hd} ! then
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
