# MetalSharp Bundle Audit and VKMT Integration Plan

This is the normalized audit and integration plan for the public MetalSharp
dependency release. It intentionally does not use the old phase or `P1`–`P8`
naming scheme. The downloaded binaries remain outside this repository; VKMT
only records provenance, paths, hashes, findings, and the work required to
rebuild or selectively stage compatible pieces.

## Audit scope and evidence

| Field | Value |
| --- | --- |
| Source release | [MetalSharp `bundles` release](https://github.com/metalsharp/MetalSharp/releases/tag/bundles) |
| Release repository | [metalsharp/MetalSharp](https://github.com/metalsharp/MetalSharp) |
| Release tag | `bundles` |
| Release commit shown by GitHub | `2a6bcc6387cc5a1a0c48146102d3aad1c4abd475` |
| Audit capture | 2026-08-19 UTC |
| Download cache | `/Volumes/AverySSD/MetalSharp-bundles/bundles` |
| Compressed bundle payload | 1.1 GiB across nine `.tar.zst` archives |
| Expanded regular-file payload | 6,376,966,106 bytes (5.94 GiB) |
| Complete member inventory | [`metalsharp-bundle-files.tsv`](metalsharp-bundle-files.tsv) |
| Archive catalog and SHA-256 values | [`metalsharp-bundle-catalog.tsv`](metalsharp-bundle-catalog.tsv) |

All nine archives, both release manifests, and the release API metadata were
downloaded. Every archive passed `zstd -t`; every downloaded asset matched the
SHA-256 digest published by GitHub's release API. The member inventory records
all 16,084 archive members, including 13,829 regular files, 1,726 directories,
and 529 symlinks. Regular members also have an extracted-file SHA-256 and a
`file(1)` classification. No archive member contains an absolute path or a
`..` traversal component, and no duplicate archive member path was found.

The inventory is intentionally committed as text rather than committing the
1.1 GiB binary download. A future audit can reproduce it from the download
cache and compare the archive digests before any payload is staged.

## Bundle contents and disposition

| Asset | Archive members | Regular files | Expanded bytes | Released root | VKMT disposition |
| --- | ---: | ---: | ---: | --- | --- |
| `metalsharp-runtime.tar.zst` | 2,380 | 2,330 | 1,944,805,905 | `runtime/` | **Do not copy directly.** Its Wine host is x86-64 Mach-O; reuse the layout and manifest model only, or rebuild an ARM64 VKMT runtime. |
| `metalsharp-graphics-dll.tar.zst` | 52 | 38 | 555,507,664 | `Graphics/dll/` | **Reference/overlay candidate.** PE files cover x86-64 and i386 guests, but every Unix graphics bridge is x86-64; no native ARM64 bridge is present. |
| `metalsharp-d3d12-developer-sdk.tar.zst` | 2,530 | 2,440 | 2,305,163,945 | `developer-sdk/d3d12/` | **High-value source and probe reference.** Import contracts and probe ideas selectively; rebuild all runtime binaries under VKMT. |
| `metalsharp-assets.tar.zst` | 11,042 | 8,959 | 1,555,589,569 | `assets/` | **Selective only.** ARM64 Mono and the Unity lane are candidates; GPTK, x86 Mono, old DXVK, and unverified XNA are not default VKMT payloads. |
| `fnalibs.tar.zst` | 8 | 6 | 8,571,232 | `fnalibs/` | **Optional FNA lane.** SDL2, FNA3D, FAudio, and theorafile are useful; FMOD is x86-64-only and separately licensed. |
| `goldberg.tar.zst` | 8 | 4 | 3,611,648 | `./x86/`, `./x64/`, `./steamclient/` | **Separate-fetch candidate.** Guest Steam DLLs may be useful after provenance and game-specific validation; never make them part of the core runtime. |
| `metalsharp-scripts-tools.tar.zst` | 31 | 26 | 138,763 | `scripts/tools/` | **Reference only.** The profile/config schemas are useful; the updater and host-native tools must not be copied without a security and architecture review. |
| `metalsharp-steam.tar.zst` | 4 | 3 | 2,399,202 | `steam/` | **Do not integrate directly.** It contains an i386 Steam installer and x86-64/i386 helper payloads. |
| `metalsharp-electron.tar.zst` | 29 | 23 | 1,178,178 | `electron/` | **Frontend reference only.** It is a built Electron application, not a VKMT runtime dependency. |

The two TSV assets are metadata, not payloads. The release manifest describes
archive-level hashes and intended roots; it does not provide a hash for every
member. The committed member inventory supplies those local audit hashes and
must not be treated as upstream provenance until the archive digest is checked.

## Exact path map

### Runtime and host boundary

`metalsharp-runtime.tar.zst` uses this layout:

```text
runtime/
  host/
    HostRuntimeABI.h
    libmetalsharp_host_runtime.dylib
    manifest.json
  metalsharp-backend
  wine/
    bin/                       Wine launcher and tools
    etc/                       dxmt.conf, mscompatdb, Vulkan ICD manifests
    lib/dxvk/i386-windows/     PE32 DXVK D3D8/9/10/11/DXGI
    lib/dxvk/x86_64-windows/   PE32+ DXVK D3D8/9/10/11/DXGI
    lib/metalsharp/            x86-64/i386 ntdll hook DLLs
    lib/moltenvk-vkmt/         MoltenVK dylibs and ICD manifest
    lib/wine/                  the large Wine builtin DLL closure
    share/                     Wine data, fonts, and message catalogs
```

The host split is mixed: `runtime/metalsharp-backend` and
`runtime/host/libmetalsharp_host_runtime.dylib` are ARM64, while
`runtime/wine/bin/wine` and `runtime/wine/bin/wineserver` are x86-64 Mach-O.
The MoltenVK dylib is universal x86-64/ARM64, and the guest DLLs are correctly
PE32 or PE32+ by guest architecture. This is a MetalSharp runtime profile, not
a drop-in replacement for VKMT's native `wine/build-ec/wine` and
`wine/build-ec/server/wineserver`.

The Vulkan ICDs point at a relative path:

```json
{
  "ICD": {
    "library_path": "../../../lib/wine/x86_64-unix/libMoltenVK.dylib",
    "api_version": "1.4.0",
    "is_portability_driver": true
  }
}
```

That relative-path pattern is reusable, but the architecture and VKMT's
existing `test/vkmt_icd.json`/`build-moltenvk.sh` promotion contract must win.

### Graphics DLL split

`metalsharp-graphics-dll.tar.zst` contains four independently named lanes:

```text
Graphics/dll/
  dxmt/
    i386-unix/winemetal.so             # x86-64 Mach-O despite directory name
    i386-windows/{d3d10core,d3d11,dxgi,dxgi_dxmt,winemetal}.dll
    x86_64-unix/winemetal.so           # x86-64 Mach-O
    x86_64-windows/{d3d10core,d3d11,d3d12,dxgi,dxgi_dxmt,nvapi64,nvngx,winemetal}.dll
  dxmt-m12/
    x86_64-unix/{winemetal.so,libc++.1.dylib,libc++abi.1.dylib,libunwind.1.dylib}
    x86_64-windows/{d3d10core,d3d11,d3d12,dxgi,dxgi_dxmt,nvapi64,nvngx,winemetal}.dll
  dxvk/
    i386-windows/{d3d10core,d3d11,d3d9,dxgi}.dll
    x86_64-windows/{d3d10core,d3d11,d3d9,dxgi}.dll
  vkd3d-proton/x86_64-windows/{d3d12,d3d12core,dxgi}.dll
```

This is valuable as a path and ABI reference for VKMT's existing
`third_party/dxvk/runtime/dxvk-vkmt-1a5919b` and
`third_party/vkd3d-proton/install-*` stages. It cannot replace the VKMT
ARM64 Unix side: the x86-64 `winemetal.so` and bundled C++ runtime are not
loadable by a native ARM64 Wine process. Any x86-64 PE overlay must remain
matched to VKMT's ARM64 Unix graphics bridge and pass the existing four-lane
graphics contracts.

### Assets and managed/runtime support

`metalsharp-assets.tar.zst` is a broad application-compatibility archive:

| Path | Contents | Audit result |
| --- | --- | --- |
| `assets/mono-arm64/` | Native ARM64 Mono host libraries, tools, managed assemblies, GAC, and build tooling; 3,734 members | The only large native host runtime candidate. It is not Wine Mono and must not replace VKMT's pinned Wine Mono 11.2.0 without a separate managed-runtime contract. |
| `assets/mono-x86/` | 7,158 members of legacy i386/x86-64 Mono and GTK/GLib support | Contains i386 and x86-64 Mach-O host binaries; excluded by VKMT's no-Rosetta host policy. |
| `assets/unity-mono/` | Four version-marked Unity Mono lanes (`2020.3`, `2021.3`, `2022.3`, `6000.0`) plus `manifest.json` | Useful design for an optional game-local Unity runtime profile. The manifest itself says the payloads are seeded from generic Mono and should be replaced by version-matched Unity payloads. |
| `assets/fna-kickstart/` | FNA managed assemblies, Mono kickstart, universal macOS native libraries, and config | Candidate for an optional FNA/XNA profile after game-local and license validation. |
| `assets/fnalibs/` | FNA3D, FAudio, SDL2, theorafile, and FMOD | Overlaps `fnalibs.tar.zst`; deduplicate rather than stage twice. |
| `assets/dxvk-1.10.3/` | x32/x64 DXVK D3D9–11 DLLs | Old compatibility reference; do not replace VKMT's pinned/rebuilt DXVK lane. |
| `assets/gptk/` | x86-64 D3DMetal framework, `libd3dshared.dylib`, and x86-64 Windows/Unix shims | Not compatible with VKMT's native ARM64 graphics bridge and not an open replacement for VKMT's vkd3d/MoltenVK path. |
| `assets/sdl3/` | ARM64 `libSDL3.dylib` | Useful native reference, but VKMT already builds and validates SDL3 for all guest ABIs. Do not introduce a duplicate unpinned copy. |
| `assets/shims/` | Native audio, SDL, Steam, FNA, and gdiplus shims | Mixed x86-64 and universal host libraries; use only as source/reference for a separately verified provider. |
| `assets/xna/` | Seven named XNA assemblies | All seven files are byte-for-byte identical (789,504 bytes; SHA-256 `5cb7e2690f927964541f180d5270330db635d78d4999461cf809078641496611`). Treat as placeholders or a packaging defect, not real XNA assemblies. |
| `assets/goldberg/` | Guest Steam API DLLs | Separate-fetch only. |

The six GPTK Unix symlinks
`assets/gptk/x86_64-unix/{d3d10,d3d11,d3d12,dxgi,nvapi64,nvngx-on-metalfx}.so`
target `../../external/libd3dshared.dylib`. With the released directory
layout, that resolves to `assets/external/…`, while the actual file is at
`assets/gptk/external/libd3dshared.dylib`; all six are dangling after
extraction. This bundle defect must be fixed upstream before those paths are
considered for any release.

### Developer SDK

The developer SDK is the most reusable part conceptually:

```text
developer-sdk/d3d12/
  README.md
  contracts/       feature, DXGI, D3D12/Metal, ABI, waiver, and unsupported ledgers
  probes/          loader, device, DXGI, resources, descriptors, shaders, PSO, barriers, and game probes
  scripts/         build, stage, preflight, contract validation, replay, and comparison tools
  baselines/       current-state records
  results/         retained summaries and failure indexes
  runtime/         staged x86-64 Wine/DXMT runtime for MetalSharp
```

The contracts/probe structure maps cleanly onto VKMT's `test/`, `scripts/`,
`docs/graphics.md`, and `docs/validation/` layout. The contents are not
drop-in: paths refer to MetalSharp's `vendor/dxmt` tree, the staged runtime is
x86-64 on the Unix side, and the embedded `runtime/manifest.json` references
older `metalsharp-runtime` and `metalsharp-graphics-dll` archive hashes than
the assets on this release. The embedded critical-file hashes do match the
files inside the SDK archive, so the SDK is internally coherent but its
cross-asset references are stale and must be regenerated before publication.

### Launch, Steam, and frontend assets

- `scripts/tools/configs/mtsp-rules.toml` is an app-id-to-renderer profile
  map (`fna_arm64`, `fna_x86`, `m9`, `m11`, `m12`, and `wine_bare`). VKMT can
  adopt this idea as a normalized launch-profile manifest, mapping each
  profile to an existing VKMT prefix/runtime stage rather than copying the
  file's MetalSharp-specific assumptions.
- `scripts/tools/configs/proof-targets.json` is a large application proof
  matrix. Its schema is useful, but its home-directory paths and historical
  status are evidence, not portable VKMT configuration.
- `scripts/tools/updater/update.sh` and `update.py` stop processes with
  `pkill`, remove `/Applications/MetalSharp.app`, mount a DMG, and relaunch it.
  They are not safe VKMT release installers and must not be imported.
- `metalsharp-electron.tar.zst` is compiled JavaScript/Vite/Electron output
  plus fonts and icons. It has no native VKMT runtime bridge.
- `metalsharp-steam.tar.zst` contains `SteamSetup.exe`,
  `steamwebhelper.exe`, and a C wrapper; the binaries are guest x86/i386
  payloads and need separate Steam licensing/provenance.

## Findings that affect release safety

1. **Architecture mismatch is the primary blocker.** The MetalSharp runtime
   and graphics bridge are built for an x86-64 Unix/Wine host profile. VKMT's
   release policy requires ARM64 host Mach-O and uses x86-64/i386 only as
   Windows guest architectures. Direct binary copying would violate the
   no-Rosetta rule and break the native Wine process boundary.
2. **The archive hashes are trustworthy only at archive level.** GitHub's
   published SHA-256 values match all downloads. Member-level hashes are now
   recorded locally in the inventory, but the upstream release does not
   publish a member checksum file for every archive.
3. **The SDK's cross-bundle manifest is stale.** Its embedded runtime and
   graphics archive references do not match the current release manifest. A
   VKMT importer must regenerate any derived manifest from the exact bytes it
   stages, never copy these references as release truth.
   The release's `metalsharp-bundle-manifest.tsv` and its
   `metalsharp-bundle-manifest-0.56.5-installed.tsv` agree on every asset
   except the runtime: current `3c5832ad…` / 329,674,644 bytes versus installed
   `8a37033a…` / 320,007,550 bytes. The developer SDK embeds yet another
   runtime/graphics pair, confirming that derived manifests are build outputs,
   not stable cross-release identifiers.
4. **The GPTK symlink set is broken.** Six released symlinks are dangling in
   the extracted path layout. Do not work around this by changing VKMT's
   loader path; report/fix the source bundle.
5. **The runtime contains duplicate configuration paths.** Both the runtime
   and SDK contain `wine/etc/mscompatdb_rules.toml` and a duplicate
   `wine/etc/etc/mscompatdb_rules.toml`, plus both normal and nested Vulkan ICD
   copies. VKMT should normalize to one canonical `etc/` tree when staging.
6. **The XNA payload is not credible.** Seven different XNA filenames are
   byte-identical. It cannot be accepted as a working XNA assembly set without
   assembly identity and runtime tests.
7. **Licensing and provenance are not interchangeable with compatibility.**
   FMOD, Steam/Goldberg, GPTK/D3DMetal, Mono, Unity Mono, and application
   assets need separate license/provenance records. A passing loader probe is
   not authorization to redistribute them.
8. **The release manifest is incomplete for the asset set.** GitHub exposes
   `goldberg.tar.zst`, but neither upstream TSV manifest lists it. The catalog
   records that omission explicitly; any VKMT release manifest must enumerate
   every payload it downloads or stages.

## VKMT integration plan

The goal is not to make VKMT a copy of MetalSharp. The goal is to use the
release as a source of compatible optional assets, path conventions, contract
ideas, and comparison fixtures while preserving VKMT's ARM64-native runtime.

### Workstream A — freeze provenance and import boundaries

**Deliverables**

- Keep `metalsharp-bundle-catalog.tsv` as the archive-level provenance record.
- Keep `metalsharp-bundle-files.tsv` as the complete path/hash/type inventory.
- Add a release note to every future imported asset naming its source archive,
  release SHA-256, member SHA-256, license, intended guest/host architecture,
  and package action.
- Reject raw MetalSharp runtime or graphics extraction into `wine/build-ec`.

**Exit gate**

The archive hash, member hash, path, PE machine, Mach-O slice, and license
are known before a file is allowed into a VKMT stage. Any unknown or mixed
architecture member remains separate-fetch or reference-only.

### Workstream B — port the D3D12 contract vocabulary

Use the SDK's `contracts/` and `probes/` as a review source, not as an
unreviewed code import. Map its concepts to these VKMT locations:

| MetalSharp input | VKMT destination | Required treatment |
| --- | --- | --- |
| `contracts/feature-support-contract.json` | `test/d3d12_graphics_contract.c`, `docs/graphics.md` | Translate feature claims into VKMT's existing conservative capability contract. Keep unsupported features explicitly denied. |
| `contracts/dxgi-contract.json` | `test/d3d12_graphics_contract.c` and DXGI probe coverage | Add only missing factory/adapter/LUID assertions; preserve VKMT's four guest-ABI runners. |
| `contracts/winemetal-bridge-contract.json` | `scripts/probe-dxmt-arm64ec.sh`, graphics validation | Compare exports against the ARM64 VKMT DXMT bridge, not the x86-64 `winemetal.so`. |
| `contracts/unsupported-api-ledger.json` and `risky-stub-ledger.json` | `docs/graphics.md` and validation capability tables | Import the conservative “reported only when proven” policy. Do not import unsupported paths as implemented. |
| `probes/probe_*` and `scripts/run-probes.sh` | `test/`, `scripts/probe-d3d12*`, `docs/validation/` | Port test intent and markers to VKMT paths; remove MetalSharp source paths and legacy workstream labels. |

**Exit gate**

The VKMT D3D12 contract passes on ARM64, ARM64EC, x86_64, and i386 where the
feature is applicable, with `scripts/probe-d3d12-graphics-contract.sh` and
the existing acceptance receipts remaining authoritative. No MetalSharp
x86-64 Unix binary is used to obtain a green result.

### Workstream C — rebuild matched native graphics providers

1. Keep `third_party/vkd3d-proton` as the source of truth and build the PE
   lanes with VKMT's existing `build-vkd3d-proton-*.sh` scripts.
2. Keep `third_party/dxvk` and VKMT's targeted DXVK stages as the D3D9–11
   source of truth. The MetalSharp DXVK 1.10.3 files are comparison fixtures,
   not replacements.
3. Keep VKMT's ARM64 MoltenVK build and
   `wine/build-ec/dlls/win32u/libMoltenVK.dylib` promotion path. Reuse only the
   relative-ICD layout idea after checking every path against an actual
   prefix.
4. Treat MetalSharp's x86-64 PE D3D12/DXGI DLLs as an optional overlay
   candidate only for the VKMT x86_64 guest lane. Before consideration, run
   export/ABI checks, `x18` scans, dependent-library checks, and the full
   D3D12 graphics contract. Do not overwrite ARM64, ARM64EC, or i386 stages.
5. Do not import `dxmt-m12` binaries directly. If M12 functionality is wanted,
   rebuild its source-equivalent bridge for ARM64 Unix and keep the existing
   VKMT DXMT provider hash and prefix staging policy.

**Exit gate**

Every staged graphics tuple has one native ARM64 Unix bridge, one matching
guest PE architecture, one source revision, and one prefix receipt. No
`x86_64-unix` file appears under an ARM64 VKMT runtime.

### Workstream D — add optional managed and FNA profiles

1. Keep official Wine Mono 11.2.0 as VKMT's default managed runtime. Its
   existing source/build/probe path is already recorded in
   `scripts/fetch-wine-mono-runtime.sh`, `scripts/build-wine-mono-arm64.sh`,
   and `scripts/probe-wine-mono-runtime.sh`.
2. Evaluate `assets/mono-arm64/` only as an optional native ARM64 Mono/FNA or
   Unity game-local runtime. Compare its CLR ABI, TLS behavior, 16-KiB page
   handling, and native dependency closure against VKMT's managed probes.
3. Use `assets/unity-mono/manifest.json` as the model for version-selected
   Unity deployment, but require real version-matched Unity Mono payloads.
   The generic seeded libraries are not sufficient proof.
4. Evaluate `fnalibs.tar.zst` for a separate FNA profile. Deduplicate SDL2
   against VKMT's validated SDL2 stage, use only the ARM64 slice of universal
   libraries for native helpers, and keep FMOD outside the default package.
5. Reject `assets/xna/` until seven distinct assembly identities and a real FNA
   or XNA launch/readback contract pass.

**Exit gate**

The `managed` and optional `fna` profiles have independent provenance,
architecture, license, staging, and behavioral receipts. Core/graphics VKMT
releases remain unchanged if these profiles are absent.

### Workstream E — normalize launch profiles and app evidence

Port the idea behind `scripts/tools/configs/mtsp-rules.toml` into a VKMT-owned
launch profile manifest. It should map app ID or detected executable to:

- `core`, `graphics`, `browser`, `managed`, or an optional FNA/Unity profile;
- the existing `scripts/vkmt-prefix` profile;
- the correct DXVK/vkd3d/DXMT provider stage;
- required redistributables and diagnostics;
- expected guest architecture and whether the route is accepted or
  diagnostic-only.

Do not copy MetalSharp's updater or absolute home-directory proof records.
Store portable paths relative to the VKMT runtime/prefix, and keep user saves,
bottles, shader caches, and diagnostics outside transactional runtime replace
operations.

**Exit gate**

One app profile can be resolved, staged, verified, launched, and recorded in
one existing prefix without invoking an unsafe process-kill/update script or
silently selecting an x86-64 host library.

### Workstream F — release packaging and acceptance

Before an imported component can appear in a VKMT release:

1. Verify the source archive digest and every staged member digest.
2. Verify Mach-O host slices are ARM64-only and PE files match the intended
   guest lane.
3. Verify symlinks after extraction; reject dangling or path-escaping links.
4. Verify no duplicate normalized configuration path (`etc/etc`) is staged.
5. Verify the source/license/provenance record and package action.
6. Run the applicable VKMT prefix, graphics, managed, browser, and release
   validation runners.
7. Compare the resulting runtime manifest with the exact staged bytes. Never
   reuse the stale embedded SDK manifest.
8. Preserve the existing rule that diagnostics, caches, candidate providers,
   and separately licensed external payloads are not silently packaged.

**Release gate**

An imported asset is either `required-runtime`, `optional-external` with a
separate fetch/install receipt, `test-only`, or `reference-only`. There is no
unclassified “bundle” bucket and no architecture exception for convenience.

## Recommended order of implementation

1. **Keep the audit metadata and reject unsafe direct copies.** This is
   complete in this change and prevents accidental architecture regressions.
2. **Port the developer SDK's contract vocabulary** into the existing VKMT
   D3D12/DXGI probes, starting with feature denial, DXGI factory behavior,
   descriptors, barriers, and shader/PSO coverage.
3. **Build a matched ARM64 provider comparison harness** that can compare a
   VKMT-built PE overlay against the MetalSharp x86-64 PE files without
   staging MetalSharp's Unix binaries.
4. **Create the normalized launch-profile manifest** and connect it to
   `scripts/vkmt-prefix` and the current provider sync commands.
5. **Add optional managed/FNA/Unity lanes** only after their payloads have
   independent provenance and four-architecture or game-local evidence.
6. **Regenerate and verify the complete VKMT release manifest** from the
   actual staged tree, then run the existing package gate in
   `scripts/verify-preservation.sh --inventory`.

The practical conclusion is that MetalSharp contributes the most as a
contract/probe/layout reference and as a source of selectively useful ARM64
managed/FNA assets. Its bundled x86-64 Wine/DXMT runtime is not a binary base
for VKMT. Native rebuilds and VKMT's existing architecture gates remain the
only path to a release-quality integration.
