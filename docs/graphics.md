# VKMT graphics

## Provider layout

The runtime keeps separate guest lanes so Wine never confuses guest
architecture with host library architecture:

| Lane | D3D11/D3D9/DXGI | D3D12/D3D12core | Native bridge |
| --- | --- | --- | --- |
| ARM64/AArch64 | DXVK D3D9/10/10.1/11 and DXGI | VKD3D-Proton | ARM64 DXMT Unix bridge |
| ARM64EC | DXVK | VKD3D-Proton | ARM64EC DXMT Windows bridge |
| x86_64 | DXVK | VKD3D-Proton | `xtajit64` plus DXMT |
| i386/WoW64 | DXVK | VKD3D-Proton | `xtajit` plus i386 DXMT |

DXVK-MacOS is built for the ARM64/AArch64 D3D9, D3D10, D3D10.1, D3D10core,
D3D11, and DXGI set as well as the other guest lanes. Wine's built-in D3D10
closure remains available as a fallback. DXMT provides D3D10, D3D10core,
D3D11, DXGI, and Winemetal routes where its architecture-specific bridge is
selected.

## Default configuration

`runtime/dxmt.conf` is loaded by `scripts/vkmt-runtime-env.sh`:

```text
dxmt.metalShaderVersion = 310
d3d11.maxFeatureLevel = 12_1
d3d11.metalSpatialUpscaleFactor = 2.0
d3d11.preferredMaxFrameRate = 60
```

The option is spelled `preferredMaxFrameRate`, matching DXMT's parser. The
historical misspelling is deliberately not emitted.

## Native Metal route

MoltenVK supplies Vulkan-to-Metal, DXMT supplies the D3D11 Metal bridge, and
VKD3D-Proton supplies D3D12 translation. OpenGL uses the staged ARM64
Metal-backed provider. Host dylibs are checked for ARM64 and relocatable
loader paths; guest DLLs are checked against their PE machine type.

## Optional D3DMetal route

D3DMetal is not part of the public VKMT-1.0 runtime. The Sikarugir audit and
current architecture constraints are recorded in [D3DMetal roadmap](https://github.com/metalsharp/VKMT-Wine/blob/main/D3DMetal.md).
A private provider may be staged only through
`scripts/stage-d3dmetal-runtime.sh`; it must be a receipt-backed ARM64
provider with a matching VKMT Wine loader contract. The default runtime keeps
D3DMetal disabled and continues to retain DXMT, DXVK, VKD3D-Proton, MoltenVK,
xtajit64, and xtajit.

## Scope

The release gate proves loading, architecture routing, provider staging,
D3D9 caps, D3D11/D3D12 contract fixtures, and single-prefix execution. It does
not claim that every Windows application or every vendor-specific graphics
extension is supported.
