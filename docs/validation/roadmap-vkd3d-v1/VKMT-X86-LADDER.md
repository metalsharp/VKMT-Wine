# VKMT VKD3D-Proton-MacOS v1.0 ladder

The latest `v1.0` asset was staged in a fresh external-SSD VKMT/MetalSharp
x86_64 Wine prefix. The test executable was rebuilt from
`VKD3D-Proton-MacOS/scripts/flprobe.c` with llvm-mingw 20260616; the stale
published probe binary was not used.

Command shape:

```text
WINEDEBUG=-all VKMT_ALLOW_NON_SINGLE_TEXEL_ALIGNMENT=1 \
  WINEDLLOVERRIDES='dxgi,d3d12,d3d12core=n,b' \
  VK_ICD_FILENAMES=<fresh-prefix>/icd.json \
  <VKMT x86_64 Wine>/bin/wine <fresh-flprobe.exe>
```

Result: process status `0`.

```text
min 12_2     : hr=0x00000000 dev=CREATED
min 12_1     : hr=0x00000000 dev=CREATED
min 12_0     : hr=0x00000000 dev=CREATED
min 11_1     : hr=0x00000000 dev=CREATED
min 11_0     : hr=0x00000000 dev=CREATED
min 1_0_CORE : hr=0x00000000 dev=CREATED
FEATURE_LEVELS max=12_2
Shader Model highest=0x65 (SM 6.5)
RaytracingTier=11 (DXR 1.1)
VRS tier=2
MeshShaderTier=10 (tier 1)
SamplerFeedbackTier=90 (tier 0_9)
TiledResourcesTier=4
ConservativeRasterTier=3
ROVsSupported=1
DepthBoundsTestSupported=1
CopyQueueTimestampQueries=1
CastingFullyTyped=1
Barycentrics=1
OutputMergerLogicOp=1
```

The compact receipt above is retained after temporary-prefix cleanup. The
source-backed full ladder corpus is also retained in
`/Volumes/AverySSD/VKD3D-Proton-MacOS/artifacts/evidence/rung-ladder-2026-08-16.txt`.
The universal MoltenVK slice and the three x86_64 PE modules are the exact
v1.0 release asset hashes in `SHA256SUMS`.

The ARM64-native P6 gate remains a separate acceptance lane and continues to
use VKMT's architecture-matched providers. The v1.0 release's published
modules are explicitly kept in `graphics/vkd3d-proton-macos-v1.0/` as the
matched x86_64 graphics overlay; they are not copied over the native ARM64,
ARM64EC, or i386 provider directories.
