# Noctalia test harness

Renders Noctalia v5 with a given config inside a container, with no GPU and no
monitor, and saves screenshots. Used to check the NASA-punk theme from Claude's
cloud workspace (or any Linux box with Docker).

```
container (Ubuntu 26.04)
  sway, headless output HEADLESS-1 (default 3840x2160)
    └─ noctalia  (draws with Mesa llvmpipe = software GL)
  grim ──asks sway for the frame──▶ PNG in out/
```

## Use

```bash
./setup.sh                                  # once per session: seconds if a cached bundle exists
                                            # in this repo's releases, ~35 min build otherwise
./shot.sh                                   # stock example.toml, desktop only
./shot.sh ../theme                          # your config dir (contains config.toml)
./shot.sh ../theme out/run1 steps/panels.txt  # also open panels and the lock screen
RES=1920x1080 ./shot.sh ../theme            # faster, lower-res
```

Each run writes to `out/<timestamp>/` (or the folder you pass):

| File | What it is |
|---|---|
| `00-desktop.png` | Desktop with bar, a few seconds after start |
| `NN-<step>.png` | One per line in the steps file |
| `validate.log` | `noctalia config validate` output for your config |
| `noctalia.log` | Full shell log |
| `errors.log` | Lines matching error/fatal/crit |
| `sway.log` | Compositor log |

Exit codes: `0` ok, `2` config validation failed, `3` Noctalia crashed or exited.

## Steps files

One step per line: `<name> <wait-seconds> <noctalia args...>`. After each
screenshot the harness runs `noctalia msg panel-close`. See `steps/panels.txt`.
List all commands with `noctalia msg --help` (or the IPC docs in
`noctalia/docs/user/ipc/`).

## Files

- `setup.sh`: starts Docker, builds the base image from the Ubuntu archive with
  debootstrap (Docker Hub may be blocked), builds the harness image, then gets
  Noctalia into `../.bundle/` (binary + assets + `example.toml`):
  1. resolves `NOCTALIA_REF` (default `main`) to a commit,
  2. downloads release `noctalia-<sha12>` from this repo if it exists,
  3. otherwise clones into `../.noctalia/`, builds, packs the bundle, and prints
     the `gh release create` command to cache it.
  `NOCTALIA_REPO=<url>` builds a fork; `FORCE_BUILD=1` skips the download.
- `Dockerfile`: build deps, sway, grim, Mesa.
- `shot.sh`: host-side runner; mounts source, config and output into the container.
- `inner.sh`: runs inside the container; starts sway, Noctalia, the steps, grim.

## Limits

- Sway stands in for Hyprland. Noctalia draws its own surfaces, so bar, panels,
  colors, fonts and radii match. Compositor effects (blur, shadows, layer
  animations) and the Hyprland workspace backend do not.
- No real services: no Wi-Fi, Bluetooth, battery, audio devices, so those
  widgets show their empty/unavailable states.
- Software rendering: fine for screenshots, says nothing about performance.

## Why Ubuntu 26.04 and not Arch

Arch mirrors and Docker Hub aren't reachable from the cloud workspace; the Ubuntu
archive and GitHub are. 24.04 is too old (WirePlumber 0.4, sdbus-c++ 1.4). Noctalia needs GCC 16 (C++23 `std::ranges::shift_right`), so the image installs `g++-16`; 26.04’s default GCC 15 fails.
26.04's libqalculate needs the gnutls libcurl, hence `libcurl4-gnutls-dev`.
