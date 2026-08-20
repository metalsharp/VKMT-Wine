# VKMT Wine runtime inventory

This document describes the current VKMT runtime layout and the contents of
the public release. Paths are relative to the installed runtime root. It is a
component inventory, not a build plan; the release manifest and SHA-256
receipts remain authoritative for the exact file list and bytes.

## Release identity

| Field | Value |
| --- | --- |
| Release | [VKMT-1.0](https://github.com/metalsharp/VKMT-Wine/releases/tag/VKMT-1.0) |
| Runtime archive | MetalSharp-Wine-Runtime-COMPLETE-all-arch-2026-07-31.tar.zst |
| Runtime archive SHA-256 | 02f42be17c776629ca786e8689aef7069d4300151e69ef95f8ac68f9bdd9d3a8 |
| Release shape | One zstd archive split into four ordered parts |
| Host | Apple Silicon macOS, ARM64-native Wine boundary |
| Guest lanes | ARM64/AArch64, ARM64EC, x86_64, i386/WoW64 |

The release also publishes the installer, the bundle manifest, the GOG
support archive, PARTS-SHA256SUMS.txt, and REASSEMBLE.txt.

## Architecture and execution

| Windows lane | Execution provider | Graphics/provider role |
| --- | --- | --- |
| ARM64/AArch64 | Native ARM64 Wine PE execution | ARM64 DXVK, DXMT, VKD3D-Proton |
| ARM64EC | Native ARM64/ARM64EC Wine PE execution | ARM64EC DXVK, DXMT, VKD3D-Proton |
| x86_64 | FEX xtajit64 | x86_64 DXVK, DXMT, VKD3D-Proton |
| i386/WoW64 | FEX xtajit | i386 DXVK, DXMT, VKD3D-Proton |

The host-side Wine executable, wineserver, Unix bridges, and native media
closures are ARM64. xtajit64 and xtajit are not optional extras: both are
required FEX execution providers and are retained in the staged runtime.

The current architecture receipt reports:

~~~text
aarch64-windows:  8,328 files
arm64ec-windows:  5,687 files
x86_64-windows:   8,265 files
i386-windows:     8,425 files
aarch64-unix:         4 files
~~~

## Runtime root

| Path | Contents |
| --- | --- |
| wine/ | Complete Wine 11.12 host, wineserver, loader, programs, libraries, per-lane PE DLL closure, fonts, native Unix modules, FEX providers, media, Java, SDL, and installer support. |
| graphics/ | DXVK, VKD3D-Proton, MoltenVK, and OpenGL/Metal graphics routes. |
| dependencies/ | GnuTLS, FreeType, GStreamer support, Wine Mono, Wine Gecko, and three Unity Mono ARM64 engines. |
| providers/ | Named known-good FEX provider copies for xtajit and xtajit64. |
| integration/ | GOG downloader support and the Steam WebHelper compatibility wrapper. |
| runtime/ | The default dxmt.conf and the all-architecture hot-set manifest. |
| runtime-manifests/ | Version and provenance manifests for Mono, Java, and Unity Mono assets. |
| scripts/ | Build, stage, launch, environment, cache, hot-set, integration, and verification helpers shipped with the runtime/source snapshot. |
| tools/ | ARM64 hot-set prefetch and snapshot utilities. |
| metadata/ | Hashes, architecture counts, dependency reports, provenance, and symlink receipts. |
| source/ | Normalized VKMT source, pinned upstream source snapshots, patches, and license texts. |

The current staged snapshot contains 35,264 files under wine, 8,519 under
dependencies, 52 under graphics, 260 under source, 59 under scripts, 7 under
integration, 10 under metadata, 2 named providers, 2 runtime files, 5 runtime
manifests, and 2 tools.

## Wine host and native runtime

The wine/ tree contains the full host and guest closure rather than a
minimal launcher-only subset:

- wine/build-ec/wine — ARM64-native Wine executable.
- wine/build-ec/server/wineserver — ARM64-native wineserver.
- wine/build-ec/loader, programs/, libs/, dlls/, nls/, and fonts/ — Wine
  loader, programs, libraries, Windows API/DLL closure, locale data, and
  CoreFonts/Windows font assets for all four guest lanes.
- wine/build-ec/dlls/xtajit/aarch64-windows/xtajit.dll — the i386/WoW64
  FEX provider.
- wine/build-ec/dlls/xtajit64/aarch64-windows/xtajit64.dll and
  wine/build-ec/dlls/xtajit64/arm64ec-windows/ — the x86_64 FEX provider and
  its ARM64EC implementation objects.
- wine/build-ec/dlls/xtajit/aarch64-windows/ — the retained compatibility
  candidates for context preservation, exception/re-entry handling, SEH
  dispatch, and the TSO load/store/effective-address variants. These are
  preserved for runtime coverage and are not discarded as “extra” DLLs.
- wine/build-ec/dxmt-v0.80/ — the DXMT Unix bridge, Windows bridges, import
  libraries, and retained Metal cache backup.
- wine/build-ec/runtime/gstreamer-arm64/ — ARM64 GStreamer libraries,
  plugins, GLib/GObject/GStreamer typelibs, and libexec plugins.
- wine/build-ec/dlls/winecoreaudio.drv/ — the CoreAudio Wine driver.
- wine/build-ec/libs/faudio/ — FAudio libraries and per-lane build outputs.
- wine/build-ec/sdl-runtime/ — SDL2 and SDL3 DLLs, import libraries, and
  headers for ARM64, ARM64EC, x86_64, and i386.
- wine/build-ec/java-runtime/{i386,x86_64}/ — Windows Java runtime closures,
  including Java executables, JNI libraries, runtime libraries, certificates,
  fonts, and notices.
- wine/build-ec/installer-runtime/innoextract/ — the ARM64 installer
  extraction utility and its relocatable dependency closure.

The named provider copies are also available at:

~~~text
providers/xtajit-arm64-known-good.dll
providers/xtajit64-arm64ec-known-good.dll
wine/wine-11.12/runtime-providers/xtajit-arm64-known-good.dll
wine/wine-11.12/runtime-providers/xtajit64-arm64ec-known-good.dll
~~~

## Graphics stack

### DXVK

DXVK is split by guest lane so Wine does not load a DLL with the wrong PE
machine type:

| Path | Included DLL set |
| --- | --- |
| graphics/dxvk/aarch64/ | d3d10_1.dll, d3d10.dll, d3d10core.dll, d3d11.dll, d3d9.dll, dxgi.dll |
| graphics/dxvk/arm64ec/ | d3d8.dll, d3d9.dll, d3d10core.dll, d3d11.dll, dxgi.dll and import libraries |
| graphics/dxvk/x86_64/ | d3d8.dll, d3d9.dll, d3d10core.dll, d3d11.dll, dxgi.dll and import libraries |
| graphics/dxvk/i386/ | d3d8.dll, d3d9.dll, d3d10core.dll, d3d11.dll, dxgi.dll and import libraries |

### DXMT

wine/build-ec/dxmt-v0.80/ includes:

- aarch64-unix/{ntdll.so,winemac.so,winemetal.so,libunwind.1.dylib};
- aarch64-windows/{d3d10core.dll,d3d11.dll,dxgi.dll,winemetal.dll};
- i386-windows/{d3d10core.dll,d3d11.dll,dxgi.dll,winemetal.dll}; and
- matching import libraries plus the retained stock-wine-builtins and
  Metal-cache backup files.

### D3D12, Vulkan, and OpenGL

- graphics/vkd3d-proton/{aarch64,arm64ec,x86_64,i386}/ contains d3d12.dll
  and d3d12core.dll for each guest lane.
- graphics/moltenvk/ contains the Vulkan-to-Metal MoltenVK runtime.
- graphics/opengl-metal/ contains the Metal-backed OpenGL provider and
  per-lane Wine built-in locations.

The default runtime/dxmt.conf is:

~~~text
dxmt.metalShaderVersion = 310
d3d11.maxFeatureLevel = 12_1
d3d11.metalSpatialUpscaleFactor = 2.0
d3d11.preferredMaxFrameRate = 60
~~~

## Managed, media, browser, font, and Java assets

| Path | Included assets |
| --- | --- |
| dependencies/wine-mono/wine-mono-11.2.0/ | Wine Mono runtime, Mono libraries for ARM64/x86/x86_64, FNA3D, FNAMF, FAudio, XNA framework assemblies, WineMono FNA assemblies, support MSI/CAB files, and managed profiles. |
| dependencies/unity-mono/unity-main-6.13.0/ | Source-built ARM64 Unity Mono BleedingEdge runtime for the current Unity branch. |
| dependencies/unity-mono/unity-6000.1-mbe-6.13.0/ | Source-built ARM64 Unity Mono BleedingEdge runtime for Unity 6000.1. |
| dependencies/unity-mono/unity-2022.3-mbe-6.13.0/ | Source-built ARM64 Unity Mono BleedingEdge runtime for Unity 2022.3. |
| dependencies/wine-gecko/{wine-gecko-2.47.4-x86,wine-gecko-2.47.4-x86_64}/ | Wine Gecko browser engines and their MSI installers for x86 and x86_64. |
| dependencies/gnutls-arm64/ | ARM64 GnuTLS closure plus crypt32 and secur32 support. |
| dependencies/gstreamer-arm64/ | Staged ARM64 GStreamer dependency closure. |
| dependencies/libfreetype.6.dylib | Native ARM64 FreeType library. |
| wine/build-ec/fonts/ and wine/wine-11.12/fonts/ | CoreFonts, Wine font resources, VGA/system fonts, and source font assets. |
| runtime-manifests/ | Wine Mono 11.2.0, Eclipse ECJ 4.6.1, Oracle JRE 8u501 ARM64, Temurin JRE 8u472 i386, Temurin JRE 8u492 x86_64, and all three Unity Mono build receipts. |

FMOD SDK binaries are not included without a redistributable SDK receipt.
FAudio, CoreAudio, Wine Mono, FNA3D, and the XNA/FNA managed assemblies are
the included compatibility routes.

## Integration assets

| Path | Contents |
| --- | --- |
| integration/gog/ | ARM64 gogdl, GPL notice, README, provenance, and SHA-256 receipt. |
| integration/steam-webhelper/ | Steam WebHelper compatibility wrapper source and bundled executable. |
| .metalsharp-runtime-install | Release identity, archive hash, GOG asset hash, install timestamp, and no-TSO marker. |
| README.txt | Installed-package quick-start notice. |

## Source, patches, and notices

The runtime source snapshot retains:

- source/VKMT/ — normalized VKMT documentation, scripts, patches, runtime
  configuration, manifests, and hot-set tooling;
- source/nested-source/Wine-14c236a84fdb/;
- source/nested-source/FEX-a4128f01913d/;
- source/nested-source/DXMT-00754a6/;
- source/nested-source/MoltenVK-1be06988/;
- source/nested-source/innoextract-67b6420/;
- source/MetalSharp-WebHelper/; and
- source/third-party-licenses/ with upstream license texts and notices.

The source and runtime provenance records pin Wine, FEX, DXMT, MoltenVK, and
innoextract revisions. The exact list is in metadata/PROVENANCE.txt.

VKMT-authored repository material is covered by the root [MIT License](../LICENSE).
That license does not replace the upstream licenses or commercial terms for
the bundled runtime components; see [third-party licenses](third-party-licenses.md).

## Metadata and verification

The following files provide the release receipts and are included with the
runtime:

~~~text
metadata/SHA256SUMS
metadata/PROVENANCE.txt
metadata/ARCHITECTURE-COUNTS.txt
metadata/KEY-FILE-ARCHITECTURES.txt
metadata/MACHO-DEPENDENCIES.txt
metadata/NONRELOCATABLE-DEPENDENCIES.txt
metadata/MACHO-WITHOUT-ARM64.txt
metadata/ABSOLUTE-SYMLINKS.txt
metadata/RELOCATED-SYMLINKS.txt
metadata/RELEASE-CLEANUP.txt
~~~

The release gate covers hash integrity, ARM64 host architecture, guest PE
lanes, provider staging, graphics/configuration presence, fresh wineboot,
and one-prefix execution across ARM64, ARM64EC, x86_64, and i386/WoW64.

## Deliberately not shipped

The redistributable runtime does not ship disposable prefixes, logs, probes,
audits, roadmaps, test fixtures, validation evidence, or tracing configuration.
Required runtime DLLs—including xtajit64, xtajit, DXMT bridges, and their
retained compatibility variants—are not removed by this policy.
