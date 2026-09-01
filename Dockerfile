# =============================================================================
# ComfyUI-Ultimate-ST — ComfyUI-Ultimate + SillyTavern
# Layered on the published base image so builds take ~3 min instead of ~50:
# the CUDA stack, torch, SageAttention and all 29 node packs are already built.
# Bump the pinned tag below to inherit a base update.
# =============================================================================
FROM ixmxamar/comfyui-ultimate:0cbe95d1635f

# ---- 1. Node.js 22 LTS (Ubuntu 22.04 ships nothing modern enough; ST needs >=20) ----
RUN apt-get update \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node --version && npm --version

# ---- 2. SillyTavern @ pinned commit ----
# Shallow-fetch the exact sha: a --depth 1 clone cannot check out an arbitrary
# commit, but fetching the sha directly can.
COPY st_pin.txt /opt/st_pin.txt
RUN ST_SHA="$(awk 'NF && $1 !~ /^#/ {print $1; exit}' /opt/st_pin.txt)" \
 && ST_URL="$(awk 'NF && $1 !~ /^#/ {print $2; exit}' /opt/st_pin.txt)" \
 && echo "SillyTavern pin: $ST_SHA" \
 && mkdir -p /SillyTavern && cd /SillyTavern \
 && git init -q && git remote add origin "$ST_URL" \
 && git fetch -q --depth 1 origin "$ST_SHA" \
 && git checkout -q FETCH_HEAD \
 && { npm ci --omit=dev --no-audit --no-fund \
      || npm install --omit=dev --no-audit --no-fund; } \
 && npm cache clean --force

# ---- 3. Scripts ----
COPY scripts/st_setup.sh /opt/scripts/st_setup.sh
COPY scripts/ci_st_gate.sh /opt/scripts/ci_st_gate.sh
COPY scripts/start.sh /opt/start.sh
RUN chmod +x /opt/start.sh /opt/scripts/st_setup.sh /opt/scripts/ci_st_gate.sh

# ---- 4. Build-time sanity: deps present and the entrypoint is well-formed ----
RUN test -d /SillyTavern/node_modules && echo "SillyTavern deps OK" \
 && bash -n /opt/start.sh && echo "start.sh syntax OK"

EXPOSE 8188 8888 22 8080 8000
WORKDIR /ComfyUI
ENTRYPOINT ["/opt/start.sh"]
