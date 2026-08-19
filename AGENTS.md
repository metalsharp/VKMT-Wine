# VKMT repository contract

VKMT is an Apple-Silicon-native Wine runtime. Keep host executables and Unix
libraries ARM64-only; x86_64 and i386 are Windows guest architectures handled
by the integrated ARM64 providers. Rosetta and hardware TSO are not supported.

## Preservation

Do not delete or wholesale rebuild generated Wine, FEX, graphics, toolchain,
patch, script, test, or documentation inputs without inspecting the replacement
artifact. Large generated trees are intentionally ignored by Git. Runtime
release work belongs on `/Volumes/AverySSD` and disposable prefixes must be
stopped and removed after use.

## Build policy

Prefer targeted component builds over a full Wine rebuild. Use the pinned
sources and patches in this checkout, keep provider hashes in staging receipts,
and never promote guessed ARM64EC or native-host binaries. Separately licensed
Java, browser, Mono, FMOD, and Unity payloads require provenance before they can
be distributed.

## Runtime policy

Every launch path must set:

```text
FEX_TSOENABLED=0
FEX_VECTORTSOENABLED=0
FEX_MEMCPYSETTSOENABLED=0
```

The default DXMT profile is `runtime/dxmt.conf`. `scripts/vkmt-runtime-env.sh`
selects it and confines native dependency lookup to the bundled ARM64 closure.
The release verifier is `scripts/verify-runtime.sh`; it performs read-only
architecture, hash, configuration, tracing, and cleanup checks.

## Release contract

A release is accepted only after:

1. all assets and four ordered archive parts have verified SHA-256 values;
2. the package contains the required ARM64 host, guest graphics, providers,
   managed/media, fonts, and configuration assets;
3. a fresh external-drive installation preserves any existing runtime;
4. `wineboot --init` returns zero in a disposable prefix;
5. ARM64, ARM64EC, x86_64, and i386/WoW64 execute in one disposable prefix;
6. no tracing, diagnostics, audits, plans, roadmaps, probes, prefixes, or logs
   are shipped in the runtime.

The checked-in source contains build/staging machinery, not generated runtime
binaries. The redistributable package is produced by
`scripts/package-runtime-release.sh` and is verified with
`scripts/verify-runtime.sh`.
