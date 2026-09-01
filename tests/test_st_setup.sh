#!/usr/bin/env bash
# shellcheck source=helpers.sh
. "$(dirname "$0")/helpers.sh"
. "$(dirname "$0")/../scripts/st_setup.sh"

echo "-- st_state_dir points at the volume"
new_sandbox
assert_eq "$(st_state_dir)" "$WORKSPACE/sillytavern" "state dir derives from WORKSPACE"
cleanup_sandbox

echo "-- st_seed_state creates and links the state dirs"
new_sandbox
mkdir -p "$ST_APP/data"
echo "shipped" > "$ST_APP/data/default.json"
st_seed_state
assert_symlink_to "$ST_APP/data"    "$WORKSPACE/sillytavern/data"    "data is linked to the volume"
assert_symlink_to "$ST_APP/plugins" "$WORKSPACE/sillytavern/plugins" "plugins is linked to the volume"
assert_symlink_to "$ST_APP/public/scripts/extensions/third-party" \
                  "$WORKSPACE/sillytavern/extensions" "third-party extensions is linked"
assert_file "$WORKSPACE/sillytavern/data/default.json" "image-shipped defaults were copied onto the volume"
cleanup_sandbox

echo "-- st_seed_state never clobbers existing volume content"
new_sandbox
mkdir -p "$ST_APP/data" "$WORKSPACE/sillytavern/data"
echo "shipped" > "$ST_APP/data/default.json"
echo "mine"    > "$WORKSPACE/sillytavern/data/default.json"
st_seed_state
assert_eq "$(cat "$WORKSPACE/sillytavern/data/default.json")" "mine" "existing volume file wins over image default"
cleanup_sandbox

echo "-- st_seed_state is idempotent"
new_sandbox
mkdir -p "$ST_APP/data"
st_seed_state
st_seed_state
assert_symlink_to "$ST_APP/data" "$WORKSPACE/sillytavern/data" "still a symlink after a second run"
assert_true "no nested self-link was created" test ! -e "$WORKSPACE/sillytavern/data/data"
cleanup_sandbox

echo "SUITE_RESULT $TESTS_RUN $TESTS_FAILED $TESTS_SKIPPED"
