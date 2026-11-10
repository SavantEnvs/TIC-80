# s7 jumps to a heap address while evaluating a cart's code

`initScheme()` (src/api/scheme.c:1208, `s7_load_c_string(sc, code, strlen(code))`) loads the cart's own code
into s7. For `repro.bin` the evaluation ends in a call through a bad function pointer. ASan:
`SEGV on unknown address 0x527000003900 (pc 0x527000003900 ...)`, "PC is at a non-executable region. Maybe a
wild jump?", `#0 <unknown module>`, `#1 initScheme scheme.c:1208:5`, `#2 tic_init_vm core.c:432`. The s7
frames between the jump and `initScheme` are lost, so the root cause inside vendor/s7/s7.c is not pinned
down here. It is in the same family as `s7-mark-rootlet-null` and `s7-gc-recursion` (s7 evaluating hostile
code), and Mayhem files it as an out-of-bounds read.

`repro.bin` is an input of Mayhem defect #3610485 (`fuzz-script-run`, run 3); its first byte (`04`) selects
the language. Run:
`/mayhem/fuzz_script_run-standalone mayhem/known-findings/s7-wild-jump/repro.bin`.
