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
