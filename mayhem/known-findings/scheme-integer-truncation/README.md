# schemeInteger converts an out-of-range double to `s7_int`

`schemeInteger()` (src/api/scheme.c:64) is `(s7_int)schemeNumber(sc, value)`, where `schemeNumber` returns
any finite `double` a cart passes (a number, or a string that `strtod` accepts). A value outside the range of
`long`, such as `1e55` or the digits of a long numeric string, is undefined behavior in the C conversion.
UBSan: `scheme.c:64:12: runtime error: 1.66667e+55 is outside the range of representable values of type
'long'` (also seen with `nan`, which `s7_is_real` accepts). The callers (`schemeInteger(...)` in the API functions from scheme.c:89 on) go on to narrow the
result to `s32`/`u8`, so the value is meaningless either way, and Mayhem files it as a numeric truncation.

`repro.bin` is the input of Mayhem defect #3610427 (`fuzz-script-run`, run 2); its first byte (`04`)
selects the language. Run:
`/mayhem/fuzz_script_run-standalone mayhem/known-findings/scheme-integer-truncation/repro.bin`.
