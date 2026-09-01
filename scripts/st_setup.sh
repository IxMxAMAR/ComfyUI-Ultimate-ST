#!/usr/bin/env bash
# SillyTavern wiring for the ComfyUI-Ultimate-ST image.
#
# Sourced by scripts/start.sh at pod boot and by scripts/ci_st_gate.sh in CI.
# Kept free of side effects at source time so tests/test_st_setup.sh can source
# it and call individual functions against a sandbox.
#
# Contract: callers set WORKSPACE (default /workspace) and ST_APP (default
# /SillyTavern) before calling anything here.

ST_APP="${ST_APP:-/SillyTavern}"

# Root of all SillyTavern state that must survive pod deletion.
st_state_dir() {
  echo "${WORKSPACE:-/workspace}/sillytavern"
}

# Move a directory's contents onto the volume once, then replace it with a
# symlink. Mirrors the models/output/input/user pattern in the base image's
# start.sh. cp -an never overwrites, so a volume that already has content wins.
st_link_dir() {
  local app="$1" vol="$2"
  mkdir -p "$vol"
  if [ -d "$app" ] && [ ! -L "$app" ]; then
    cp -an "$app/." "$vol/" 2>/dev/null || true
    rm -rf "$app"
  fi
  mkdir -p "$(dirname "$app")"
  ln -sfn "$vol" "$app"
}

# NOTE: node_modules is deliberately absent here. It is ~40k small files and
# belongs on the image's local disk; on network storage it adds minutes to
# every boot.
st_seed_state() {
  local state
  state="$(st_state_dir)"
  mkdir -p "$state/config"
  st_link_dir "$ST_APP/data"                                  "$state/data"
  st_link_dir "$ST_APP/plugins"                               "$state/plugins"
  st_link_dir "$ST_APP/public/scripts/extensions/third-party" "$state/extensions"
}
