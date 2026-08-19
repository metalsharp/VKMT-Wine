# VKMT Performance and Stability

This is the consolidated performance, candidate-optimization, memory-ordering,
MSync, and stability reference. Candidate changes remain subordinate to the
behavioral gates and are never promoted solely because a benchmark improves.

## Performance optimization record


Date: 2026-07-31

### Objective

Optimize the actual runtime rather than the MetalSharp backend: Wine startup
and process lifecycle, FEX x86_64/i386 translation throughput, cross-architecture
transitions, CPU overhead, GPU translation, pipeline compilation, and reusable
caches.

Backend changes are permitted only where they provide low-overhead measurement
or remove work that obscures runtime measurements. They are not the primary
optimization target.

All accepted configurations must keep these settings disabled:

- `FEX_TSOENABLED=0`
- `FEX_VECTORTSOENABLED=0`
- `FEX_MEMCPYSETTSOENABLED=0`

Correctness gates for ARM64, AArch64, ARM64EC, x86_64, and i386/WoW64 remain
mandatory. Do not trade away the accepted exception, memory, Java JIT,
graphics, Steam child-process, or exact-shutdown contracts for benchmark
numbers.

### Current measured and inspected baseline

- The accepted Steam WebHelper path renders in approximately 28 seconds.
- Steam's CEF GPU child currently forces `FEX_MAXINST=1` to preserve precise
  architectural state during synchronous exception delivery. Normal FEX uses
  multiblock translation and a substantially larger instruction ceiling. This
  is the highest-confidence translation bottleneck.
- A same-prefix x86_64 entry fixture measured approximately 0.88-0.92 seconds
  with a cold wineserver and approximately 0.03 seconds with the Wine session
  warm. The first observed cold run was 2.07 seconds while MoltenVK initialized
  and logged its complete capability surface.
- FEX contains code-map generation and reusable code-cache infrastructure, but
  the Windows/ARM64EC cache loader is explicitly disabled and the Windows image
  tracker still has unfinished cache load/register steps. Repeat Windows
  processes therefore do not yet receive the intended persistent translated
  ARM64 code reuse.
- The installed runtime contains 35,260 files totaling about 15.7 GB; 14,874
  files are smaller than 64 KiB. The Steam prefix contains 12,053 files.
  Startup can therefore be dominated by metadata and path lookup latency even
  when sequential storage bandwidth is high.
- Normal Steam launch currently performs wrapper readiness checks, a
  synchronous Wine `reg import`, MoltenVK readiness checks, and production
  graphics tracing. Two recent Steam traces contained 32,440 lines. These are
  supporting launch costs, not the central runtime optimization project.
- Some game routes copy and hash injected DLLs again at launch, and preset
  shader SQLite databases can be reopened and merged again on an unchanged
  launch.

### acceptance lane - Runtime measurement spine

Add one correlation identifier spanning the launch request, Wine, wineserver,
NTDLL, both FEX providers, graphics translation, and child processes. Record:

1. launch request received;
2. runtime readiness completed;
3. Wine process spawned;
4. wineserver connection established;
5. NTDLL process initialization entered/completed;
6. FEX context initialized;
7. first guest block translated or loaded from cache;
8. PE entry point reached;
9. first native/guest boundary transitions by class;
10. graphics device initialization;
11. shader conversion and pipeline-cache hit/miss;
12. first submission and first visible present;
13. Steam browser, renderer, GPU, and utility child lifecycle; and
14. process and exact-prefix teardown.

Benchmark four states independently:

- cold process and cold wineserver;
- warm macOS file cache with cold wineserver;
- persistent wineserver/session;
- persistent session plus warm FEX and graphics caches.

Use 20-30 runs and report median, p90, and p95. Capture CPU time, logical and
physical I/O, page faults, loaded image count, failed path probes, translated
blocks, cache hits, dispatcher exits, architecture transitions, shader compile
time, pipeline creation time, and first-frame latency. Use `os_signpost`,
Instruments File Activity, Time Profiler, System Trace, and M4 Processor Trace
where appropriate.

Gate: repeated benchmark sessions agree within 5% or explain the variance.

### acceptance lane - FEX precise-exception fast path

Replace the Steam GPU child's single-instruction block workaround without
weakening its correctness:

- Record a compact mapping from host JIT PC to exact guest RIP.
- Record where live guest registers reside at exception-capable instructions:
  host registers, spills, or constants.
- On a synchronous fault, reconstruct and publish the exact guest architectural
  state before Wine dispatches the exception.
- If full state maps are initially too expensive, split blocks or commit state
  only around instructions that can produce the relevant synchronous fault.
- Restore normal multiblock translation and a normal `MaxInst` after the
  original CEF regression passes.

Gate:

- the original CEF synchronous-access-violation regression passes;
- no stale guest register reaches Wine SEH;
- the GPU child uses normal multiblock translation;
- all no-TSO settings remain zero; and
- Steam first visible paint is below 10 seconds initially, with below 5
  seconds as the warm-path target.

### acceptance lane - Persistent FEX translated-code cache on Windows

Complete the existing FEX Windows code-cache contract:

1. bounds-check the complete cache file before reading headers, block lists,
   relocation records, code, or guest-page metadata;
2. allocate ARM64EC-compatible executable storage;
3. copy and relocate cached ARM64 code;
4. perform the required instruction-cache maintenance;
5. finalize executable protection;
6. register cached blocks and executable guest ranges with the lookup cache;
7. retain mapped-cache ownership for the complete process lifetime; and
8. integrate Wine's existing flush, protection, free/unmap, section-unmap,
   dirty-write, and self-modifying-code invalidation notifications.

The cache identity must include:

- complete PE content identity;
- FEX commit and cache-format version;
- Wine/FEX ABI generation;
- x86_64 versus i386 mode;
- effective host CPU features;
- `MaxInst`, multiblock, precise-exception, and dynamic-code modes; and
- all three no-TSO values.

Do not reuse a normal-image cache for Java/HotSpot or another dynamic-code
mode unless that mode's invalidation fixture explicitly passes. Generate or
refresh caches after successful runs, preferably outside the first-paint
critical path. Prioritize Steam, SteamUI, CEF/libcef, shared runtime DLLs, and
frequently launched game images.

Gate:

- more than 80% of eligible early guest blocks hit cache on repeat launch;
- repeat JIT generation time falls by at least 70%;
- cache corruption or mismatch safely falls back to live translation; and
- self-modifying code, Java JIT, exceptions, i386, graphics, and child-process
  gates pass.

### acceptance lane - Wine process, loader, and session overhead

- Profile NTDLL initialization, PE mapping, imports, ARM64X redirection,
  wineserver requests, Unix calls, DLL search misses, initial services, and
  teardown.
- Add a prefix-scoped, bounded warm-session policy using Wine's persistent
  server support. Never share one session between prefixes. Shut it down for
  migration, repair, provider replacement, or MSync mode changes.
- Determine why a trivial cold x86_64 fixture initializes MoltenVK and defer
  Vulkan/Metal initialization until a process actually imports the graphics
  route.
- Build a generation-aware resolved-DLL cache and negative lookup cache.
- Keep verified GStreamer and font registries; do not rescan the complete
  native dependency closure during ordinary launches.
- Prefer stable `@loader_path`/`@rpath` dependencies and narrow search paths
  over broad `DYLD_LIBRARY_PATH` plus `DYLD_FALLBACK_LIBRARY_PATH` lists.

Gate:

- warm trivial x86_64 and i386 execution below 75 ms p95;
- failed filesystem/path probes reduced by at least 50%;
- native ARM64 Wine and exact prefix shutdown remain correct; and
- no Homebrew, Rosetta, or undeclared host dependency appears.

### acceptance lane - Cross-architecture transition reduction

Instrument and classify transitions across:

- x86_64/i386 guest to FEX JIT;
- JIT to ARM64EC/ARM64X Wine code;
- ARM64EC to native ARM64 Unix libraries;
- syscalls and Unix calls;
- callbacks, APCs, exceptions, context get/set, and thread lifecycle; and
- graphics and media host bridges.

Then:

- eliminate duplicate guest/host pointer and context conversion;
- cache safe thunk and export resolution;
- batch boundary operations where Windows ordering permits;
- promote measured hot Wine builtin paths to ARM64X/ARM64EC rather than
  repeatedly emulating pure x86 implementations; and
- preserve explicit acquire/release or barrier behavior required by the
  no-TSO memory contract.

Gate: expensive boundary transitions per startup interval or representative
frame fall by 25-50% without changing observable Windows behavior.

### acceptance lane - CPU/JIT throughput and cache locality

Profile the FEX decoder, frontend, IR passes, emitter, dispatcher, lookup
cache, code invalidation, thread state, Wine syscall bridge, and ARM64EC
handoffs on real Steam and game workloads.

- Compare the accepted provider with clean `-O2`, `-O3`, ThinLTO, and PGO
  builds independently.
- Do not combine compiler changes until each result has a correctness and
  performance measurement.
- Improve lookup-cache and thread-state locality based on measured cache
  misses and false sharing.
- Reduce allocator churn and batch code-buffer growth/finalization.
- Avoid M4-only instructions in the general release unless explicit CPU slices
  and selection logic are introduced.

Gate: at least 15% lower guest CPU time after persistent-code-cache benefits
are excluded, with all architecture and Java gates passing.

### acceptance lane - GPU translation and pipeline cache

Measure DXVK, vkd3d-proton, DXMT, OpenGL-Metal, Winemetal, and MoltenVK
independently. Record:

- DXBC/DXIL/SPIR-V/MSL conversion;
- Vulkan pipeline-cache lookup and creation;
- Metal library and pipeline compilation;
- command queue and first submission; and
- first present plus subsequent frame-time stutter.

Create one versioned cache identity containing the translation-stack revisions,
source shader hash, root signature and pipeline descriptor, macOS build, Metal
compiler/language generation, and GPU family/device.

- Persist the Vulkan caches actually consumed by DXVK/vkd3d-proton/MoltenVK.
- Harvest and serialize Metal binary archives for DXMT, OpenGL-Metal, and
  MoltenVK-compatible paths.
- Load compatible archives before pipeline creation.
- Compile missing pipelines asynchronously when correctness and title behavior
  allow it.
- Keep per-game caches isolated while permitting separately versioned shared
  presentation/UI archives.

Gate:

- warm pipeline-cache hit rate above 90%;
- warm pipeline creation below 100 ms p95 for deterministic fixtures;
- first-frame latency reduced by at least 50%; and
- incompatible cache identities always fall back safely.

### acceptance lane - Executable memory and cache maintenance

Status: completed 2026-08-01. The WoW64 instruction-cache flush boundary no
longer repeats the same guest-range invalidation through both the common
tracker and a second host-to-guest path. Correlated baseline/candidate traces
prove a 50.00% reduction in flush invalidation passes. The trace-only metrics
cover flush ranges, general invalidation passes/bytes, thread lookup eviction,
RWX write faults, and protection calls; their atomic accounting is disabled
outside an active VKMT performance trace.

Measure JIT code-buffer allocation, RW/RX transitions, instruction-cache
maintenance, invalidation ranges, lookup eviction, page faults, and
self-modifying-code behavior.

- Batch executable-page finalization and instruction-cache maintenance where
  visibility and exception semantics allow.
- Prefer page-granular invalidation over complete-cache eviction.
- Keep W^X and current macOS executable-memory correctness.
- Never use TSO as a shortcut.

Gate: protection/cache-maintenance operations during startup fall by at least
50%, while the i386 SMC, Java JIT, exception, and cross-process fixtures pass.

### acceptance lane - Runtime hot-set and storage support

Status: completed 2026-08-01. A native ARM64 sampler records the file-backed
resident mappings and short-lived open files of Wine plus its descendant
processes during the first five seconds. The resulting relocatable manifest is
identity-checked, capped at 256 MiB, and consumed through asynchronous
`F_RDADVISE`/`F_RDAHEAD`. Requests are prefix-scoped, serialized, rate-limited,
toggleable, and fall back to ordinary demand paging when an entry changes.
No duplicate runtime archive or RAM copy is retained; macOS remains the LRU
owner of the advised clean pages.

Storage is supporting work, not the primary optimization target. Trace the
actual PE, Mach-O, registry, font, media, shader, and cache pages consumed in
the first five seconds.

- Build a per-title hot-set manifest.
- Test `F_RDADVISE`, `F_RDAHEAD`, or controlled mmap prefetch only for files
  demonstrated to be on the critical path.
- Keep the immutable runtime layout valid; do not concatenate executable
  images into an unusable archive or copy the full runtime into RAM.
- Apply explicit cache quotas and LRU eviction.
- Measure metadata latency, physical read stalls, and page faults instead of
  advertised sequential bandwidth.

Gate: genuinely cold physical read stall time falls by at least 25%, with no
warm-cache regression.

### Supporting launch cleanup

These are useful but subordinate to Wine/FEX/GPU work:

- production Steam uses `WINEDEBUG=-all`; diagnostic graphics tracing is
  opt-in;
- seed the Steam D3D12 registry guard during prefix preparation/migration and
  store a versioned receipt;
- verify wrapper and deployed DLL hashes only when metadata or runtime
  generation changes;
- merge preset shader databases only when the preset/runtime identity changes;
- create verbose runtime logs only for explicit diagnostics; and
- fix MoltenVK readiness detection to use the canonical bundled paths.

### Required execution order

1. acceptance lane measurement spine.
2. acceptance lane precise exception reconstruction and removal of `MAXINST=1`.
3. acceptance lane persistent FEX translated-code cache.
4. acceptance lane Wine loader/session work.
5. acceptance lane cross-architecture transition reduction.
6. acceptance lane CPU/JIT profiling and optimization.
7. acceptance lane GPU translation and pipeline archives.
8. acceptance lane executable-memory/cache-maintenance improvements.
9. acceptance lane measured hot-set support.

Supporting launch cleanup may accompany acceptance lane, but it must not displace or be
reported as the core optimization project.

### Final performance acceptance

- All existing ARM64, AArch64, ARM64EC, x86_64, and i386/WoW64 correctness
  gates pass in the accepted single-prefix configuration.
- Every FEX TSO setting remains zero.
- Warm Steam first visible paint targets below 5-10 seconds from the current
  approximately 28-second accepted baseline.
- Warm trivial guest process entry is below 75 ms p95.
- Repeat eligible JIT work falls by at least 70%.
- Warm graphics pipeline-cache hit rate exceeds 90%, with at least 50% lower
  first-frame latency in deterministic graphics fixtures.
- No Rosetta process or x86 Mach-O host dependency participates.

## Candidate optimization policy and ledger


VKMT now has a pinned, out-of-tree integration point for
[`sebyx07/c-ai-optimizer`](https://github.com/sebyx07/c-ai-optimizer).

The execution plan and complete 82-file ledger are maintained separately in
`docs/performance.md` and `docs/OPTIMIZATION_LEDGER.tsv`.
The current acceptance lane all-architecture baseline is retained in
`docs/validation/optimization-baseline-20260803/`.

### Pin and commands

The optimizer is pinned to:

```text
c6f96df0ec9973a4cbdb7b015b1fd106c815ad89
```

The checkout is intentionally under the ignored `third_party/` tree. Use:

```sh
scripts/vkmt-c-ai-optimizer.sh setup
scripts/vkmt-c-ai-optimizer.sh inventory
scripts/vkmt-c-ai-optimizer.sh smoke
scripts/vkmt-c-ai-optimizer.sh prepare
scripts/vkmt-c-ai-optimizer.sh inventory-all
scripts/vkmt-c-ai-optimizer.sh prepare-all
scripts/vkmt-c-ai-optimizer.sh disposition
scripts/vkmt-c-ai-optimizer.sh verify
```

`prepare` creates a timestamped, immutable candidate workspace under
`build/c-ai-optimizer-candidates/`. It copies the high-priority custom Wine
inputs and records their SHA-256 values. It never writes to
`wine/wine-11.12`.

`inventory-all` and `prepare-all` operate on the complete 82-file ledger,
including files marked manual-review or generated/no-rewrite. Preparing a
file is not permission to transform or promote it.

`disposition` validates that every ledger row marked `candidate` has exactly
one row in `docs/OPTIMIZATION_DISPOSITION.tsv`. Boundary/triage rows are
required to carry an evidence reference and a next action; they are not
treated as optimization wins.

### Why this is candidate-only

The upstream project is a proof of concept built around isolated numeric C
functions. Its default CMake configuration requires OpenMP and unconditionally
adds `-march=native -mavx -ffast-math`. That is unsuitable for VKMT's native
Apple ARM64 host, ARM64EC/x86_64 guest paths, i386/WoW64, exception handlers,
loader locks, signal frames, and FEX dispatcher ABI. The VKMT smoke command
therefore omits x86 AVX flags on ARM64 and validates the optimizer's scalar
plus OpenMP fallback only.

The manifest marks ABI-sensitive files `manual-only`. They may be profiled,
but no whole-file candidate rewrite or OpenMP insertion is allowed. Candidates are
limited to isolated leaf helpers after profiling proves that the function is
hot and that its memory ordering, aliasing, exception, and reentrancy behavior
are irrelevant to the contract.

### Promotion contract

No candidate may replace a Wine source file until it has:

1. a before/after benchmark from a VKMT workload, not the optimizer demo;
2. identical focused behavior on ARM64, ARM64EC, x86_64, and i386 where the
   file participates in that architecture;
3. no ABI, SEH, lock-order, callback, FEX invalidation, or MSync regression;
4. a source hash and reproducible candidate record; and
5. a measurable win that survives the acceptance lane smoke, WoW64 VM, CEF x64, and MSync
   gates.

The optimizer's own benchmark claims are not VKMT evidence. Current setup
evidence is retained in
`docs/validation/optimizer-setup-20260803/RESULTS.md`.

The first file-level loader candidate was evaluated against paired control
measurements and rejected as `PROFILED_NO_PROMOTION`; its receipt is
`docs/validation/optimization-candidate-loader-20260803/RESULTS.md`.
The installed Wine tree was restored to the pre-candidate source after the
measurement.

The first accepted narrow helper is
`dlls/ntdll/unix/file.c::buffer_contains()`. Its `memchr()` candidate passed
250,000 exact-equivalence cases, repeated helper benchmarks, an actual ARM64
NTDLL build, and the prepared acceptance lane four-architecture gate before promotion in
nested commit `07df604e8f4e2f475bdd9983905cf98802905ee7`. The complete receipt
is `docs/validation/optimization-file-scan-20260803/RESULTS.md`.
The remaining 12 candidate rows are explicitly reviewed as either
`PROFILED_NO_SAFE_CANDIDATE` or protected boundary code in
`docs/validation/optimization-candidate-review-20260803/RESULTS.md`.

## Candidate optimization execution record


Status: Workstreams 0 and 1, the WoW64/MSync functional promotion gate, the Workstream 2
and Workstream 4 candidate passes, and the current safe-candidate review are
complete. One pure helper was promoted, two candidates were rejected, four
were profiled with no safe pure leaf, and eight remain protected by ABI,
pointer, lock, TLS, ordering, or FEX boundaries. A future workload may reopen
one of those rows; no unsafe rewrite is pending in this pass.
This document does not authorize source changes by itself. The current
c-ai-optimizer integration is a candidate pipeline. One narrowly scoped pure
helper has now been promoted after paired source, equivalence, build, and acceptance lane
validation; no broad candidate-generated rewrite has been promoted.

### Scope and operating rules

The corpus currently contains 82 custom C paths relative to the Wine 11.12
release baseline: 80 committed custom paths plus two additional current
worktree paths. There are no custom C++ paths. Optimization is function-level,
not whole-file rewriting.

- Use the existing canonical prefix:
  build/probe-runs/phase-a-graphics-prefix.
- Do not create disposable prefixes or run routine wineboot.
- Use the current acceptance lane providers and acceptance lane acceptance gates; acceptance lane is supporting
  smoke evidence only.
- Keep FEX_TSOENABLED, FEX_VECTORTSOENABLED, and FEX_MEMCPYSETTSOENABLED set
  to 0.
- Preserve ABI, SEH/unwind behavior, callback order, lock order, signal-frame
  layout, guest-pointer conversion, FEX invalidation, and server
  linearization points.
- Never use -march=native or ARM64-incompatible AVX flags for the native build.
  Do not use -ffast-math for Win32-semantic code or introduce OpenMP into
  Wine runtime, lock, signal, loader, or callback paths.
- candidate output is a candidate until it has reproducible source hashes,
  architecture builds, functional tests, and workload measurements.
- Optimize only VKMT-owned changes or an explicitly identified hot helper; do
  not rewrite untouched upstream Wine merely because it is in a custom file.
- Record accepted changes and their evidence in docs/package-and-validation.md; never package
  candidate binaries, caches, prefixes, or diagnostic logs.

### Workstream 0 — Freeze and establish the baseline

Before generating candidates:

1. Record the nested Wine commit, Wine release base, FEX revision, acceptance lane provider
   hashes, compiler/toolchain versions, build flags, and canonical prefix
   receipt.
2. Preserve and hash the current dirty functional work in WoW64 VM, MSync,
   ARM64 signal handling, WoW64 USER, FreeType, and Winsock. Do not optimize
   those changes and unrelated candidate changes in the same patch.
3. Run the existing baseline on ARM64, ARM64EC, x86_64, and i386/WoW64.
4. Retain baseline results for acceptance lane hotset, WoW64 VM, FEX mapping/invalidation,
   MSync, DXMT, CEF x64 OSR, Electron x64, and process loading.
5. Record median and p95 timing over repeated runs; return code alone is not a
   performance baseline.

Known CEF i386 limitations remain an explicit diagnostic boundary. They must
not be converted into a false green result while optimizing x64 or WoW64.

Exit: the current source and its known failures are reproducible before any
candidate is evaluated.

### Workstream 1 — Build the function-level ledger

For each of the 82 paths below, identify the custom hunks and functions,
callers, architecture reachability, hotness, and semantic risks. Each function
gets one initial status:

- candidate — an isolated pure helper may receive an out-of-tree candidate;
- manual-review — candidates may suggest but not directly rewrite or promote;
- protected — ABI, synchronization, signal, JIT, or callback boundary;
- generated/no-rewrite — generated thunk or build/bootstrap code;
- not-hot/no-candidate — profiled without forcing an optimization.

The ledger must include a baseline hash, candidate hash, compiler flags,
benchmark workload, affected architectures, test receipts, and rejection
reason where applicable.

The current candidate-path disposition matrix is
`docs/OPTIMIZATION_DISPOSITION.tsv`. `PROFILED_NO_SAFE_CANDIDATE` and
`CANDIDATE_BLOCKED_*` are explicit review outcomes, not performance wins. A
new matching workload may reopen them, but they do not authorize a rewrite.

### Workstream 2 — NTDLL, loader, exceptions, and host boundaries

These are the highest-priority functional files, but they are protected from
blind candidate rewriting:

- dlls/ntdll/exception.c
- dlls/ntdll/loader.c
- dlls/ntdll/process.c
- dlls/ntdll/signal_arm64.c
- dlls/ntdll/signal_arm64ec.c
- dlls/ntdll/sync.c
- dlls/ntdll/thread.c
- dlls/ntdll/unix/loader.c
- dlls/ntdll/unix/msync.c
- dlls/ntdll/unix/process.c
- dlls/ntdll/unix/signal_arm64.c
- dlls/ntdll/unix/sync.c
- dlls/ntdll/unix/thread.c
- dlls/ntdll/unix/virtual.c

Profile loader startup, DLL resolution, process creation, exception return,
signal transitions, host/guest calls, synchronization, MSync, and VM calls.
Only a demonstrably pure leaf helper may become a candidate. No candidate may
change SEH state, unwind metadata, loader locks, stack layout, signal frames,
callback reentrancy, TEB/emulator state, or host transition ordering.

First eligible candidate pass:

- dlls/ntdll/heap.c
- dlls/ntdll/unix/env.c
- dlls/ntdll/unix/file.c
- dlls/ntdll/unix/socket.c
- dlls/ntdll/unix/system.c

The initial candidate scope is limited to pure size, lookup, parsing,
normalization, address-conversion, or calculation helpers. Heap ownership,
allocation, synchronization, signal, and process lifecycle code remains
manual until separately proven.

#### Workstream 2 candidate pass B — opt-in Steam marker scan

The pure `buffer_contains()` helper in `dlls/ntdll/unix/file.c` was changed
from a byte-by-byte full scan to a `memchr()` first-byte search followed by
the same exact `memcmp()` confirmation. The scan is only reached when
`VKMT_STEAM_HANDOFF_NOTIFY=1`; the notification socket, atomic state machine,
read completion ordering, and TSO-disabled behavior were not changed.

`scripts/probe-ai-ntdll-file-scan.sh` ran 250,000 deterministic equivalence
cases and nine repeated benchmark cells. For 4 KiB and 64 KiB absent/end
markers, the candidate was approximately 23x and 30x faster; for 1 MiB it
was approximately 33x faster. The marker-at-offset-zero cells are below the
clock resolution and are not presented as a speed claim. The actual ARM64
`ntdll.so` built successfully, the prepared-prefix acceptance lane gate passed ARM64,
ARM64EC, x86_64, and i386/WoW64, and the change was promoted in nested Wine
commit `07df604e8f4e2f475bdd9983905cf98802905ee7`.

Receipt: `docs/validation/optimization-file-scan-20260803/RESULTS.md`.

The remaining candidate-row review is retained at
`docs/validation/optimization-candidate-review-20260803/RESULTS.md`. It
records four no-safe-candidate rows and eight protected/boundary rows; those
rows are not performance wins and do not authorize unsafe rewrites.

#### Workstream 2 candidate pass A — heap free-list index

`get_free_list_index()` in `dlls/ntdll/heap.c` received one out-of-tree
candidate that replaces the generic bit-scan wrapper with a native compiler
`clz` intrinsic while preserving the zero case and all bin arithmetic. The
candidate was built with the actual ARM64 Wine flags. Its `ntdll.so` was
byte-identical to control (`e1959129...`), so it was recorded as
`PROFILED_NO_PROMOTION` rather than being staged or benchmarked as a claimed
speedup. The source and installed runtime were restored to their original
hashes, and the canonical-prefix acceptance lane prepared-prefix gate passed all four
architectures with status 0.

Receipt: `docs/validation/optimization-heap-index-20260803/RESULTS.md`.
This is a valid rejection. The other Workstream 2 candidate rows are dispositioned
by the safe-candidate review rather than forced through an unsafe transform.

### Workstream 3 — WoW64 virtual memory correctness, then optimization

Protected files:

- dlls/wow64/file.c
- dlls/wow64/memory.c
- dlls/wow64/process.c
- dlls/wow64/security.c
- dlls/wow64/sync.c
- dlls/wow64/syscall.c
- dlls/wow64/system.c
- dlls/wow64/virtual.c
- dlls/wow64win/gdi.c
- dlls/wow64win/user.c

First prove the VM contract for x64 and i386/WoW64:

- reserve, commit, decommit, recommit, release, and address reuse;
- protection changes, partial unmaps, overlapping views, and file mappings;
- high host-address translation and guest-aperture pressure;
- concurrent map/protect/unmap pressure;
- Chromium/Electron reservation and decommit patterns;
- FEX generated-code mappings and invalidation.

Only after that contract is green may candidates be considered for pure page
lookup, interval arithmetic, generation comparison, protection lookup, or
non-mutating translation. Candidates may not add allocation in sensitive
callbacks or change transactional publication, rollback, stale-map handling,
guest/host ownership, or FEX invalidation.

Exit: no stale mapping, protection, address-reuse, or corruption evidence on
either guest architecture.

### Workstream 4 — FEX and x86_64/i386 emulation

Files:

- dlls/xtajit64/cpu.c
- dlls/xtajit64/vkmt/context.c
- dlls/xtajit64/vkmt/dispatch.c
- dlls/xtajit64/vkmt/interp.c
- dlls/xtajit64/vkmt/jit.c

Initial treatment:

- cpu.c: candidate-only for measured pure backend helpers;
- interp.c: candidate-only for isolated instruction/flag helpers;
- context.c, dispatch.c, and jit.c: protected.

Test x86_64 and i386 guests for generated-code maps, invalidation,
protection, allocation reuse, exceptions, signal return, and nested process
loading. Do not alter dispatcher loops, executable-memory publication, JIT
code generation, context save/restore, or invalidation ordering.

#### Workstream 4 candidate pass A — interpreter width-mask helper

The pure `sz_mask()` helper in `dlls/xtajit64/vkmt/interp.c` was evaluated
out-of-tree with a constant mask table. Five direct x86_64 launches for the
candidate and matched control were all `rc=0` with the expected guest marker,
but the candidate median was 1.54% slower. The strict acceptance lane wrapper also exposed
the current provider lifecycle-telemetry gap and was not treated as a green
performance result. The candidate was rejected, the canonical acceptance lane provider was
restored, and the prepared-prefix acceptance lane gate passed all four architectures.

Receipt: `docs/validation/optimization-fex-mask-20260803/RESULTS.md`.
This pass does not authorize changes to FEX dispatch, JIT, context, mapping,
invalidation, or executable-memory paths.

### Workstream 5 — Graphics, Metal, Vulkan, OpenGL, and CEF

Protected host-boundary files:

- dlls/opengl32/unix_thunks.c
- dlls/opengl32/unix_wgl.c
- dlls/opengl32/wgl.c
- dlls/user32/button.c
- dlls/win32u/class.c
- dlls/win32u/driver.c
- dlls/win32u/gdiobj.c
- dlls/win32u/hook.c
- dlls/win32u/message.c
- dlls/win32u/opengl.c
- dlls/win32u/vulkan.c
- dlls/win32u/window.c
- dlls/win32u/winstation.c
- dlls/winecoreaudio.drv/coreaudio.c
- dlls/winemac.drv/macdrv_main.c
- dlls/winemac.drv/opengl.c
- dlls/winemac.drv/window.c
- dlls/winevulkan/loader_thunks.c
- dlls/winevulkan/loader.c
- dlls/winevulkan/vulkan_thunks.c
- dlls/winevulkan/vulkan.c

Potential narrow candidates:

- dlls/dwrite/freetype.c
- dlls/win32u/freetype.c
- dlls/win32u/sysparams.c

Only pure text/geometry conversion, cache-key, immutable lookup, pixel, or
format-conversion helpers are eligible. Driver loading, host callbacks,
window/message dispatch, Vulkan/OpenGL procedure translation, presentation,
audio callbacks, and Metal transitions remain manual.

Required gates are DXMT, Vulkan/OpenGL/Metal paths, CEF x64 OSR startup and
deterministic pixel output, and clean shutdown. CEF i386 remains separately
reported rather than used to falsify the accepted x64 gate.

### Workstream 6 — Networking, system, and runtime helpers

Potential candidate files, limited to pure helpers:

- dlls/msvcrt/locale.c
- dlls/winhttp/net.c
- dlls/ws2_32/protocol.c
- dlls/ws2_32/socket.c
- dlls/ws2_32/unixlib.c

The following remain manual-review until profiling identifies a safe leaf:

- dlls/crypt32/unixlib.c
- dlls/kernel32/process.c
- dlls/kernel32/sync.c
- dlls/kernelbase/process.c
- dlls/kernelbase/sync.c
- dlls/mscoree/mscoree_main.c
- dlls/msvcrt/main.c
- dlls/msvcrt/thread.c
- dlls/ntoskrnl.exe/instr.c
- dlls/secur32/schannel_gnutls.c

Crypto, TLS, synchronization, process startup, and instruction emulation must
not receive unsafe math, OpenMP, or opaque whole-file rewrites.

The existing x64 address-list sort contract now has a prepared-prefix path:
`scripts/probe-x64-address-list-sort.sh --prefix PATH`. Its canonical acceptance lane
receipt is `docs/validation/address-list-sort-final-canonical-20260803/`; the
probe reuses the prefix, verifies it first, and does not run Wineboot or stage
providers in prepared mode.

### Workstream 7 — Server-side synchronization and mapping

Files:

- server/inproc_sync.c
- server/main.c
- server/mapping.c
- server/msync.c
- server/thread.c

Prove MSync waiter registration, pulse tokens, manual/auto-reset pulse
behavior, WaitAll rollback, abandoned mutex ownership, cancellation, and
cross-process ordering first. Server linearization points and lock-held code
remain human-reviewed. Only pure non-mutating helpers may later become
candidates.

### Workstream 8 — Bootstrap and tooling

Files:

- libs/winecrt0/arm64ec.c
- programs/wineboot/wineboot.c
- tools/makedep.c
- tools/wine/wine.c

These are lower priority. Profile them only for a specific startup or build
time objective. Do not optimize wineboot merely to make test setup faster;
the product runtime and prepared-prefix work are separate concerns.

### Workstream 9 — Candidate generation and promotion loop

For each candidate function:

1. Copy the exact source hash into the ignored candidate workspace.
2. Generate one function-level candidate.
3. Compile with actual Wine target flags for every affected architecture.
4. Run focused tests, property tests, ASan/UBSan where supported, and TSan
   where the function is not signal/lock-sensitive.
5. Run the relevant integration gates and compare repeated medians and p95.
6. Reject candidates with any functional, ABI, sanitizer, architecture, or
   known performance regression.
7. Require a repeatable targeted improvement. The proposed default is at least
   5% on the targeted workload with no more than 1% regression elsewhere,
   unless a latency-critical path has an explicitly recorded alternative
   threshold.
8. Promote one small change in one nested Wine commit.
9. Record source hash, optimizer commit, flags, evidence, and result in the
   ledger and docs/package-and-validation.md.

If profiling finds no safe or meaningful candidate, record
PROFILED_NO_SAFE_CANDIDATE. Every file must be reviewed, but every file does
not need to change.

### Workstream 10 — Final acceptance and packaging

The optimized corpus must pass the applicable acceptance lane gates on ARM64, ARM64EC,
x86_64, and i386/WoW64, including:

- process loading, loader, exceptions, and teardown;
- WoW64 VM contract;
- FEX generated-code and invalidation tests;
- MSync;
- DXMT and graphics rendering;
- CEF x64 OSR;
- browser and process-loading fixtures;
- acceptance lane hotset/performance evidence.

Final records must include:

- function-level candidate ledger;
- accepted and rejected candidate history;
- source and optimizer hashes;
- reproducible build commands;
- before/after benchmark receipts;
- architecture gate receipts;
- updated docs/package-and-validation.md;
- nested Wine commits for accepted source changes.

No candidate binary, cache, disposable prefix, or diagnostic log is a package
asset.

### Proposed execution order

1. Workstream 0 baseline and source freeze.
2. Workstream 1 function ledger for all 82 files.
3. dlls/ntdll/heap.c and pure dlls/ntdll/unix/* helpers.
4. WoW64 VM proof, without candidate changes until the contract is green.
5. dlls/xtajit64/cpu.c and isolated interp.c helpers.
6. CEF/graphics boundary profiling and narrow conversion candidates.
7. Networking, locale, and other supporting helpers.
8. Final acceptance lane cross-architecture promotion and inventory update.

## No-TSO ordering and Rosetta parity


### Goal

Match Rosetta's observable download, synchronization, and child-process
reliability while keeping:

```text
FEX_TSOENABLED=0
FEX_VECTORTSOENABLED=0
FEX_MEMCPYSETTSOENABLED=0
```

No Rosetta process or x86 Mach-O host component may participate. Rosetta is a
behavioral reference only; it is not acceptance evidence for the final stack.

### Workstream 0 — Freeze and instrument the current stack

- Preserve current Wine/FEX source and runtime hashes.
- Record Steam-specific wake and handoff changes separately from generic
  synchronization changes.
- Add bounded counters for:
  - WaitOnAddress registrations.
  - Wake-before-wait events.
  - Delivered and retained wakes.
  - Timeouts and synthetic Steam wakes.
  - i386/x86_64 process creation and provider attachment.
- Assert all three FEX TSO settings at process startup.
- Keep logs and disposable state on the external SSD.

Gate:

- Native ARM64 Wine starts normally.
- i386 and x86_64 probes load.
- Instrumentation remains silent unless explicitly enabled.
- No full Wine rebuild.

### Workstream 1 — Reproduce Rosetta's tests through FEX

Status: **complete**. Accepted evidence is
`docs/validation/no-tso-ordering-20260731T024459Z/RESULTS.md`.

Port the direct Rosetta tests into Windows PE fixtures for i386 and x86_64:

- One million release/acquire publications.
- WaitOnAddress wake-before-wait.
- Wake while waiter registration is in progress.
- WakeSingle and WakeAll with multiple waiters.
- Repeated timeout versus real-wake races.
- Condition-variable and critical-section ping-pong.
- APC arrival during waits.
- Second-thread and repeated-thread lifecycle.
- 128 concurrent child processes.
- Eight concurrent HTTPS range downloads from the exact Steam CDN package.

Gate:

- Zero stale reads, lost wakes, or stranded threads.
- 128/128 child completions.
- Eight identical downloaded payload hashes.
- Both i386 and x86_64 pass with TSO disabled.

### Workstream 2 — Implement the software x86 memory model in FEX

Status: **complete**. Accepted evidence is
`docs/validation/no-tso-memory-v15-20260731T034214Z/RESULTS.md`.

review generated ARM64 for:

- Ordinary x86 loads and stores.
- Locked instructions and interlocked operations.
- Compare/exchange loops and memory fences.
- Self-modifying code publication and code-cache invalidation.
- Guest-to-native and native-to-guest transitions.

Implement a dedicated non-TSO correctness mode:

- Use acquire/release operations where they provide the required edge.
- Use explicit `DMB ISHLD`/`DMB SY` ordering for loads, stores, and x86
  Store-to-Load ordering; LDAR/STLR alone do not fully provide that guarantee.
- Use LSE atomics or LDAXR/STLXR loops for locked operations.
- Place transition barriers at Wine Unix-call, syscall, callback, APC, and
  exception boundaries.
- Make guest writes visible before waking another thread.
- Require an acquire operation after a waiter observes a wake.

Gate:

- Dumped ARM64 shows the intended LDAR/STLR/LSE/DMB sequences.
- Workstream 1 ordering and synchronization tests pass with every TSO option off.
- The fixtures require no Steam-specific wake injection.

### Workstream 3 — Replace Wine's lossy WoW64 wait bridge

Status: **complete**. Accepted evidence is
`docs/validation/no-tso-wait-20260731T034855Z/RESULTS.md`.

- Detect WoW64 at runtime with `WowTebOffset`, never host compile-time
  `__i386__`.
- Replace raw thread-alert delivery with persistent synchronization state.
- Make wake-before-wait survive registration races.
- Eliminate the fixed raw-pointer pending-wake cache. Wakes without registered
  waiters are not retained, so allocation-generation ambiguity cannot arise.
- Prevent pointer reuse from consuming an old wake.
- Prevent event closure while a waker still owns a reference.
- Preserve legal Windows spurious wakes without manufacturing success for
  unrelated waits.
- Cover WakeSingle, WakeAll, timeout, process exit, APC, and exception
  interruption.

Gate:

- Every Workstream 1 wait/wake race passes repeatedly.
- No pending-wake overflow or address-reuse failure occurs.
- Steam's synthetic RtlWaitOnAddress recovery can be disabled.

### Workstream 4 — Fix asynchronous networking

Status: **complete**. Accepted evidence is
`docs/validation/no-tso-network-v5-20260731T040055Z/RESULTS.md`.

Run the exact Steam CDN fixture through Windows APIs:

- WS2_32 connection and TLS traffic.
- Multiple simultaneous package requests.
- Partial reads and completion callbacks.
- Connection reuse and HTTP range restart.
- Server close during a pending receive.
- IOCP/threadpool completion.
- Worker shutdown while callbacks are outstanding.

Trace only these transitions:

```text
request submitted
socket readable
bytes received
completion queued
completion consumed
package committed
```

Gate:

- No HTTP 200 response completes with zero bytes.
- No package is reported missing after reaching its expected byte count.
- Eight concurrent i386 and x86_64 transfers match native/Rosetta hashes.
- No wake injection occurs while traffic is actively progressing.

### Workstream 5 — Match Rosetta's child-process contract

Status: child-process/provider mechanics accepted on 2026-07-31. Evidence:
`docs/validation/no-tso-process-v8-20260731T041911Z/RESULTS.md`.

The accepted fresh-prefix fixture proves the i386-to-x86_64 provider handoff,
inherited environment/CWD/standard handles/events/raw kernel handles, and exact
wait/exit behavior. Exact SteamService plus i386/x86_64 Steam client probes
pass. Raw inherited socket handles follow Windows semantics: they remain valid
kernel handles but require `WSADuplicateSocket`/`WSASocket` before Winsock use.
No `ws2_32` compatibility deviation was retained.

Validate the full Steam architecture chain:

```text
SteamSetup.exe (i386)
  -> steam.exe bootstrapper
  -> SteamService.exe
  -> x86_64 Steam update
  -> final Steam.exe
  -> steamwebhelper.exe
```

For every child:

- Attach the correct FEX provider before its first guest instruction.
- Preserve inherited handles, environment, current directory, sockets, and
  standard handles.
- Stage i386 and x86_64 modules from the same prefix.
- Preserve process-exit and wait semantics.
- Prevent fallback to Rosetta.
- Keep the native host side ARM64.

Gate:

- 128/128 generic CreateProcess fixtures pass.
- SteamService loads and exits correctly.
- i386-to-x86_64 updater transition occurs in one prefix.
- Final Steam and WebHelper children start without manual intervention.

The last two application-specific transition bullets are exercised by Workstream 6
with the real Steam parent. `steamwebhelper.exe` cannot validly be sustained as
a fabricated standalone child because Steam supplies its Chromium IPC and
window-handle command line.

### Workstream 6 — Clean Steam acceptance run

Use a fresh Steam installation in the existing all-architecture prefix.

Gate ladder:

1. Installer UI completes.
2. First download reaches the exact expected byte count.
3. Extraction completes.
4. Installation completes.
5. `Update complete, launching Steam` appears.
6. The updater exits naturally.
7. The next Steam process starts automatically.
8. The x64 follow-on update completes.
9. SteamUI.dll and both steamclient DLLs exist and load.
10. Steam WebHelper starts.
11. The login UI paints and remains responsive.

Rules:

- A log observer may report progress but must not influence execution.
- Synthetic Steam wakes and external forced-relaunch supervisors do not count
  as success.
- Failed attempts remove only exact Steam state and temporary logs before the
  next run.

### Workstream 7 — Remove compatibility scaffolding

- Disable or remove the Steam-specific synthetic wake path.
- Remove the forced updater-relaunch workaround.
- Retain the generic FEX memory-ordering and Wine wait/wake corrections.
- Run ARM64, ARM64EC, x86_64, and i386 single-prefix gates.
- Run Java, CEF, Vulkan, DXMT, OpenGL, SDL, and controller regressions.

Final review:

- Every host Mach-O executable and Unix bridge is ARM64.
- `vmmap` shows no Rosetta runtime mapping.
- No translated macOS process exists.
- All three FEX TSO options are confirmed disabled.
- Generated ARM64 contains the required acquire/release and barrier operations.
- Commit accepted Wine/FEX changes and update `AGENTS.md`.
- Produce a new `.tar.zst` recovery archive.

### Immediate next action

Begin Workstream 6 with a clean all-architecture Steam prefix. Run SteamSetup and
observe—without influencing—the download, extraction, install, natural updater
exit, i386-to-x86_64 client transition, real Steam-parent WebHelper launch, and
responsive login UI. Keep all TSO options and synthetic wake/relaunch recovery
disabled.

## macOS MSync backend


VKMT Wine includes the Mach-semaphore MSync backend used by current
CodeWeavers Wine. The implementation was ported from the CrossOver 26.3.0
FOSS Wine 11.0 source bundle to this Wine 11.12 tree, then adapted to Wine
11.12's current in-process synchronization interfaces.

Source provenance:

- Upstream bundle: `crossover-sources-26.3.0.tar.gz`
- Download page: <https://www.codeweavers.com/crossover/source>
- Bundle SHA-256:
  `ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872`
- Preserved reference tree: `third_party/crossover-wine-26.3.0`
- Historical MSync reference: `third_party/wine-msync`

### Toggle

MSync is off by default. Enable it for every process using a prefix:

```sh
WINEMSYNC=1 wine program.exe
```

Explicitly disable it with `WINEMSYNC=0`, or leave `WINEMSYNC` unset. The
optional `WINEMSYNC_QLIMIT` variable changes the Mach message-port queue limit;
the default is 50.

The toggle is a wineserver-lifetime property. Do not mix enabled and disabled
clients under one running prefix server. Stop that exact prefix's server before
changing modes:

```sh
WINEPREFIX=/path/to/prefix wineserver -k
WINEPREFIX=/path/to/prefix wineserver -w
```

The client deliberately rejects a mismatched mode instead of silently using a
different synchronization contract.

### Focused rebuild

Only the server and ntdll Unix library are affected:

```sh
make -C wine/build-ec -j8 server/wineserver
make -C wine/build-ec -j8 dlls/ntdll/ntdll.so
```

If `server/protocol.def` changes, regenerate the checked-in protocol files
first:

```sh
(cd wine/wine-11.12 && ./tools/make_requests)
```

### Acceptance

Run:

```sh
scripts/probe-msync.sh
```

The probe uses one fresh native ARM64 prefix and exact wineserver restarts to
prove unset, explicit-off, and enabled modes. It covers manual and auto-reset
events, semaphore counts and limits, recursive and abandoned mutexes,
wait-all, signal-and-wait, alertable APC delivery, a second thread, and a
named event shared with a child process.

The broader architecture regression also passes with MSync enabled:

```sh
WINEMSYNC=1 scripts/probe-p8-single-prefix-architectures.sh
```

That gate proves ARM64, ARM64EC, x86_64, and i386/WoW64 execution in one fresh
prefix while every host executable and Unix library remains ARM64.
