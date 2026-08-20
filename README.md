# VKMT Wine

[![Release](https://img.shields.io/github/v/release/metalsharp/VKMT-Wine?label=release)](https://github.com/metalsharp/VKMT-Wine/releases)

VKMT Wine is an Apple-Silicon-native, cross-architecture Wine runtime for
macOS. The Wine host and native Unix boundary are ARM64; FEX supplies the
execution path for x86_64 and i386/WoW64 Windows applications.

## Architecture

~~~text
Apple Silicon macOS
└── ARM64 Wine host and wineserver
    ├── ARM64/AArch64 Windows
    ├── ARM64EC Windows
    ├── x86_64 Windows  ── FEX xtajit64
    └── i386/WoW64      ── FEX xtajit
~~~

xtajit64 and xtajit are required runtime providers. Both are retained in the
runtime, along with their architecture-specific build and compatibility
variants.

## Quick start

Download the [latest runtime release](https://github.com/metalsharp/VKMT-Wine/releases),
install it to an external volume, and keep the Wine prefix outside the runtime:

~~~sh
export VKMT_RUNTIME_ROOT=/Volumes/VKMT-runtime
export WINEPREFIX=/Volumes/VKMT-prefix
"$VKMT_RUNTIME_ROOT/wine/bin/metalsharp-wine" winecfg
~~~

The launcher selects the bundled native dependencies, disables hardware TSO
for FEX, and loads the default DXMT profile.

## Documentation

- [Complete runtime inventory](docs/runtime-inventory.md)
- [Project overview](docs/project-overview.md)
- [Architecture](docs/architecture.md)
- [Graphics](docs/graphics.md)
- [Performance](docs/performance.md)
- [Packaging and validation](docs/package-and-validation.md)
- [MetalSharp integration](docs/metalsharp-integration.md)
- [Third-party license index](docs/third-party-licenses.md)

The complete inventory is the component-level description of the shipped
runtime. The release's file hashes and asset manifest remain authoritative for
the exact bytes in a particular build.

## License

VKMT combines Wine, FEX, DXMT, DXVK, VKD3D-Proton, MoltenVK, Mono, and other
upstream components. Their license texts and notices are retained with the
runtime source and release assets; see the [third-party license index](docs/third-party-licenses.md).
