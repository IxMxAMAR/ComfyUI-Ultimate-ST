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

echo "-- st_gen_password produces a usable secret"
new_sandbox
pw="$(st_gen_password)"
assert_eq "${#pw}" "24" "generated password is 24 chars"
assert_true "generated password is URL-safe" bash -c "[[ '$pw' =~ ^[A-Za-z0-9]+$ ]]"
assert_true "two calls differ" test "$(st_gen_password)" != "$(st_gen_password)"
cleanup_sandbox

echo "-- first boot generates and persists"
new_sandbox
st_seed_state
st_resolve_credentials
first="$ST_RESOLVED_PASSWORD"
assert_eq "$ST_RESOLVED_USER" "user" "default username is user"
assert_true "a password was produced" test -n "$first"
assert_file "$WORKSPACE/sillytavern/config/.st_credentials" "credential store written"
assert_file "$WORKSPACE/sillytavern/CREDENTIALS.txt" "human-readable credentials written"
assert_true "CREDENTIALS.txt contains the password" grep -qF "$first" "$WORKSPACE/sillytavern/CREDENTIALS.txt"
cleanup_sandbox

echo "-- second boot reuses the stored password"
new_sandbox
st_seed_state
st_resolve_credentials
first="$ST_RESOLVED_PASSWORD"
unset ST_RESOLVED_PASSWORD
st_resolve_credentials
assert_eq "$ST_RESOLVED_PASSWORD" "$first" "password is stable across boots"
cleanup_sandbox

echo "-- ST_PASSWORD overrides the stored value (reset lever)"
new_sandbox
st_seed_state
st_resolve_credentials
export ST_PASSWORD="rotated-secret"
export ST_USER="chris"
st_resolve_credentials
assert_eq "$ST_RESOLVED_PASSWORD" "rotated-secret" "env password wins"
assert_eq "$ST_RESOLVED_USER" "chris" "env username wins"
unset ST_PASSWORD ST_USER
st_resolve_credentials
assert_eq "$ST_RESOLVED_PASSWORD" "rotated-secret" "the rotated password was persisted"
assert_eq "$ST_RESOLVED_USER" "chris" "the rotated username was persisted"
cleanup_sandbox

echo "SUITE_RESULT $TESTS_RUN $TESTS_FAILED $TESTS_SKIPPED"
