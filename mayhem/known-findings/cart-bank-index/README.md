# tic_cart_load indexes `binary[]` with an unchecked bank

`tic_cart_load()` (src/cart.c:210, `case CHUNK_BINARY`) stores `binary[chunk->bank] = ...`. A chunk's `bank`
is a 3-bit field (0..7) read from the file, but the local `binary` array has `TIC_BINARY_BANKS` = 4 entries
(src/cart.c:184), so a `CHUNK_BINARY` chunk with bank 4..7 writes past the end of the stack array. ASan:
`stack-buffer-overflow ... WRITE of size 4 ... in tic_cart_load /mayhem/src/cart.c:210:43` (`binary` is
`[192, 256)`, the access is at offset 256). The `cart->banks[chunk->bank]` chunks above it index the 8-entry
`banks` array, so only this one overflows. It is a different line from `LOAD_CHUNK(cart->lang)` (:208), which
`MIN(sizeof(to), size)` bounds.

UBSan reports the same bank index as `src/cart.c:210:21: runtime error: index 5 out of bounds for type
'struct BinaryChunk[4]'` (indexes 5, 6 and 7 seen; Mayhem defect #3610433, `fuzz-cart-load` run 2).

`repro.tic` is the input of Mayhem defect #3595745 (`fuzz-cart-load`, run 1). Run:
`/mayhem/fuzz_cart_load-standalone mayhem/known-findings/cart-bank-index/repro.tic`.
