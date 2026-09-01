#!/usr/bin/env bash
# CI gate: boot SillyTavern alone and prove basic auth is actually enforced.
# Guards against publishing an open chat UI that will hold a live API key.
set -euo pipefail

export WORKSPACE=/tmp/ci-workspace
export ST_USER=ciuser
export ST_PASSWORD=ci-test-password
mkdir -p "$WORKSPACE"

. /opt/scripts/st_setup.sh
st_prepare

cd /SillyTavern
node server.js --configPath "$(st_config_path)" > /tmp/st.log 2>&1 &
ST_PID=$!

ready=0
for _ in $(seq 1 60); do
  if curl -s -o /dev/null "http://127.0.0.1:8000/"; then ready=1; break; fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  echo "FAIL: SillyTavern never became reachable on :8000"
  cat /tmp/st.log
  exit 1
fi

code_noauth="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8000/")"
code_auth="$(curl -s -o /dev/null -w '%{http_code}' -u "$ST_USER:$ST_PASSWORD" "http://127.0.0.1:8000/")"

kill "$ST_PID" 2>/dev/null || true

echo "unauthenticated -> $code_noauth ; authenticated -> $code_auth"
[ "$code_noauth" = "401" ] || { echo "FAIL: expected 401 without credentials, got $code_noauth"; cat /tmp/st.log; exit 1; }
[ "$code_auth"   = "200" ] || { echo "FAIL: expected 200 with credentials, got $code_auth"; cat /tmp/st.log; exit 1; }

# The volume must carry state, and must never carry node_modules.
test -f "$WORKSPACE/sillytavern/CREDENTIALS.txt" || { echo "FAIL: CREDENTIALS.txt missing"; exit 1; }
test ! -e "$WORKSPACE/sillytavern/node_modules"   || { echo "FAIL: node_modules leaked onto the volume"; exit 1; }

# The stateful dirs must be real symlinks onto the volume (assertable here,
# unlike on the Windows dev box).
for pair in "data:data" "plugins:plugins" "public/scripts/extensions/third-party:extensions"; do
  app="/SillyTavern/${pair%%:*}"
  vol="$WORKSPACE/sillytavern/${pair##*:}"
  [ -L "$app" ] || { echo "FAIL: $app is not a symlink"; exit 1; }
  [ "$(readlink "$app")" = "$vol" ] || { echo "FAIL: $app -> $(readlink "$app"), expected $vol"; exit 1; }
done

echo "ST gate PASS"
