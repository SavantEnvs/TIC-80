# tic_cart_load reads past a short buffer

`tic_cart_load()` (src/cart.c:128) runs `memcmp(buffer, "\x89PNG", 4)` before looking at `size`, so any
input shorter than 4 bytes (including libFuzzer's empty startup probe) is a 4-byte read past the end of the
buffer. ASan: `heap-buffer-overflow ... READ of size 4 ... in tic_cart_load src/cart.c:128`.

`repro.bin` is a 1-byte input. Reproduce it by calling `tic_cart_load(cart, buf, 1)` with `buf` a 1-byte heap
allocation. `fuzz_cart_load` returns -1 for `size < 4` so it can start at all; this is the only input class
that guard hides.
