#!/usr/bin/env bash
# Fetch TIC-80's git submodules (empty gitlink dirs in the fork) at their pinned commits into
# /opt/toolchains/deps/<name>-<sha12>/src, read-only. Run as root by mayhem/Dockerfile.
set -euo pipefail
list="${1:-mayhem/vendor-deps.txt}"
while read -r name url sha; do
  [ -n "$name" ] || continue
  d="/opt/toolchains/deps/${name}-${sha:0:12}"
  [ -d "$d/src" ] && continue
  mkdir -p "$d/src"
  git -C "$d/src" init -q
  git -C "$d/src" fetch -q --depth 1 "$url" "$sha"
  git -C "$d/src" -c advice.detachedHead=false checkout -q FETCH_HEAD
  rm -rf "$d/src/.git"
  chmod -R a+rX "$d"
done < "$list"
