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
- [Keeping custom nodes across rebuilds](#keeping-custom-nodes-across-rebuilds)
- [What persists](#what-persists)
- [Troubleshooting](#troubleshooting)
- [Updating](#updating)
- [Credits and license](#credits-and-license)

---

## Quick start

You need a RunPod account with credit, and an OpenRouter API key if you want to
chat.

> **Ready-made RunPod template:** `ComfyUI Ultimate + SillyTavern`
> (id `uw8jq78pl7`) — deploy it directly at
> **<https://console.runpod.io/deploy?template=uw8jq78pl7>**
> or search for it by name under Templates in the RunPod console.

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

None of these are pre-filled on the template on purpose — an env var shipped with
a value would give every deployer the same SillyTavern password. Add the ones you
want in the RunPod deploy form under *Environment Variables*.

## Keeping custom nodes across rebuilds

ComfyUI, its Python environment and the 29 bundled node packs live **inside the
image, on the pod's local NVMe** — not on the network volume. That is why this
image starts far faster than templates which install ComfyUI onto `/workspace`
and then import tens of thousands of files over network storage on every boot.

The trade-off: anything you install through ComfyUI-Manager also lands on local
disk, and local disk is wiped when the pod is destroyed.

The fix is a pin list, not a symlink — so your nodes still load from fast local
disk, and the list works on any pod, any volume, any account.

**The one command you need.** Install nodes through the Manager UI exactly as
normal, then:

```bash
comfy-nodes freeze
```

That records every node you added — at the exact commit you are running — into
`/workspace/comfy_nodes.txt`. On every future boot they are cloned back and
their requirements reinstalled, before ComfyUI starts.

Run it from a JupyterLab terminal (port 8888 → File → New → Terminal) or over SSH.

**The rest of the commands:**

| Command | Does |
|---------|------|
| `comfy-nodes status` | Shows which installed nodes are **not** yet recorded — i.e. what you would lose on a rebuild |
| `comfy-nodes freeze` | Records everything you have installed |
| `comfy-nodes add <git-url> [sha]` | Installs a node and records it, in one step |
| `comfy-nodes list` | Shows what is pinned |
| `comfy-nodes restore` | Re-runs the restore now |

You can also edit `/workspace/comfy_nodes.txt` by hand — it is the same
`<dirname> <git_url> <commit_sha>` format the image uses for its own nodes. The
sha is optional (omit it to track the default branch), and a bare git URL works.

**What it costs.** Restoring a handful of nodes adds roughly 10–25 seconds to a
cold boot, mostly pip; the wheel cache lives on the volume, so later boots are
faster. Progress is logged to `/workspace/comfy_nodes.log`.

**When to graduate a node into the image instead.** The pin list is for nodes
you are trying out or that change often. Once you have settled on one
permanently, add it to `node_pins.txt` and rebuild: the build takes ~3 minutes
because everything heavy comes from the base image, and a baked node costs
**nothing** at boot because it and its dependencies are already installed. If
your boot is getting slow, that is the signal to promote your pinned nodes.

**Packs installed from the Comfy Registry.** ComfyUI-Manager increasingly
installs node packs as versioned archives rather than git clones, so those
directories contain no `.git`. `freeze` handles them: it falls back to the
`Repository` url the Registry requires in `pyproject.toml` and records them as
tracking `HEAD` (an archive carries no commit id, so there is nothing exact to
pin to). To pin one to a specific commit, reinstall it with
`comfy-nodes add <git-url> <sha>`.

If a pack has neither a git remote nor a Repository url, it genuinely cannot be
restored — `freeze` and `status` both say so explicitly rather than skipping it
quietly, because a silent omission would only surface as a missing node after
your next rebuild.

Three guarantees, all enforced in CI: the manifest can never modify or overwrite
one of the 29 bundled packs; a node whose repo has moved, been deleted or gone
private is logged and skipped, so it can never stop the pod from booting; and a
pack that cannot be recorded is always reported, never dropped in silence.

## What persists

Everything below lives on your network volume and survives pod deletion:

```
/workspace/
  comfy_nodes.txt    your pinned custom nodes (see above)
  comfy_nodes.log    what the last restore did
  pip-cache/         wheel cache, makes later boots faster
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

**SillyTavern won't load.** Read its log at
`/workspace/sillytavern/logs/sillytavern.log` — it is on the volume, so you can
open it straight from the file browser on port 8080, no SSH needed. (It is also
symlinked to `/var/log/sillytavern.log` if you are on a terminal.) The service
restarts itself automatically if it crashes, so give it a few seconds before
investigating.

**"Could not fetch OpenRouter credits", or the model dropdown is empty.** Click
**Connect** first. SillyTavern saves the API key server-side when you connect,
and both the credit lookup and the model list use the *saved* key — so before
you press Connect they will fail even though the key is correct.

**Connected, but generations fail.** Check your credit balance at
[openrouter.ai/credits](https://openrouter.ai/credits). With a zero balance only
models tagged `:free` will actually run.

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
- `scripts/node_manifest.sh`, `scripts/restore_nodes.sh`, `scripts/comfy-nodes`,
  `scripts/ci_nodes_gate.sh` — new; custom-node persistence, worth porting
  upstream to ComfyUI-Ultimate since the base image has the same limitation
- `.github/workflows/build.yml` — no CUDA compile, plus the auth gate

## Credits and license

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) by comfyanonymous
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) by the SillyTavern team
- Base image: [ComfyUI-Ultimate](https://github.com/IxMxAMAR/ComfyUI-Ultimate)

See [LICENSE](LICENSE). Bundled software remains under its own license.
