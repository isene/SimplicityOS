"loop1" [ 5 begin dup . cr 1 - dup 0 = until drop ] define
"show-y" [ {editor-y} @ . ] define
"test-lt" [ 0 22 < . ] define
"test-if1" [ 1 if 42 . else 99 . then ] define
"inc-y" [ {editor-y} @ 1 + {editor-y} ! ] define
"test-inc" [ {editor-y} @ . inc-y {editor-y} @ . ] define
"down2" [ {editor-y} @ 22 < if {editor-y} @ 1 + {editor-y} ! then ] define
"test-d2" [ {editor-y} @ . down2 {editor-y} @ . ] define
