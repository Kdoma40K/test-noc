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
cd harness
./setup.sh                                    # once per session, ~5 min (images) + seconds (bundle)
./shot.sh                                     # stock example.toml, desktop only
./shot.sh ../theme                            # the repo's theme (theme/config.toml)
./shot.sh ../theme out/run1 steps/panels.txt  # also panels + lock screen
RES=1920x1080 ./shot.sh ../theme              # faster, lower-res (default 3840x2160)
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
| `status.json` | `noctalia msg status` at startup |

Exit codes: `0` ok, `2` config validation failed, `3` Noctalia crashed or exited,
`4` Noctalia never answered IPC, `5` a screenshot looks blank.

Timing: the harness polls `noctalia msg status` until Noctalia answers (up to
`READY_TIMEOUT`, 60 s), then waits `SETTLE` (3 s) for the first frame. Don't
replace that with a fixed sleep: startup time varies a lot in a fresh container.

Expected noise in `errors.log`: no system D-Bus, and failed downloads (plugin
catalogs, palettes, currency rates), because the container is offline. Anything
else is worth reading.

## Steps files

One step per line: `<name> <wait-seconds> <noctalia args...>`. After each
screenshot the harness runs `noctalia msg panel-close`. See `steps/panels.txt`.
IPC commands are listed in Noctalia's docs (`docs/user/ipc/`) or with
`noctalia msg --help`. Software rendering is slow: give the lock screen ~10 s.

## How Noctalia gets here: the bundle cache

Building Noctalia takes ~48 min on the cloud workspace's 2 CPUs (~5 min on an
8-core PC). So the build output is cached as a "bundle" (binary + assets +
`example.toml`) on this repo's **`bundle-cache` branch**, one tarball per
Noctalia commit: `noctalia-bundle-<sha12>.tar.gz`.

`setup.sh` uses the commit pinned in `NOCTALIA_COMMIT`:
1. Cached bundle for that commit on `bundle-cache` → unpack into `../.bundle/` (seconds).
2. Otherwise → clone into `../.noctalia/`, build, pack the bundle.

`NOCTALIA_REF=<tag|branch|sha>` overrides the pin for one run,
`NOCTALIA_REPO=<url>` builds a fork, `FORCE_BUILD=1` skips the cache.

⚠️ **No accidental compiles:** if there's no cached bundle for the requested commit,
`setup.sh` stops in seconds with a message instead of compiling. Pass
`ALLOW_BUILD=1` when you really mean to build (e.g. upgrading Noctalia).
Never delete the `bundle-cache` branch.

### Upgrading Noctalia

1. `ALLOW_BUILD=1 NOCTALIA_REF=<new tag or sha> ./setup.sh` (builds, since it isn't cached).
2. Check it with `./shot.sh`.
3. Put the new commit in `NOCTALIA_COMMIT` and commit that.
4. Cache the tarball setup.sh left in `harness/`:
   ```bash
   git fetch origin bundle-cache
   git worktree add /tmp/cache origin/bundle-cache -B bundle-cache
   cp harness/noctalia-bundle-*.tar.gz /tmp/cache/
   git -C /tmp/cache add . && git -C /tmp/cache commit -m "bundle-cache: <sha12>"
   git -C /tmp/cache push origin bundle-cache && git worktree remove /tmp/cache
   ```
   GitHub releases would be the more usual home for this, but Claude's cloud
   sessions can't create releases; plain git pushes work everywhere.

## Files

- `setup.sh`: starts Docker (via the agent proxy in Claude's workspace), builds
  the base image from the Ubuntu archive with debootstrap (Docker Hub isn't
  reachable there), builds the harness image, then gets the bundle (above).
  Idempotent.
- `NOCTALIA_COMMIT`: the pinned Noctalia commit.
- `Dockerfile`: build deps, GCC 16, sway, grim, Mesa.
- `shot.sh`: host-side runner; mounts bundle, config and output into the container.
- `inner.sh`: runs inside the container; starts sway, Noctalia, the steps, grim.
  Skips the first-run wizard by creating `$NOCTALIA_STATE_HOME/noctalia/.setup-complete`.

⚠️ Noctalia appends `/noctalia` to `NOCTALIA_CONFIG_HOME` and `NOCTALIA_STATE_HOME`.
That's why the config dir is mounted at `/xdg/config/noctalia`.

## Limits

- Sway stands in for Hyprland. Noctalia draws its own surfaces, so bar, panels,
  colors, fonts and radii match. Compositor effects (blur, shadows, layer
  animations) and the Hyprland workspace backend do not.
- No real services: no Wi-Fi, Bluetooth, battery, audio devices, so those
  widgets show their empty/unavailable states.
- Software rendering: fine for screenshots, says nothing about performance.
- Fonts: only DejaVu and Noto are installed. Theme fonts (Departure Mono, DSEG7,
  IBM Plex Mono) need adding to the image before they'll render.

## Why Ubuntu 26.04 and not Arch

Arch mirrors and Docker Hub aren't reachable from the cloud workspace; the Ubuntu
archive and GitHub are. 24.04 is too old (WirePlumber 0.4, sdbus-c++ 1.4).
Noctalia needs GCC 16 (C++23 `std::ranges::shift_right`), so the image installs
`g++-16`; 26.04's default GCC 15 fails. 26.04's libqalculate needs the gnutls
libcurl, hence `libcurl4-gnutls-dev`.
