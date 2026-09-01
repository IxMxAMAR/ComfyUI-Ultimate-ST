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
