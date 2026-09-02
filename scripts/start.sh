#!/usr/bin/env bash
# RunPod Pod entrypoint: wire the network volume, start SSH + JupyterLab +
# filebrowser + SillyTavern, then run ComfyUI in the foreground.
set -u
export PATH="/opt/venv/bin:$PATH"

WORKSPACE="${WORKSPACE:-/workspace}"
echo "[start] wiring persistent dirs onto $WORKSPACE"
for d in models output input user; do
  mkdir -p "$WORKSPACE/$d"
  if [ -d "/ComfyUI/$d" ] && [ ! -L "/ComfyUI/$d" ]; then
    cp -an "/ComfyUI/$d/." "$WORKSPACE/$d/" 2>/dev/null || true
    rm -rf "/ComfyUI/$d"
  fi
  ln -sfn "$WORKSPACE/$d" "/ComfyUI/$d"
done

# --- SSH (RunPod injects PUBLIC_KEY) ---
if [ -n "${PUBLIC_KEY:-}" ]; then
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
fi
mkdir -p /run/sshd && /usr/sbin/sshd && echo "[start] sshd up on :22" || echo "[start] WARN sshd failed"

# --- JupyterLab (open/no-auth by default; set JUPYTER_TOKEN to require one) ---
JUPYTER_TOKEN="${JUPYTER_TOKEN:-}"
nohup jupyter lab --allow-root --ip=0.0.0.0 --port=8888 --no-browser \
  --ServerApp.token="$JUPYTER_TOKEN" --ServerApp.password='' \
  --ServerApp.root_dir="$WORKSPACE" \
  --ServerApp.allow_origin='*' --ServerApp.allow_remote_access=True \
  --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=True \
  > /var/log/jupyter.log 2>&1 &
if [ -n "$JUPYTER_TOKEN" ]; then
  echo "[start] JupyterLab up on :8888 (token: $JUPYTER_TOKEN)"
else
  echo "[start] JupyterLab up on :8888 (no auth)"
fi

# --- filebrowser (noauth, writable db in /tmp) ---
if command -v filebrowser >/dev/null 2>&1; then
  nohup filebrowser -r "$WORKSPACE" -a 0.0.0.0 -p 8080 --noauth -d /tmp/filebrowser.db \
    > /var/log/filebrowser.log 2>&1 &
  echo "[start] filebrowser up on :8080"
else
  echo "[start] filebrowser not installed, skipping :8080"
fi

# --- SillyTavern (background, restart-on-crash) ---
# Set ST_DISABLE=1 to boot a plain ComfyUI-Ultimate pod with no chat UI.
if [ "${ST_DISABLE:-0}" = "1" ]; then
  echo "[start] SillyTavern disabled via ST_DISABLE=1"
else
  # shellcheck source=/opt/scripts/st_setup.sh
  . /opt/scripts/st_setup.sh
  st_prepare
  ST_CFG="$(st_config_path)"
  ST_LOG="$(st_log_path)"
  # Keep the conventional path working for anyone who SSHes in expecting it.
  ln -sfn "$ST_LOG" /var/log/sillytavern.log

  # A pod operator is not necessarily able to revive a dead Node process over
  # SSH, and restarting the whole pod costs a ~90s ComfyUI reload — so keep
  # SillyTavern alive here rather than letting a crash end the service.
  (
    cd /SillyTavern || exit 1
    while true; do
      node server.js --configPath "$ST_CFG" >> "$ST_LOG" 2>&1
      rc=$?
      echo "[start] SillyTavern exited (rc=$rc), restarting in 5s" >> "$ST_LOG"
      sleep 5
    done
  ) &

  echo "[start] SillyTavern up on :8000 (user: $ST_RESOLVED_USER)"
  echo "[start] SillyTavern password: $ST_RESOLVED_PASSWORD"
  echo "[start]   (also saved to $(st_state_dir)/CREDENTIALS.txt — readable via filebrowser on :8080)"
fi

# --- Restore user-pinned custom nodes onto LOCAL disk (see comfy_nodes.txt) ---
# Runs after the light services are up so their logs are watchable while this
# works, but before ComfyUI imports. Never fatal: a dead node repo must not stop
# the pod booting.
bash /opt/scripts/restore_nodes.sh || echo "[start] WARN node restore reported an error; continuing"

# --- ComfyUI (foreground). Attention: prefer the KJNodes 'Patch Sage Attention'
#     node over the global --use-sage-attention flag. Override via COMFY_ARGS. ---
cd /ComfyUI
echo "[start] launching ComfyUI on :8188"
exec python main.py --listen 0.0.0.0 --port 8188 ${COMFY_ARGS:-}
