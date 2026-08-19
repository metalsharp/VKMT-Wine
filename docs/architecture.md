# VKMT architecture

## Host boundary

VKMT runs a native ARM64 Wine host and wineserver on Apple Silicon. Windows
ARM64/AArch64, ARM64EC, x86_64, and i386 code remains in the guest boundary;
there is no x86 macOS bridge and no Rosetta requirement.

## Guest execution

ARM64 and ARM64EC use Wine's ARM64 PE loader and paired ARM64EC/ARM64X
imports. x86_64 uses the ARM64EC `xtajit64` provider. i386/WoW64 uses the
ARM64 `xtajit` provider and the Wine guest-page manager. The VM manager owns
reserve, commit, protection, executable publication, invalidation, and release
so high host mappings do not depend on a low 4-GiB host aperture.

Provider replacement is receipt-backed and invalidates per-prefix translated
code and graphics caches. Every provider launch disables all three FEX TSO
controls and rejects Rosetta.

## Native closures

Wine's ARM64 Unix modules resolve FreeType, GnuTLS, GStreamer, SDL, CoreAudio,
MoltenVK, and graphics libraries through the staged runtime tree. The launch
environment removes inherited search paths and sets the DXMT configuration
file to `runtime/dxmt.conf` unless the caller selects an explicit profile.

## Reproducibility

Pinned source revisions and focused patches live under `patches/`. Generated
Wine/FEX/graphics trees and cross-toolchains are ignored because they are
large, platform-specific build outputs. `scripts/verify-runtime.sh` validates
a prepared runtime; `scripts/package-runtime-release.sh` creates a clean
redistributable without development diagnostics.
