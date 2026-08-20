# MetalSharp bundle contents and VKMT integration

## Scope

The MetalSharp `bundles` release was downloaded to the external drive, checked
against GitHub SHA-256 values, decompressed with zstd integrity checks, and
inventoried member-by-member. The complete catalog remains in
`docs/metalsharp-bundle-catalog.tsv` and `docs/metalsharp-bundle-files.tsv`.

The catalog covers 11 release assets, 16,084 archive members, 13,829 regular
files, 1,726 directories, and 529 symlinks. No absolute or traversal archive
member was accepted.

## Integration decisions

| Bundle family | VKMT disposition |
| --- | --- |
| Runtime host and graphics | Do not copy x86_64 Unix bridges into the ARM64 host. Rebuild or retain matched VKMT ARM64 providers. |
| Developer SDK | Use contracts, path vocabulary, probes, and compatibility notes as source guidance only. Do not ship its diagnostics. |
| ARM64 Mono | Candidate managed-runtime input after independent source, license, and application validation. |
| FNA/FAudio | Use the existing Wine Mono FNA/XNA and FAudio lanes; keep profiles optional and path-stable. |
| Steam/frontend | Import only launch metadata and runtime-independent compatibility ideas. Do not import updater scripts or destructive cleanup behavior. |
| Assets and fonts | Promote only files with clear provenance and a verified architecture/license receipt. |

## Findings

- The MetalSharp runtime and graphics archives contain x86_64 Unix binaries;
  direct replacement of VKMT's ARM64 host bridge is unsafe.
- Six GPTK symlinks resolve to a wrong relative path in the released layout.
- Some runtime manifests contain duplicate nested `etc/etc` paths.
- The XNA payload contains seven byte-identical placeholder DLL names.
- The developer SDK's embedded runtime and graphics hashes do not match the
  current release assets, so release metadata must be treated as provenance,
  not as a current package manifest.
- A source-built ARM64 Unity Mono BleedingEdge 6.13.0 engine and its managed
  profiles are included under `dependencies/unity-mono/`, with a revision and
  build receipt. Proprietary FMOD SDK binaries are not present because no
  redistributable SDK receipt was available; FAudio and Wine Mono provide the
  included compatibility routes rather than a fabricated FMOD replacement.

## VKMT defaults

`runtime/dxmt.conf` is the normalized default profile:

```text
dxmt.metalShaderVersion = 310
d3d11.maxFeatureLevel = 12_1
d3d11.metalSpatialUpscaleFactor = 2.0
d3d11.preferredMaxFrameRate = 60
```

`DXMT_CONFIG_FILE` is set by `scripts/vkmt-runtime-env.sh` and can be replaced
by an explicit application profile. The shipped runtime package includes the
profile and excludes development diagnostics.

## Acceptance boundary

Use the release inventory, `scripts/verify-runtime.sh`, and the external fresh
installation receipt together. Source presence alone does not prove runtime
compatibility. The published package passed hash, architecture, configuration,
no-tracing, fresh `wineboot`, and four-lane single-prefix checks.
