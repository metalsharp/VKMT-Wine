# VKMT Audit 2 — Close-out Gates

Date: 2026-08-19

Audit 2 is the Phase 6/7 close-out checklist. It is intentionally independent
of the earlier optimization ledger and does not include CEF/Electron as a
required implementation target.

## Gate A — TSO and translation policy

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

## Gate B — stale-state and memory-leak audit

For each fresh-prefix run:

1. record the prefix receipt and provider/runtime hashes;
2. run one Wineboot and restage providers;
3. run the contract in a single wineserver lifetime;
4. stop the wineserver and wait for it to exit;
5. verify no process, temporary prefix, candidate provider, or probe log is
   left outside the evidence directory;
6. repeat the run in a second fresh prefix;
7. compare resident-set high-water and allocation/leak summaries.

Timeouts, wrapper success, partial markers, and a process that is merely
terminated are failures, not passes.

## Gate C — architecture matrix

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

## Gate D — graphics feature truthfulness

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

## Gate E — package integrity

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
7. run the P6 architecture gate from the newly installed target; and
8. replace the old release assets only after all preceding gates pass.

## Current decision

Audit 2 is complete for the scoped product lanes: native VKMT P6/P8 remains
the all-architecture baseline, while the v1.0 graphics overlay is accepted
only for the x86_64 Wine route that passed its fresh ladder. The explicit
native-FEX compatibility note prevents the release's x86_64 claim from being
mistaken for all-architecture graphics support.
