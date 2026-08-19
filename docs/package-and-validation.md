# VKMT Packaging and Validation

This is the consolidated package inventory, preservation policy, release
validation, compatibility boundaries, and stability close-out record. It
replaces the former inventory and review documents.

## Package inventory and release policy


This is the release/package composition inventory. It is deliberately a
provenance and verification document, **not** a claim that source presence or
staging alone proves runtime compatibility. A redistributable package is
invalid if it omits a required row or includes an excluded row.

### Package policy

- Host executables and host dylibs must be ARM64-only; Rosetta is excluded.
- Provider promotion remains governed by
  `scripts/stage-runtime-providers.sh` and its pinned SHA-256 values.
- Browser, Java, Mono, Gecko, and other separately licensed payloads are not
  silently bundled. They require their own provenance and user-fetch/install
  policy.
- Do not include guessed ARM64EC dispatcher code, unverified generated
  binaries, obsolete candidate providers, disposable prefixes, caches, logs,
  or historical diagnostics in a release bundle.

### Authoritative TSV inventory

The block below is consumed by `scripts/verify-preservation.sh --inventory`.
Fields are: `id, class, architectures, canonical_path,
producer_or_stage_script, verification_source, acceptance_runner,
provenance_license, package_action`.

```tsv
id	class	architectures	canonical_path	producer_or_stage_script	verification_source	acceptance_runner	provenance_license	package_action
wine-host	required-runtime	arm64	wine/build-ec/wine	wine build	scripts/verify-preservation.sh	acceptance lane hotset acceptance; acceptance lane provider smoke	Wine LGPL	required
wineserver	required-runtime	arm64	wine/build-ec/server/wineserver	wine build	scripts/verify-preservation.sh	acceptance lane hotset acceptance; acceptance lane provider smoke	Wine LGPL	required
ntdll-host	required-runtime	arm64	wine/build-ec/dlls/ntdll/ntdll.so	wine build	scripts/verify-preservation.sh	scripts/probe-msync.sh; scripts/probe-ai-ntdll-file-scan.sh	Wine LGPL	required
xtajit64	required-runtime	arm64ec	wine/build-ec/dlls/xtajit64/aarch64-windows/xtajit64.dll	scripts/stage-runtime-providers.sh	scripts/stage-runtime-providers.sh	acceptance lane hotset acceptance; acceptance lane provider smoke	project-pinned	provider-required
xtajit	required-runtime	arm64	wine/build-ec/dlls/xtajit/aarch64-windows/xtajit.dll	scripts/stage-runtime-providers.sh	scripts/stage-runtime-providers.sh	acceptance lane hotset acceptance; acceptance lane provider smoke	project-pinned	provider-required
wow64-bridge	required-runtime	arm64	wine/build-ec/dlls/wow64/aarch64-windows/wow64.dll	wine build	scripts/vkmt-prefix	acceptance lane hotset acceptance; acceptance lane provider smoke	Wine LGPL	required
wow64win-bridge	required-runtime	arm64	wine/build-ec/dlls/wow64win/aarch64-windows/wow64win.dll	wine build	scripts/vkmt-prefix	acceptance lane hotset acceptance; acceptance lane provider smoke	Wine LGPL	required
i386-pe-closure	required-runtime	i386	wine/build-ec/dlls	scripts/vkmt-prefix	scripts/vkmt-prefix	acceptance lane hotset acceptance; acceptance lane provider smoke	Wine LGPL	required
host-libs	required-runtime	arm64	wine/build-ec/dlls/win32u	scripts/stage-wine-host-libs.sh	scripts/verify-preservation.sh	graphics probes	component licenses	required
fex-source	required-source	arm64,x64,i386	third_party/FEX-2607	FEX checkout	git revision and status	acceptance lane/FEX probes	FEX license	source-required
moltenvk-source	required-source	arm64	third_party/MoltenVK	MoltenVK checkout	scripts/verify-preservation.sh	graphics probes	MoltenVK license	source-required
dxvk-source	required-source	x64,i386	third_party/dxvk	DXVK checkout	scripts/verify-preservation.sh	future DXVK gate	DXVK license	source-required
d3dcompiler-contract	test-only	arm64,arm64ec,x64,i386	test/d3dcompiler_contract.c	scripts/probe-d3dcompiler-contract.sh	docs/validation/d3dcompiler-contract-final-20260803/capability.tsv	acceptance lane one-prefix contract	Wine LGPL	exclude
moltenvk-behavior	behavior-contract	native arm64	test/moltenvk_behavior_contract.c;test/moltenvk_storage_read.comp;test/moltenvk_image_read.comp	scripts/probe-moltenvk-behavior.sh	docs/validation/moltenvk-behavior-final-20260803/RESULTS.md;capability.tsv	acceptance lane direct Vulkan/Metal behavior	MoltenVK/Vulkan licenses	required-source
eac-contract	test-only	arm64,arm64ec,x64,i386	test/eac_contract.c;test/eac_mock_backend	scripts/probe-eac-contract.sh	docs/package-and-validation.md	acceptance lane mock lifecycle/negative matrix	project test code	exclude
eac-host-bridge	test-only	arm64	dlls/vkmt_eac/unix/vkmt_eac.c	scripts/probe-eac-contract.sh	docs/package-and-validation.md	acceptance lane dynamically loaded mock bridge	project test code	exclude
eac-runtime	optional-external	x64	build/probe-runs/phase-a-graphics-prefix/drive_c/vkmt-eac-test	scripts/stage-eac-runtime.sh	VKMT_EAC_STAGE.tsv;docs/package-and-validation.md	n/a	Epic EOS/EAC license	separate-fetch;never-package
graphics32-consumer-closure	optional-runtime	i386	third_party/dxvk/runtime/dxvk-vkmt-1a5919b/x32;third_party/vkd3d-proton/install-win32/bin	scripts/vkmt-prefix sync-graphics32	prefix .vkmt manifest + graphics32-sync.receipt	D3D11/D3D12 consumer lanes	DXVK/vkd3d-proton licenses	separate-provider-policy
vkd3d-source	required-source	x64,i386	third_party/vkd3d-proton	vkd3d-proton checkout	scripts/verify-preservation.sh	future vkd3d gate	vkd3d-proton license	source-required
dxmt-pair	required-runtime	arm64ec	wine/build-ec/dxmt-v0.80/aarch64-windows	scripts/stage-dxmt-runtime.sh	scripts/stage-dxmt-runtime.sh	scripts/probe-dxmt-arm64ec.sh	project-pinned	profile-graphics
gecko	optional-external	all	third_party/wine-gecko	scripts/stage-gecko-runtime.sh	external manifest	future browser gate	MPL/user fetch	separate-fetch
java	optional-external	arm64	third_party/private/oracle-jre-8u501-arm64	scripts/stage-native-java-runtime.sh	external provenance	managed probes	Oracle license	separate-fetch
cef-webview-electron	optional-external	x64,i386	third_party/browser-runtimes	dedicated future stage	required future manifest	future browser gate	vendor licenses	not-bundled-until-staged
diagnostics	excluded	all	docs/validation	create-on-demand	n/a	n/a	n/a	exclude
prefixes-caches	excluded	all	build/probe-runs	create-on-demand	n/a	n/a	n/a	exclude
candidate-providers	excluded	all	wine/wine-11.12/runtime-providers/*candidate*	rollback-only	pinned provider verifier	n/a	project policy	exclude
```

### Prepared-prefix profiles

| Profile | Verified Workstream-A content | Explicitly not claimed installed |
| --- | --- | --- |
| core | Wine host closure, providers, GStreamer/GPU-cache/hotset contracts, WoW64 bridges, i386 DLL closure | Browser and managed payloads |
| graphics | core plus the preserved release-qualified DXMT pair; optional receipt-backed 32-bit DXVK/vkd3d consumer closure via `sync-graphics32` | CEF/WebView2/Electron payloads; 32-bit graphics providers are not staged until that explicit sync |
| browser | graphics plus browser identity metadata | CEF, WebView2, Electron payloads |
| managed | core plus managed identity metadata | Wine Mono and Java payload installation |
| full | union of the above truthful contracts | Any component lacking a prefix staging helper |

### Release/package gate

1. Run `scripts/verify-preservation.sh --inventory`.
2. Verify every `required-runtime` row is present with its architecture and
   pinned/hash verification path.
3. Verify every external asset has a provenance/hash receipt and is either
   separately fetched or explicitly authorized for distribution.
4. Run `scripts/vkmt-prefix verify --prefix PATH`, then run
   `scripts/probe-perf-p8-hotset.sh` with the release prefix and manifest.
Acceptance lane is final acceptance; legacy workstream receipts are supporting historical diagnostics only.
5. Reject a package containing an `excluded` path, stale prefix/caches,
   Rosetta/x86 host Mach-O content, unpinned provider bytes, or diagnostic
   logs masquerading as acceptance evidence.

### Known Workstream-A gaps

Dedicated reusable prefix stage helpers are still needed for DXVK, vkd3d,
CEF, WebView2, Electron, Wine Mono, and managed/browser fixtures. Their
presence in this inventory preserves provenance; it does not make them
package-ready or accepted.

DXMT prefix staging uses the separately preserved release-qualified pair at `build/provider-preservation/pre-dxmt-cross-process-allow-20260731`; locally regenerated build output is intentionally not staged until promoted.

### WoW64 VM workstream inventory (current working state)

The single canonical working prefix for this workstream is:

```text
build/probe-runs/phase-a-graphics-prefix
```

Do **not** create or reset another prefix for the WoW64 work. The workstream uses
the existing receipt-backed graphics prefix and fast-syncs only the rebuilt
WoW64 closure (`wow64.dll`, `wow64win.dll`, and i386 `ntdll.dll`) with:

```sh
scripts/vkmt-prefix sync-wow64 --prefix "$PWD/build/probe-runs/phase-a-graphics-prefix"
scripts/vkmt-prefix verify --prefix "$PWD/build/probe-runs/phase-a-graphics-prefix"
```

The current staged WoW64 bridge SHA-256 is
`cd534da4ec125c292bede66e5b7bf6a91eb5ce4c025db7bb0a0df77d3b129a39`.
The matching staged USER bridge is
`8703ca51aaa5ec5f1e0859f46835add0d4e247cfda0b055f82504ef1978c9113`,
and the rebuilt i386 `syswow64/ntdll.dll` is
`50ad58ec524fbf6ebde1d89d52b346b6c66a98eb5c2fe94b5f0dd7a87d70a861`.
The canonical ARM64EC renderer provider is now
`wine/wine-11.12/runtime-providers/xtajit64-arm64ec-p8-rendering-known-good.dll`
with SHA-256
`cccc70a4dd598371ed11c5a7979ca2ecff66a9849ba8086421a69054890c8c5f`.
The former `xtajit64-arm64ec-known-good.dll` (`0dde3c54...`) remains a
rollback artifact and is not the default staged provider.
The preserved DXMT pair remains authoritative; if `wineboot --update` is
needed on this existing prefix, run it first and then restage DXMT with
`scripts/vkmt-prefix sync-dxmt`. Do not run full prefix creation as part of
this workstream.

#### WoW64 source and test artifacts

| Artifact | Role | Package action | Evidence |
| --- | --- | --- | --- |
| `wine/wine-11.12/dlls/wow64/memory.c` | static-pool interval registry, overlay retirement, split/reuse tracking, committed-page publication state | source-only; rebuild bridge | ARM64 WoW64 DLL build; focused VM contract |
| `wine/wine-11.12/dlls/wow64/virtual.c` | transactional VM/map/unmap publication and rollback; explicit MEM_DECOMMIT versus MEM_RELEASE handling | source-only; rebuild bridge | focused VM contract; Electron ia32 diagnostic |
| `wine/wine-11.12/dlls/wow64win/user.c` | preserves MAKEINTATOM class values instead of translating them as guest pointers | source-only; rebuild USER bridge | Electron ia32 progressed past the prior `0xc021` fault |
| `wine/wine-11.12/dlls/wow64/wow64_private.h` | registry lifecycle declarations | source-only | bridge build |
| `test/wow64_vm_contract.c` | x64/i386 reserve, commit, decommit, protection, aliases, executable reuse, concurrency | test-only; exclude package | `docs/validation/wow64-vm-contract-cef-fix-final2` |
| `scripts/probe-wow64-vm-contract.sh` | one-prefix x64 then i386 runner with FEX trace correlation | test-only; exclude package | focused receipt |
| `docs/validation/wow64-vm-contract-current-20260802` | focused evidence after decommit publication fix | diagnostics; exclude package | `WOW64_VM_CONTRACT_ALL_OK`, i386 invalidation summary |
| `docs/validation/single-prefix-20260728` | four-architecture regression evidence | diagnostics; exclude package | `P6_SINGLE_PREFIX_ALL_ARCHITECTURES_OK`, `status=0` |
| `docs/validation/performance-hotset-20260801` | final hotset/performance regression evidence using the same prefix | diagnostics; exclude package | `P8_HOTSET_OK`, 61.84% median stall reduction |

The focused proof records all three FEX TSO modes as zero, requires both x64
and i386 markers, requires concurrent and executable-reuse markers, and
requires a nonzero correlated i386 FEX `maintenance_summary` invalidation
counter. The current acceptance lane ARM64EC provider emits no x64 FEX component row for
this fixture; the runner records that telemetry gap explicitly as
`x64_fex_trace=unavailable-provider-telemetry` rather than treating loader
TSV files as provider proof. It does not by itself claim that CEF, Electron
ia32, or Chromium renderer allocation traces are complete browser acceptance;
those remain separate integration gates.

The acceptance lane hotset gate also passed against this same prefix:
`physical_gbps=0.867708`, `effective_gbps=2.145993`,
`total_gbps=1.003657`, `stall_reduction_pct=59.79`, and
`warm_regression_pct=-3.92`.

#### Existing-prefix CEF/Electron diagnostic pass

The CEF and Electron probes now accept the same receipt-backed prefix with
`--prefix`; they do not create a prefix or run `wineboot` unless their
explicit `*_WINEBOOT_UPDATE=1` escape hatch is selected. Existing-prefix mode
fast-syncs only the rebuilt WoW64 bridge, matching `wow64win.dll`, and i386
`ntdll.dll`; it does not rehash/copy the whole i386 closure on every
Electron/CEF invocation. The compatibility launcher and CEF child hook are
staged into a temporary per-run client directory, not into the canonical
prefix.

The current diagnostic runs are preserved here:

| Probe | Prefix | Evidence | Result |
| --- | --- | --- | --- |
| CEF 109 x86_64 + i386/WoW64 legacy probe | `build/probe-runs/phase-a-graphics-prefix` | `docs/validation/cef-existing-prefix-v4` | historical only; not current provider acceptance |
| Electron 42 x64 + ia32/WoW64 legacy probe | `build/probe-runs/phase-a-graphics-prefix` | `docs/validation/electron-existing-prefix-v3` | both ABIs executed; legacy diagnostic traces only |

CEF-specific observations above are historical diagnostics. The current
x86_64 OSR gate below is accepted. Electron x64 now passes the
renderer/result gate with the acceptance lane provider. Electron ia32 reaches the guest
runtime, but still fails in V8 at `electron.exe+0x4697c6` while reading an
object in a recently decommitted Chromium allocation; it produces no
renderer/result markers. This remains an open ia32/FEX compatibility issue,
not probe success.

The FEX TSVs are loader/JIT and maintenance allocation evidence, not a claim
that every Chromium renderer VM operation has been traced. The focused OSR
pixel gate below is the accepted x86_64 rendering proof; direct ia32 renderer
allocation/protection proof remains open. The canonical prefix was verified
after the legacy runs with `VKMT_PREFIX_VERIFY_OK`; no new disposable prefix
was used.

#### CEF/Electron rendering work in progress

The CEF host path now has a real windowless C API host in
`third_party/metalsharp-cef/vkmt_browser_capi.c`. It requests CEF OSR,
provides a 1280x800 `cef_render_handler_t`, samples BGRA paint output, and
emits `VKMT_BROWSER_PIXEL_OK` when the deterministic RGB(17,34,51) page is
painted. `scripts/launch-vkmt-cef-browser.sh` now supports the canonical
receipt-backed prefix without wineboot, converts host log paths to `Z:` paths,
accepts `VKMT_BROWSER_EXTRA_ARGS`, and accepts duration values with or without
an `s` suffix. The existing CEF wrapper no longer unconditionally appends
`--disable-gpu`; the launcher/probe owns the rendering policy.

The reusable OSR gate is `scripts/probe-cef-osr-render.sh`; it only accepts
the existing receipt-backed prefix, waits for the pixel marker, and records
`CEF_X86_64_OSR_RENDER_OK` without creating or resetting a prefix.

The canonical prefix was updated in place with `vkmt-prefix refresh`; this did
not run `wineboot` or recreate the prefix. The launcher has an opt-in
`VKMT_BROWSER_WAIT_FOR_RENDER=1` mode that waits for the OSR pixel marker and
returns a deterministic status instead of treating CEF child shutdown timing
as a rendering failure.

The x86_64 rendering gate remains accepted on its recorded canonical acceptance lane
evidence. The current i386 CEF run is intentionally not marked accepted:
`docs/validation/cef-i386-config-hardened-20260802/` proves export loading and
FEX allocation tracing with the current provider, but the browser never
publishes a DevTools endpoint and no renderer/pixel markers are present. This
is a live CEF/WoW64 integration gap, not a prefix or provider-receipt failure.

The x86_64 rendering gate is accepted on the recorded canonical acceptance lane provider:

| Diagnostic | Evidence | Result |
| --- | --- | --- |
| acceptance lane final non-WoW64 architecture gate | `docs/validation/final-nonwow64-20260803` | ARM64, ARM64EC, and x86_64 smoke `rc=0`; i386/WoW64 intentionally excluded |
| Current CEF x86_64 OSR final gate | `docs/validation/cef-x64-final-20260803` | current host rebuilt, `VKMT_BROWSER_PIXEL_OK`, deterministic BGRA marker, launcher `rc=0`; canonical-prefix reuse |
| Windowless CEF host, canonical acceptance lane provider | `docs/validation/cef-osr-render-final` | `VKMT_BROWSER_PIXEL_OK`, BGRA `51,34,17,255`, launcher `rc=0`; one-prefix reuse |
| Electron x64 software-render fixture, canonical acceptance lane provider | `docs/validation/electron-render-final-canonical-x64-vmfix` | `ELECTRON_X64_OK`, HTTPS/input/audio/pixel result, renderer and FEX allocation markers; `rc=0` |
| WoW64 VM contract, x64+i386 | `docs/validation/wow64-vm-contract-cef-fix-final2` | both architecture contracts, concurrent pressure, executable reuse, i386 FEX invalidation; `rc=0` |
| CEF 109 i386/WoW64 diagnostic | `docs/validation/cef-i386-config-hardened-20260802` | current provider exports and FEX allocation trace; CDP/pixel/renderer gate timed out; not accepted |
| Electron ia32/WoW64 | `docs/validation/electron-render-final-canonical-i386-vmfix` | prior atom fault removed; still fails at V8 `0x004697c6` after `MEM_DECOMMIT`; no renderer/result; not accepted |
| Official CEF x64, bundled SwiftShader/windowed | `docs/validation/cef-existing-prefix-v9-explorer` | separate legacy diagnostic; not the OSR acceptance gate |

The current ARM64EC acceptance lane rendering provider is
`xtajit64-arm64ec-p8-rendering-known-good.dll` (`cccc70a4...`). The current
ARM64/i386 WoW64 provider is
`xtajit-arm64-p8-wineconfig-known-good.dll`
(`ac512105b5feb85227f2814deb77de603d73ff4713ee60045b23e51c2276f386`), built
from FEX commit `a4128f01913d25d49f0d1cd1f62668327de1815e` with the config-file
startup hardening in `third_party/FEX-2607/Source/Common/Config.cpp`. The old
`e030b4d3...` provider remains rollback-only and is not staged. Provider
staging now updates the existing prefix manifest/receipt through
`scripts/vkmt-prefix sync-providers`; no prefix recreation or wineboot is
needed. Do not package diagnostic logs, disposable browser runtimes, or
rollback providers.

#### D3DCompiler contract (acceptance lane, 2026-08-03)

The complete D3DCompiler fixture is `test/d3dcompiler_contract.c`. Its
single-prefix runner is `scripts/probe-d3dcompiler-contract.sh`; it validates
the existing receipt-backed prefix before execution, never creates a prefix,
and records `wineboot=not-run`. The runner compiles and executes ARM64,
ARM64EC, x86_64, and i386 PE fixtures with all FEX TSO controls set to zero.

The canonical prefix is
`build/probe-runs/phase-a-graphics-prefix`. The i386 D3D11/D3D12 consumer
lanes use the explicit, hash-backed
`scripts/vkmt-prefix sync-graphics32` operation. It stages only the x32 DXVK
`d3d11.dll`/`dxgi.dll` pair and win32 vkd3d-proton `d3d12.dll`/
`d3d12core.dll`; their source paths and hashes are included in the prefix
manifest and `graphics32-sync.receipt`. No Wineboot or full prefix rebuild is
needed to add this closure.

The retained receipt is
`docs/validation/d3dcompiler-contract-final-20260803/RESULTS.md`, with the
machine-readable architecture/API table in `capability.tsv`. The final run
returned status 0 and recorded:

| Area | Evidence |
| --- | --- |
| VS/PS/CS, macros, flags, include handler, failures/diagnostics | all four compiler lanes `PASS` |
| Unicode `D3DCompileFromFile`/`D3DReadFileToBlob`, preprocess, disassembly | 43/46/47 rows recorded for every architecture; 46/47 file APIs pass |
| Reflection/signatures and version behavior | 47 metadata pass; 43 `D3DReflect` `E_NOINTERFACE` is explicitly `KNOWN_LIMITATION` |
| Unsupported API behavior | `D3DLoadModule` `E_NOTIMPL`; spec stubs such as compression, trace, `D3DReflectLibrary`, and `D3DSetBlobPart` are explicit `KNOWN_STUB_NOT_CALLED` rows and are never invoked |
| Generated DXBC consumers | i386 DXVK D3D11 readback and vkd3d-proton D3D12 compute pipeline both pass in isolated processes |

The consumer processes are intentionally isolated: combining DXVK D3D11 and
vkd3d-proton D3D12 in one i386 process currently faults after the D3D11 pass.
That boundary is retained as a diagnostic rather than hidden. The table also
keeps all expected missing exports and the d3dcompiler_43 reflection
limitation visible; a green runner status is not a claim that Wine stubs are
implemented. These D3DCompiler DLLs and probe executables are test/runtime
inputs, not package payloads unless separately licensed and promoted.

#### Current final-gate boundary (2026-08-03)

The acceptance boundary for this workstream is the non-WoW64 architecture gate
plus the user-facing x86_64 CEF OSR host. Both were run against
`build/probe-runs/phase-a-graphics-prefix` with the current acceptance lane providers and
all three FEX TSO controls set to zero. No prefix was recreated and Wineboot
was not run. The authoritative retained summaries are:

- `docs/validation/final-nonwow64-20260803/RESULTS.md`
- `docs/validation/cef-x64-final-20260803/RESULTS.md`

i386/WoW64 CEF is intentionally outside this final gate. The official CEF
Windows32 runtime is present and exports load, but the current i386 browser
does not return from `cef_initialize` or publish a DevTools/renderer/pixel
marker. That remains an open compatibility gap and must not be represented
as package-ready or green. The standalone legacy `cefclient` diagnostic is
also not the product acceptance gate; the user-facing CEF host and its OSR
pixel marker are the authoritative x86_64 result here.

#### candidate optimization Workstream 0/1 baseline (2026-08-03)

The file-by-file optimization plan is `docs/performance.md` and
the source-hashed ledger for all 82 custom C paths is
`docs/OPTIMIZATION_LEDGER.tsv`. The current candidate pipeline is pinned
to c-ai-optimizer commit
`c6f96df0ec9973a4cbdb7b015b1fd106c815ad89`.
The candidate-path disposition matrix is
`docs/OPTIMIZATION_DISPOSITION.tsv`; boundary and triage rows are not
performance acceptance claims.
Run `scripts/vkmt-c-ai-optimizer.sh disposition` to verify that all 15 ledger
candidate rows are represented exactly once before packaging or promotion.

The prepared-prefix Winsock address-order contract is recorded at
`docs/validation/address-list-sort-final-canonical-20260803/`. Its runner is
`scripts/probe-x64-address-list-sort.sh --prefix PATH`; fresh bootstrap mode
remains available separately.

The active provider-backed architecture runner is
`scripts/probe-p8-single-prefix-architectures.sh`. It reuses the canonical
graphics prefix and does not recreate it or run Wineboot in prepared-prefix
mode. The compatibility `probe-p6-single-prefix-architectures.sh` name and
historical acceptance lane evidence remain provenance-only; current acceptance markers and
new receipts use acceptance lane naming to identify the acceptance lane provider generation.

Workstream/1 evidence is
`docs/validation/optimization-baseline-20260803/`. It passed
ARM64, ARM64EC, x86_64, and i386/WoW64 with status 0 and all three FEX TSO
settings fixed at zero. One narrow pure NTDLL marker-scan candidate has since
been promoted; the ledger and disposition matrix record its source hash and
receipt separately from the remaining candidate/manual-review boundary.

#### candidate optimization WoW64/MSync promotion (2026-08-03)

The current nested Wine functional changes are committed at
`wine/wine-11.12` commit `656bd43`. Targeted builds were promoted into the
actual `wine/build-ec` runtime and the existing canonical prefix was updated
only through `scripts/vkmt-prefix sync-wow64`.

The combined receipt is
`docs/validation/optimization-wow64-msync-20260803/RESULTS.md`.
The WoW64 contract passed x64 and i386 mapping pressure, reuse, concurrency,
executable reuse, and i386 FEX invalidation. MSync passed manual/auto pulse,
WaitAll rollback, stale-port recovery, and invalid-destination fallback.
These are functional source promotions; no candidate-generated performance candidate
has been promoted in this workstream. The separate NTDLL scan promotion is recorded
below.

#### candidate optimization Workstream 2 file-scan promotion (2026-08-03)

`dlls/ntdll/unix/file.c::buffer_contains()` was promoted in nested Wine commit
`07df604e8f4e2f475bdd9983905cf98802905ee7` after 250,000 equivalence cases,
repeated benchmark cells, an actual ARM64 `ntdll.so` build, and the prepared
Acceptance lane four-architecture gate passed. The candidate accelerates the opt-in Steam
handoff marker scan while leaving notification state, socket transport,
completion ordering, and default-disabled behavior unchanged.

Receipt: `docs/validation/optimization-file-scan-20260803/RESULTS.md`.
The promoted ARM64 `ntdll.so` hash is
`e3cd6e3c55a96ea5f47c7c9a24f3c268fecb15b0bdf43d6577aa4450b71aae89`.
The 12 remaining candidate dispositions and their concrete next actions are
reviewed in `docs/validation/optimization-candidate-review-20260803/RESULTS.md`.
After a final existing-prefix Wineboot update, use
`scripts/vkmt-prefix refresh --prefix PATH` once before prepared gates; this
restores any built-in files that Wineboot may replace and does not recreate or
reset the prefix.

#### candidate optimization FEX/graphics gates (2026-08-03)

The FEX workstream receipt is
`docs/validation/optimization-fex-20260803/RESULTS.md`. The graphics
workstream receipt is
`docs/validation/optimization-graphics-20260803/RESULTS.md`.
The current acceptance lane hot-set run measured `61.45%` cold blocking-stall reduction,
`2.249713 GB/s` effective delivery, and `0.15%` warm regression. CEF x86_64
OSR emitted the deterministic pixel marker with status 0. No FEX or graphics
source candidate was promoted because no candidate passed a repeatable
workload-specific speed gate.

The first loader candidate evaluation is retained at
`docs/validation/optimization-candidate-loader-20260803/RESULTS.md`.
It passed the functional gates but was rejected for promotion because its
paired startup measurements did not establish a repeatable improvement and
the i386 tail became noisy. The candidate source is not in the installed Wine
tree or canonical prefix.

The complete 82-file candidate workspace preparation is recorded in
`docs/validation/optimization-corpus-20260803/RESULTS.md`. The workspace is
ignored and contains no promoted binaries.

#### candidate optimization final acceptance lane gate receipt (2026-08-03)

The final one-prefix receipt is
`docs/validation/optimization-final-20260803/RESULTS.md`. It records the
native ARM64 Wineboot update (`rc=0`), the acceptance lane all-architecture fixture gate,
WoW64 VM, MSync, CEF x86_64 OSR, and the final acceptance lane hot-set measurement. The
prefix was refreshed in place after Wineboot repopulated a stale i386 DLL;
`scripts/vkmt-prefix` now prunes only stale prefix-owned i386 closure files
that have no source-built counterpart before rebuilding the receipt.

#### candidate optimization Workstream 2 candidate pass A (2026-08-03)

The first Workstream 2 heap candidate receipt is
`docs/validation/optimization-heap-index-20260803/RESULTS.md`.
It evaluated the pure `get_free_list_index()` helper in the actual installed
NTDLL build, but the native `clz` candidate compiled to a byte-identical
`ntdll.so` under the current ARM64 flags. It was therefore rejected as
`PROFILED_NO_PROMOTION`; no candidate binary or source was staged into the
Wine tree or canonical prefix. The source and installed NTDLL hashes were
restored exactly, and the prepared-prefix acceptance lane gate returned status 0 for
ARM64, ARM64EC, x86_64, and i386/WoW64. This receipt closes only this heap
candidate pass; it does not claim that the remaining eligible C paths have
been materially optimized.

#### candidate optimization Workstream 4 candidate pass A (2026-08-03)

The FEX interpreter mask candidate receipt is
`docs/validation/optimization-fex-mask-20260803/RESULTS.md`.
It evaluated only the pure `sz_mask()` helper. Candidate and control direct
x86_64 launches were all `rc=0` with the expected marker, but the candidate
was 1.54% slower at the median and did not meet the promotion threshold. It
was rejected without staging; the canonical acceptance lane ARM64EC provider was restored,
prefix verification passed, and the prepared-prefix acceptance lane gate again passed
ARM64, ARM64EC, x86_64, and i386/WoW64. The FEX dispatcher/JIT/context,
invalidation, and executable-memory code remains protected and unchanged.

#### Networking, TLS trust, COM/STA, DirectWrite, and CEF text gate (acceptance lane, 2026-08-03)

This workstream reuses the single receipt-backed prefix
`build/probe-runs/phase-a-graphics-prefix`; no new prefix or wineboot was used.
All lanes set `FEX_TSOENABLED=0`, `FEX_VECTORTSOENABLED=0`, and
`FEX_MEMCPYSETTSOENABLED=0`.

| Area | Implementation / runner | Evidence | Status |
|---|---|---|---|
| WinSock | `test/network_contract.c`, `scripts/probe-network-contract.sh` | `docs/validation/network-contract-final-20260803/` | ARM64, ARM64EC, x86_64, i386 processes rc=0; IPv4/IPv6, localhost ordering, nonblocking connect, select, WSAPoll, event rearm, IOCP, and parallel close pass; i386 `SIO_ADDRESS_LIST_SORT` is explicit `UNSUPPORTED` / WSAEOPNOTSUPP |
| TLS/trust | `test/tls_trust_contract.c`, `scripts/probe-tls-trust-contract.sh`, `test/browser/tls_connect_delay_proxy.mjs` | `docs/validation/tls-trust-contract-final-20260803/` | All four architectures rc=0; WinHTTP/WinINet valid root+intermediate+hostname, expired rejection, untrusted-root rejection, and local fragmented CONNECT proxy pass without bypass flags |
| COM/UI/fonts | `test/ui_com_dwrite_contract.c`, `scripts/probe-ui-com-dwrite-contract.sh` | `docs/validation/ui-com-dwrite-contract-final-20260803/` | All four processes rc=0; STA pump/callback/nested loop/window lifetime, font enumeration/glyphs/layout/fallback pass where supported; standard IStream cross-apartment marshal is explicit `UNSUPPORTED` on all lanes and i386 mixed-script layout metrics are explicit `UNSUPPORTED` |
| CEF text/pixels/trust | `third_party/metalsharp-cef/vkmt_browser_capi.c`, `scripts/probe-cef-osr-render.sh`, `test/tls_trust_contract.c` | `docs/validation/cef-osr-render-final/RESULTS.md`, `capability.tsv`, and `browser-20260803T145321.log` | CEF data-URL and local-root HTTPS loads pass DOM text, deterministic BGRA, and foreground text pixels; root install/remove is explicit; `--ignore-certificate-errors` is diagnostic-only |

The DirectWrite source review is
`docs/validation/ui-com-dwrite-contract-final-20260803/font-source-review.txt`.
`dlls/dwrite/freetype.c` and `dlls/win32u/freetype.c` were not modified or
promoted in this workstream; no optimization is claimed without a benchmark-backed
source change and a passing contract gate.
The old BoringSSL diagnostic note about a custom-FEX `0xc000001d` before
application output is superseded. The current acceptance lane provider and canonical
prepared prefix pass the x86_64 BoringSSL startup/TLS launch with `rc=0`, and
the four-lane FEX startup receipt is
`docs/validation/fex-startup-20260803/RESULTS.md`. The probe remains
diagnostic-only for trust acceptance; WinHTTP/WinINet fragmented lanes remain
authoritative. The updated diagnostic details are in
`docs/validation/tls-trust-contract-final-20260803/boringssl-diagnostic.txt`.

#### Easy Anti-Cheat compatibility workstream (acceptance lane, 2026-08-03)

The EAC-only contract is implemented by:

- test/eac_contract.c
- test/eac_mock_backend/main.c
- test/eac_mock_backend/vkmt_eac_test_protocol.[ch]
- dlls/vkmt_eac/unix/vkmt_eac.[ch]
- scripts/stage-eac-runtime.sh
- scripts/probe-eac-contract.sh

The host bridge is a test-only dynamically loaded native .so; it is not an
Epic implementation and must never be reported as a real EAC attestation
provider. The loopback backend uses a VKMT-owned protocol and test key. It
covers valid challenge/response, module-digest mismatch, expiration, missing
capabilities, wrong architecture, bad signatures, malformed messages, replay
rejection, backend disconnect, separate client/server restart, four-client
concurrent sessions, and callback/lifetime cleanup.

The official artifacts are kept outside Git at:

/Volumes/AverySSD/anticheat-evaluation/

The canonical prefix was updated in place by scripts/stage-eac-runtime.sh
without Wineboot. Only the required Win64 loading surface was staged under:

drive_c/vkmt-eac-test/

The stage manifest is VKMT_EAC_STAGE.tsv. It records the staged EOS SDK DLL,
protected launcher, EAC setup executable, test settings, dummy target, and
source archive hashes. The official setup executable is never invoked with an
install command; the probe only creates it for a bounded loader test.

Authoritative evidence:

docs/package-and-validation.md
docs/package-and-validation.md
docs/package-and-validation.md

The final run returned EAC_CONTRACT_ALL_ARCHITECTURES_OK and status=0.
ARM64, ARM64EC, x86_64/FEX, and i386/WoW64 all passed the VKMT mock contract,
malformed-message and negative matrix, client/server restart, and concurrent
session checks. The x86_64/FEX lane also:

- loaded all selected EOS Anti-Cheat client/server exports;
- created the official start_protected_game.exe;
- created the official EasyAntiCheat_EOS_Setup.exe without installing it;
- recorded launcher/setup exit or bounded-termination results.

The official Win64 launcher is NOT_APPLICABLE to ARM64, ARM64EC, and i386
guest binaries; those lanes retain mock/API coverage. Real EAC backend
attestation remains MISSING_PRODUCT_CONFIGURATION because the downloaded
sample settings contain placeholder product, sandbox, and deployment IDs.
No VKMT_EAC_REAL_ATTESTATION_OK marker exists. Kernel-driver requirements
remain unsupported unless a legitimate platform/vendor implementation is
provided.

EAC binaries are external licensed assets and are never package payloads by
default. They must remain separate-fetch;never-package unless distribution
authorization is separately documented.

#### MoltenVK capability-truthfulness workstream (acceptance lane, 2026-08-03)

`scripts/probe-moltenvk-behavior.sh` is the authoritative native ARM64
Vulkan/Metal fixture. It directly verifies null storage-buffer descriptors and
out-of-bounds storage-buffer/storage-image robustness readback on Apple M4.
It records typed-buffer alignment properties (16-byte storage/uniform
alignment) without claiming unaligned offsets are safe. Transform feedback
and indirect-count behavior are explicitly not advertised: the previous
transform-feedback path only tracked state and skipped capture, so its
extension entry and feature bits were removed instead of being reported as
working.

The source truthfulness change is nested MoltenVK commit `665b11e7`, with the
raw bundling delta in `patches/moltenvk-phase2-665b11e7.patch`; the rebuild
script promotes the resulting universal dylib into
`wine/build-ec/dlls/win32u/libMoltenVK.dylib`. This is a deliberate capability
boundary, not evidence that transform feedback or indirect-count is complete.

Evidence:

docs/validation/moltenvk-behavior-final-20260803/RESULTS.md
docs/validation/moltenvk-behavior-final-20260803/capability.tsv

#### Graphics behavioral coverage expansion (acceptance lane, 2026-08-03)

The following fixtures and runners reuse the receipt-backed canonical prefix
`build/probe-runs/phase-a-graphics-prefix`; none creates a prefix or invokes
Wineboot:

| Area | Source / runner | Evidence | Current truth |
|---|---|---|---|
| D3D11 | `test/d3d11_graphics_contract.c`, `scripts/probe-d3d11-graphics-contract.sh` | `docs/validation/d3d11-graphics-contract-final-20260803/` | Latest receipt: i386 completes device, VS/PS/CS, compute UAV readback, texture copy/readback, and render-target shader readback. ARM64EC/x86_64 create the device and shaders but retain a bounded structured-UAV compute readback gap (`0x80004005`); the latest ARM64 rerun timed out during provider startup and is not counted green. Swapchain is headless-not-applicable; device-loss injection is not claimed. The runner supports targeted `VKMT_D3D11_GRAPHICS_LANES`. |
| D3D12 | `test/d3d12_graphics_contract.c`, `scripts/probe-d3d12-graphics-contract.sh` | `docs/validation/d3d12-graphics-contract-final-20260803/` | **All four lanes rc=0** generated VS/PS/CS, queue/allocator/list, descriptor-table UAV, RTV descriptor, graphics/compute pipeline, barriers, render/compute readback, fence timeout/completion, and device-removal-reason query. ARM64/ARM64EC required the ARM64-safe DXIL-SPIRV plus vkd3d C-TLS fixes and rebuilt providers. i386 second-device recreation remains explicitly `NOT_CLAIMED`; swapchain/device-loss injection remains separate. |
| D3D9 | `test/d3d9_contract.c`, `scripts/probe-d3d9-contract.sh` | `docs/validation/d3d9-runtime-20260728/` | Device and texture upload are proven in attempted lanes; both fixed-function and shader textured draw/readback remain unavailable in the current headless DXVK route and are not advertised as passing. Present is no-display only. The runner supports targeted `VKMT_D3D9_LANES`. |
| OpenGL | `test/opengl_extended_contract.c`, `scripts/probe-opengl-extended-contract.sh` | `docs/validation/opengl-runtime-20260728/` | Four architecture processes execute and record a no-display boundary on this host. The display-capable fixture contains indexed VBO/EBO, texture sampling, FBO, uniform, sync, sharing, UBO API, present, and resize markers; no headless run is counted as visible-presentation proof. |
| MoltenVK runtime promotion | `scripts/build-moltenvk.sh`, `wine/build-ec/dlls/win32u/libMoltenVK.dylib` | `docs/validation/moltenvk-behavior-final-20260803/` plus runtime hash | Rebuilt universal MoltenVK is promoted into the actual Wine tree, not only the prefix/package. Runtime extension truthfulness remains authoritative from the direct native behavior receipt. |
| ARM64EC DXMT | `scripts/probe-dxmt-arm64ec.sh` | runner source | WMT bridge proof remains plus a standard `D3D11CreateDevice` lane; this does not convert to a pass until that runner is executed successfully with the paired DXMT provider. |

The capability tables intentionally distinguish `PASS`, `NOT_APPLICABLE`,
`UNAVAILABLE`, and `CRASH_OR_FAIL`; feature enumeration or DLL presence is not
substituted for behavioral proof. The rebuilt i386 vkd3d-proton runtime is in
`third_party/vkd3d-proton/install-win32/bin` and was used by the D3D12 i386
contract. All test environments set FEX TSO modes to zero.

The i386 vkd3d-proton rebuild was performed with
`scripts/build-vkd3d-proton-i386.sh` after the transform-feedback policy
change. The resulting i386 D3D12 device plus graphics render/readback receipt
returned rc=0; older pre-rebuild binaries returned `DXGI_ERROR_UNSUPPORTED`
or `E_INVALIDARG` and must not be used as current evidence.

The ARM64 graphics/compute failure was fixed rather than waived. DXIL-SPIRV
C++ `thread_local` and vkd3d C `__declspec(thread)` paths emitted
`[x18,#0x58]` accesses in ARM64/ARM64EC PEs;
`subprojects/dxil-spirv/util/vkmt_thread_local.hpp` plus the vkd3d UAV,
debug-buffer, and address-binding paths now route Windows builds through
Win32 TLS and preserve native TLS elsewhere. The reproducible builders are
`scripts/build-vkd3d-proton-arm64.sh` and
`scripts/build-vkd3d-proton-arm64ec.sh`. Current installed provider hashes:

```
arm64    d3d12.dll     278daf30d640e3d6f1d339ba0fbe6170b3724a7dea37208759d145be633b496e
arm64    d3d12core.dll 54f939570cf893526e4f70134b7a097e9091db70a20ed5d99589d66512117e93
arm64ec  d3d12.dll     7a5f0d3656c64b066fe0663bc563e6d4ac96b6e29a4769eaae3f6f0bc6f38230
arm64ec  d3d12core.dll 8ebf054bf8336af06725466d7bc32eb61fd767f4e5077f82d0bf28f2ed620cd9
win32    d3d12.dll     52cfe58b301771dc163fd45a5c0689bf22d1bc2396133456e7f2bd94cc3b87f1
win32    d3d12core.dll 56abc44d741df607ccf4ae7d3cdbd801d592fba4124bccab1705661fefbeaad3
MoltenVK wine/build-ec/dlls/win32u/libMoltenVK.dylib
         f05d95bb072630c301228752ecdbe5eecc5afce2d3de5365b2a29934fd32e0f2
```

#### Graphics infrastructure Workstream 0 (acceptance lane, 2026-08-03)

`scripts/verify-graphics-infrastructure.sh` is the non-mutating Workstream 0 gate.
It verifies the existing receipt-backed
`build/probe-runs/phase-a-graphics-prefix` without creating a prefix or
running Wineboot. It checks the promoted custom FEX providers, universal
MoltenVK, architecture-matched DXVK/vkd3d-proton artifacts, ARM64EC DXMT
artifacts, and native ARM64 `winemetal.so` closure. It also rejects any active
graphics acceptance runner that enables a FEX TSO mode.

The receipt is
`docs/validation/graphics-infrastructure-final/RESULTS.md` and the artifact
hash/architecture table is `capability.tsv`. The gate returned
`GRAPHICS_INFRASTRUCTURE_P8_OK`; this verifies staging integrity only and does
not claim that the remaining D3D11, D3D9, DXMT full-device,
MoltenVK transform-feedback/indirect-count, or display-backed feature gaps are
complete.

#### FEX/WoW64 graphics prerequisite Workstream 1 (acceptance lane, 2026-08-03)

The nested Wine source promotion is commit `f108c09` in
`wine/wine-11.12`. It makes native guest-range selection retry a concrete gap
when a derived low alias is occupied, while preserving an explicitly
requested guest address. It also makes `NtUnmapViewOfSection` and
`NtUnmapViewOfSectionEx` retire the complete mapping reservation after
commit/decommit interval splitting instead of retiring only the queried
interval. The rebuilt ARM64 WoW64 module is staged in the canonical prefix by
`scripts/vkmt-prefix sync-wow64`.

`test/wow64_vm_contract.c` and `scripts/probe-wow64-vm-contract.sh` now prove
top-down/high-host allocation, guest-aperture pressure, reserve/commit/
decommit/recommit/release, protection, reuse, overlapping file views,
concurrent allocation/mapping pressure, executable reuse, and correlated
i386 FEX invalidation. The all-lane receipt is
`docs/validation/graphics-wow64-final/RESULTS.md` with matching
`capability.tsv`; both x64 and i386 returned rc=0 with all FEX TSO settings
zero. On x64, fixed low-host hints are explicitly recorded as the
high-host-aperture policy rather than treated as a false allocation pass.

## Preservation and cleanup policy


Current active project root: `/Volumes/AverySSD/VKMT`.

### Preserved active inputs and outputs

- `wine/wine-11.12` — active Wine 11.12 source with custom ARM64 / ARM64EC /
  WoW64 changes.
- `wine/build-ec` — active targeted-build tree.  It contains ARM64, x86_64,
  and i386 PE outputs, native ARM64 Unix libraries, and the staged FEX
  `dlls/xtajit/aarch64-windows/xtajit.dll` provider.
- `third_party/{FEX-2607,dxvk,vkd3d-proton,MoltenVK,DXMT-v0.80,dxmt-src-v0.80}`
  — pinned component source/build trees.
- `patches/` and `scripts/` — source patches and repeatable targeted build /
  probe commands.
- `test/` — probe source and PE probes.
- `build/fex-wow64` — current FEX provider build output.
- `toolchains/llvm-mingw-20260616-ucrt-macos-universal` — the active in-tree
  LLVM-mingw cross-toolchain and its custom C++/libunwind runtime inputs.

The current active stage does not contain `winemetal.dll` or `winemetal.so`.
That is a known preservation gap: DXMT sources and build scripts are present,
but its installed runtime must be rebuilt/staged before DXMT can be claimed as
preserved.

### Historical archive classification

`/Volumes/AverySSD/VKMT-archive-recovery/.issue25` consists primarily of July
13 MetalSharp release-runtime copies, disposable prefix snapshots, and logs.
`/Volumes/AverySSD/Arm64WINE-archive-2026-07-13/root/.issue25` contains a
second byte-identical historical runtime set.  A sampled `libLLVM.dylib` from
both `release-runtime` trees had SHA-256
`5eb23789b65618aa23195596307e2086fa6ca392f9caaf82ec5422e98cadec76`.

Neither archive is the active VKMT source/build tree.  Do not remove the
current `VKMT` root.  Archive deletion may proceed only as Workstream 0 cleanup,
after checking the active inventory above.

### Cleanup record

On 2026-07-26, the verified obsolete
`VKMT-archive-recovery/.issue25` workspace was removed.  It represented about
93,106,332 KiB of logical directory usage.  APFS reported no snapshots and no
open deleted files, but did not return corresponding physical free space;
therefore logical `du` figures must not be treated as guaranteed reclaimable
space.  No remaining archive or non-VKMT user data has been removed.

The remaining active temporary probe roots and small targeted-build logs were
removed after inspection.  The project now uses exact-prefix cleanup only;
there is no broad Wine-server kill or project-tree deletion in the probes.

At the latest inventory, Wine's `dxgi`, `d3d12`, and `d3d12core` PE modules
exist for ARM64, x86_64, and i386.  The FEX provider, FreeType, MoltenVK, and
the in-tree LLVM-mingw toolchain exist.  This is preservation evidence only,
not a runtime compatibility claim.  The DXMT v0.80 stage was rebuilt on
2026-07-26 from the preserved source using Xcode 27.0 beta's installed Metal
Toolchain.  `winemetal.dll` reports `IMAGE_FILE_MACHINE_ARM64EC` and
`winemetal.so` reports ARM64 Mach-O.  Its runtime probe is still a later
acceptance gate.

DXVK now has staged x86_64 and i386 PE runtimes, and vkd3d-proton has a staged
x86_64 D3D12 runtime. DXMT also has i386 PE modules including
`i386-windows/winemetal.dll`. That i386 PE module is intentionally paired with
the already-staged native ARM64 `aarch64-unix/winemetal.so`; an i386 Mach-O
bridge would violate the ARM64-host/no-Rosetta contract.

The i386 `winemetal.dll` was verified as `COFF-i386`; the paired Unix module
was verified as ARM64 Mach-O. The full `scripts/verify-preservation.sh`
inventory passed after staging these outputs.

### Historical archive salvage

Before any further historical-archive cleanup, the unique tracked Wine edits
and root build metadata from `Arm64WINE-archive-2026-07-13` were copied to
`archive-salvage/Arm64WINE-archive-2026-07-13`.  The retained copy includes a
binary Git diff, the exact modified source files, provenance, and SHA-256
checksums.  Verify it with `shasum -a 256 -c SHA256SUMS` from that directory.

After that verification, the historical archive's `.issue25` subtree was
removed on 2026-07-26.  It contained about 89 GiB of repeated release/prefix
runtime stages and contained no DXMT/Winemetal or FEX/XTajit artifact absent
from active VKMT.  The external volume free space increased from 15 GiB to
103 GiB.  The archive root itself remains for further item-by-item reviewing.

The separately named `VKMT-archive-recovery` tree was then verified against
the surviving historical archive: its Wine revision, binary custom-diff hash,
and root metadata hashes were identical. It was removed as a 23 GiB duplicate.
The volume reported 110 GiB free after the removal.

`Arm64WINE_Build` was also reviewed as an older clean Wine 11.5/Blink workspace.
It contained no DXMT/Winemetal/FEX artifact absent from VKMT; its root build
scripts and provenance were checksummed into `archive-salvage/Arm64WINE_Build`
before the obsolete 10 GiB workspace was removed.

## Release validation findings


Date: 2026-08-19

This is the Workstream 3 review for the upgrade and stability plan in
`/Users/averyfelts/Documents/Obsidian/VKMT Upgrade and Stability plan.md`.
It is deliberately evidence-led: source presence, feature advertisement, and
wrapper exit status are not accepted as proof of a runtime capability.

### Host and platform boundary

The target host is Apple Silicon macOS (`Darwin arm64`). Box64/Box32 and
`systemd-binfmt` are Linux components; neither can be installed or registered
in the macOS kernel. VKMT therefore uses the correct native macOS design:

* ARM64 Wine and ARM64 Unix libraries;
* ARM64EC/ARM64X for the hybrid Windows surface;
* the native ARM64 FEX-derived `xtajit64.dll` provider for x86_64 guests;
* the native ARM64 FEX-derived `xtajit.dll` provider plus WoW64 for i386;
* no x86 Mach-O bridge, Rosetta dependency, or Linux binfmt registration.

This is a platform substitution, not a silently skipped gate. A Linux Box64
installation would be a separate runtime and cannot be used to validate VKMT's
macOS path. `scripts/probe-release-architecture.sh` records this boundary and
fails closed if run on a non-Darwin host.

### Findings and gates

| plan workstream | Finding | Gate / evidence | Status |
| --- | --- | --- | --- |
| 1 | External-drive release installation is transactional and isolated from the existing `~/.metalsharp/runtime`. | VKMT v0.60.0 release installer, external target, archive SHA-256, and `.metalsharp-runtime-install` receipt. | PASS |
| 1 | Box64/Box32 + `systemd-binfmt` are not applicable to this macOS target. FEX is the paired translator. | Host/platform checks and provider hashes in the acceptance lane release receipt. | PASS (platform-adapted) |
| 2 | All four guest architecture routes execute in one fresh prefix with all FEX TSO controls set to zero. | `P6_SINGLE_PREFIX_ALL_ARCHITECTURES_OK`; historical full acceptance lane receipts remain required for functional acceptance. | PASS |
| 3 | Reusable prefix lifecycle, provider staging, cache/hotset receipts, and evidence layout exist. | `scripts/vkmt-prefix`, `scripts/stage-runtime-providers.sh`, `docs/validation/`. | PASS |
| 4 | Safe performance work is measured and retained; unsafe candidates are rejected. | `docs/validation/performance-hotset-20260801/RESULTS.md`, candidate optimization ledger/disposition, no-TSO receipts. | PASS |
| 5 | The latest VKD3D-Proton-MacOS v1.0 asset is verified and passes the complete ladder in VKMT's matched x86_64 Wine lane. Its x86_64 PE modules are packaged as an explicit overlay; they are not copied over VKMT's native ARM64/ARM64EC/i386 directories because the same modules do not expose the ladder through the ARM64 FEX route. | Release asset SHA-256, fresh-probe ladder, module hashes, and the raw ARM64 compatibility run under `docs/validation/release-vkd3d-v1/`. | PASS (x86_64 overlay; native FEX lane preserved) |
| 6 | TSO must remain disabled in every launch path and review. | `FEX_TSOENABLED=0`, `FEX_VECTORTSOENABLED=0`, `FEX_MEMCPYSETTSOENABLED=0`; `docs/performance.md`. | PASS |
| 7 | review 2 is the close-out review for compatibility gaps, leakage, and stale state. | `review2.md`, the acceptance lane release receipt, and the retained native-FEX compatibility note. | PASS |
| 8 | Package comparison, split/reassembly, installer regeneration, external installation, and release replacement include the native VKMT baseline and the explicit v1.0 x86_64 graphics overlay. | `docs/validation/release-package-20260819/RESULTS.md`, final installer receipt, and release asset verification. | PASS |

### Workstream 4 gate ladder

The following are the required gates after any runtime or translator change:

1. Source and patch identity are recorded before building.
2. The canonical provider hashes match the build stage and the prefix after
   Wineboot.
3. A fresh prefix runs ARM64, ARM64EC, x86_64, and i386/WoW64 with all TSO
   settings zero and without Rosetta.
4. The affected functional contract is rerun (MSync, WoW64 VM, networking/
   TLS, UI/COM, browser, or graphics).
5. Cold/warm performance is measured with output checksums and memory samples;
   a speed claim requires a matched control and no stability regression.
6. The prefix, wineserver, temporary logs, and candidate providers are
   removed after evidence is copied to a versioned validation directory.

### Security and leakage review

* Runtime installation uses SHA-256 verification before extraction, extracts
  to a sibling staging directory, and activates with a single rename.
* The prior runtime is preserved as a backup unless the explicit discard
  option is used; the existing installation is never overwritten by the
  plan validation install.
* Release archives must contain public source and licenses only. Encrypted
  payloads, keys, user prefixes, private caches, and absolute symlinks are
  rejected.
* All FEX TSO settings are forced to zero by the runtime launcher and prefix
  receipt. Certificate-ignore settings remain diagnostic-only.
* Temporary validation prefixes and logs are not release assets. Evidence is
  copied before cleanup.

### Promotion rule

No feature bit, release README, or historic receipt closes Workstream 5 by itself.
The v1.0 overlay is promoted only for the architecture it actually passed:
freshly rebuilt x86_64 VKMT Wine. The native ARM64/ARM64EC/i386 acceptance lane lane keeps
the architecture-matched VKMT graphics artifacts and its raw v1.0 FEX probe
is retained as a compatibility boundary rather than misreported as a pass.

## Close-out validation gates


Date: 2026-08-19

review 2 is the Workstream 6/7 close-out checklist. It is intentionally independent
of the earlier optimization ledger and does not include CEF/Electron as a
required implementation target.

### Gate A — TSO and translation policy

Required for every acceptance command and launcher:

```text
FEX_TSOENABLED=0
FEX_VECTORTSOENABLED=0
FEX_MEMCPYSETTSOENABLED=0
```

The provider must reject a nonzero effective value, no launch script may
enable Apple's hardware TSO mode, and no Rosetta process may participate in a
VKMT acceptance run. The software x86 ordering implementation is retained:
acquire/release loads and stores, barriers for unaligned operations, and
acquire/release locked RMW operations.

### Gate B — stale-state and memory-leak review

For each fresh-prefix run:

1. record the prefix receipt and provider/runtime hashes;
2. run one Wineboot and restage providers;
3. run the contract in a single wineserver lifetime;
4. stop the wineserver and wait for it to exit;
5. verify no process, temporary prefix, candidate provider, or probe log is
   left outside the evidence directory;
6. repeat the run in a second fresh prefix;
7. compare resident-set high-water and allocation/leak summaries.

The retained executable-memory gate records status-0 self-modifying-code,
Java JIT, cross-process, graphics, and exact-cleanup runs in
`docs/validation/performance-executable-memory-20260801/RESULTS.md`; the acceptance lane
hot-set receipt records repeated status-0 four-architecture runs and the
working-set/cache controls in `docs/validation/performance-hotset-20260801/`.

Timeouts, wrapper success, partial markers, and a process that is merely
terminated are failures, not passes.

### Gate C — architecture matrix

| Route | Required evidence |
| --- | --- |
| ARM64 | native Wine/loader, Vulkan, graphics, and teardown |
| ARM64EC | CHPE/import routing, callbacks, graphics bridge, and teardown |
| x86_64 | FEX provider, CPU/lifecycle, DXVK/vkd3d graphics, and teardown |
| i386 | WoW64/FEX memory, syscall/callback/exception, graphics, and teardown |

The aggregate marker is accepted only with four individual markers and a
status-0 receipt from one prefix and one wineserver lifetime:

```text
P6_SINGLE_PREFIX_ARM64_OK
P6_SINGLE_PREFIX_ARM64EC_OK
P6_SINGLE_PREFIX_X86_64_OK
P6_SINGLE_PREFIX_I386_OK
P6_SINGLE_PREFIX_ALL_ARCHITECTURES_OK
```

### Gate D — graphics feature truthfulness

The promoted VKMT graphics set must provide behavioral evidence for:

* D3D12 feature levels 12_2, 12_1, 12_0, 11_1, 11_0, and CORE_1_0;
* Shader Model 6.5;
* DXR 1.1 / ray-tracing tier 1.1;
* VRS tier 2;
* mesh shader tier 1 and pixel-exact dispatch;
* sampler feedback tier 0_9 with 64-bit image-atomic lowering;
* tiled resources tier 4, conservative rasterization tier 3, ROVs, depth
  bounds, barycentrics, typed-format casting, copy-queue timestamps, and
  output-merger logical operations.

The vkd3d-proton-macos v1.0 release provides an x86_64 Wine/Rosetta artifact.
Its exact asset SHA-256, module paths, and feature output are recorded in the
fresh x86_64 VKMT Wine ladder receipt. The modules are promoted as an explicit
x86_64 overlay only; the native ARM64/ARM64EC/i386 directories retain their
architecture-matched VKMT artifacts because the raw x86_64 modules do not pass
the same feature query through the ARM64 FEX route.

### Gate E — package integrity

The final package must:

1. contain every required original and promoted runtime asset;
2. contain no user prefixes, temporary logs, encryption keys, or absolute
   symlinks;
3. pass `zstd -t` and a full manifest hash check;
4. compare its normalized manifest against the previous release and report
   additions, removals, and changed hashes;
5. split into ordered release parts, verify every part hash, reassemble, and
   verify the archive hash again;
6. install transactionally to the external drive with a regenerated installer;
7. run the acceptance lane architecture gate from the newly installed target; and
8. replace the old release assets only after all preceding gates pass.

### Current decision

review 2 is complete for the scoped product lanes: native VKMT acceptance lane/acceptance lane remains
the all-architecture baseline, while the v1.0 graphics overlay is accepted
only for the x86_64 Wine route that passed its fresh ladder. The explicit
native-FEX compatibility note prevents the release's x86_64 claim from being
mistaken for all-architecture graphics support.
