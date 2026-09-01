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
  mkdir -p "$state/config" "$state/logs"
  st_link_dir "$ST_APP/data"                                  "$state/data"
  st_link_dir "$ST_APP/plugins"                               "$state/plugins"
  st_link_dir "$ST_APP/public/scripts/extensions/third-party" "$state/extensions"
}

# 24 URL-safe characters from the kernel CSPRNG. Avoids openssl, which is not
# guaranteed present in every base layer.
st_gen_password() {
  head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-24
}

# Resolution order: ST_PASSWORD env (reset lever) > value stored on the volume
# > freshly generated. Result is persisted so redeploys need no configuration.
st_resolve_credentials() {
  local state store user pw
  state="$(st_state_dir)"
  store="$state/config/.st_credentials"
  mkdir -p "$state/config"

  user=""
  pw=""
  if [ -f "$store" ]; then
    # shellcheck disable=SC1090
    . "$store"
    user="${STORED_ST_USER:-}"
    pw="${STORED_ST_PASSWORD:-}"
  fi

  [ -n "${ST_USER:-}" ]     && user="$ST_USER"
  [ -n "${ST_PASSWORD:-}" ] && pw="$ST_PASSWORD"

  [ -n "$user" ] || user="user"
  [ -n "$pw" ]   || pw="$(st_gen_password)"

  ST_RESOLVED_USER="$user"
  ST_RESOLVED_PASSWORD="$pw"

  umask 077
  cat > "$store" <<EOF
STORED_ST_USER='$user'
STORED_ST_PASSWORD='$pw'
EOF
  chmod 600 "$store"

  cat > "$state/CREDENTIALS.txt" <<EOF
SillyTavern login for this pod
==============================

  username: $user
  password: $pw

This password lives on your network volume, so it stays the same across pod
restarts, redeploys, and new pods that mount this volume.

To change it: set the ST_PASSWORD environment variable on the pod and restart.
EOF
}

st_config_path() {
  echo "$(st_state_dir)/config/config.yaml"
}

# The log goes on the volume, not /var/log, so it is readable through the
# filebrowser UI (which is rooted at $WORKSPACE). Without this, diagnosing a
# SillyTavern problem needs SSH or a Jupyter terminal — too much to ask of
# someone deploying this for the first time. It also survives a pod restart.
st_log_path() {
  echo "$(st_state_dir)/logs/sillytavern.log"
}

# SillyTavern resolves config as CLI args > SILLYTAVERN_* env > config.yaml >
# defaults, so exporting here beats editing YAML and cannot corrupt a file.
# Defaults being overridden: listen=false, whitelistMode=true,
# basicAuthMode=false, browserLaunch.enabled=true.
st_export_config() {
  export SILLYTAVERN_LISTEN="true"
  export SILLYTAVERN_WHITELISTMODE="false"
  # Deliberately not configurable. A pod's URL is public and this instance
  # holds a live API key; there is no supported way to serve it unauthenticated.
  export SILLYTAVERN_BASICAUTHMODE="true"
  export SILLYTAVERN_BASICAUTHUSER_USERNAME="$ST_RESOLVED_USER"
  export SILLYTAVERN_BASICAUTHUSER_PASSWORD="$ST_RESOLVED_PASSWORD"
  export SILLYTAVERN_BROWSERLAUNCH_ENABLED="false"
  export SILLYTAVERN_PORT="${ST_PORT:-8000}"
  SILLYTAVERN_DATAROOT="$(st_state_dir)/data"
  export SILLYTAVERN_DATAROOT
}

# The one entry point callers need.
st_prepare() {
  st_seed_state
  st_resolve_credentials
  st_export_config
}
