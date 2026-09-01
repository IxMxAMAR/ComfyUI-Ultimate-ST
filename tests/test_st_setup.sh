#!/usr/bin/env bash
# shellcheck source=helpers.sh
. "$(dirname "$0")/helpers.sh"
. "$(dirname "$0")/../scripts/st_setup.sh"

echo "-- st_state_dir points at the volume"
new_sandbox
assert_eq "$(st_state_dir)" "$WORKSPACE/sillytavern" "state dir derives from WORKSPACE"
cleanup_sandbox

echo "SUITE_RESULT $TESTS_RUN $TESTS_FAILED"
