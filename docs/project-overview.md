# VKMT project overview

VKMT is a source-integrated, Apple-Silicon-native Wine runtime. Its product
boundary is a native ARM64 host with four Windows guest routes: ARM64/AArch64,
ARM64EC, x86_64, and i386/WoW64.

The repository contains pinned patches, focused build/stage utilities,
contracts, normalized documentation, and release packaging. Generated Wine,
FEX, graphics, and toolchain trees stay on the external build volume.

The current release is accepted when the external-drive installer, hash
manifest, default DXMT profile, native host checks, no-TSO policy, fresh
`wineboot`, and one-prefix four-lane execution all pass. The production package
contains no probes, tests, validation evidence, audits, plans, roadmaps,
tracing configuration, prefixes, or logs.

See [architecture](architecture.md), [graphics](graphics.md),
[performance](performance.md), [packaging](package-and-validation.md), and
[MetalSharp integration](metalsharp-integration.md).
