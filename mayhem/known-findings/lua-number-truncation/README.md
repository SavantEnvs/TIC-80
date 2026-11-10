# getLuaNumber converts an out-of-range double to `s32`

`getLuaNumber()` (src/api/luaapi.c:35) is `(s32)lua_tonumber(lua, index)`. A script that passes a number
outside the range of `int` to any API function that reads its arguments this way (the Lua-family runtimes
share this file) is undefined behavior in the C conversion. UBSan: `luaapi.c:35:12: runtime error: 6e+125 is
outside the range of representable values of type 'int'`. It is the same kind of bug as
`scheme-integer-truncation`, in a different runtime's argument reader.

`repro.bin` is the input of Mayhem defect #3610488 (`fuzz-script-run`, run 3); its first byte (`02`) selects
the language. Run:
`/mayhem/fuzz_script_run-standalone mayhem/known-findings/lua-number-truncation/repro.bin`.
