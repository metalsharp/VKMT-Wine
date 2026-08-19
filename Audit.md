# VKMT Upgrade and Stability Audit

Date: 2026-08-19

This is the Phase 3 audit for the upgrade and stability roadmap in
`/Users/averyfelts/Documents/Obsidian/VKMT Upgrade and Stability Roadmap.md`.
It is deliberately evidence-led: source presence, feature advertisement, and
wrapper exit status are not accepted as proof of a runtime capability.

## Host and platform boundary

The target host is Apple Silicon macOS (`Darwin arm64`). Box64/Box32 and
`systemd-binfmt` are Linux components; neither can be installed or registered
in the macOS kernel. VKMT therefore uses the correct native macOS design:

* ARM64 Wine and ARM64 Unix libraries;
* ARM64EC/ARM64X for the hybrid Windows surface;
* the native ARM64 FEX-derived `xtajit64.dll` provider for x86_64 guests;
* the native ARM64 FEX-derived `xtajit.dll` provider plus WoW64 for i386;
* no x86 Mach-O bridge, Rosetta dependency, or Linux binfmt registration.

This is a platform substitution, not a silently skipped gate. A Linux Box64
installation would be a separate runtime and cannot be used to validate VKMT's
macOS path. `scripts/probe-roadmap-p6-release.sh` records this boundary and
fails closed if run on a non-Darwin host.

## Findings and gates

| Roadmap phase | Finding | Gate / evidence | Status |
| --- | --- | --- | --- |
| 1 | External-drive release installation is transactional and isolated from the existing `~/.metalsharp/runtime`. | VKMT v0.60.0 release installer, external target, archive SHA-256, and `.metalsharp-runtime-install` receipt. | PASS |
| 1 | Box64/Box32 + `systemd-binfmt` are not applicable to this macOS target. FEX is the paired translator. | Host/platform checks and provider hashes in the P6 release receipt. | PASS (platform-adapted) |
| 2 | All four guest architecture routes execute in one fresh prefix with all FEX TSO controls set to zero. | `P6_SINGLE_PREFIX_ALL_ARCHITECTURES_OK`; historical full P8 receipts remain required for functional acceptance. | PASS |
| 3 | Reusable prefix lifecycle, provider staging, cache/hotset receipts, and evidence layout exist. | `scripts/vkmt-prefix`, `scripts/stage-runtime-providers.sh`, `docs/validation/`. | PASS |
| 4 | Safe performance work is measured and retained; unsafe candidates are rejected. | `docs/validation/perf-p8-hotset-20260801/RESULTS.md`, AI optimization ledger/disposition, no-TSO receipts. | PASS |
| 5 | The latest VKD3D-Proton-MacOS v1.0 asset is verified and passes the complete ladder in VKMT's matched x86_64 Wine lane. Its x86_64 PE modules are packaged as an explicit overlay; they are not copied over VKMT's native ARM64/ARM64EC/i386 directories because the same modules do not expose the ladder through the ARM64 FEX route. | Release asset SHA-256, fresh-probe ladder, module hashes, and the raw ARM64 compatibility run under `docs/validation/roadmap-vkd3d-v1/`. | PASS (x86_64 overlay; native FEX lane preserved) |
| 6 | TSO must remain disabled in every launch path and audit. | `FEX_TSOENABLED=0`, `FEX_VECTORTSOENABLED=0`, `FEX_MEMCPYSETTSOENABLED=0`; `docs/NO_TSO_ROSETTA_PARITY_PLAN.md`. | PASS |
| 7 | Audit 2 is the close-out audit for compatibility gaps, leakage, and stale state. | `Audit2.md`, the P6 release receipt, and the retained native-FEX compatibility note. | PASS |
| 8 | Package comparison, split/reassembly, installer regeneration, external installation, and release replacement include the native VKMT baseline and the explicit v1.0 x86_64 graphics overlay. | `docs/validation/roadmap-package-final-20260819/RESULTS.md`, final installer receipt, and release asset verification. | PASS |

## Phase 4 gate ladder

The following are the required gates after any runtime or translator change:

1. Source and patch identity are recorded before building.
2. The canonical provider hashes match the build stage and the prefix after
   Wineboot.
3. A fresh prefix runs ARM64, ARM64EC, x86_64, and i386/WoW64 with all TSO
   settings zero and without Rosetta.
4. The affected functional contract is rerun (MSync, WoW64 VM, networking/
   TLS, UI/COM, browser, or graphics).
5. Cold/warm performance is measured with output checksums and memory samples;
   a speed claim requires a matched control and no stability regression.
6. The prefix, wineserver, temporary logs, and candidate providers are
   removed after evidence is copied to a versioned validation directory.

## Security and leakage audit

* Runtime installation uses SHA-256 verification before extraction, extracts
  to a sibling staging directory, and activates with a single rename.
* The prior runtime is preserved as a backup unless the explicit discard
  option is used; the existing installation is never overwritten by the
  roadmap validation install.
* Release archives must contain public source and licenses only. Encrypted
  payloads, keys, user prefixes, private caches, and absolute symlinks are
  rejected.
* All FEX TSO settings are forced to zero by the runtime launcher and prefix
  receipt. Certificate-ignore settings remain diagnostic-only.
* Temporary validation prefixes and logs are not release assets. Evidence is
  copied before cleanup.

## Promotion rule

No feature bit, release README, or historic receipt closes Phase 5 by itself.
The v1.0 overlay is promoted only for the architecture it actually passed:
freshly rebuilt x86_64 VKMT Wine. The native ARM64/ARM64EC/i386 P6 lane keeps
the architecture-matched VKMT graphics artifacts and its raw v1.0 FEX probe
is retained as a compatibility boundary rather than misreported as a pass.
