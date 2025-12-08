\ hello.forth - Simple test app loaded from disk
\ This demonstrates disk-based app loading

: hello "Hello from disk!" . cr ;

: greet
  "Welcome to Simplicity OS!" . cr
  "Loaded from disk sectors." . cr
;
