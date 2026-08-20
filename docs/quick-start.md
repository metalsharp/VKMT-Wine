# Quick start

VKMT Wine is an Apple-Silicon-native Wine runtime for macOS. The host Wine
boundary is ARM64; FEX provides the x86_64 and i386/WoW64 guest routes.

## Install VKMT-1.0

Requirements: Apple Silicon macOS, an external target volume with at least
19,000,000 KiB free, `curl`, and `zstd`. Install `zstd` with Homebrew if it
is not already available:

```sh
brew install zstd
```

Download the installer from the [VKMT-1.0 release](https://github.com/metalsharp/VKMT-Wine/releases/tag/VKMT-1.0), make it executable, and select an external target:

```sh
curl -fL -o install-vkmt-runtime.sh \
  https://github.com/metalsharp/VKMT-Wine/releases/download/VKMT-1.0/install-metalsharp-wine-runtime.sh
chmod +x install-vkmt-runtime.sh
./install-vkmt-runtime.sh --target /Volumes/VKMT-runtime
```

The installer downloads or reuses the four verified runtime parts and the
ARM64 GOG support archive, reassembles the archive, verifies every published
hash, stages it transactionally, and writes an installation receipt. Use
`--bundle-dir DIR` or `--local-only` when the release assets are already
available locally. An existing target is preserved unless `--replace` is
explicitly supplied.

## Launch

Keep `WINEPREFIX` outside the immutable runtime. The launch adapter sets the
ARM64 host boundary, loads the bundled native dependency closure, selects the
default DXMT profile, and exports the no-TSO FEX contract:

```sh
export VKMT_RUNTIME_ROOT=/Volumes/VKMT-runtime
export WINEPREFIX=/Volumes/VKMT-prefix
"$VKMT_RUNTIME_ROOT/wine/bin/metalsharp-wine" winecfg
```

Run a Windows program by replacing `winecfg` with its executable and
arguments. `xtajit64` and `xtajit` are required runtime providers and remain
installed for the x86_64 and i386/WoW64 routes.

## Next references

- [Architecture](architecture.md) — host/guest routing, source tree, and
  integration paths.
- [Runtime inventory](runtime-inventory.md) — complete installed-path
  inventory and component list.
- [Packaging and validation](package-and-validation.md) — release gates and
  receipts.
- [Third-party licenses](third-party-licenses.md) — component licensing and
  redistribution boundaries.
