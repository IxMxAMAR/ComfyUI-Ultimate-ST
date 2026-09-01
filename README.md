# ComfyUI-Ultimate-ST

**AI image generation and AI chat in one RunPod pod.** This image bundles
[ComfyUI](https://github.com/comfyanonymous/ComfyUI) (image and video
generation, with 29 popular custom-node packs pre-installed) and
[SillyTavern](https://github.com/SillyTavern/SillyTavern) (a character-driven
chat front-end) so both are running the moment the pod boots.

SillyTavern here is a **front-end only** — it talks to a remote model provider
such as [OpenRouter](https://openrouter.ai/), so the GPU stays dedicated to
ComfyUI. **No model weights are shipped**; you download those from inside
ComfyUI on first use.

> Built on [`ixmxamar/comfyui-ultimate`](https://hub.docker.com/r/ixmxamar/comfyui-ultimate).
> Published as:
>
> ### `docker.io/ixmxamar/comfyui-ultimate-st:latest`

---

## Table of contents

- [Quick start](#quick-start)
- [Finding your SillyTavern password](#finding-your-sillytavern-password)
- [Connecting OpenRouter](#connecting-openrouter)
- [Generating images inside a chat](#generating-images-inside-a-chat)
- [Services and ports](#services-and-ports)
- [Environment variables](#environment-variables)
- [What persists](#what-persists)
- [Troubleshooting](#troubleshooting)
- [Updating](#updating)
- [Credits and license](#credits-and-license)

---

## Quick start

You need a RunPod account with credit, and an OpenRouter API key if you want to
chat.

1. **Create a network volume** in RunPod (Storage → Network Volumes). 50 GB is a
   reasonable start; image models are large. Pick a datacenter with RTX-class
   GPUs available.
2. **Deploy this template** onto a pod, choosing an **RTX-class GPU**
   (4090 / 5090 / A5000 or better) and attaching that volume at `/workspace`.
3. **Wait about 90 seconds.** ComfyUI is the slowest service to come up. Watch
   the pod log until you see `To see the GUI go to:`.
4. **Open port 8000** from the pod's Connect menu — that's SillyTavern. Your
   browser will ask for a username and password; see the next section.
5. **Open port 8188** for ComfyUI.

Deploying without a network volume works, but **everything is lost when the pod
is deleted** — chats, characters, API keys, and downloaded models. Use a volume.

## Finding your SillyTavern password

SillyTavern is password-protected because a RunPod URL is public: anyone who
knows it could otherwise read your chats and spend your API credits.

**On first boot a password is generated for you.** You can find it in two places:

- **The pod log**, on a line reading
  `[start] SillyTavern password: ...`
- **The file `/workspace/sillytavern/CREDENTIALS.txt`**, which you can read in
  your browser via the file browser on **port 8080**.

The default username is `user`.

That password is stored **on your network volume**, so it stays the same across
pod restarts, redeploys, and brand-new pods that mount the same volume. You
never have to set it up again.

**To change it:** set the `ST_PASSWORD` environment variable on the pod and
restart. The new value replaces the stored one.

## Connecting OpenRouter

1. Get an API key at [openrouter.ai/keys](https://openrouter.ai/keys).
2. In SillyTavern, open the **plug icon** (API Connections) in the top bar.
3. Set **API** to `Chat Completion`, and **Chat Completion Source** to
   `OpenRouter`.
4. Paste your key, click **Connect**, then pick a model from the dropdown.

Your key is saved into `/workspace/sillytavern/data/`, so it persists with
everything else on the volume — you only enter it once.

## Generating images inside a chat

SillyTavern can call the ComfyUI running in the same pod, so images generate
locally with no extra API cost.

1. Download at least one checkpoint in ComfyUI first (port 8188) — the image
   ships with no model weights. The bundled **Civicomfy** and
   **RunpodDirect** nodes can pull models straight into the volume.
2. In SillyTavern, open **Extensions → Image Generation**.
3. Set the source to **ComfyUI** and the URL to `http://127.0.0.1:8188`.
4. Pick a workflow and a checkpoint, then use `/imagine` in chat.

## Services and ports

| Port | Service | Authentication |
|------|---------|----------------|
| 8000 | **SillyTavern** | **Username + password (always on)** |
| 8188 | ComfyUI | None |
| 8888 | JupyterLab | Token, only if `JUPYTER_TOKEN` is set |
| 8080 | filebrowser | None |
| 22 | SSH | Your `PUBLIC_KEY` |

Only SillyTavern is password-protected by default, because it is the only
service holding an API key that costs money to abuse. Treat the other URLs as
private — do not share them.

## Environment variables

All are optional.

| Variable | Default | Purpose |
|----------|---------|---------|
| `ST_PASSWORD` | auto-generated | Sets/resets the SillyTavern password. |
| `ST_USER` | `user` | SillyTavern username. |
| `ST_PORT` | `8000` | Port SillyTavern listens on. |
| `ST_DISABLE` | unset | Set to `1` to boot a plain ComfyUI pod with no chat UI. |
| `JUPYTER_TOKEN` | empty | Require a token for JupyterLab. Leave empty for no auth. |
| `CIVITAI_API_KEY` | — | For downloading models from Civitai in-UI. |
| `HF_TOKEN` | — | For gated Hugging Face models. |
| `COMFY_ARGS` | — | Extra ComfyUI command-line arguments. |
| `PUBLIC_KEY` | injected by RunPod | SSH public key. |

## What persists

Everything below lives on your network volume and survives pod deletion:

```
/workspace/
  sillytavern/
    data/            chats, characters, personas, settings, API keys
    config/          SillyTavern server config and your stored password
    plugins/         installed server plugins
    extensions/      installed third-party UI extensions
    CREDENTIALS.txt  your login, in plain text
  models/  output/  input/  user/     ComfyUI models and generations
```

SillyTavern's `node_modules` is deliberately **not** on the volume — it is tens
of thousands of tiny files and would add minutes to every boot over network
storage. It ships inside the image instead.

## Troubleshooting

**Port 8188 shows 403 Forbidden.** Almost always means you clicked the link
before ComfyUI finished its ~90 second startup, and your browser cached the
error. Hard-refresh (Ctrl+Shift+R) or open it in a private window. ComfyUI is
the slowest service to boot; JupyterLab and filebrowser come up immediately.

**SillyTavern won't load.** Check `/var/log/sillytavern.log` over SSH or in
JupyterLab. The service restarts itself automatically if it crashes, so give it
a few seconds before investigating.

**The browser never asks for a password.** It probably cached your credentials
from an earlier session. That is expected.

**Chat replies arrive all at once instead of streaming word by word.** RunPod's
HTTP proxy can buffer streamed responses. If you hit this, connect over a
RunPod **TCP port** mapping for 8000 instead of the HTTP proxy — that bypasses
the buffering entirely.

**Lost your password.** Set `ST_PASSWORD` on the pod to anything you like and
restart; it overwrites the stored one.

## Updating

**To pick up a newer ComfyUI or node set:** change the pinned tag on the first
`FROM` line in the `Dockerfile` to a newer
[`ixmxamar/comfyui-ultimate`](https://hub.docker.com/r/ixmxamar/comfyui-ultimate/tags)
tag and push. CI rebuilds in a few minutes, because everything heavy is already
built in that base image.

**To pick up a newer SillyTavern:** change the commit SHA in `st_pin.txt`.

**Relationship to the base repo.** This is a fork of
[`IxMxAMAR/ComfyUI-Ultimate`](https://github.com/IxMxAMAR/ComfyUI-Ultimate).
Only these files differ, which keeps syncing changes from upstream a small diff:

- `Dockerfile` — layers on the base image instead of building from CUDA
- `scripts/start.sh` — the base entrypoint plus one SillyTavern block
- `scripts/st_setup.sh`, `scripts/ci_st_gate.sh`, `st_pin.txt` — new
- `.github/workflows/build.yml` — no CUDA compile, plus the auth gate

## Credits and license

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) by comfyanonymous
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) by the SillyTavern team
- Base image: [ComfyUI-Ultimate](https://github.com/IxMxAMAR/ComfyUI-Ultimate)

See [LICENSE](LICENSE). Bundled software remains under its own license.
