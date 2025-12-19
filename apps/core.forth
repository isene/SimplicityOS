( Core Words - Extended RPN definitions loaded at boot )

( Word listing commands )
"words-kernel" [
  "+ - * / mod = < > <> <= >= 0= and or xor not . .s dup drop swap rot over @ ! c@ c! emit cr ~ ? words execute len type array at put type-new type-name type-set type-name? screen-char screen-clear screen-scroll screen-set key key? key-up key-down key-left key-right key-escape if then else begin until while repeat again app-enter app-exit disk-read disk-write save restore info remove define sort allot load clstk varcount"
] define

"words-core" [
  "words-kernel words-core words-user nip tuck 2dup 2drop 2swap abs negate min max within"
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
