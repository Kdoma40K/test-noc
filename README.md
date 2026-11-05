# bundle-cache

Prebuilt Noctalia bundles for `harness/setup.sh` (binary + assets + example.toml),
one tarball per Noctalia commit: `noctalia-bundle-<sha12>.tar.gz`.
Built with GCC 16 on Ubuntu 26.04; they only run inside the harness image.
`setup.sh` fetches this branch and uses the tarball that matches the requested commit.
