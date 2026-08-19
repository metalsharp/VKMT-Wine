# Final VKMT roadmap package receipt

Date: 2026-08-19

## Archive

* Archive: `MetalSharp-Wine-Runtime-COMPLETE-all-arch-2026-07-31.tar.zst`
* SHA-256: `b62e651ed723d28be007d6fc3fcdcd6f180daad8f0d2c341eeb339c4167fccee`
* Parts: four ordered parts, split at 400,000,000 bytes.
* `zstd --long=31 -t`: PASS.
* Reassembly byte comparison and SHA-256: PASS (`VKMT_REASSEMBLY_OK`).

## Manifest comparison

The normalized final manifest was compared with the original release
manifest before publication:

* Original entries: 45,892
* Final entries: 45,911
* Original entries missing from final: 0
* Added entries: 19 (the explicit v1.0 graphics overlay, audits, validation
  receipts, and release verification scripts; plus the empty build directory).

## Installer and runtime gate

The regenerated installer uses the `metalsharp/VKMT-Wine` repository, the
final archive/part hashes, `--long=31` decoding, and an external-drive default
target. `--prepare-only --local-only` passed, followed by a full transactional
installation at:

```text
/Volumes/AverySSD/VKMT-roadmap-work/runtime-final
```

The installed target passed the release-installation architecture gate:

```text
P6_SINGLE_PREFIX_ARM64_OK
P6_SINGLE_PREFIX_ARM64EC_OK
P6_SINGLE_PREFIX_X86_64_OK
P6_SINGLE_PREFIX_I386_OK
P6_SINGLE_PREFIX_ALL_ARCHITECTURES_OK
status=0
```

The temporary prefix and wineserver were stopped and removed by the gate.
