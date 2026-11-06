#!/usr/bin/env bash
# One-time-per-session setup for the Noctalia test harness (Claude cloud workspace,
# or any Ubuntu/Debian box with Docker). Idempotent: skips steps already done.
#   ./setup.sh            build images + unpack the cached Noctalia bundle
#   NOCTALIA_REF=<ref>    tag/branch/commit to use (default: the commit pinned in NOCTALIA_COMMIT)
#   NOCTALIA_REPO=<url>   build your fork instead of upstream
#   ALLOW_BUILD=1         allow compiling Noctalia when no cached bundle exists
#                         (~48 min on Claude's 2-CPU workspace; refused without it)
#   FORCE_BUILD=1         ignore the cache and compile (implies ALLOW_BUILD)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${NOCTALIA_SRC:-$HERE/../.noctalia}"
BUNDLE="$HERE/../.bundle"
REPO="${NOCTALIA_REPO:-https://github.com/noctalia-dev/noctalia.git}"
REF="${NOCTALIA_REF:-$(cat "$HERE/NOCTALIA_COMMIT")}"
SUITE=resolute   # Ubuntu 26.04: has wireplumber 0.5 + new sdbus-c++ (24.04 is too old)

# 0. Pre-flight: make sure we won't fall into a long compile by accident.
#    Runs before anything slow, so a refusal costs seconds, not minutes.
PRE_SHA="$(git ls-remote "$REPO" "$REF" | head -1 | cut -f1)"; PRE_SHA="${PRE_SHA:-$REF}"
PRE_ASSET="noctalia-bundle-${PRE_SHA:0:12}.tar.gz"
if [ -z "${FORCE_BUILD:-}" ] && [ -z "${ALLOW_BUILD:-}" ] \
   && [ "$(cat "$BUNDLE/COMMIT" 2>/dev/null)" != "$PRE_SHA" ]; then
  if ! { git -C "$HERE" fetch --quiet --depth 1 origin bundle-cache 2>/dev/null \
         && git -C "$HERE" cat-file -e "FETCH_HEAD:$PRE_ASSET" 2>/dev/null; }; then
    echo "!! No cached bundle for Noctalia ${PRE_SHA:0:12} on the bundle-cache branch."
    echo "!! Building it takes ~48 min here. Refusing without ALLOW_BUILD=1."
    echo "!! Usual causes: NOCTALIA_COMMIT or NOCTALIA_REF changed, or bundle-cache was deleted."
    exit 1
  fi
fi

# 1. Docker daemon. In Claude's cloud workspace it isn't running and must
#    use the agent proxy for downloads.
if ! sudo docker info >/dev/null 2>&1; then
  echo "== starting dockerd"
  (sudo env HTTPS_PROXY="${HTTPS_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" \
     NO_PROXY=localhost,127.0.0.1 dockerd > /tmp/dockerd.log 2>&1 &)
  for _ in $(seq 30); do sudo docker info >/dev/null 2>&1 && break; sleep 1; done
fi

# 2. Base image. Docker Hub may be blocked, so build the rootfs from the
#    Ubuntu archive with debootstrap and import it.
if ! sudo docker image inspect noctalia-base:26.04 >/dev/null 2>&1; then
  echo "== bootstrapping Ubuntu 26.04 base image"
  command -v debootstrap >/dev/null || { sudo apt-get update -qq; sudo apt-get install -y -qq -o Acquire::Retries=5 debootstrap; }
  [ -e /usr/share/debootstrap/scripts/$SUITE ] || sudo ln -s gutsy /usr/share/debootstrap/scripts/$SUITE
  sudo rm -rf "$HERE/rootfs"
  sudo debootstrap --variant=minbase --components=main,universe $SUITE "$HERE/rootfs" https://archive.ubuntu.com/ubuntu
  sudo tar -C "$HERE/rootfs" -c . | sudo docker import - noctalia-base:26.04
  sudo rm -rf "$HERE/rootfs"
fi

# 3. Harness image: build deps + sway + grim + Mesa (software GL).
if ! sudo docker image inspect noctalia-harness >/dev/null 2>&1; then
  echo "== building harness image"
  if [ -f /root/.ccr/ca-bundle.crt ] || sudo test -f /root/.ccr/ca-bundle.crt; then
    sudo cp /root/.ccr/ca-bundle.crt "$HERE/ca-bundle.crt"
  else
    cp /etc/ssl/certs/ca-certificates.crt "$HERE/ca-bundle.crt"
  fi
  sudo chmod 644 "$HERE/ca-bundle.crt"
  sudo docker build --network host --build-arg HTTPS_PROXY="${HTTPS_PROXY:-}" \
    -t noctalia-harness "$HERE"
fi

# 4. Pick the Noctalia commit to use.
SHA="$(git ls-remote "$REPO" "$REF" | head -1 | cut -f1)"
[ -z "$SHA" ] && SHA="$REF"   # REF may already be a commit hash
SHORT="${SHA:0:12}"
ASSET="noctalia-bundle-$SHORT.tar.gz"
echo "== Noctalia $REF = $SHORT"

if [ -x "$BUNDLE/noctalia" ] && [ "$(cat "$BUNDLE/COMMIT" 2>/dev/null)" = "$SHA" ]; then
  echo "== bundle already present"; echo "== ready: ./shot.sh [config-dir]"; exit 0
fi

# 5. Fast path: take a cached bundle from this repo's `bundle-cache` branch.
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE"
if [ -z "${FORCE_BUILD:-}" ] && git -C "$HERE" fetch --quiet --depth 1 origin bundle-cache 2>/dev/null \
   && git -C "$HERE" cat-file -e "FETCH_HEAD:$ASSET" 2>/dev/null; then
  git -C "$HERE" show "FETCH_HEAD:$ASSET" | tar -C "$BUNDLE" -xz
  echo "== using cached bundle $ASSET"; echo "== ready: ./shot.sh [config-dir]"; exit 0
fi
[ -z "${FORCE_BUILD:-}" ] && echo "== no cached bundle for $SHORT, building from source"

# 6. Slow path: build from source (~35 min on 2 CPUs, ~5 min on 8+).
if [ ! -d "$SRC/.git" ]; then
  git clone "$REPO" "$SRC"
fi
git -C "$SRC" fetch --quiet origin "$SHA" 2>/dev/null || git -C "$SRC" fetch --quiet origin "$REF"
git -C "$SRC" checkout --quiet "$SHA"
sudo chmod -R a+rwX "$SRC"
sudo docker run --rm --network host -v "$SRC":/src -w /src noctalia-harness bash -c '
  [ -f build-release/build.ninja ] || meson setup build-release --buildtype=release -Dcpp_std=c++23 -Dtests=disabled
  meson compile -C build-release noctalia'

# 7. Pack a portable bundle: binary + merged assets + stock config.
cp "$SRC/build-release/noctalia" "$BUNDLE/"
mkdir -p "$BUNDLE/assets"
cp -r "$SRC/assets/." "$BUNDLE/assets/"
[ -d "$SRC/lib/assets" ] && cp -r "$SRC/lib/assets/." "$BUNDLE/assets/"
cp "$SRC/example.toml" "$BUNDLE/"
echo "$SHA" > "$BUNDLE/COMMIT"
tar -C "$BUNDLE" -czf "$HERE/$ASSET" .
echo "== built. To cache it for future sessions, add $ASSET to the bundle-cache branch:"
echo "   see harness/README.md (Caching a new bundle)"
echo "== ready: ./shot.sh [config-dir]"
