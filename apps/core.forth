( Core Words - Extended RPN definitions loaded at boot )

( Word listing commands - alphabetically sorted )
"words-kernel" [
  "! * + - . .s / 0= < <= <> = > >= ? @ again allot and app-enter app-exit array at begin c! c@ clstk cr define disk-read disk-write drop dup else emit execute if info key key-down key-escape key-left key-right key-up key? len load mod not or over put remove repeat restore rot save screen-char screen-clear screen-scroll screen-set sort swap then type type-name type-name? type-new type-set until varcount while words xor ~"
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
"2swap" [ rot rot ] define

( Math helpers )
"abs" [ dup 0 < if 0 swap - then ] define
"negate" [ 0 swap - ] define
"min" [ 2dup > if swap then drop ] define
"max" [ 2dup < if swap then drop ] define
"within" [ over - rot rot - > ] define
