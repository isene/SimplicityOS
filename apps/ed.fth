( Simplicity Editor )
( Run: "ed" load ed-run )

4096 allot [ebuf] !
0 [ex] !
0 [ey] !
0 [emode] !

: eclear [ebuf] @ 512 32 fill ;

: epos [ey] @ 80 * [ex] @ + 2 * 0xB8000 + [cursor] ! ;

: eput
  [ey] @ 80 * [ex] @ + [ebuf] @ + c!
  [ey] @ 80 * [ex] @ + 2 * 0xB8000 + dup
  [ebuf] @ [ey] @ 80 * + [ex] @ + c@ swap c!
  7 swap 1 + c!
  [ex] @ 1 + dup 79 > if drop 79 then [ex] !
  epos
;

: ed-run
  eclear
  0 [ex] ! 0 [ey] ! 0 [emode] !
  epos
  begin
    key
    [emode] @ if
      dup 27 = if 0 [emode] ! drop else
      dup 8 = if [ex] @ 0 > if [ex] @ 1 - [ex] ! then drop else
      dup 10 = if 0 [ex] ! [ey] @ 23 < if [ey] @ 1 + [ey] ! then drop else
      dup 32 < if drop else eput then then then then
      epos
    else
      dup 113 = if drop 1 else
      dup 105 = if 1 [emode] ! drop 0 else
      dup 104 = if [ex] @ 0 > if [ex] @ 1 - [ex] ! then drop 0 else
      dup 108 = if [ex] @ 79 < if [ex] @ 1 + [ex] ! then drop 0 else
      dup 106 = if [ey] @ 23 < if [ey] @ 1 + [ey] ! then drop 0 else
      dup 107 = if [ey] @ 0 > if [ey] @ 1 - [ey] ! then drop 0 else
      drop 0
      then then then then then then
      epos
    then
  until
;
