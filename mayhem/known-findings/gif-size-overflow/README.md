# readGif multiplies the GIF's width and height in `int`

`readGif()` (src/ext/gif.c:40) computes `gif->SWidth * gif->SHeight * sizeof(GifPixelType)`. `SWidth` and
`SHeight` are the 16-bit-sourced `GifWord` (`int`) fields of the file's screen descriptor, and the product
of the two is taken in `int` before it is widened, so a cover image with a large screen size is a signed
integer overflow. UBSan: `gif.c:40:36: runtime error: signed integer overflow: 63867 * 40448 cannot be
represented in type 'GifWord' (aka 'int')`. The result is then stored in an `s32 size` and passed to
`malloc`/`memset`, so with the overflow ignored the allocation is the wrong size.

A cart reaches it through `tic_cart_load` (src/cart.c:222, the `CHUNK_COVER` chunk, which holds a GIF).
`repro.tic` is the input of Mayhem defect #3610442 (`fuzz-cart-load`, run 2). Run:
`/mayhem/fuzz_cart_load-standalone mayhem/known-findings/gif-size-overflow/repro.tic`.
