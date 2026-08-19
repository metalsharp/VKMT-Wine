# Candidate disposition review — remaining custom C paths

Date: 2026-08-03

This is a completion review of the 15 candidate rows in
`docs/OPTIMIZATION_LEDGER.tsv`. It is intentionally not a green
performance claim. The source hunks were compared with the Wine 11.12 base,
then mapped to the existing workload receipts and protected-boundary rules.

## Summary

| Count | Result |
| ---: | --- |
| 1 | accepted and promoted (`ntdll/unix/file.c`) |
| 2 | measured and rejected (`ntdll/heap.c`, `xtajit64/vkmt/interp.c`) |
| 4 | profiled with no safe pure candidate |
| 8 | protected/boundary-blocked |

The 12 remaining rows have no promoted candidate. Four are explicitly
`PROFILED_NO_SAFE_CANDIDATE`; eight are protected or boundary-blocked. A
runtime gate passing is not treated as proof that one of their custom helpers
is hot or safe to rewrite. Their matrix rows retain a concrete next action.

## Remaining rows

| Path | Current disposition | Workload/boundary evidence | Why no promotion |
| --- | --- | --- | --- |
| `dlls/dwrite/freetype.c` | profiled/no safe candidate | CEF x86_64 OSR; graphics acceptance lane | Apple FreeType fallback is startup-only `dladdr`/path loading; no hot pure leaf isolated |
| `dlls/msvcrt/locale.c` | profiled/no safe candidate | acceptance lane ARM64EC and all-architecture smoke | Custom hunk is diagnostic-only logging; removing or changing it is not a runtime speed win |
| `dlls/ntdll/unix/env.c` | boundary | acceptance lane i386/WoW64 and VM receipts | PEB/NLS pointer translation and failure termination are guest-pointer boundaries |
| `dlls/ntdll/unix/socket.c` | boundary | acceptance lane i386/WoW64 network coverage | WSABUF/control/address conversion requires exact guest-size validation |
| `dlls/ntdll/unix/system.c` | profiled/no safe candidate | acceptance lane ARM64/ARM64EC startup | Darwin LSE `sysctl` publication is a small startup query, not a measured hot path |
| `dlls/win32u/freetype.c` | profiled/no safe candidate | CEF OSR and graphics acceptance lane | Bundled FreeType fallback and Fontconfig null guard are startup/availability paths |
| `dlls/win32u/sysparams.c` | lock-boundary | graphics/DXMT receipts | recursive user-lock unlock/relock protocol cannot be transformed without ownership proof |
| `dlls/winhttp/net.c` | TLS-boundary | CEF/browser runtime receipts | SSPI/TLS cleanup, certificate verification, and buffer ownership are security lifecycle code |
| `dlls/ws2_32/protocol.c` | API-state boundary | acceptance lane/browser networking receipts | NLA query allocation and one-shot state machine are ABI/API behavior, not a pure helper |
| `dlls/ws2_32/socket.c` | ordering boundary | prepared acceptance lane address-sort receipt | Stable IPv4/IPv6 ordering is semantic; no measured Chromium Happy-Eyeballs leaf candidate exists |
| `dlls/ws2_32/unixlib.c` | WoW64 boundary | acceptance lane i386/WoW64 and browser receipts | addrinfo/hostent host-to-guest publication and size checks must remain explicit |
| `dlls/xtajit64/cpu.c` | FEX boundary | FEX/acceptance lane invalidation receipts | callbacks, invalidation, process/thread lifecycle, and feature publication are protected |

## Accepted/rejected receipts

- Accepted scan: `docs/validation/optimization-file-scan-20260803/RESULTS.md`.
- Rejected heap candidate: `docs/validation/optimization-heap-index-20260803/RESULTS.md`.
- Rejected FEX candidate: `docs/validation/optimization-fex-mask-20260803/RESULTS.md`.
- Full candidate matrix: `docs/OPTIMIZATION_DISPOSITION.tsv`.

This review closes the current safe-candidate pass: four rows have no safe
pure leaf and eight remain protected/boundary code. A future workload may
reopen a row only if it isolates a pure leaf. It does not authorize
whole-file rewrites, pointer or lock transformations, TLS changes, FEX
callback changes, or semantic ordering changes.
