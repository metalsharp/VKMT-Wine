# VKMT Graphics and Translation

This is the consolidated graphics reference for D3D9–D3D12, DXVK, DXMT,
MoltenVK, vkd3d-proton, OpenGL, SDL, and transform-feedback behavior.

## D3D12 on Metal architecture


### Goal

Run Direct3D 12 titles on macOS by combining:

```
D3D12 API calls ──► vkd3d-proton (D3D12 → Vulkan)
                  ──► MoltenVK (Vulkan → Metal)
                  ──► Metal driver
```

This is the same proven pipeline as Apple Game Porting Toolkit's D3DMetal and
CodeWeavers CrossOver. VKMT's differentiator: upstream, open, and focused on
closing the MoltenVK gaps that vkd3d-proton requires — "guaranteeing" the
translation instead of hoping the Vulkan subset lines up.

### What we have

- `third_party/vkd3d-proton` — D3D12-on-Vulkan translation layer (D3D12 API,
  DXGI bits it owns, DXIL→SPIR-V via bundled `dxil-spirv`, and
  D3D12 shaders compiled to SPIR-V). Submodules: Vulkan-Headers, SPIRV-Headers,
  dxil-spirv, etc.
- `third_party/MoltenVK` — Vulkan-on-Metal implementation. `fetchDependencies`
  pulls SPIRV-Cross, SPIRV-Tools, glslang, Vulkan-Headers/Tools, cereal.
- `third_party/dxvk` — reference only (D3D9–11). Not in the critical path, but
  useful for shared Wine/DXGI idioms if VKMT later covers pre-12 APIs.
- Prior art worth studying on this drive: `DXMT-Finisher-Research-20260712`
  (DXMT takes the D3D11→Metal direct route; many of its Metal-side solutions
  transfer to our MoltenVK work).

### Known gaps (vkd3d-proton requirements vs. stock MoltenVK)

vkd3d-proton has a documented minimum Vulkan feature set; several of its
heavy-use paths are weak or missing in MoltenVK:

1. **Bindless / descriptor indexing** — vkd3d-proton is fundamentally bindless
   (raw VA descriptor heaps). MoltenVK supports `VK_EXT_descriptor_indexing`
   via Metal argument buffers, but tier limits, update-after-bind, and
   mutable descriptor types need reviewing against vkd3d-proton's demands.
2. **Stream output** — D3D12 SO maps to `VK_EXT_transform_feedback`.
   MoltenVK has historically not supported it (Metal has no direct equivalent;
   needs emulation via compute pass + argument-buffer feedback).
3. **DXR raytracing** — `VK_KHR_ray_tracing_pipeline` is unimplemented in
   MoltenVK. Metal 3+ has native RT (acceleration structures, intersection
   queries). Big work item; map RT pipeline → MPS/MTL raytracing APIs.
4. **Geometry shaders** — unsupported by MoltenVK. vkd3d-proton needs them for
   some titles. Emulation path: Metal mesh/object shaders (Apple7+/Metal 3)
   or compute expansion.
5. **Tessellation** — MoltenVK supports it via compute pre-pass, but
   correctness/perf against vkd3d-proton workloads must be validated.
6. **Shader semantics** — SPIRV-Cross MSL gaps that matter here: precise math,
   BCD integer patterns from dxil-spirv output, wave/subgroup ops,
   demote-to-helper-invocation, sampler feedback.
7. **Memory model / sync** — vkd3d-proton uses UAV barriers and
   `VK_KHR_buffer_device_address`; check Metal memory-barrier granularity and
   BDA emulation correctness.
8. **WSI / present** — no DXGI swapchain on macOS; need a VKMT WSI shim
   (`VK_KHR_surface`/`swapchain` → `CAMetalLayer` + present pacing, HDR,
   fullscreen).

### Workstreams

#### Workstream 0 — Build & environment (now)
- [x] Repo skeleton on external SSD (`/Volumes/AverySSD/VKMT`)
- [ ] Clone vkd3d-proton (+ submodules), MoltenVK (+ fetchDependencies), DXVK (ref)
- [ ] Toolchain: Xcode + Command Line Tools, mingw-w64 cross compiler
      (vkd3d-proton builds Windows PE DLLs: `d3d12.dll`, `d3d12core.dll`),
      Meson/Ninja, Homebrew deps (`brew install mingw-w64 meson ninja glslang`)
- [ ] Build MoltenVK (`make macos`) → `MoltenVK.xcframework`
- [ ] Cross-build vkd3d-proton (`./package-release.sh` path or meson cross file)
- [ ] Hello-triangle smoke test under Wine/macOS with VK_LOADER debug on

#### Workstream 1 — Gap review
- [ ] Script MoltenVK's `VkPhysicalDevice` report vs vkd3d-proton's required
      feature/extension list (`libs/vkd3d/device.c` minimum requirements)
- [ ] Run vkd3d-proton's test suite where buildable; catalog failures by gap
- [ ] Produce `docs/graphics.md` with per-gap severity and owner

#### Workstream 2 — Core correctness ("guarantee" work)
- [ ] Descriptor indexing / argument-buffer tier parity; fix mutable/update-after-bind
- [ ] BDA + memory-barrier correctness fixes in MoltenVK
- [ ] SPIRV-Cross MSL fixes for dxil-spirv output patterns (upstream PRs where possible)
- [ ] WSI shim: `CAMetalLayer` surface, present queue, vsync/pacing

#### Workstream 3 — Feature extension (the D3D12-for-MoltenVK avenue)
- [ ] Transform feedback / stream output emulation (compute feedback pass)
- [ ] DXR: `VK_KHR_ray_tracing_pipeline` → Metal RT mapping (largest item)
- [ ] Geometry shader emulation (mesh shaders on Apple silicon)
- [ ] Sampler feedback, subgroup completeness, misc `VK_EXT_*` vkd3d wants

#### Workstream 4 — Integration & testing (plug in to test at the end)
- [ ] VKMT installer: MoltenVK ICD + vkd3d-proton DLLs into a Wine prefix
- [ ] Test matrix: vkd3d-proton tests → VKCTS/Vulkan samples → real D3D12 titles
- [ ] Perf pass: GPU frame capture in Xcode, argument-buffer residency, pipelines

### Non-goals (for now)

- D3D9–11 (DXVK/DXMT territory)
- Windows-on-Arm translation (out of scope; x86 titles still need Wine's WoW64)
- Upstreaming everything immediately (we PR upstream when stable, but VKMT
  carries patches as needed)

### Repo layout

```
VKMT/
├── docs/graphics.md
├── third_party/
│   ├── vkd3d-proton/
│   ├── MoltenVK/
│   └── dxvk/            # reference
├── patches/             # our patches against upstream (applied via script)
├── scripts/             # fetch, apply-patches, build, package
└── docs/                # GAPS.md, design notes
```

## MoltenVK and vkd3d-proton capability gaps


Evidence gathered 2026-07-24 from `third_party/vkd3d-proton` (cited `vkd3d/…`)
and `third_party/MoltenVK` (cited `mvk/…`). MoltenVK 1.4.2 advertises Vulkan 1.4
(`mvk/MoltenVK/MoltenVK/Utility/MVKEnvironment.h:65`).

### How vkd3d-proton defines requirements

- No hard-required device extension strings — all ~90 extensions in
  `optional_device_extensions[]` are opportunistic (`vkd3d/libs/vkd3d/device.c:66-167`,
  checks at `:449` and `:3103`).
- Hard requirements: minimum Vulkan API 1.3 (`vkd3d/include/vkd3d.h:53`,
  enforced at `device.c:3535`), and feature checks in
  `vkd3d_init_device_caps()` (`device.c:3240-3486`) — every `E_INVALIDARG` is init-fatal.

### FATAL gaps (device creation fails today)

| Requirement | vkd3d evidence | MoltenVK status | mvk evidence |
|---|---|---|---|
| VK_EXT_transform_feedback: `transformFeedbackQueries` | `device.c:3292-3296` | **Missing entirely** (D3D12 stream output) | absent from `MVKExtensions.def`; ext never chained |
| VK_EXT_robustness2: `robustBufferAccess2` + `robustImageAccess2` | `device.c:3429-3434` | `robustBufferAccess2 = false` unconditionally; image2 only on Apple GPUs | `MVKDevice.mm:635-638` |
| VK_EXT_robustness2: `nullDescriptor` | `device.c:3436-3440` | `false` unconditionally | `MVKDevice.mm:638` |

Satisfied hard checks (no work needed): vertex attribute divisor, single-texel
alignment, `samplerMirrorClampToEdge` (macOS OK), `shaderDrawParameters`,
VK_KHR_push_descriptor, maintenance5/6, all Vulkan 1.3 features
(dynamicRendering, synchronization2, maintenance4).

### Optional-but-important (compatibility ceiling)

| Extension / feature | vkd3d use | MoltenVK status |
|---|---|---|
| VK_KHR_acceleration_structure + ray_tracing_pipeline + ray_query + RT maintenance1 + deferred_host_ops + opacity_micromap | DXR tiers 1.0–1.2 (`device.c:9885-9959`) | **Missing** — no RT code in tree |
| VK_EXT_mesh_shader | SM 6.5+ mesh shaders (`device.c:10029`) | **Missing** (SPIRV-Cross in this fork has MSL mesh-shader support; not exposed) |
| VK_EXT_descriptor_indexing (runtime arrays, partial bind, update-after-bind, variable count) | bindless tier 3 | **Supported**; full 1e6 limits only at argument-buffer Tier 2 (`MVKDevice.mm:196-205,863-867`) |
| bufferDeviceAddress | GPUVA, SM 6.6+ | Supported, macOS 13+ (`MVKDevice.mm:214`) |
| Subgroup ops (rotate/ballot/quad/maximal reconvergence) | wave ops | Mostly supported on Apple GPUs; note 1.4.2 "disable non-working quad control flow" |
| VK_KHR_fragment_shading_rate | VRS tiers 1/2 | **Missing** |
| VK_EXT_conditional_rendering | predication | **Missing** |
| VK_EXT_conservative_rasterization | ConservativeRasterizationTier | **Missing** |
| VK_EXT_custom_border_color | static samplers | **Missing** |
| VK_EXT_depth_clip_enable | depth clip control | **Missing** (has depth_clip_control, different ext) |
| VK_KHR_draw_indirect_count (`drawIndirectCount`) | ExecuteIndirect | **Disabled** (`MVKDevice.mm:2833`) |
| VK_EXT_shader_image_atomic_int64 / shaderBufferInt64Atomics | int64 atomics | **Missing** |
| VK_EXT_graphics_pipeline_library / shader_module_identifier / mutable_descriptor_type / descriptor_buffer / memory_priority / pageable_device_local_memory / image_sliced_view_of_3d / cooperative_matrix / float8 | optional perf/correctness paths | **Missing** |
| Sparse residency (tiled resources tier 3) | options.TiledResourcesTier | Not supported; vkd3d degrades gracefully (`device.c:3261-3266`) |
| VK_EXT_extended_dynamic_state2/3 | dynamic states | Both advertised; individual bits partially emulated (vkd3d disables most at `device.c:3346-3372`) |
| VK_EXT_hdr_metadata, memory_budget, fragment_shader_interlock, present_id/wait, swapchain_maintenance1, calibrated_timestamps, texel_buffer_alignment, external_memory_host, shader_stencil_export, line_rasterization | misc | **Supported** |
| Sampler feedback (OPTIONS7) | `device.c:6013` | Plausible (`shaderResourceMinLod` on Apple/Mac1); needs runtime verification |
| Vendor exts (NV_*, AMD_*, NVX_*, MESA_*, VALVE_*) | vendor perf paths | All missing (expected on macOS) |
| `shaderInt64` | Int64ShaderOps | Supported on Apple GPUs/Mac1 |

### Config gates to remember

- Argument-buffer Tier 2 (Apple7+/Mac2) → full bindless limits; config
  `useMetalArgumentBuffers` (`MVKConfigMembers.def:81`).
- BDA requires macOS 13+ (`MVKFoundation.cpp:139`); MoltenVK refuses Vulkan
  ≥1.3 instances without it (`MVKInstance.mm:330`).
- `wideLines` needs `useMetalPrivateAPI` (`MVKDevice.mm:2769`).
- MoltenVK 1.4.2 minimum deployment: macOS 12.0.

### Runtime notes (2026-07-24, Wine integration findings)

- **winevulkan extension filtering**: Wine's Unix-side vulkan driver only
  forwards extensions in its built-in list. MetalSharp's wine-11.5 build lacks
  VK_EXT_transform_feedback, VK_EXT_robustness2, and
  VK_EXT_texel_buffer_alignment entirely (`strings winevulkan.so` → 0 hits),
  so vkd3d-proton under Wine sees none of the features we enabled natively.
  Probe failures cascade: coopmat proc load → TF check → texel alignment →
  robustness2. Short-term: `patches/vkd3d-proton-vkmt-wine-compat.patch`
  demotes the TF/texel-alignment checks to WARN and makes the coopmat proc
  optional. Proper fix: native arm64 Wine 11.12 build (`scripts/build-wine.sh`)
  where we control the winevulkan extension list.
- **Texel buffer alignment is a real MoltenVK gap too**: natively, MoltenVK
  reports 16-byte `storageTexelBufferOffsetAlignment` (Metal
  `minimumTextureBufferAlignment`), failing vkd3d's single-texel check even
  without Wine filtering. Typed buffer views with byte offsets not divisible
  by 16 will misbehave until MoltenVK gains offset emulation.

### Priority order (severity × effort)

1. **robustness2: `robustBufferAccess2` + `nullDescriptor`** — fatal, medium
   effort. Options: SPIRV-Cross robustness instrumentation for buffers, or
   a justified "lie" where Metal argument-buffer runtime already bounds-checks
   + null-descriptor emulation in argument-buffer encoding. vkd3d refuses to
   drop robustness (`device.c:3409-3421`).
2. **VK_EXT_transform_feedback** — fatal, high effort. No Metal equivalent;
   emulate stream output with a compute feedback pass + `transformFeedbackQueries`
   via pipeline statistics emulation. Alternative short-term: patch vkd3d to
   disable stream output (breaks SO-using games).
3. **DXR stack** — biggest workstream. Metal 3 RT (MTLAccelerationStructure,
   intersection functions) maps reasonably; MTL4 in macOS 26 improves fit.
4. **VK_EXT_mesh_shader** — high value; SPIRV-Cross MSL mesh support already
   exists in this fork, work is exposing the Vulkan ext + pipeline stages.
5. **VK_KHR_fragment_shading_rate** — tier 1 emulation likely feasible.
6. **Early wins (bounded, independent):** conditional_rendering,
   conservative_rasterization, custom_border_color, depth_clip_enable,
   drawIndirectCount (compute pass to patch counts).
7. Sparse/tiled tier 3 and pipeline-library niceties — opportunistic.

Bottom line: three checkboxes (robustness2 × 2, transform feedback) stand
between MoltenVK and vkd3d-proton device creation; after that, DXR, mesh
shaders, and VRS define the game-compatibility ceiling.

## Graphics capability record


Updated 2026-08-03 from direct contract receipts. This is a capability
boundary document, not a claim that every row is green.

The Workstream 0 infrastructure gate is
`docs/validation/graphics-infrastructure-final/RESULTS.md`. It verifies the
receipt-backed canonical graphics prefix without Wineboot, checks the
architecture headers and hashes of the promoted custom FEX, DXVK,
vkd3d-proton, DXMT, and MoltenVK artifacts, and rejects nonzero TSO settings
in active graphics acceptance runners. It is staging evidence only; it does
not replace the behavioral rows below.

The FEX/WoW64 prerequisite gate is
`docs/validation/graphics-wow64-final/RESULTS.md`. The nested Wine memory
source fix is commit `f108c09`; it repairs derived low-alias fallback and
complete reservation retirement after interval splitting. The x64 and i386
VM contracts now pass high-host/top-down allocation, guest-aperture pressure,
reserve/commit/decommit/recommit, protection, reuse, overlapping views,
concurrent mapping pressure, executable reuse, and correlated i386 FEX
invalidation with all TSO settings zero.

The current custom MoltenVK truthfulness delta is nested commit `665b11e7`.
It is promoted into the actual universal Wine runtime by
`scripts/build-moltenvk.sh` and is reproducible from
`patches/moltenvk-phase2-665b11e7.patch` (with the broader source recipe
recorded in `patches/MoltenVK-vkmt-phase2-fatal-gaps.patch`).

### Requirement matrix

| Area | Behavioral evidence | Result |
|---|---|---|
| MoltenVK null descriptors | Native ARM64 null storage-buffer read returns zero | **PASS — narrow** |
| MoltenVK robust buffer/image access | Native ARM64 direct OOB storage-buffer and storage-image reads return zero | **PASS — narrow** |
| MoltenVK transform feedback | Direct capture/counters/queries are not available | **NOT ADVERTISED**; extension and feature bits disabled |
| MoltenVK indirect count | Count-buffer alignment/zero/nonzero/synchronization not proven | **NOT ADVERTISED** |
| MoltenVK typed-buffer alignment | Device reports 16-byte storage/uniform alignment | **QUERY_ONLY**; unaligned offsets are not claimed |
| D3D11 device/VS/PS/CS/compute/texture/render | `d3d11-graphics-contract` | Latest receipt: i386 completes the full lane; ARM64EC/x86_64 create the device/shaders but retain a bounded structured-UAV compute readback gap; ARM64 latest rerun timed out during provider startup and is not counted green |
| D3D11 swapchain/present/resize | Same fixture | **NOT APPLICABLE** on current no-display host |
| D3D11 device-loss/recreation | No safe injected loss fixture | **NOT CLAIMED** |
| D3D12 queue/fence/copy/readback | Existing no-DXGI probe and acceptance lane fixture | **PASS — all four lanes** |
| D3D12 VS/PS/CS, descriptor-table UAV, render/compute readback, barriers, fence timeout | `d3d12_graphics_contract.c` | **PASS — all four lanes**, after the ARM64-safe DXIL-SPIRV/C TLS fixes and rebuilt ARM64/ARM64EC providers |
| D3D12 second device initialization | Same fixture | **PASS — ARM64, ARM64EC, x86_64**; i386/WoW64 is explicitly `NOT_CLAIMED` because the second `D3D12CreateDevice` entry faults after the first lane completes |
| D3D12 swapchain/present/resize | No-display host and no window lane in fixture | **NOT CLAIMED** |
| D3D9 device/texture/surface | `d3d9_contract.c` | Device and texture upload/readback pass; fixed-function and shader textured draw/readback remain unavailable in the current headless DXVK route |
| D3D9 present/resize/reset | `d3d9_contract.c` | Visible present is no-display; reset is downstream of draw gap |
| OpenGL indexed/texture/FBO/uniform/sync/share/UBO/present | `opengl_extended_contract.c` | Four processes execute; current host records `NO_DISPLAY`, so display-dependent rows are not passes |
| ARM64EC DXMT D3D11CreateDevice | `probe-dxmt-arm64ec.sh` now includes full lane | **PENDING EXECUTION**; WMT-only bridge is not sufficient |

### Receipts

- MoltenVK: `docs/validation/moltenvk-behavior-final-20260803/RESULTS.md`
- D3D11: `docs/package-and-validation.md`
- D3D12: `docs/validation/d3d12-graphics-contract-final-20260803/RESULTS.md`
- D3D9: `docs/validation/d3d9-runtime-20260728/RESULTS.md`
- OpenGL: `docs/validation/opengl-runtime-20260728/RESULTS.md`

All new contract runners use the existing receipt-backed prefix, do not call
Wineboot, set `FEX_TSOENABLED=0`, `FEX_VECTORTSOENABLED=0`, and
`FEX_MEMCPYSETTSOENABLED=0`, and retain nonzero lanes and unsupported APIs in
their capability tables.

### Immediate gaps

1. Diagnose the x64/ARM64EC D3D11 structured-UAV compute-readback boundary
   while preserving the passing ARM64/i386 lanes. The current fixture uses a
   bounded event/nonblocking-map path and does not turn the failure into a
   pass. The most recent ARM64 rerun also needs an isolated startup diagnosis;
   its earlier receipt had passed before repeated canonical-prefix sessions.
2. Provide a display-backed D3D9/OpenGL/DXGI swapchain fixture, or retain the
   explicit headless fallback policy.
3. Implement a real MoltenVK transform-feedback capture path before restoring
   `VK_EXT_transform_feedback`.
4. Execute the updated DXMT standard D3D11 gate and add compute/render
   readback to it before claiming DXMT WoW64 coverage.

5. Repair the i386/WoW64 second-device D3D12CreateDevice thunk path before
   claiming D3D12 device recreation for that lane; the core device, compute,
   render, readback, and fence contract is already rc=0.

### ARM64 pipeline fix

The ARM64/ARM64EC D3D12 pipeline/compute crash was not a D3D12 feature
limitation. It was a combination of DXIL-SPIRV C++ `thread_local` lowering and
vkd3d C `__declspec(thread)` accesses emitting x18-relative accesses at the
Wine/FEX boundary. `subprojects/dxil-spirv/util/vkmt_thread_local.hpp` and
the vkd3d UAV/debug/address-binding paths now use Win32 TLS on Windows while
retaining native TLS elsewhere. The rebuilt providers are installed in
`third_party/vkd3d-proton/install-arm64` and `install-arm64ec`, and the
four-lane D3D12 receipt records pixel readback `64,128,191,255`, compute
readback, fence timeout/completion, and rc=0. i386's second-device thunk
boundary remains visible in the receipt rather than being hidden.

## Transform-feedback emulation design


Status: **design only** (Stage 1, the passthrough advertisement of
`VK_EXT_transform_feedback`, is implemented and documented at the bottom).

### Problem

Metal has no stream-output / transform-feedback hardware stage. vkd3d-proton
requires `VK_EXT_transform_feedback` with `transformFeedbackQueries == VK_TRUE`
to create a device at all (libs/vkd3d/device.c), and uses it to implement D3D12
stream output (`D3D12_SO_DECLARATION_ENTRY`, `CreateStreamOutputPipelineState`,
`SOSetTargets`, `DrawAuto`/counters). Stage 1 makes device creation succeed and
runs non-SO workloads perfectly, but games that actually capture varyings get
nothing written to their SO buffers. Stage 2 implements real capture.

### Design: vertex stage as a compute pre-pass

The approach mirrors MoltenVK's existing tessellation emulation
(`MVKCmdDraw::encode` tess paths, `MVKCommandUse::kMVKCommandUseTessellationVertexTessCtl`,
`MVKMetalComputeCommandEncoderState::prepareRenderDispatch`), which already runs
the vertex (and tess-control) stage as a Metal compute dispatch feeding a
post-processed vertex buffer into a fixed-function render pass.

#### 1. Pipeline compile time

When a `VkGraphicsPipeline` is created with a
`VkPipelineRasterizationStateStreamCreateInfoEXT` in its rasterization state
`pNext` chain (or, for vkd3d-proton's usage, whenever the SO state indicates
captured varyings — see "vkd3d-proton specifics" below), the pipeline is marked
as a *stream-output pipeline* and records:

- `rasterizationStream` (we advertise `geometryStreams = false`, so it must be 0;
  pipeline creation can reject otherwise with `VK_ERROR_FEATURE_NOT_PRESENT`-style
  validation error, or simply ignore since VUID forbids non-zero),
- the set of captured outputs. **Note:** vanilla Vulkan determines captured
  varyings from `VkPipelineRasterizationStateStreamCreateInfoEXT` plus the
  SPIR-V `XfbBuffer`/`XfbStride`/`Offset` decorations emitted by glslang when the
  shader is compiled with transform-feedback layout qualifiers. vkd3d-proton
  instead compiles DXIL→SPIR-V via dxil-spirv with SO declaration metadata; the
  captured varying set must be extracted from the SPIR-V execution-mode /
  decoration data by SPIRV-Cross reflection (`SPIRVariable` decorations
  `DecorationXfbBuffer`, `DecorationXfbStride`, `DecorationOffset`).

#### 2. SPIRV-Cross changes (External/SPIRV-Cross)

Confirmed: **no MSL transform-feedback support exists**. The only
`xfb`/`transform feedback`/`stream out` hits are in `spirv_glsl.cpp` (GLSL
backend), `spirv.hpp`/`spirv_common.hpp` (decoration enums), and `main.cpp`
(reflection CLI). `spirv_msl.cpp` never reads `DecorationXfbBuffer` /
`DecorationXfbStride` / `DecorationOffset`.

Required work in `spirv_msl.cpp` / `CompilerMSL`:

- New option `CompilerMSL::Options::capture_transform_feedback` (plus a
  `ShaderTransformFeedbackInfo` in `MSLShaderInterface` describing up to
  `kMVKMaxTransformFeedbackBufferCount` (4) output buffers: per-buffer stride,
  and per-captured-output (variable id, offset, xfb buffer index)).
- When enabled for a vertex shader compiled **as a compute kernel** (the same
  "vertex-as-compute" mode the tessellation pre-pass already uses
  (`is_tessellation_shader()`-adjacent paths, `MSL_VERTEX_ATTR` / stage-in
  struct handling), each captured output is additionally written to
  `device` address space: `xfb_buffers[i][atomic_counter[i] * stride + offset] = value`.
- The write index comes from a per-buffer atomic counter bound as
  `device atomic_uint*` — see §3.
- The pre-pass kernel must also write the ordinary vertex outputs (position and
  all varyings) into the indirect vertex buffer it produces, exactly as the
  tessellation vertex pre-pass does today, so the subsequent fixed-function
  render pass re-runs a trivial "passthrough" vertex shader. Whether the real
  render pass keeps the original vertex shader (and SO capture only happens in
  the pre-pass) or uses a passthrough shader is an open choice; the tessellation
  infrastructure already demonstrates the passthrough route
  (`MVKGraphicsPipeline` tess-related `getMTLComputePipelineState` paths).

#### 3. Counter buffers

`vkCmdBeginTransformFeedbackEXT` binds per-buffer counter buffers holding the
current write offset (in *bytes* for the Vulkan extension, unlike D3D12's
filled-size counters — vkd3d-proton adapts).

- Each Vulkan counter buffer (a `VkBuffer` range) maps to a 4-byte
  `atomic_uint` in an MTLBuffer. MoltenVK keeps the *Vulkan-visible* counter
  buffers as the single source of truth: the pre-pass kernel does
  `atomic_fetch_add_explicit(&counter, 1)` per emitted vertex and uses the
  returned value as the output slot.
- On `vkCmdBeginTransformFeedbackEXT` with `pCounterBuffers == NULL`, counters
  conceptually start at 0; with non-NULL counter buffers, the captured offset
  resumes. Because the counter values live in device memory already, both cases
  work without host reads: NULL counters bind a MoltenVK-internal zeroed
  scratch counter buffer (per command encoder, from
  `MVKCommandResourceFactory`/command encoding pool), non-NULL binds the
  app's buffer directly.
- Multi-buffer XFB: each of the up-to-4 SO buffers has its own counter; the
  SPIR-V `XfbBuffer` decoration selects which counter a captured output uses.

#### 4. Draw execution with an active SO pipeline

Inside `MVKCmdDraw*::encode` (and indexed/indirect variants), when
`_vkGraphics._transformFeedbackActive` and the bound pipeline is an SO pipeline
(Stage 1 already tracks `_xfbBuffers`, `_xfbCounterBuffers`,
`_transformFeedbackActive` in `MVKVulkanGraphicsCommandEncoderState`):

1. Switch to the compute encoder (`getMTLComputeEncoder` with a new
   `MVKCommandUse`, e.g. `kMVKCommandUseTransformFeedbackVertex`), exactly like
   the tessellation pre-pass switches encoders mid-render-pass.
2. Dispatch the vertex-as-compute kernel over the draw's vertex range
   (instances handled like the tess pre-pass's instance expansion). The kernel
   writes captured varyings into the bound `_xfbBuffers` at offsets advanced by
   the per-buffer atomic counters, and writes the full vertex output record
   into a scratch indirect vertex buffer.
3. Return to the render encoder and issue the real draw sourcing the scratch
   vertex buffer (tessellation's `needsVertexAdjustment` /
   `vtxAdjmts` paths in `MVKCmdDraw.mm` are the template for this fixup).

Rasterization-discard interaction: D3D12 SO-only passes use
`D3D12_RASTERIZER_DESC` with no render targets; in Vulkan this maps to
`rasterizerDiscardEnable`. When discard is on, step 3 is skipped entirely and
only the compute capture runs — this is the cheap and common SO case.

#### 5. `vkCmdDrawIndirectByteCountEXT` (D3D12 `DrawAuto` / SO-as-input)

The draw's vertex count is `counterValue / vertexStride`. Since the counter
lives in device memory, do what DXVK does for `drawIndirectCount`:

- A tiny compute "args patching" kernel (new pipeline in
  `MVKCommandResourceFactory`, alongside
  `newCmdDrawIndirectTessConvertBuffersMTLComputePipelineState`) reads the
  counter buffer, computes `vertexCount = counter / vertexStride`, and writes a
  `MTLDrawPrimitivesIndirectArguments` struct into a scratch buffer.
- The draw then issues `drawPrimitives:indirectBuffer:` from the patched args.
- This replaces the Stage-1 stub, which currently logs a warning and skips the
  draw.

#### 6. Queries (`VK_QUERY_TYPE_TRANSFORM_FEEDBACK_STREAM_EXT`)

`transformFeedbackQueries = true` is already advertised.

- `primitivesWrittenQuery`: read back the counter delta (end counter − begin
  counter) × vertices-per-primitive for the stream's topology. Implement as a
  compute reduction writing into the query pool's visibility/result buffer,
  or — simpler first cut — patch the counter value into the query result
  buffer with the same args-patching kernel used in §5.
- `primitivesGeneratedQuery` (pre-SO): can be approximated by the input vertex
  count when no clipping-dependent accuracy is required; a correct
  implementation needs a counting pass and can be deferred.

#### 7. State tracking already in place (Stage 1)

`MVKVulkanGraphicsCommandEncoderState` holds:

- `_xfbBuffers[kMVKMaxTransformFeedbackBufferCount]` — bound SO buffers,
- `_xfbCounterBuffers[kMVKMaxTransformFeedbackBufferCount]` — bound counters,
- `_transformFeedbackActive`.

Stage 2 consumes this state in the draw commands; no new Vulkan-visible state
is needed. `MVKCmdBindTransformFeedbackBuffers`, `MVKCmdBeginTransformFeedback`,
`MVKCmdEndTransformFeedback` already record all bindings at encode time.

### Task breakdown

1. **SPIRV-Cross**: parse `DecorationXfbBuffer/Stride/Offset` in reflection;
   `CompilerMSL` option + codegen writing captured outputs to device buffers
   via an atomic counter in vertex-as-compute mode. (Largest piece.)
2. **MoltenVK pipeline**: plumb stream state from
   `VkPipelineRasterizationStateStreamCreateInfoEXT` + SPIRV-Cross reflection
   into `MVKGraphicsPipeline`; compile SO pre-pass MSL via the new option.
3. **Command encoding**: new `MVKCommandUse`, draw-command branch for SO
   pre-pass + scratch vertex buffer handoff (model on tessellation paths in
   `MVKCmdDraw.mm`).
4. **Counters**: internal zeroed scratch counters for the NULL-counter case;
   buffer binding plumbing into the pre-pass kernel's argument buffer.
5. **Args patching**: `vkCmdDrawIndirectByteCountEXT` compute patch pass +
   indirect draw (replace Stage-1 skip-stub).
6. **Queries**: transform-feedback-stream query pools via counter deltas.
7. **Testing**: vkd3d-proton stream-output tests (libs/vkd3d tests,
   `test_stream_output`), then a real D3D12 SO workload.

### Stage 1 reference (implemented)

- `VK_EXT_transform_feedback` advertised for all platforms (10.11+ macOS,
  8.0+ iOS) — chosen over Apple-GPU-only gating because the passthrough
  emulation needs no Metal capability; capture quality does not depend on GPU
  family. Files: `MVKExtensions.def`, `MVKDevice.mm` (features: transformFeedback
  = true, geometryStreams = false; properties: spec-minimum limits,
  transformFeedbackQueries = true, transformFeedbackDraw = true), entry points
  in `vulkan.mm`/`MVKInstance.mm`, command classes in `MVKCmdDraw.h/.mm`,
  state in `MVKCommandEncoderState.h/.mm`.
- Behavior: buffers/counters tracked; draws run normally without capture;
  one-time `MVKLogWarn` on first `vkCmdBeginTransformFeedbackEXT`;
  `vkCmdDrawIndirectByteCountEXT` logs once and skips.
- vkd3d-proton impact: `d3d12_device_caps_init` marks stream output supported;
  only games that actually bind SO targets and render with SO pipelines are
  affected (their captured buffers stay unwritten). Everything else is exact.

## SDL runtime


VKMT carries source-built Windows SDL runtimes for every supported guest ABI:

| Guest ABI | PE machine |
|---|---|
| AArch64 | `IMAGE_FILE_MACHINE_ARM64` |
| ARM64EC | `IMAGE_FILE_MACHINE_ARM64EC` |
| x86_64 | `IMAGE_FILE_MACHINE_AMD64` |
| i386/WoW64 | `IMAGE_FILE_MACHINE_I386` |

The pinned inputs are SDL2 2.32.10 and SDL3 3.4.10. Their upstream release
commits and the VKMT compatibility commits are recorded in
`wine/build-ec/sdl-runtime/manifest.txt`.

Build or restage all architectures:

```sh
scripts/build-sdl-runtime.sh
```

Limit a rebuild with `VKMT_SDL_ARCHES`, for example:

```sh
VKMT_SDL_ARCHES="arm64ec i386" scripts/build-sdl-runtime.sh
```

Run the authoritative single-prefix acceptance gate:

```sh
scripts/probe-sdl-runtime.sh
```

The probe validates SDL version, dummy audio/video initialization, a hidden
window, software-surface fill/readback, event delivery, a worker thread,
dynamic DLL loading, and clean teardown for both SDL generations on every
guest ABI. It also verifies the x86_64 emulator instructions needed by these
builds and rejects Rosetta or non-ARM64 host Wine artifacts.

The i386 runtime is intentionally scalar. Its build disables MMX/SSE and
compiler vectorization, avoiding FEX paths that would otherwise carry a
non-temporal vector store across the guest-page translation boundary.
