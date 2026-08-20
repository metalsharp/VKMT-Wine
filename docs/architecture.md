# VKMT architecture

This document describes the normalized repository tree and the installed
`VKMT-1.0` runtime tree. Paths in the installed-runtime sections are relative
to the runtime root. The [runtime inventory](runtime-inventory.md) is the
authoritative component-by-component file list; release manifests and SHA-256
receipts are authoritative for exact bytes.

## Execution model

VKMT has one native host boundary and four Windows guest lanes:

```text
Apple Silicon macOS (arm64)
└── Wine host + wineserver + Unix/native closures (arm64)
    ├── ARM64/AArch64 Windows modules  ── native ARM64 PE execution
    ├── ARM64EC Windows modules         ── native ARM64/ARM64EC execution
    ├── x86_64 Windows modules          ── FEX xtajit64
    └── i386/WoW64 Windows modules      ── FEX xtajit
```

The host is never an x86 macOS process and the runtime does not require
Rosetta. FEX is a Windows guest execution provider inside the ARM64 Wine
boundary, not a replacement for the native host. Both `xtajit64` and
`xtajit` are required and are retained with their architecture-specific
compatibility candidates.

The current architecture receipt records:

```text
aarch64-windows  8,328 files
arm64ec-windows  5,687 files
x86_64-windows   8,265 files
i386-windows     8,425 files
aarch64-unix         4 files
```

## Repository source tree

The repository is the source and integration layer. Large generated Wine,
FEX, graphics, dependency, and toolchain outputs remain on the external build
volume and are staged into the release only after verification.

```text
VKMT-Wine/
├── .github/workflows/ci.yml       cross-language CI
├── ci/
│   ├── cmake/                     portable CMake smoke project
│   └── java/                      Java smoke source
├── docs/
│   ├── architecture.md            this host/tree/integration model
│   ├── quick-start.md              installation and launch
│   ├── runtime-inventory.md       installed component inventory
│   ├── graphics.md                graphics providers and checks
│   ├── performance.md             runtime performance contracts
│   ├── package-and-validation.md  packaging and release gates
│   ├── project-overview.md        project boundary
│   ├── metalsharp-integration.md  external bundle integration
│   ├── third-party-licenses.md    licensing and receipts
│   └── *-bundle-*.tsv              imported bundle catalog/file records
├── patches/                       pinned upstream deltas
├── runtime/
│   ├── dxmt.conf                  default DXMT profile
│   └── hotsets/                    release hot-set manifest
├── runtime-manifests/             version and build receipts
├── scripts/                       fetch, build, stage, launch, and verify
├── test/                          source-tree contracts and acceptance probes
├── third_party/                   build-only source/tool inputs
├── tools/                         hot-set and performance utilities
└── LICENSE, README.md             project identity and entry point
```

The source tree is copied into `source/VKMT/` in a release package. The
packager intentionally omits checkout metadata, generated build trees,
CI-only fixtures, tests, disposable evidence, audits, roadmaps, and temporary
prefixes from the redistributable runtime.

## Installed runtime tree

`VKMT-1.0` is assembled under one relocatable root. The top-level tree is:

```text
VKMT-1.0/
├── dependencies/
│   ├── gnutls-arm64/              ARM64 TLS closure
│   ├── gstreamer-arm64/           ARM64 GStreamer closure
│   ├── libfreetype.6.dylib        ARM64 FreeType
│   ├── unity-mono/                three ARM64 Unity Mono engines
│   ├── wine-gecko/                x86/x86_64 Gecko engines/installers
│   └── wine-mono/                 Wine Mono, FNA/XNA/FAudio managed assets
├── graphics/
│   ├── dxmt/                      staged DXMT release-facing assets
│   ├── dxvk/{aarch64,arm64ec,x86_64,i386}/
│   ├── moltenvk/                  Vulkan-to-Metal provider
│   ├── opengl-metal/              ARM64 Metal-backed OpenGL provider
│   ├── vkd3d-proton/{aarch64,arm64ec,x86_64,i386}/
│   └── vkd3d-proton-macos-v1.0/   compatibility/provider receipt set
├── integration/
│   ├── gog/                       native ARM64 gogdl and legal receipts
│   └── steam-webhelper/           Steam WebHelper compatibility layer
├── metadata/                      hashes, provenance, architecture reports
├── providers/                     known-good xtajit/xtajit64 copies
├── runtime/
│   ├── dxmt.conf                  default graphics configuration
│   └── hotsets/                   bounded read-ahead manifest
├── runtime-manifests/             Java, Mono, and Unity Mono receipts
├── scripts/                       relocatable runtime helpers
├── source/
│   ├── VKMT/                      normalized VKMT source snapshot
│   ├── nested-source/             pinned upstream source snapshots
│   ├── third-party-licenses/      upstream notices and license texts
│   └── MetalSharp-WebHelper/      WebHelper source/provenance
├── tools/                         installed hot-set utilities
└── wine/
    ├── bin/                       generated launch adapters
    ├── build-ec/                  active ARM64 Wine build and closures
    ├── lib/                       relocatable graphics/provider links
    └── wine-11.12/                Wine data, fonts, and provider receipts
```

The staged snapshot contains 35,264 files under `wine`, 8,519 under
`dependencies`, 52 under `graphics`, 260 under `source`, 59 under `scripts`,
7 under `integration`, 10 under `metadata`, 2 named providers, 2 runtime
files, 5 runtime manifests, and 2 tools. These counts are recorded in
`metadata/ARCHITECTURE-COUNTS.txt` for the published build.

## What each host contains

### Native macOS host (`wine/build-ec`)

The host side is ARM64-only:

- `wine/build-ec/wine` — native Wine launcher and ARM64 Unix boundary.
- `wine/build-ec/server/wineserver` — native ARM64 process/server boundary.
- `wine/build-ec/dlls/*/*.so`, `libs/`, `loader/`, and `programs/` — Unix
  modules, loaders, libraries, and host-side program support.
- `wine/build-ec/dlls/winecoreaudio.drv/` — CoreAudio integration.
- `wine/build-ec/runtime/gstreamer-arm64/` — ARM64 media closure.
- `wine/build-ec/java-runtime/{i386,x86_64}/` — Windows Java closures used by
  the corresponding guest lanes.
- `wine/build-ec/dxmt-v0.80/aarch64-unix/` — ARM64 `winemetal.so`, `winemac.so`,
  `ntdll.so`, and their native support libraries.
- `wine/build-ec/runtime/hotset/` — ARM64 prefetch helper and hot-set data.

Native dependency lookup is made hermetic by `scripts/vkmt-runtime-env.sh`.
It sets the staged GStreamer paths, typelibs, plugin scanner, prefix-scoped
registry, DXMT configuration, GPU cache generation, and FEX no-TSO variables;
inherited host search paths are not used to replace the bundled closure.

### ARM64/AArch64 guest host

The ARM64 guest lane is the native PE lane. Its Windows modules live under
`wine/build-ec/dlls/*/aarch64-windows/` and `programs/*/aarch64-windows/`.
It receives the ARM64 graphics providers from:

```text
graphics/dxvk/aarch64/
graphics/vkd3d-proton/aarch64/
wine/build-ec/dxmt-v0.80/aarch64-windows/
```

This lane uses native ARM64 Wine PE execution; it does not pass through FEX.

### ARM64EC guest host

ARM64EC modules live under `wine/build-ec/dlls/*/arm64ec-windows/` and use the
ARM64EC graphics lanes:

```text
graphics/dxvk/arm64ec/
graphics/vkd3d-proton/arm64ec/
wine/build-ec/dxmt-v0.80/aarch64-windows/
```

The x86-64 machine type shown by some ARM64EC PE tools is expected: ARM64EC
contains the Windows mixed-architecture ABI while the native host remains
ARM64.

### x86_64 guest host

x86_64 Windows modules live under `wine/build-ec/dlls/*/x86_64-windows/` and
are executed by the required `xtajit64` provider. The matching graphics lanes
are:

```text
providers/xtajit64-arm64ec-known-good.dll
wine/wine-11.12/runtime-providers/xtajit64-arm64ec-known-good.dll
graphics/dxvk/x86_64/
graphics/vkd3d-proton/x86_64/
```

The provider is staged into the Wine system directory by
`scripts/stage-runtime-providers.sh`; prefix receipts record its hash and
source mapping.

### i386/WoW64 guest host

i386 Windows modules live under `wine/build-ec/dlls/*/i386-windows/` and are
executed through the ARM64 `xtajit` provider and Wine WoW64 bridge. The
matching graphics lanes are:

```text
providers/xtajit-arm64-known-good.dll
wine/wine-11.12/runtime-providers/xtajit-arm64-known-good.dll
graphics/dxvk/i386/
graphics/vkd3d-proton/i386/
```

`wow64.dll` and `wow64win.dll` remain in the ARM64 system directory; the i386
closure is staged into the prefix `syswow64` directory. Provider candidates
for context preservation, exception/re-entry handling, SEH dispatch, and TSO
coverage remain under `wine/build-ec/dlls/xtajit/aarch64-windows/` and are not
treated as removable extras.

## Graphics and managed integration

Graphics are lane-separated so Wine never resolves a PE DLL with the wrong
machine type. `scripts/stage-dxmt-runtime.sh` installs the DXMT ARM64 Unix
bridge and the Windows bridge pair; the `graphics/` copies are the release
catalog and are linked into the Wine-facing layout through `wine/lib/`.
The default `runtime/dxmt.conf` is:

```text
dxmt.metalShaderVersion = 310
d3d11.maxFeatureLevel = 12_1
d3d11.metalSpatialUpscaleFactor = 2.0
d3d11.preferredMaxFrameRate = 60
```

Wine Mono/FNA/XNA/FAudio managed assets, Unity Mono engines, Gecko, fonts,
GnuTLS, FreeType, GStreamer, SDL, and Java are staged as separate closures
under `dependencies/`, `wine/build-ec/`, and `runtime-manifests/`. Their
version receipts identify the build or redistribution source without
mixing their native host libraries into the guest PE lanes.

## Integration and verification flow

The integration path is intentionally one-way:

```text
source + patches
    → build scripts and external build trees
    → architecture/provider gates
    → staged runtime root
    → package script + metadata/SHA256SUMS
    → split release assets
    → installer verification and relocation
    → prefix-scoped provider/graphics staging
    → Wine launch
```

`scripts/verify-runtime.sh` checks the prepared tree. Then
`scripts/package-runtime-release.sh` copies the verified tree, replaces
`source/VKMT` with the normalized checkout snapshot, removes development-only
material, rebuilds the package hash receipt, and creates the archive and its
four ordered parts. The release installer verifies the parts, archive stream,
member layout, payload hashes, ARM64 host, and GOG archive before activation.

At runtime, `wine/bin/metalsharp-wine` is a relocatable adapter created by the
installer. It sets `VKMT_RUNTIME_ROOT` and `WINEBUILDDIR`, sources the hermetic
environment, and invokes the ARM64 Wine host. Prefix operations are kept
outside the runtime and are receipt-backed by `scripts/vkmt-prefix`; provider
and graphics updates are hash-checked before they are accepted.

## Related documents

- [Quick Start](quick-start.md)
- [Runtime inventory](runtime-inventory.md)
- [Graphics](graphics.md)
- [Performance](performance.md)
- [Packaging and validation](package-and-validation.md)
- [Third-party licenses](third-party-licenses.md)
