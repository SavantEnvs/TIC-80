# png_read has no libpng error handler, so a corrupt PNG aborts

`png_read()` (src/ext/png.c:65, `png_read_info`) creates its `png_struct` without an error function and
never calls `setjmp`, so any libpng error on a malformed PNG goes `png_error` -> `png_default_error` ->
`png_longjmp` -> `abort()` (vendor/libpng/pngerror.c:775). A `.tic` cart is PNG-wrapped, so `tic_cart_load`
reaches it with whatever the file holds. Output of the standalone binary: `libpng error: PNG unsigned
integer out of range`, then SIGABRT (exit 134). There is no ASan report; Mayhem files it as
`png_longjmp @ pngerror.c:775` (CWE-20).

`repro.tic` is the input of Mayhem defect #3595749 (`fuzz-cart-load`, run 1). Run:
`/mayhem/fuzz_cart_load-standalone mayhem/known-findings/png-no-error-handler/repro.tic`.
