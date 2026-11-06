# Noctalia test harness image: Ubuntu 26.04 + build deps + headless sway.
# Base is a debootstrapped rootfs (see setup.sh), because Docker Hub may be unreachable.
FROM noctalia-base:26.04

ARG HTTPS_PROXY
ENV DEBIAN_FRONTEND=noninteractive

COPY ca-bundle.crt /tmp/proxy-ca.crt
RUN cat /tmp/proxy-ca.crt >> /etc/ssl/certs/ca-certificates.crt \
 && echo 'deb https://archive.ubuntu.com/ubuntu resolute main universe' > /etc/apt/sources.list \
 && echo 'deb https://archive.ubuntu.com/ubuntu resolute-updates main universe' >> /etc/apt/sources.list \
 && if [ -n "$HTTPS_PROXY" ]; then echo "Acquire::https::Proxy \"$HTTPS_PROXY\";" > /etc/apt/apt.conf.d/90proxy; fi \
 && echo "Acquire::Retries \"5\";" > /etc/apt/apt.conf.d/80retries \
 && apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      git ca-certificates meson ninja-build g++-16 just pkg-config \
      libwayland-dev wayland-protocols libegl-dev libgles-dev \
      libfreetype-dev libfontconfig-dev \
      libcairo2-dev libpango1.0-dev libharfbuzz-dev \
      libxkbcommon-dev libglib2.0-dev \
      libsecret-1-dev libsodium-dev \
      libsdbus-c++-dev libpipewire-0.3-dev libwireplumber-0.5-dev \
      libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev \
      libcurl4-gnutls-dev libwebp-dev libjxl-dev libsndfile1-dev librsvg2-dev \
      libqalculate-dev libxml2-dev \
      libmd4c-dev libtomlplusplus-dev libical-dev \
      nlohmann-json3-dev libstb-dev libjemalloc-dev \
      sway grim libgl1-mesa-dri libegl-mesa0 dbus dbus-x11 \
      fonts-dejavu-core fonts-noto-core python3 \
 && rm -f /etc/apt/apt.conf.d/90proxy \
 && rm -rf /var/lib/apt/lists/*

ENV CC=gcc-16 CXX=g++-16
RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /home/tester
