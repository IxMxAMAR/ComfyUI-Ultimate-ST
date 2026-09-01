#!/usr/bin/env bash
# shellcheck source=helpers.sh
. "$(dirname "$0")/helpers.sh"

START="$(dirname "$0")/../scripts/start.sh"

echo "-- start.sh integrity"
assert_true "start.sh parses as valid bash" bash -n "$START"
assert_true "ComfyUI is still the exec'd foreground process" \
  grep -qE '^exec python main\.py' "$START"
assert_true "SillyTavern is started before the ComfyUI exec" \
  bash -c "[ \$(grep -n 'st_prepare' '$START' | head -1 | cut -d: -f1) -lt \$(grep -n '^exec python main.py' '$START' | cut -d: -f1) ]"
assert_true "ST_DISABLE escape hatch exists" grep -q 'ST_DISABLE' "$START"
assert_true "the watchdog restarts SillyTavern" grep -q 'restarting' "$START"
assert_true "node_modules is never placed on the volume" \
  bash -c "! grep -q 'node_modules' '$START'"

echo "SUITE_RESULT $TESTS_RUN $TESTS_FAILED $TESTS_SKIPPED"
