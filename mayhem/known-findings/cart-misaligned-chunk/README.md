# tic_cart_load dereferences a misaligned Chunk

`nim_bunny.tic` (upstream `templates/nim/`) makes `tic_cart_load` read `Chunk` members through a pointer
into the byte buffer (src/cart.c:153); UBSan reports `member access within misaligned address ... for type
'const Chunk'`. Run: `/mayhem/fuzz_cart_load-standalone nim_bunny.tic`. The same happens for the second
Nim template cart. Not in `testsuite/` because it halts the sanitizer build.
