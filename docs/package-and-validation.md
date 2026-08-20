# VKMT packaging and validation

## Package policy

A redistributable package contains runtime assets and provenance only. Host
Mach-O files must be ARM64; guest PE files may be ARM64/AArch64, ARM64EC,
x86_64, or i386. No Rosetta bridge, tracing configuration, disposable prefix,
cache, log, test, probe, or generated evidence file may be included.

Separately licensed payloads are shipped only with a matching license and
source/hash receipt. The release includes a source-built ARM64 Unity Mono
BleedingEdge engine and managed profiles; FAudio and Wine Mono remain the
redistributable compatibility routes. Proprietary FMOD runtime libraries are
not synthesized or copied without a valid redistributable SDK receipt.

## Required runtime inventory

| Asset | Required location | Acceptance |
| --- | --- | --- |
| Wine host | `wine/build-ec/wine` | ARM64 Mach-O |
| wineserver | `wine/build-ec/server/wineserver` | ARM64 Mach-O |
| WoW64 providers | `wine/build-ec/dlls/xtajit*/aarch64-windows` | hash and PE machine check |
| DXMT Unix bridge | `wine/build-ec/dxmt-v0.80/aarch64-unix/winemetal.so` | ARM64 Mach-O |
| DXMT guest bridges | `wine/build-ec/dxmt-v0.80/{aarch64,i386}-windows` | PE closure |
| DXVK lanes | `graphics/dxvk/{aarch64,arm64ec,x86_64,i386}` | D3D11/D3D9/DXGI |
| VKD3D lanes | `graphics/vkd3d-proton/{aarch64,arm64ec,x86_64,i386}` | D3D12/D3D12core |
| DXMT defaults | `runtime/dxmt.conf` | exact four option values |
| Native media | `wine/build-ec/runtime/gstreamer-arm64` and CoreAudio | ARM64 closure and manifest |
| Managed/FNA | `dependencies/wine-mono/wine-mono-11.2.0` | ARM64/x86_64/i386 payloads |
| Unity Mono | `dependencies/unity-mono/{unity-main,unity-6000.1-mbe,unity-2022.3-mbe}-6.13.0` | three ARM64 native engines and build receipts |
| Fonts | `wine/wine-11.12/fonts` and build font closure | present and relocatable |
| Receipts | `metadata/SHA256SUMS`, `metadata/PROVENANCE.txt` | verified before activation |

## Release procedure

1. Start from a clean checkout and a separately verified runtime tree.
2. Run `scripts/verify-runtime.sh --runtime-root PATH`.
3. Run `scripts/package-runtime-release.sh` to create the archive and four
   ordered parts on the external drive.
4. Verify `PARTS-SHA256SUMS.txt`, the archive zstd stream, the member manifest,
   and the generated installer constants.
5. Install with the generated installer to a new external target. Existing
   MetalSharp installations are never selected as the target.
6. Run the fresh install verifier, `wineboot --init` with a disposable prefix,
   and the four-lane single-prefix acceptance runner from the external evidence
   workspace. Remove the temporary fixtures and prefix afterward.
7. Upload the four parts, installer, manifest, GOG integration archive, and
   reassembly instructions with asset clobbering only after all local hashes
   match the release API.

## Current release receipt

The clean runtime archive prepared for publication at
`VKMT-1.0` includes ARM64 DXVK D3D10, D3D10.1, D3D11,
D3D9, and DXGI lanes plus Unity Mono engines from the current, Unity 6000.1,
and Unity 2022.3 branches. The release asset manifest and
`PARTS-SHA256SUMS.txt` are the authoritative hash receipt for each published
asset.
The fresh external install passed `VKMT_RUNTIME_VERIFIED`, `WINEBOOT_RC0`,
and the four-lane single-prefix acceptance result. Raw logs and temporary
prefixes are retained only in the external workspace, never in this checkout
or the release package.
