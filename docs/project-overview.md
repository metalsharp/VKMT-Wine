# VKMT Project Overview

This document is the consolidated project status, product scope, operating
principles, and acceptance model for VKMT. It replaces the former plan and
graphics-plan documents with a normalized, domain-oriented reference.

## Current baseline

VKMT is an Apple-Silicon-native Wine distribution for ARM64, ARM64EC,
x86_64, and i386/WoW64 Windows software. Native host code remains ARM64 and
x86 guest execution uses the in-tree FEX-derived providers. Rosetta is not a
runtime dependency.

A feature is accepted only when implementation, deterministic behavioral
coverage, applicable architecture coverage, retained evidence, and a reusable
runner all agree. Historical workstream labels are intentionally omitted from
this document; validation receipts retain their original machine markers where
those markers are part of a runner interface.

## Product completion and acceptance


### Operating principles

- No CI requirement. Validation remains reproducible through local, staged,
  targeted runners and retained evidence receipts.
- A feature is complete only with implementation, deterministic test,
  applicable architecture coverage, retained evidence, and a reusable runner.
- Preserve known-good behavior while expanding coverage. Do not make broad
  FEX, Wine, or MoltenVK updates without a contract test identifying the gap.
- Test-only orchestration hooks must be opt-in, ABI-safe, and never provide
  production timing-workaround semantics.

### 1. Shared validation and prepared-prefix infrastructure

This is the highest-leverage foundation: it removes repeated prefix setup,
makes results comparable, and prevents false positives from missing runtime
pieces.

#### 1.1 Generic prefix lifecycle runner

Implement a reusable runner:

```sh
scripts/vkmt-prefix create  --profile core|graphics|browser|managed|full --prefix PATH
scripts/vkmt-prefix verify  --prefix PATH
scripts/vkmt-prefix warm    --prefix PATH
scripts/vkmt-prefix run     --prefix PATH -- command.exe
scripts/vkmt-prefix reset   --prefix PATH
scripts/vkmt-prefix destroy --prefix PATH
```

Profiles:

| Profile | Required staged components |
| --- | --- |
| core | Wine prefix, FEX providers, host libraries, WoW64 support, GStreamer closure, environment contract, GPU cache and hotset |
| graphics | core plus MoltenVK, DXVK, vkd3d-proton, DXMT where supported, MetalSharp runtime |
| browser | graphics plus CEF, Chromium fixture assets, WebView2, Electron assets, Gecko, and TLS roots |
| managed | core plus Wine Mono, Java/JRE/JDK runtime, and managed fixtures |
| full | All supported components and diagnostic fixtures |

Each prefix should contain:

```text
prefix/.vkmt/receipt.json
prefix/.vkmt/staged-files.manifest
prefix/.vkmt/environment.sh
prefix/.vkmt/wineboot.status
prefix/.vkmt/cache-state.json
```

The receipt must record VKMT/Wine/FEX/graphics component identities, host
architecture, staged provider hashes, runtime closure hashes, Wine prefix
version, cache and hotset identity, installed roots, and Wineboot status.

Required behavior:

- `create` stages dependencies, creates the prefix, runs Wineboot once,
  restages anything Wineboot changes, and writes a receipt.
- `verify` detects missing, stale, or incompatible staged state.
- `warm` performs narrow warm-up workloads without treating them as proof.
- `run` rejects incomplete/stale prefixes unless explicitly overridden for
  diagnosis.
- Tests accept `--prefix PATH`; fresh-prefix mode remains for bootstrap
  testing.

Migrate first:

- `scripts/probe-p8-single-prefix-architectures.sh`
- `scripts/probe-msync.sh`
- `scripts/probe-dxmt-arm64ec.sh`
- `scripts/probe-cef-runtime.sh`
- `scripts/probe-perf-p8-hotset.sh`
- managed Java/Wine Mono probes
- networking/browser fixture probes

### 2. Architecture matrix and evidence

Every component should state intended support:

| Architecture | Required baseline |
| --- | --- |
| ARM64 | Native Wine/loader/process/runtime behavior |
| ARM64EC | Native/translated interoperability, CHPE redirection, callback and unwind correctness |
| x64 | WoW64/FEX execution, PE loading, graphics/browser/managed behavior |
| i386 | WoW64/FEX execution, address-space pressure, legacy graphics/browser compatibility |

Acceptance lane remains a focused all-architecture loader/lifecycle regression probe. acceptance lane is
the accepted final runtime baseline: it adds the measured hot-set contract,
identity-checked staging, integrated launch, and a fresh four-architecture
status-0 matrix. acceptance lane is never release acceptance by itself.

Standard evidence layout:

```text
docs/validation/<component>-<date>/
  RESULTS.md
  environment.txt
  prefix-receipt.json
  commands.txt
  ARM64/
  ARM64EC/
  x86_64/
  i386/
```

Each result must identify command, prefix receipt, architecture, exit status,
required markers/artifacts, exclusions, and whether it is acceptance,
diagnostic, or exploratory. Timeouts, signals, wrapper success, and partial
markers are not acceptance passes.

### 3. MSync

MSync has focused work and all-architecture validation for:

- server-managed event waiter registration;
- pulse-specific wake tokens;
- exact non-latching PulseEvent behavior;
- WaitAll rollback bookkeeping;
- abandoned-mutex rollback restoration;
- deterministic opt-in test hooks.

Maintain it by adding stress coverage for repeated manual/auto pulse,
pulse-before-wait non-latching, wake/set/reset races, abandoned mutex retries,
and recursively pre-owned mutexes. Run this gate after changes to ntdll,
wineserver synchronization, WoW64 wait machinery, or FEX signal/exception
behavior. Preserve shared ABI assertions.

### 4. WoW64 virtual memory: `dlls/wow64/memory.c`

This is a major compatibility area for i386, Chromium/Electron allocation,
graphics applications, and FEX-generated code.

#### 4.1 Contract to prove

Validate:

- high host-address allocations and guest aperture pressure;
- reserve/commit/decommit/recommit;
- protection changes;
- overlapping views and partial unmaps;
- address reuse;
- file mappings;
- concurrent allocation/mapping pressure;
- FEX generated-code maps and invalidation;
- Chromium/Electron reservation/decommit patterns.

#### 4.2 Candidate implementation direction

Profile before replacing the existing registry. If lookup/locking or
correctness pressure warrants it, introduce a sparse page-granular indexed
mapping model:

- 4 KiB guest-page lookup;
- two-level sparse guest address map;
- static/pre-reserved leaf allocation;
- host base, state, protection, and generation metadata;
- no heap allocation in sensitive callbacks;
- explicit synchronization/reentrancy rules;
- transactional map/unmap update ordering.

Potential benefits are bounded mapping lookup, explicit partial-unmap state,
stale association detection, and stable FEX mapping/protection data.

#### 4.3 Tests

Add/extend a WoW64 VM contract fixture for x64/i386 guest modes:

- reserve, commit, decommit, recommit, release, reuse;
- partial protect and unmap;
- section/view mappings;
- overlap ordering;
- high-address translation;
- concurrent map/protect/unmap;
- Chromium-like allocator stress;
- FEX guest-code mapping and invalidation.

Acceptance: correct faults/protection, no stale mappings or corruption, and
no regressions in acceptance lane i386, DXMT i386, Electron ia32, or browser fixtures.

### 5. FEX, process loading, and transitions

#### 5.1 Compatibility contract

Document the local FEX base revision, local commits, patch ownership,
behavior contracts, cache assumptions, and performance-sensitive paths.
Treat upstream update work as a controlled compatibility project.

#### 5.2 Process/loader contract suite

Implement all-applicable-architecture tests for:

- `CreateProcess` and `NtCreateUserProcess`;
- command line, environment, CWD, executable lookup;
- inherited handles, redirected pipes, consoles;
- suspended startup/resume and exit cleanup;
- LoadLibrary/GetProcAddress/forwarders/delay loads;
- loader lock/reentrancy;
- TLS/FLS and thread lifecycle;
- APC/callback paths;
- ARM64EC CHPE routing;
- exception/unwind/callback transitions across FEX and ARM64EC.

#### 5.3 Runtime-image cache safety

Create cold/warm/corrupt/stale cache tests covering repeated process lifecycle,
JIT invalidation, DLL load/unload, graphics startup, Java JIT/GC, and browser
subprocesses. Reintroduce deliberately excluded CRT images only one at a
time with graphics/browser/managed regressions.

#### 5.4 Transition optimization

Profile real workloads: CEF, WebView2, Electron x64/ia32, Steam/launchers,
Java, DXMT, and i386 graphics. Use transition histograms to optimize only
proven hot boundaries.

### 6. Core Wine functional substrate

#### 6.1 Networking and WinSock

Promote existing socket experiments into a contract suite:

- IPv4/IPv6 loopback and DNS/address ordering;
- `SIO_ADDRESS_LIST_SORT`;
- nonblocking connect;
- event select/rearm, select/poll/WSAPoll;
- overlapped I/O and async lifetime;
- parallel connections and close races;
- TLS fragmentation/partial reads/writes;
- proxy environment handling where supported.

Prioritize x64/i386, then all applicable architectures.

#### 6.2 TLS and trust

Replace certificate-bypass acceptance with a deterministic local trust
fixture:

- locally trusted valid root and hostname;
- expired/untrusted certificate rejection;
- intermediate chains;
- WinHTTP and WinINet;
- CEF/Chromium and WebView2.

Ignore-certificate-errors remains diagnostic-only.

#### 6.3 UI, COM, callbacks, and fonts

Build a contract suite for COM apartments, STA message pumping, cross-thread
callbacks, controller/environment completion, nested loops, window lifetime,
and DirectWrite enumeration/layout/shaping/fallback. Use CEF/WebView pixel
checks to validate actual text output. Investigate and validate changes in
`dlls/dwrite/freetype.c` and `dlls/win32u/freetype.c`.

### 7. Browser and application hosts

#### 7.1 CEF/Chromium

Current evidence includes CEF exports and selective diagnostic/candidate CDP
markers, but canonical release-style C0 evidence did not publish DevTools in
the required window. This is not yet promoted standard-exit acceptance.

Sequence:

1. Browser prepared-prefix closure.
2. Standard startup contract: child processes, DevTools endpoint, clean exit.
3. CDP semantic contract: navigation, trusted HTTPS, script/DOM, input,
   audio where practical, screenshot checksum, deterministic teardown.
4. Explicit architecture policy: validate x64 graphics path; keep i386
   software-only limitations visible until equivalent support exists.
5. OSR: render buffers, input, resize, dirty rectangles, deterministic pixels.
6. Subprocess robustness: crash/restart, multiple instances, cache/profile
   isolation.

#### 7.2 WebView2

Move bootstrap proof to full application proof:

- environment/controller callbacks return;
- WebView creation/navigation;
- script callback;
- trusted HTTPS;
- host/web messaging;
- resize/input;
- clean shutdown;
- deterministic DOM or screenshot output.

Trace COM apartment state, callback marshaling, message-loop behavior,
window handles, and cross-thread waits. Do not mask callback failure with
timeouts.

#### 7.3 Electron

Keep Electron x64 as a strong deterministic regression workload. Expand it
with multi-window, renderer/GPU lifecycle, packaged startup, and profile
behavior.

For ia32: first minimize/reproduce its decommitted-allocation failure, prove
the WoW64 memory contract, then add startup/rendering acceptance and expand
behavior only after that.

### 8. Graphics plan

#### 8.1 Capability truthfulness

Every nontrivial advertised feature needs behavioral proof. For partial
features, implement correctly, disable/limit exposure, or document a precise
fallback policy. Feature bits alone are not proof.

#### 8.2 MoltenVK

Add direct behavioral fixtures for robust access, null descriptors, transform
feedback, indirect draw count, and typed-buffer alignment.

Transform feedback must capture actual output. Test buffer contents,
pause/resume, streams, query counts, and offsets. Implement an emulation path
or stop advertising it if correctness cannot be delivered.

For indirect count, test count-buffer alignment, zero/nonzero counts, and
synchronization.

#### 8.3 D3D9, OpenGL, D3D11, and D3D12

D3D9 needs device creation, texture/surface, clear, textured draw, readback,
present, resize, and reset tests.

OpenGL needs vertex/index paths, texture upload/readback, FBOs,
uniforms/UBOs, context sharing, visible present/resize, and synchronization.

Expand D3D11/D3D12 with deterministic shader/device/resource tests, compute
and render readback, texture copies, swapchain/present, command queue/fence,
descriptor/barrier behavior, and DXVK/vkd3d-facing workloads.

### 9. DXMT

ARM64EC DXMT already has proof beyond a staging bridge: Metal device discovery,
imported DXGI factory lifecycle, and loader/CHPE routing. A D3D11 device
fixture exists, but canonical acceptance currently uses the narrower WMT path.

Therefore next steps are:

1. Promote ARM64EC `D3D11CreateDevice` to a standard gate.
2. Add D3D11 compute/readback.
3. Add render target/readback.
4. Add DXGI swapchain/present/resize.
5. Add device-loss/recreation if feasible.
6. Establish i386 runtime acceptance: staging, process/load, device,
   compute/readback, then render/present.

Do not claim WoW64 DXMT support until the i386 runtime path has evidence.

### 10. D3DCompiler

Current proof includes x64 compilation to DXBC and i386 D3D11 consumption with
deterministic compute readback. It is not complete D3DCompiler coverage.

Add `test/d3dcompiler_contract.c` and all-architecture execution for:

- VS/PS/CS compilation;
- flags/macros/include handlers;
- compile failures and diagnostics;
- `D3DCompileFromFile`, including Unicode/path behavior;
- preprocess and disassembly;
- reflection metadata;
- 43/46/47 DLL behavior;
- explicit unsupported API HRESULTs;
- D3D11/D3D12 consumption of generated DXBC where applicable.

Publish an architecture/API capability table and do not conceal known stubs.

### 11. Apple Silicon optimization program

Measure before optimizing. For each workload retain cold/warm prefix/cache,
startup latency, process count, FEX transitions, CPU time, memory high-water,
shader/cache timings, cache hit/miss data, and output checksums.

Priority workloads:

1. CEF startup/CDP;
2. WebView2 lifecycle;
3. Electron x64 and later ia32;
4. Java startup/JIT/GC;
5. DXMT D3D11;
6. DXVK/vkd3d;
7. Steam/launcher startup.

Candidates:

- reduce measured FEX boundary crossings;
- improve runtime-image cache reuse/safety;
- optimize WoW64 mapping lookup/invalidation;
- avoid redundant staging and loader work;
- preserve native ARM64 execution;
- optimize Metal lifetime/synchronization only with correctness coverage;
- version shader-cache warming/eviction through prefix receipts;
- assess thread QoS/affinity only after measured evidence.

### 12. Execution order

#### Workstream A: foundation

1. Implement `scripts/vkmt-prefix`.
2. Add receipts, verification, profiles, and standard evidence structure.
3. Migrate acceptance lane and MSync.

#### Workstream B: core contracts

4. Process/loader/cross-architecture suite.
5. WinSock/TLS suite.
6. WebView2 callback-return investigation.
7. WoW64 VM stress and Chromium-style allocator reproducer.

#### Workstream C: memory and FEX

8. Profile `dlls/wow64/memory.c`.
9. Implement indexing/transaction improvements only if justified.
10. Validate FEX cache/process/transition behavior.

#### Workstream D: browser/application host

11. CEF standard DevTools/startup gate.
12. CEF trusted HTTPS/CDP/pixel/subprocess gate.
13. WebView2 full lifecycle contract.
14. Electron x64 regression expansion.
15. Electron ia32 recovery after VM proof.

#### Workstream E: graphics

16. D3DCompiler contract.
17. DXMT ARM64EC device/compute/render proof.
18. DXMT i386 proof.
19. D3D9/OpenGL render and present coverage.
20. MoltenVK feature-truthfulness, transform feedback, and indirect-count work.
21. DXVK/vkd3d application-facing regressions.

#### Workstream F: performance

22. Benchmark the prepared workload matrix.
23. Optimize measured FEX/WoW64/Apple Silicon bottlenecks.
24. Retain before/after performance and functional evidence.

### 13. Product-ready definition

Do not claim broad compatibility from smoke tests alone. A release-quality
claim requires:

| Area | Minimum proof |
| --- | --- |
| Architectures | acceptance lane plus architecture-specific functional workloads |
| MSync | Deterministic pulse/rollback stress |
| Process loading | Child creation, loader, pipes, callbacks, teardown |
| FEX | Cache safety, exceptions, transitions, nested processes |
| WoW64 memory | Mapping/protection/reuse/concurrency/Chromium-style stress |
| Networking/TLS | IPv4/IPv6/events/order/trusted success and rejection |
| CEF | Standard startup, trusted HTTPS, CDP, pixels, subprocesses, teardown |
| WebView2 | Returning callbacks, navigation/script/input/teardown |
| Electron | Robust x64; ia32 after VM contract is green |
| D3DCompiler | Compile/preprocess/reflection plus runtime shader output |
| DXMT | ARM64EC render proof and i386 proof before WoW64 claims |
| Graphics | Deterministic render/readback/present and truthful feature exposure |
| Apple Silicon performance | Measured improvement with functional output proof |

The priority order is intentional: reusable staged prefixes, process/loader
correctness, WoW64 memory, FEX transitions, networking/TLS, and browser
callback behavior unlock more applications than isolated rendering features.

## Graphics completion and acceptance


This plan finishes VKMT's custom graphics stack rather than merely proving
that its DLLs load. MoltenVK, FEX, Wine, DXVK, vkd3d-proton, DXMT,
MetalSharp, and the WoW64 boundary are all custom or locally patched, so every
feature must be accepted from behavioral evidence against the actual promoted
runtime.

### Non-negotiable operating rules

1. **acceptance lane only.** Do not use acceptance lane labels, providers, receipts, or fallback
   binaries.
2. **One canonical prefix:**
   `build/probe-runs/phase-a-graphics-prefix`.
3. Probes reuse that prefix, never recreate it, and do not invoke Wineboot.
   They stage only the provider under test and record exact provider hashes.
4. An older backup binary must never be used to make a failing test pass.
   Source-built, promoted runtime artifacts are authoritative.
5. Every source fix must be promoted into the actual Wine/build tree before it
   is accepted; changing only the prefix is insufficient.
6. Test every applicable architecture independently:
   - ARM64;
   - ARM64EC;
   - x86_64 through the custom FEX/xtajit64 provider;
   - i386/WoW64 through the custom FEX/xtajit provider.
7. Acceptance runs force all FEX TSO controls off:

   ```text
   FEX_TSOENABLED=0
   FEX_VECTORTSOENABLED=0
   FEX_MEMCPYSETTSOENABLED=0
   ```

8. A feature is either behaviorally proven, correctly implemented and proven,
   explicitly disabled with a documented fallback, or reported as a real
   gap. Feature bits and DLL presence are never sufficient evidence.

### Workstream 0 — Lock the acceptance lane graphics infrastructure

#### Work

Create one shared graphics execution layer with:

- canonical-prefix validation;
- architecture-to-provider mapping;
- exact staging manifests;
- provider hash verification;
- no-TSO environment enforcement;
- wineserver lifecycle handling;
- retained logs on failure;
- no prefix creation and no Wineboot.

Maintain separate provider profiles. DXVK and DXMT must never be mixed.

| Profile | Runtime |
|---|---|
| DXVK | `d3d9`, `d3d10`, `d3d11`, `dxgi` |
| vkd3d-proton | `d3d12`, `d3d12core`, `dxgi` |
| DXMT | `d3d10core`, `d3d11`, `dxgi`, `winemetal.dll`, `winemetal.so` |
| OpenGL | Wine OpenGL plus MetalSharp/SPIR-V-Cross |
| MoltenVK | Promoted Wine `libMoltenVK.dylib` |
| FEX | Current custom `xtajit.dll` and `xtajit64.dll` |

#### TSO cleanup

Active graphics runners must remain zero-TSO. Legacy Java diagnostic scripts
that explicitly set `FEX_TSOENABLED=1` must be converted to internal
software-ordering tests, clearly quarantined as non-acceptance diagnostics, or
removed from the acceptance path. The final graphics gate must fail if an
active graphics or Java acceptance script enables TSO.

#### Gate

Produce:

```text
docs/validation/graphics-infrastructure-final/
  RESULTS.md
  capability.tsv
  staging-manifests/
  hashes.sha256
```

### Workstream 1 — Finish FEX and WoW64 memory correctness

This workstream comes first because D3D11, D3D9, CEF, Electron, and Java all rely
on the same guest mapping behavior.

#### Scope

review and, where required, repair:

- `dlls/wow64/memory.c`;
- FEX guest-code map registration;
- executable-map invalidation;
- reserve/commit/decommit/recommit;
- partial unmaps;
- protection changes;
- overlapping views;
- file mappings;
- high-address host mappings;
- concurrent allocation pressure;
- stale mapping detection;
- W^X transitions;
- FEX generated-code invalidation.

Profile the current fixed registry before replacing it. If lookup, locking, or
correctness pressure warrants it, use a sparse/indexed model with 4 KiB guest
pages, pre-reserved leaves, host/state/protection/generation metadata, no heap
allocation in sensitive callbacks, explicit synchronization, and transactional
map/unmap publication.

#### Required fixture

The WoW64 VM contract must cover:

- reserve/commit/decommit/recommit/release;
- partial protect/unmap;
- overlap ordering;
- address reuse;
- file sections/views;
- high-address translation;
- concurrent map/protect/unmap;
- Chromium-style reservation/decommit;
- FEX executable-map invalidation;
- Java code-cache allocation and invalidation.

#### Gate

Both x64 and i386 must produce:

```text
WOW64_VM_CONTRACT_ALL_OK
FEX_INVALIDATION_NONZERO
NO_STALE_MAPPING
NO_CORRUPTION
FEX_TSO=0
```

No graphics workaround may replace this correctness gate.

### Workstream 2 — Complete custom MoltenVK behavior

The current custom MoltenVK has narrow robust/null behavior proven, while
transform feedback and indirect-count remain disabled. The full goal requires
implementing them or retaining an explicit, justified limitation.

**Current acceptance lane status (2026-08-03):** the direct ARM64 behavior gate passes and
the custom runtime is rebuilt/promoted, but the capability policy is still
truthful fallback rather than full feature completion. Nested source commit
`665b11e7` disables the old passthrough transform-feedback advertisement;
`docs/validation/moltenvk-behavior-final-20260803/RESULTS.md` is the receipt.

#### 2.1 Robust access and null descriptors

Expand the direct native tests to cover:

- storage buffers;
- storage images;
- null descriptors;
- out-of-bounds reads and writes;
- synchronization after OOB access;
- descriptor reuse;
- applicable buffer formats.

#### 2.2 Transform feedback

Implement actual output capture in the custom MoltenVK path, not just state
tracking. Prove:

- captured vertex data;
- buffer contents;
- pause/resume;
- multiple streams;
- query counts;
- offsets;
- overflow behavior;
- synchronization;
- repeated capture cycles.

If Metal has no direct primitive, implement an explicit emulation path using
shader/output instrumentation and custom buffer management. Do not restore
the extension until captured bytes and counters are correct.

#### 2.3 Indirect draw count

Implement and test:

- aligned count buffers;
- unaligned count rejection or fixup;
- zero counts;
- nonzero counts;
- count changes between submissions;
- command synchronization;
- graphics and compute variants.

#### 2.4 Typed-buffer alignment

Implement offset fixups or precise rejection. Test aligned and misaligned
offsets, views crossing boundaries, and read/write correctness.

#### Gate

Native ARM64 must produce actual output and counter evidence. Then exercise
the behavior through D3D11 and D3D12 consumers where applicable.

### Workstream 3 — Stabilize and complete vkd3d-proton/D3D12

The current D3D12 path is the strongest: all four architectures pass
deterministic render/compute/readback. The ARM64/ARM64EC provider now avoids
both DXIL-SPIRV C++ TLS and vkd3d C PE-TLS x18 accesses.

**Current acceptance lane status (2026-08-03):** the canonical fixture is rc=0 on ARM64,
ARM64EC, x86_64, and i386/WoW64 for VS/PS/CS, descriptor-table UAV, render
and compute output, barriers, texture/buffer copies, fence timeout/completion,
and removal-reason queries. A second device initialization passes on the three
64-bit lanes; i386's second `D3D12CreateDevice` entry faults after the first
lane completes and is recorded as `DEVICE_RECREATE_NOT_CLAIMED_I386_WOW64`.

#### Remaining work

Add and prove:

- swapchain creation;
- present;
- resize;
- fullscreen/windowed transitions where possible;
- queue synchronization;
- fence timeout behavior;
- descriptor-table coverage;
- UAV/SRV/RTV transitions;
- device removal/recreation;
- texture-array and format coverage;
- additional DXIL shader variants;
- vkd3d-facing workloads.

Keep the ARM64-safe DXIL-SPIRV TLS implementation. Do not reintroduce
x18-relative C++ TLS into ARM64 or ARM64EC binaries.

#### Gate

All four lanes must pass VS/PS, compute, render target, texture copy,
barriers, descriptors, queue/fence, and device recreation. Present/resize is
accepted when a display-backed lane is available.

### Workstream 4 — Finish DXVK D3D11

#### 4.1 Fix the current boundary

Minimize the ARM64EC/x86_64 structured-UAV failure across:

- structured-buffer creation;
- UAV stride;
- dispatch;
- UAV unbind;
- staging copy;
- map/readback;
- provider boundary;
- FEX/WoW64 pointer conversion.

Diagnose the latest ARM64 startup timeout separately from D3D11 device
creation. Keep the failing logs and do not convert `E_FAIL` into a pass using
known-boundary markers.

#### 4.2 Complete D3D11

All four architectures must prove:

- device creation;
- VS/PS/CS compilation;
- structured and raw buffers;
- UAV/SRV;
- compute readback;
- texture upload/copy/readback;
- render target;
- blend/depth state;
- multiple render targets;
- map/unmap;
- synchronization;
- swapchain/present/resize;
- device-loss/recreation.

#### 4.3 D3D10

Add a DXVK D3D10 contract for `d3d10core.dll`, device creation,
buffer/texture creation, shader load, draw, readback, and DXGI interaction.

#### Gate

No architecture is accepted for D3D11 until the same fixture passes with its
matched DXVK provider.

### Workstream 5 — Finish DXMT

DXMT remains a separate custom stack and must not be inferred from DXVK or from
bridge/factory loading alone.

#### Scope

Prove and repair:

- ARM64EC `d3d11.dll`;
- ARM64EC `dxgi.dll`;
- `d3d10core.dll`;
- `winemetal.dll`;
- ARM64 `winemetal.so`;
- native device discovery;
- imported DXGI factory lifecycle;
- CHPE/loader routing;
- i386 PE loading through the ARM64 host bridge.

#### Required lanes

1. Native WMT/Metal device discovery.
2. ARM64EC `D3D11CreateDevice`.
3. ARM64EC compute/readback.
4. ARM64EC render/readback.
5. DXGI swapchain/present/resize.
6. D3D10 core/device path.
7. i386/WoW64 device creation.
8. i386 compute/readback.
9. i386 render/readback.
10. Close/release/device recreation.

The i386 path uses the ARM64 host `winemetal.so`; no i386 Mach-O sidecar is
required or expected.

#### Gate

Do not claim DXMT WoW64 support until the complete i386 device, compute, and
render sequence passes.

### Workstream 6 — Finish DXVK D3D9

#### Diagnose first

Reduce the current textured-render failure into independent fixtures:

1. fixed-function vertex/declaration path;
2. vertex-shader/pixel-shader path;
3. texture sampling;
4. render-target readback;
5. i386 pointer/handle conversion.

#### Required coverage

- device creation;
- caps;
- texture/surface creation;
- lock/unlock;
- clear;
- fixed-function textured draw;
- shader textured draw;
- readback;
- present;
- resize;
- reset;
- lost-device behavior;
- i386/WoW64 object and pointer lifetime.

A clear or texture upload is not sufficient. The acceptance marker must
contain known expected pixels from a textured draw on every applicable
architecture.

### Workstream 7 — Complete OpenGL 1.x–4.x through SPIR-V-Cross

#### Offscreen contract

Produce real offscreen evidence for all four architectures covering:

- indexed VBO/EBO;
- texture upload/sampling/readback;
- FBO attachment and blit;
- uniforms;
- UBOs;
- synchronization;
- context sharing;
- shader compile/link diagnostics;
- GLSL 1.20 through 4.50;
- integer, float, texture, and framebuffer formats.

#### Display contract

On a display-backed host, add:

- WGL context creation;
- visible window;
- swap/present;
- resize;
- framebuffer resize;
- context recreation;
- window-thread synchronization.

`NO_DISPLAY` is a valid environmental result but is not a visible-rendering
pass.

#### Gate

Publish separate offscreen all-architecture and display-backed results, plus
an explicit unsupported API table.

### Workstream 8 — FEX/Java graphics integration

Run the real graphics fixtures through the custom FEX providers with:

- all TSO settings zero;
- no hardware TSO request;
- no Rosetta fallback;
- no stale provider;
- no stale guest mappings;
- generated-code invalidation enabled;
- W^X transitions validated.

Exercise Java startup, Java code-cache pressure, CEF renderer allocations,
D3D11/D3D12 shader compilation, OpenGL shader translation, repeated process
creation/shutdown, and concurrent graphics helper processes.

The same provider hash and no-TSO proof must appear in every graphics receipt.

### Workstream 9 — Cross-stack integration

After individual API gates are green, run integrated workloads for:

- DXVK D3D9;
- DXVK D3D11;
- vkd3d-proton D3D12;
- DXMT D3D11;
- OpenGL;
- CEF x64 rendering;
- CEF i386 diagnostics where supported;
- simultaneous graphics processes;
- shader-cache and GPU-cache reuse;
- process termination during compilation;
- device recreation after renderer restart.

This workstream specifically checks interaction between FEX memory mappings, the
Wine loader, MoltenVK, DXVK, vkd3d-proton, DXMT, MetalSharp, wineserver/MSync,
and CEF/renderer processes.

### Workstream 10 — Final acceptance lane acceptance and packaging

Produce:

```text
docs/validation/graphics-final/
  RESULTS.md
  capability.tsv
  architecture-matrix.tsv
  provider-hashes.sha256
  staging-manifest.tsv
  failure-boundaries.md
```

Update `docs/package-and-validation.md`, `AGENTS.md`, `README.md`, `docs/graphics.md`, and every
staging/build script. Replace stale acceptance lane references with acceptance lane.

Every architecture must have an explicit row for MoltenVK, D3D9, D3D10,
D3D11, D3D12, DXMT, OpenGL, and FEX/Java integration. Each row must be
`PASS`, `NOT_APPLICABLE` with a reason, `EXPLICIT_UNSUPPORTED` with a precise
fallback, or `FAIL` with retained diagnostics.

The final runtime gate must use the actual promoted Wine tree and the canonical
prepared prefix. No old provider or backup binary may be used to manufacture a
green result.

### Workstream completion discipline

At the end of each workstream:

1. build the custom source;
2. promote the resulting runtime into the actual Wine/build tree;
3. verify hashes and architecture headers;
4. stage only the required files into the canonical prefix;
5. run targeted and all-architecture contracts;
6. retain logs and capability tables;
7. update `docs/package-and-validation.md`, `AGENTS.md`, and relevant gap documentation;
8. commit only that workstream's changes.

No workstream is complete merely because a DLL loads or because a prefix can be
created. The completion criterion is reproducible behavior from the promoted
Acceptance lane runtime with FEX TSO disabled.
