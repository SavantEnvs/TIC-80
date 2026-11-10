# s7's `mark_rootlet` dereferences NULL during a GC triggered in `initScheme`

`mark_rootlet()` (vendor/s7/s7.c:7245, `gc_mark(slot_value(*tmp++))`) reads a slot from the rootlet's
slot table that is not a valid slot pointer while `gc()` (:7314) is running. ASan:
`SEGV on unknown address 0x0000000001cd ... READ ... in mark_rootlet s7.c:7245:13` (a zero-page address, so
Mayhem files it as a NULL pointer dereference), reached as
`try_to_call_gc` (:7636) <- `inline_make_let` (:8763) <- `op_c_catch` (:51217) <- `eval` <-
`s7_load_c_string_with_environment` <- `initScheme` (src/api/scheme.c:1208, which loads the cart's own code)
<- `tic_init_vm` (src/core/core.c:432) <- `tic_core_tick`. So it fires while s7 evaluates the cart's code.

`repro.bin` is the input of Mayhem defect #3595747 (`fuzz-script-run`, run 1). Its first byte (`04`)
selects the language. Run:
`/mayhem/fuzz_script_run-standalone mayhem/known-findings/s7-mark-rootlet-null/repro.bin`.
