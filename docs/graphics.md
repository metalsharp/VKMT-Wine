# VKMT graphics

## Provider layout

The runtime keeps separate guest lanes so Wine never confuses guest
architecture with host library architecture:

| Lane | D3D11/D3D9/DXGI | D3D12/D3D12core | Native bridge |
| --- | --- | --- | --- |
| ARM64/AArch64 | DXVK and Wine built-ins | VKD3D-Proton | ARM64 DXMT Unix bridge |
| ARM64EC | DXVK | VKD3D-Proton | ARM64EC DXMT Windows bridge |
| x86_64 | DXVK | VKD3D-Proton | `xtajit64` plus DXMT |
| i386/WoW64 | DXVK | VKD3D-Proton | `xtajit` plus i386 DXMT |

Wine's built-in D3D10/D3D10core closure remains available in every guest
lane. DXMT provides D3D10, D3D10core, D3D11, DXGI, and Winemetal routes where
its architecture-specific bridge is selected.

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

## Scope

The release gate proves loading, architecture routing, provider staging,
D3D9 caps, D3D11/D3D12 contract fixtures, and single-prefix execution. It does
not claim that every Windows application or every vendor-specific graphics
extension is supported.
