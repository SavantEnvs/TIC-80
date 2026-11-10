#!/usr/bin/env bash
# Runs the project's own pre-built ctest binaries (built by build.sh) and asserts each one's final assertion line,
# then the script-API conformance report. CTRF summary on stdout.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}


BIN=mayhem/build-test/bin

# name|last non-empty line the test prints when every one of its assertions held
CASES='js-test|JavaScript runtime tests passed
lua-test|Lua runtime tests passed
forth-test|Forth runtime tests passed
menubar-test|menubar ok
sgamepad-test|sgamepad ok
sgamepad-hid-test|sgamepad_hid ok
sound-test|sound ok
ui-test|ui ok
keyboard-test|keyboard ok
mouse-test|mouse ok
start-test|start ok
embed-test|embed ok
boot-test|boot ok
project-test|project ok
history-test|history checks passed
history-limit-test|history limit checks passed
studio-services-test|services ok
code-find-test|search ok
code-vi-test|asks ok
code-editor-test|view slide ok
map-editor-test|world ok
sfx-editor-test|tooltip ok
sprite-editor-test|scanline ok
music-editor-test|tooltip and pointer ok
menu-test|menu ok
mainmenu-test|mainmenu ok
modes-test|modes ok
modes-test-nosurf|modes ok
run-test|run ok
surf-test|surf ok
code-text-test|trim ok
code-text-test-pro|trim ok
export-test|refusal ok
export-test-pro|refusal ok
fft-test|FFT raw magnitude, smoothing, range and disabled API checks passed
fft-test-stubs|FFT raw magnitude, smoothing, range and disabled API checks passed
vqt-test|VQT tones, gain, smoothing, whitening, capture windows and lifecycle checks passed
vqt-test-stubs|VQT tones, gain, smoothing, whitening, capture windows and lifecycle checks passed
draw-test|draw ok
blit-test|blit ok'

passed=0; failed=0
while IFS='|' read -r name want; do
  [ -n "$name" ] || continue
  if [ ! -x "$BIN/$name" ]; then echo "FAIL $name: $BIN/$name was not built" >&2; failed=$((failed+1)); continue; fi
  out=$(timeout 600 "$BIN/$name" 2>&1); rc=$?
  last=$(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 1)
  if [ "$rc" -eq 0 ] && [ "$last" = "$want" ]; then
    echo "PASS $name"; passed=$((passed+1))
  else
    echo "FAIL $name (rc=$rc, last line: '$last', want: '$want')" >&2; failed=$((failed+1))
  fi
done <<< "$CASES"

# Script API conformance: every language runs the same 133 API probes and must match the reference output.
CONF='js|133
moon|133
fennel|133
scheme|133
squirrel|133
wren|133
janet|133
python|133
miniscript|116
forth|97'
if [ ! -x "$BIN/api-conformance" ]; then
  echo "FAIL api-conformance: $BIN/api-conformance was not built" >&2; failed=$((failed+1))
else
  out=$(timeout 900 "$BIN/api-conformance" tests/conformance/probes 2>&1); rc=$?
  while IFS='|' read -r lang cov; do
    if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qF -- "**$lang: ✅ no divergences, coverage $cov/133**"; then
      echo "PASS api-conformance $lang"; passed=$((passed+1))
    else
      echo "FAIL api-conformance $lang (rc=$rc)" >&2; failed=$((failed+1))
    fi
  done <<< "$CONF"
fi

emit_ctrf cmake-ctest "$passed" "$failed" 0
