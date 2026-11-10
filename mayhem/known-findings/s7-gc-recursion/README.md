# s7's garbage collector recurses without bound and overflows the stack

The marker in vendor/s7/s7.c recurses through `gc_mark` -> `mark_slot` -> `mark_let` -> `mark_closure` ->
`gc_mark` ... (s7.c:6838, :6885, :6900, :6908, :6995, :6997, :6999) with no depth limit. A cart's Scheme
code that builds a deep chain of closures and environments makes one GC cycle recurse until the stack is
gone. ASan: `stack-overflow ... in mark_let /mayhem/vendor/s7/s7.c:6900:38` with the same 4 frames
repeating. The sanitizer's larger stack frames make it hit the 8 MiB stack sooner than a plain build would,
but the recursion is unbounded either way. These are stack overflows, not leaks or out-of-memory.

They are 4 of the 5 `fuzz-script-run` defects of run 1 (#3595740, #3595739, #3595731, #3595729), which
differ only in the first frame ASan reports. Run 2 found more inputs with the same stacks and dedups them
into those defects. The runtime is TIC-80's own Scheme one (`WITH_SYSTEM_EXTRAS 0`,
`DISABLE_FILE_IO 1`), the one every Scheme cart runs on.

`repro.bin` is a `fuzz_script_run` input: its first byte (`04`) selects the language, the rest is the code.
Run: `/mayhem/fuzz_script_run-standalone mayhem/known-findings/s7-gc-recursion/repro.bin`.
