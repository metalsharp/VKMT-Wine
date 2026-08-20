# Security policy

## Supported versions

| Version or branch | Status |
| --- | --- |
| `main` | Supported |
| `VKMT-1.0` | Supported release |
| Older tags | Not supported |

VKMT is an Apple-Silicon-native Wine runtime assembled from Wine, FEX, DXMT,
DXVK, VKD3D-Proton, MoltenVK, and other separately licensed components. A
security report may affect VKMT integration, the build/staging scripts, the
release installer, or an upstream component. Upstream component issues should
also be reported to the relevant upstream project.

## Reporting a vulnerability

Please do **not** open a public issue for an unpatched vulnerability. Send a
private report to [averyfelts@aol.com](mailto:averyfelts@aol.com) with:

- a concise description and impact;
- the affected tag, commit, runtime path, or release asset;
- reproduction steps or a minimal proof of concept;
- relevant logs, hashes, and platform details; and
- any proposed mitigation, if available.

Do not send passwords, private keys, personal data, complete Wine prefixes, or
large runtime archives. Use the release SHA-256 receipts to identify payloads.

We will acknowledge a report when practical, triage the impact, coordinate a
fix or upstream disclosure, and publish a release note when remediation is
available. Please allow reasonable time for coordinated disclosure before
publishing details.

## Runtime security boundaries

- Verify `metadata/SHA256SUMS`, the release part hashes, and the installer
  receipt before activating a runtime.
- Keep `WINEPREFIX`, application data, shader caches, and logs outside the
  immutable runtime root.
- Do not replace `xtajit`, `xtajit64`, graphics bridges, or native libraries
  with unverified binaries. Provider and graphics staging must remain
  receipt-backed.
- Do not run release archives or build scripts from an untrusted working
  directory. Review shell, Python, Rust, and installer changes before use.
- Third-party components retain their own security advisories and licenses;
  see [the third-party license index](docs/third-party-licenses.md).

## Scope

This policy covers the VKMT repository, its release installer and packaging
logic, published release metadata, and the integration contracts that select
runtime providers. It does not replace the security policies of Wine, FEX,
DXMT, DXVK, VKD3D-Proton, MoltenVK, or other bundled projects.
