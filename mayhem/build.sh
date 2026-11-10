#!/usr/bin/env bash
#
# mayhem/build.sh — builds TIC-80's three libFuzzer harnesses (+ run-once -standalone twins) and the
# project's own test suite. Runs in the commit image as `mayhem` in /mayhem; offline-safe and re-runnable.
#
#  * Every vendor/* directory is a git submodule, empty in a fork. The Dockerfile fetched each pinned
#    commit into /opt/toolchains/deps/<name>-<sha12>/src (mayhem/vendor-deps.txt); they are copied into
#    vendor/<name> here. Git sees those paths as submodule gitlinks, so the tree stays clean.
#  * Fuzz build: TIC-80's own code (core, cart, script bindings, project parser) with ASan+UBSan+SanCov;
#    the vendored interpreters/libraries are built plain with DWARF 3 (see mayhem/fuzz.cmake).
#  * Test build: normal Release flags, in its own directory, so test.sh is an honest oracle.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# 1) Submodule sources from the image's dependency cache.
while read -r name url sha; do
  [ -n "$name" ] || continue
  mkdir -p "vendor/$name"
  cp -ru --no-preserve=ownership "/opt/toolchains/deps/${name}-${sha:0:12}/src/." "vendor/$name/"
done < mayhem/vendor-deps.txt

# Options shared by both builds: every script language that builds headless, static runtime, no window system.
# (YUE, WASM, GRAVITY and RUBY stay off: they fetch or generate sources the air-gapped build cannot.)
COMMON_CMAKE=(
  -G Ninja -DCMAKE_C_COMPILER="$CC"
  -DBUILD_WITH_ALL=ON -DBUILD_WITH_YUE=OFF -DBUILD_WITH_WASM=OFF -DBUILD_WITH_GRAVITY=OFF -DBUILD_WITH_RUBY=OFF
  -DBUILD_SDL=OFF -DBUILD_SOKOL=OFF -DBUILD_SDLGPU=OFF -DBUILD_PLAYER=OFF -DBUILD_TOOLS=OFF
)

# CMake wipes the whole cache (command-line -D options included) when the compiler path it resolves changes,
# e.g. the Dockerfile's ccache pre-fill puts a ccache shim first in PATH and a plain re-run does not.
# Start such a tree over instead.
reset_if_compiler_changed() {
  local cached
  cached="$(sed -n 's/^CMAKE_C_COMPILER:[A-Z]*=//p' "$1/CMakeCache.txt" 2>/dev/null || true)"
  if [ -n "$cached" ] && [ "$cached" != "$(command -v "$CC")" ]; then rm -rf "$1"; fi
}
reset_if_compiler_changed mayhem/build-fuzz
reset_if_compiler_changed mayhem/build-test

# 2) Sanitized fuzz build.
mkdir -p mayhem/build-fuzz
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o mayhem/build-fuzz/lsan_off.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link -c "$STANDALONE_FUZZ_MAIN" -o mayhem/build-fuzz/standalone_main.o

FUZZ_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -O1 -fsanitize=fuzzer-no-link"
cmake -S . -B mayhem/build-fuzz "${COMMON_CMAKE[@]}" \
  -DBUILD_TESTS=OFF -DCMAKE_BUILD_TYPE= \
  -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$SANITIZER_FLAGS" \
  -DCMAKE_PROJECT_INCLUDE="$SRC/mayhem/fuzz.cmake" -DMAYHEM_FUZZ=ON \
  -DMAYHEM_LSAN_OFF_OBJ="$SRC/mayhem/build-fuzz/lsan_off.o" \
  -DMAYHEM_STANDALONE_MAIN_OBJ="$SRC/mayhem/build-fuzz/standalone_main.o" \
  -DMAYHEM_LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE"
cmake --build mayhem/build-fuzz -j"$MAYHEM_JOBS" --target \
  fuzz_cart_load fuzz_cart_load-standalone \
  fuzz_project_load fuzz_project_load-standalone \
  fuzz_script_run fuzz_script_run-standalone

# 3) The project's own tests, normal flags. console-test is left out: it needs the sound backend that
#    BUILD_SDL/BUILD_SOKOL=OFF removes, so it does not link in a headless build.
TESTS=$(cat mayhem/tests.txt)
cmake -S . -B mayhem/build-test "${COMMON_CMAKE[@]}" \
  -DBUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS"
# shellcheck disable=SC2086
cmake --build mayhem/build-test -j"$MAYHEM_JOBS" --target $TESTS
