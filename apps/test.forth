"showkey" [ begin key dup . cr dup 113 = until drop ] define
"testesc" [ key-escape . ] define
"show-editor-y" [ {editor-y} @ . ] define
"show-y-addr" [ {editor-y} . ] define
"vc" [ varcount . ] define
"loop1" [ 5 begin dup . cr 1 - dup 0 = until drop ] define
"show-xy" [ {editor-x} @ . {editor-y} @ . ] define
"right2" [ {editor-x} @ 78 < if {editor-x} @ 1 + {editor-x} ! then ] define
"test-right2" [ show-xy right2 show-xy ] define
"test-right" [ show-xy editor-right show-xy ] define
"set-x-5" [ 5 {editor-x} ! ] define
"test-shared" [ show-xy set-x-5 editor-right show-xy ] define
"loop2" [ 0 begin dup 3 < while 1 + repeat ] define
"loop3" [ 0 begin dup 3 < while dup drop 1 + repeat ] define
"loop16" [ 0 begin dup 16 < while dup drop 1 + repeat drop ] define
"ktest" [ key? . ] define
"kloop" [ 1 {run} ! begin {run} @ while key? dup 113 = if 0 {run} ! then drop repeat ] define

( Test literal values to find crash boundary )
"t100" [ 0 begin 1 + dup 100 > until . ] define
"t1k" [ 0 begin 1 + dup 1000 > until . ] define
"t10k" [ 0 begin 1 + dup 10000 > until . ] define
"t50k" [ 0 begin 1 + dup 50000 > until . ] define
"t60k" [ 0 begin 1 + dup 60000 > until . ] define
"t65k" [ 0 begin 1 + dup 65000 > until . ] define
"t65535" [ 0 begin 1 + dup 65535 > until . ] define
"t65536" [ 0 begin 1 + dup 65536 > until . ] define
"p65535" [ 65535 . ] define
"p65536" [ 65536 . ] define
"p65537" [ 65537 . ] define
"p100k" [ 100000 . ] define
"t70k" [ 0 begin 1 + dup 70000 > until . ] define
"t100k" [ 0 begin 1 + dup 100000 > until . ] define
"t500k" [ 0 begin 1 + dup 500000 > until . ] define
"t1m" [ 0 begin 1 + dup 1000000 > until . ] define
"t2m" [ 0 begin 1 + dup 2000000 > until . ] define
"t3m" [ 0 begin 1 + dup 3000000 > until . ] define
"twhile" [ 0 begin dup 5 < while 1 + repeat . ] define
