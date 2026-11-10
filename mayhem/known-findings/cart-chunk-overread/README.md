# tic_cart_load copies a chunk larger than the input

`LOAD_CHUNK` in src/cart.c:143 takes the chunk's declared `size` from the file and `memcpy`s that many
bytes from the input buffer without checking it against `end`, so a chunk header that claims more bytes than
remain is a heap-buffer-overflow READ (ASan `READ of size 11520 ... in __asan_memcpy ... tic_cart_load`).

`repro.tic` was found by `fuzz_cart_load` mutating the seed corpus. Run:
`/mayhem/fuzz_cart_load-standalone mayhem/known-findings/cart-chunk-overread/repro.tic`.

The same missing check feeds the `CHUNK_COVER` path (src/cart.c:222): `gif_read_data(ptr,
retro_le_to_cpu16(chunk->size))` gives the GIF decoder the chunk's declared size, so a cover chunk that
claims more bytes than remain makes `readBuffer` (src/ext/gif.c:193, `memcpy`) read past the input: ASan
`heap-buffer-overflow ... in __asan_memcpy ... readBuffer gif.c:193:5 ... DGifGetScreenDesc` (Mayhem defect
#3610548, `fuzz-cart-load` run 3). `repro-cover.tic` is that input:
`/mayhem/fuzz_cart_load-standalone mayhem/known-findings/cart-chunk-overread/repro-cover.tic`.
