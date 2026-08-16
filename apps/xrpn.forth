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
