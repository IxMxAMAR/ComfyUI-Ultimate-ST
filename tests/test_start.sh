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

DOCKERFILE="$(dirname "$0")/../Dockerfile"
echo "-- Dockerfile pins"
assert_true "base image is pinned to an exact sha tag, not latest" \
  grep -qE '^FROM ixmxamar/comfyui-ultimate:0cbe95d1635f' "$DOCKERFILE"
assert_true "port 8000 is exposed" grep -qE '^EXPOSE .*8000' "$DOCKERFILE"
assert_true "entrypoint is preserved" grep -q 'ENTRYPOINT \["/opt/start.sh"\]' "$DOCKERFILE"
assert_true "SillyTavern is installed from the pinned sha in st_pin.txt" \
  grep -q 'st_pin.txt' "$DOCKERFILE"

echo "-- ci gate script"
CI_GATE="$(dirname "$0")/../scripts/ci_st_gate.sh"
assert_true "ci_st_gate.sh parses as valid bash" bash -n "$CI_GATE"
assert_true "gate asserts 401 without credentials" grep -q '401' "$CI_GATE"
assert_true "gate asserts 200 with credentials" grep -q '200' "$CI_GATE"
assert_true "gate asserts node_modules never reaches the volume" \
  grep -q 'node_modules leaked' "$CI_GATE"

echo "SUITE_RESULT $TESTS_RUN $TESTS_FAILED $TESTS_SKIPPED"
