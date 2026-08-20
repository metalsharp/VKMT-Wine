# D3DMetal integration roadmap for VKMT Wine

## Executive result

The Sikarugir audit is complete. Sikarugir is a working Wineskin-style
wrapper and configuration implementation for Apple Game Porting Toolkit
(GPTK) D3DMetal. Its implementation is the engine-selection logic, required
Wine filesystem layout, and runtime configuration; the proprietary D3DMetal
provider is supplied by the selected GPTK engine rather than reimplemented in
Sikarugir's open-source repository.

The current VKMT release is a different architecture:

    Apple Silicon macOS
    └── ARM64 Wine host
        ├── ARM64/AArch64 and ARM64EC Windows guests
        ├── x86_64 Windows guests through FEX xtajit64
        └── i386/WoW64 Windows guests through FEX xtajit

The observed GPTK/D3DMetal payload in the existing bundle catalog is
x86_64 Mach-O and expects an x86_64-unix Wine closure. The current VKMT
runtime has an ARM64 host and a working FEX x86_64/i386 Windows guest path,
but it does not yet expose the D3DMetal provider boundary required by the
Sikarugir engine layout. That is the adaptation work for this phase.

This document therefore treats Sikarugir's working D3DMetal pipeline as the
integration contract: preserve its provider layout and engine-selection
semantics, conform the guest/host transitions to VKMT's ARM64 runtime, and
prove the resulting D3D11/D3D12 path. No proprietary Apple binary is
committed to this repository.

## Audited source and evidence

| Source | Revision | Audited contents | Result |
| --- | --- | --- | --- |
| Sikarugir | 39710f11e0b9a1b4a1a7110ef8c8ad6fbf1fe786 | 20 tracked files: README, one image, issue metadata, and 12 D3DMetal PDFs covering 1.1, 2.0, 2.1, and 3.0 | Working wrapper documentation and provider contract |
| Sikarugir FOSS sources | 4be1b048f8df14b073a6e39e8245bbb52c6a71c0 | 75 tracked source/project files; LGPL-2.1 license | Working engine-selection/configuration layer; GPTK supplies the provider |
| Local binary catalog | docs/metalsharp-bundle-files.tsv | Historical GPTK members and hashes | D3DMetal and helper Mach-O members are x86_64 |
| Installed GPTK 3.0-2 | /Applications/Game Porting Toolkit.app/Contents/Resources/wine/lib | External D3DMetal framework, libd3dshared.dylib, and x86_64-unix Wine closure | All inspected native members are x86_64; rejected by the staging gate |
| Current published runtime tree | /Volumes/AverySSD/VKMT-roadmap-2/fresh-install-published | ARM64 Wine host and current graphics/runtime closure | No D3DMetal payload or x86_64-unix Wine lane |

The complete source checkouts used for the audit are retained outside the VKMT
repository at:

    /Volumes/AverySSD/Sikarugir-audit
    /Volumes/AverySSD/Sikarugir-foss-sources-audit

They are audit inputs, not runtime dependencies.

The published VKMT-1.0 release manifest was also checked directly from GitHub:
`metalsharp-bundle-manifest.tsv` has nine release entries and no D3DMetal,
GPTK, libd3dshared, or x86_64-unix entry. Its runtime note explicitly
identifies the archive as a clean runtime with no audits or roadmaps. The
locally retained member manifest for that exact archive was checked as well;
its archive SHA-256 is
`02f42be17c776629ca786e8689aef7069d4300151e69ef95f8ac68f9bdd9d3a8`, and
`rg` finds zero D3DMetal, GPTK, libd3dshared, or x86_64-unix members. Direct
extraction of the two host members from that archive reports both
`wine/build-ec/tools/wine/wine` and `wine/build-ec/server/wineserver` as
Mach-O `arm64`. The public release therefore remains D3DMetal-free by design.

## What Sikarugir actually implements

The public Sikarugir repository contains the Apple license, acknowledgements,
and versioned GPTK read-me documents. The FOSS source repository contains the
configuration UI and wrapper metadata that makes the D3DMetal engine work
when paired with the GPTK provider.

The relevant FOSS behavior is:

1. It exposes a D3DMETAL wrapper property and a D3DMetal checkbox.
2. It checks for a d3dmetal_force marker in the Wine engine.
3. It enables the option on macOS Sonoma or later. On Intel builds it also
   requires the process to be translated; the ARM64 build removes that
   translated-process requirement.
4. When the marker and lib/wine/x86_64-unix/ntdll.so are present, it treats
   D3DMetal as forced and disables DXVK.
5. Selecting D3DMetal disables alternate translation-layer selections, enables
   the CrossOver-MoltenVK compatibility flag used by that engine, and disables
   fast-math and msync controls for the forced engine.
6. The GPTK documents place the provider under the Wine engine's lib
   directory. Version 2.x documents lib/external/D3DMetal.framework and
   lib/external/libd3dshared.dylib; version 3.0 documents the complete
   lib/wine and lib/external trees.
7. Version 3.0 documents x86_64-unix and x86_64-windows D3DMetal lanes,
   D3DM_SUPPORT_DXR, D3DM_ENABLE_METALFX, and the separate
   ROSETTA_ADVERTISE_AVX control. The last control is not appropriate for
   VKMT because VKMT does not use Rosetta.
8. HUD, Metal capture, and DXIL debug processing are diagnostic paths. They
   are not enabled by VKMT.

This is Sikarugir's working engine-selection and filesystem-layout
implementation. The Apple provider remains an external dependency; this
phase adapts the working path to VKMT rather than replacing it with another
translation backend.

## D3DMetal pipeline reconstructed from the documents

The documented GPTK layout is:

    lib/
    ├── external/
    │   ├── D3DMetal.framework
    │   └── libd3dshared.dylib
    ├── wine/
    │   ├── x86_64-unix/
    │   │   ├── d3d10.so -> ../../external/libd3dshared.dylib
    │   │   ├── d3d11.so -> ../../external/libd3dshared.dylib
    │   │   ├── d3d12.so -> ../../external/libd3dshared.dylib
    │   │   └── dxgi.so -> ../../external/libd3dshared.dylib
    │   └── x86_64-windows/
    │       ├── d3d10.dll
    │       ├── d3d11.dll
    │       ├── d3d12.dll
    │       └── dxgi.dll
    └── wine/<custom Wine closure>

The application path is:

    Windows x86_64 application
      -> x86_64 Wine PE and Unix bridge
      -> libd3dshared.dylib
      -> D3DMetal.framework
      -> Metal on Apple Silicon

The important distinction is that the documented application and Wine Unix
closure are x86_64. They are run in a Rosetta-based GPTK environment. That
path cannot be transplanted into the ARM64-native VKMT host by retaining only
the framework.

## Architecture and licensing gates

### Architecture gate

The provider is acceptable to VKMT only when every Mach-O member in the
framework and libd3dshared.dylib reports exactly arm64. Fat binaries,
x86_64 binaries, i386 binaries, Rosetta-only binaries, and host-side
translation shims are rejected.

The installed GPTK 3.0-2 was also tested directly: its
lib/external/libd3dshared.dylib and D3DMetal.framework binary report x86_64,
and its Wine closure is under x86_64-unix. The current release verifier remains
responsible for the ARM64 host and the FEX guest providers. D3DMetal is an
additional Sikarugir/GPTK graphics path and does not change the required
xtajit64 or xtajit providers.

### Licensing gate

The Sikarugir PDFs reproduce Apple's GPTK license. The license permits
internal use, testing, and evaluation on Apple-branded hardware, and permits
limited non-commercial distribution only under its terms. It prohibits
reverse engineering and requires the applicable notices. This is not
compatible with silently placing an Apple payload inside the public MIT
VKMT release or treating it as VKMT-authored code.

The intake script therefore requires both the Apple license and the complete
acknowledgements receipt, writes a private-noncommercial-only provenance
boundary, and never downloads or modifies the provider. The public package
path refuses unreceipted/private D3DMetal content.

## Executed integration work

### Source audit

Completed. The two Sikarugir repositories, all versioned D3DMetal PDFs, the
FOSS configuration source, the current VKMT source tree, the current published
runtime tree, the installed GPTK 3.0-2 payload, and the historical bundle file
catalog were inspected.

### Safe provider intake

Implemented:

    scripts/stage-d3dmetal-runtime.sh

It accepts an externally obtained Apple GPTK payload only when:

- external/D3DMetal.framework and external/libd3dshared.dylib exist;
- framework symlinks remain relative and resolve inside the framework;
- every Mach-O member is exactly ARM64;
- a current VKMT Wine build exists;
- an Apple license and acknowledgements receipt are supplied; and
- the destination does not already contain a provider.

The canonical private staging path is:

    graphics/d3dmetal/external/
    graphics/d3dmetal/legal/
    graphics/d3dmetal/PROVENANCE.txt
    graphics/d3dmetal/SHA256SUMS

The documented Wine lookup paths are represented by explicit relative
symlinks under:

    wine/lib/external/

The script currently prints that activation remains blocked until the VKMT
Wine loader contract is installed. That contract is an implementation item,
not a reason to reject Sikarugir's working D3DMetal design; merely copying a
framework is insufficient without wiring its actual guest and Unix lanes.

### Provider verification

Implemented:

    scripts/verify-d3dmetal-runtime.sh

The provider-only mode verifies provider architecture, symlink containment,
license/acknowledgements receipts, provenance boundary, and payload hashes.
The default mode additionally requires an explicit
graphics/d3dmetal/VKMT-WINE-CONTRACT.txt receipt covering the ARM64 loader
and both x86_64 and i386 guest lanes.

The verifier also checks the provider ABI, not only filenames and CPU slices:

- `libd3dshared.dylib` must export Wine's `___wine_unix_call_funcs` table;
- the framework must export `CreateDXGIFactory`, `D3D11CreateDevice`,
  `D3D12CreateDevice`, and `GFXT_Initialize`; and
- neither provider member may link a Rosetta dependency.

This is the native-host boundary required by VKMT's current build policy. The
installed GPTK 3.0-2 fails before this ABI gate because all inspected provider
members are x86_64 and the bundle uses an x86_64-unix Wine closure.

### Opt-in environment handling

Implemented:

    scripts/vkmt-d3dmetal-env.sh

scripts/vkmt-runtime-env.sh loads this file only when
VKMT_D3DMETAL_ENABLE=1. The profile is fail-closed and does not enable
D3DMetal by default. It sets only the documented DXR/MetalFX feature
switches, the Sikarugir-compatible `D3DMETAL_RUNTIME_DIR`,
`D3DMETAL_EXTERNAL_DIR`, and `D3DMETAL_UNIXLIB_DIR` provider paths, and the
private provider path. It does not set Rosetta controls, Metal capture, HUD,
DXIL debug processing, injected libraries, or tracing flags.

### Current runtime preservation

No file was removed from the current VKMT runtime. No D3DMetal binary was
copied from the historical x86_64 bundle or installed GPTK. The staging gate was
run against the installed GPTK 3.0-2 and rejected it before creating a target.
xtajit64, xtajit, their compatibility variants, and the native ARM64 host
remain untouched.

## Remaining ARM64 adaptation work

The full D3DMetal execution requirement is not yet claimed because the
Sikarugir/GPTK path has not been wired into the current VKMT ARM64/FEX Wine
layout. This is an adaptation task, not a conclusion that Sikarugir's
D3DMetal implementation is nonfunctional:

- represent Sikarugir's `d3dmetal_force` engine-selection contract in VKMT;
- map the GPTK `lib/external` provider layout to the VKMT Wine build without
  colliding with existing runtime providers;
- connect the x86_64 Windows D3DMetal guest lane and its Unix provider
  boundary through the current FEX/Wine transition path;
- test the current ARM64 runtime with the actual D3DMetal provider, not only
  a static placeholder receipt; and
- preserve licensing, provenance, and the no-tracing policy during the
  adaptation.

The implementation sequence is:

1. Port Sikarugir's engine marker, provider search paths, and mode-selection
   semantics into a dedicated VKMT D3DMetal profile.
2. Build the Wine/FEX adapter for the x86_64 guest lane while preserving the
   ARM64 native host boundary.
3. Stage the GPTK provider through that profile with license and provenance
   receipts.
4. Run disposable-prefix D3D11 and D3D12 conformance tests with no
   diagnostic capture or tracing enabled.
5. Promote only after runtime, architecture, and provider receipts agree.

## Acceptance matrix

| Gate | Evidence | Status |
| --- | --- | --- |
| Sikarugir repository fetched at pinned revision | /Volumes/AverySSD/Sikarugir-audit, Git revision above | Complete |
| Sikarugir FOSS source fetched at pinned revision | /Volumes/AverySSD/Sikarugir-foss-sources-audit, Git revision above | Complete |
| D3DMetal document versions audited | 1.1, 2.0, 2.1, 3.0 PDFs and their acknowledgements/licenses | Complete |
| Existing binary architecture audited | docs/metalsharp-bundle-files.tsv and installed GPTK 3.0-2 | Complete; x86_64 only |
| Current VKMT host/runtime boundary audited | current published runtime tree | Complete; ARM64 host, no D3DMetal |
| Proprietary payload intake is legal/receipt-backed | staging script and required receipt arguments | Complete when a provider is supplied |
| Provider architecture and hashes are verified | verify-d3dmetal-runtime.sh --provider-only | Complete when a provider is supplied |
| D3DMetal default is off | VKMT_D3DMETAL_ENABLE opt-in branch | Complete |
| Diagnostic capture/tracing is not enabled | environment script contains no capture/debug enablement | Complete |
| Matching ARM64 VKMT Wine/FEX adapter | VKMT-WINE-CONTRACT.txt and adapter build | In progress |
| D3DMetal D3D11/D3D12 runtime execution | disposable-prefix conformance run | Not yet run |
| Public release inclusion | prohibited until legal and adapter gates pass | Intentionally not claimed |

## Reproduction commands

Audit the checked-out Sikarugir source:

    git -C /Volumes/AverySSD/Sikarugir-audit status --short --branch
    git -C /Volumes/AverySSD/Sikarugir-audit ls-tree -r --name-only HEAD
    rg -n -i 'd3dmetal|d3dm|gptk|d3dmetal_force|x86_64-unix' \
      /Volumes/AverySSD/Sikarugir-foss-sources-audit

Verify the current VKMT host boundary:

    file /Volumes/AverySSD/VKMT-roadmap-2/fresh-install-published/wine/build-ec/tools/wine/wine
    find /Volumes/AverySSD/VKMT-roadmap-2/fresh-install-published \
      -type f -iname '*d3dmetal*' -o -iname 'libd3dshared.dylib'

Stage a privately licensed, ARM64 provider only after obtaining it from Apple:

    ./scripts/stage-d3dmetal-runtime.sh \
      --runtime-root /path/to/private/vkmt-runtime \
      --source /path/to/apple-gptk/lib \
      --license /path/to/D3DMetal-License.pdf \
      --acknowledgements /path/to/D3DMetal-Acknowledgements.pdf \
      --version 3.0

Verify the staged provider and, only after the adapter exists, the full
contract:

    ./scripts/verify-d3dmetal-runtime.sh \
      --runtime-root /path/to/private/vkmt-runtime --provider-only
    ./scripts/verify-d3dmetal-runtime.sh \
      --runtime-root /path/to/private/vkmt-runtime

The provider ABI receipt can be inspected independently with:

    nm -gU /path/to/private/vkmt-runtime/graphics/d3dmetal/external/libd3dshared.dylib \
      | grep '___wine_unix_call_funcs$'
    nm -gU /path/to/private/vkmt-runtime/graphics/d3dmetal/external/D3DMetal.framework/Versions/Current/D3DMetal \
      | grep -E '(_CreateDXGIFactory|_D3D11CreateDevice|_D3D12CreateDevice|_GFXT_Initialize)$'

The installed GPTK 3.0-2 rejection was recorded with:

    provider must be arm64-only: .../libd3dshared.dylib (x86_64)
    x86_64 GPTK provider correctly rejected; no files staged

The final two commands are deliberately not reported as passing for the
current VKMT release because no provider or loader contract is present.
