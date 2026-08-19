# VKMT

VKMT is an Apple-Silicon-native Wine runtime for ARM64/AArch64, ARM64EC,
x86_64, and i386/WoW64 Windows software on macOS. Host Wine, wineserver,
translation bridges, graphics Unix libraries, and native media closures are
ARM64; x86_64 and i386 are guest code only.

## Runtime contents

- Wine 11.12 with ARM64, ARM64EC/ARM64X, x86_64, and i386 guest stages.
- Native ARM64 FEX-derived CPU providers for x86_64 and i386/WoW64.
- DXMT, DXVK, VKD3D-Proton, MoltenVK, and OpenGL/Metal graphics routes.
- FAudio, CoreAudio, SDL, GStreamer, fonts, Wine Mono/FNA/XNA, and managed
  runtime integration.
- Transactional external-drive packaging with hash receipts and a default
  DXMT profile at `runtime/dxmt.conf`.

The source repository intentionally omits generated build trees and separately
licensed payloads. The public runtime release contains only normalized source
provenance and runtime assets; development diagnostics are not shipped.

## Quick start

For an installed runtime:

```sh
export VKMT_RUNTIME_ROOT=/Volumes/AverySSD/VKMT-runtime
export WINEPREFIX=/Volumes/AverySSD/VKMT-prefix
"$VKMT_RUNTIME_ROOT/wine/bin/metalsharp-wine" winecfg
```

Use a prefix outside the runtime. The launcher sets the no-TSO policy, loads
`runtime/dxmt.conf`, and scopes native dependency lookup to the bundled tree.

## Build and package

The full build requires Xcode, CMake/Meson/Ninja, the pinned LLVM-MinGW
cross-toolchain, and the ignored upstream trees named in `AGENTS.md`. Focused
build entry points include:

```sh
scripts/build-wine.sh
scripts/build-dxvk-aarch64.sh
scripts/build-dxvk-vkmt.sh 32
scripts/build-dxmt-arm64ec.sh
scripts/build-dxmt-i386.sh
scripts/build-vkd3d-proton.sh
scripts/build-vkd3d-proton-i386.sh
scripts/build-fex-wow64.sh
scripts/build-sdl-runtime.sh
scripts/build-wine-mono-arm64.sh
```

Verify a staged runtime without creating a prefix:

```sh
scripts/verify-runtime.sh --runtime-root /Volumes/AverySSD/VKMT-runtime
```

Build a clean four-part release from a verified runtime:

```sh
scripts/package-runtime-release.sh \
  --runtime-root /Volumes/AverySSD/VKMT-runtime \
  --output-dir /Volumes/AverySSD/VKMT-release
```

## Architecture and compatibility

The native host boundary, guest execution model, graphics routes, performance
policy, packaging rules, and MetalSharp bundle integration are documented in:

- [Project overview](docs/project-overview.md)
- [Architecture](docs/architecture.md)
- [Graphics](docs/graphics.md)
- [Performance](docs/performance.md)
- [Packaging](docs/package-and-validation.md)
- [MetalSharp bundle integration](docs/metalsharp-integration.md)

The release gate is represented by the normalized acceptance record
`SINGLE_PREFIX_ALL_ARCHITECTURES_OK`. The historical marker used during the
external fresh-install run is retained only in the external evidence directory,
not in the source or runtime package.

## Boundaries

D3D9, DXMT, browser engines, Java, Mono, and installer support are each
accepted according to the files and providers actually shipped. FMOD and
Unity-specific Mono distributions are not copied or fabricated without their
licensed SDKs and version-matched sources; FAudio and Wine Mono are the
redistributable compatibility routes.

## License

The project-owned sources and patches retain their upstream licenses. Review
all third-party notices before redistribution. Commercial MetalSharp runtime
licensing is separate from this public source repository.
