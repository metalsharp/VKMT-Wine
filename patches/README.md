# VKMT patch set

Patches are focused source deltas, not an ordered milestone series. Apply only
the patch that matches the pinned source revision and build script.

- `wine-11.12-vkmt.patch` — base VKMT Wine integration.
- `wine-11.12-arm64-mono-fusion.patch` — managed runtime fusion.
- `wine-11.12-java-j5.patch` — Java/WoW64 handoff support.
- `wine-11.12-no-tso-steam-runtime.patch` — software ordering and Steam path.
- `wine-wow64-f108c09.patch` — WoW64 bridge repair.
- `fex-2607-vkmt.patch` — FEX provider integration.
- `fex-2607-java-j5.patch` — managed execution boundary.
- `fex-2607-no-tso-steam-runtime.patch` — no-TSO Steam behavior.
- `fex-wow64-nested-code-buffer-pin.patch` — guest code-buffer ownership.
- `dxmt-v0.80-xcode27-arm64.patch` — native DXMT build support.
- `dxvk-vkmt-moltenvk.patch` — DXVK/MoltenVK integration.
- `MoltenVK-vkmt-fatal-gaps.patch` and `moltenvk-665b11e7.patch` — required
  Metal feature admission and behavior fixes.
- `vkd3d-proton-tls.patch` — VKD3D-Proton thread-local integration.
- `wine-mono-11.2.0-arm64-coree.patch` — ARM64 managed loader support.
- `innoextract-boost-system-header-only.patch` — relocatable installer tool.
