( Core Words - Extended RPN definitions loaded at boot )

( Word listing commands - alphabetically sorted )
"words-kernel" [
  "! * + - . .s / 0= < <= <> = > >= ? @ again allot and app-enter app-exit array at begin c! c@ clstk cr cursor-hide cursor-show define disk-read disk-write drop dup edit else emit execute free if info key key-down key-escape key-left key-right key-up key? len load mod not or over put remove repeat restore rot save screen-char screen-clear screen-get screen-line-shift screen-scroll screen-set sort swap then type type-name type-name? type-new type-set until varcount vars while words xor ~"
] define

"words-core" [
  "2drop 2dup 2swap abs max min negate nip tuck within words-core words-kernel words-user"
] define

"words-user" [
  "editor hello invaders test"
] define

( Common stack words )
"nip" [ swap drop ] define
"tuck" [ swap over ] define
"2dup" [ over over ] define
"2drop" [ drop drop ] define
"2swap" [ {2s-d} ! {2s-c} ! {2s-b} ! {2s-a} ! {2s-c} @ {2s-d} @ {2s-a} @ {2s-b} @ ] define

( Math helpers )
"abs" [ dup 0 < if 0 swap - then ] define
"negate" [ 0 swap - ] define
"min" [ 2dup > if swap then drop ] define
"max" [ 2dup < if swap then drop ] define
( within: lo <= n < hi )
"within" [ {wi-h} ! {wi-l} ! {wi-n} ! {wi-n} @ {wi-l} @ >= {wi-n} @ {wi-h} @ < and ] define
