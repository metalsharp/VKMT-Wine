# Native ARM64 FEX lane note

The same x86_64 release DLLs were also loaded in a fresh ARM64 VKMT/FEX
prefix. `d3d12_probe.exe` returned status 0 and logged the Apple M4 adapter,
but the old published probe binary reported the native FEX feature query
incorrectly. A fresh probe built from the release repository was therefore
used for the accepted x86_64 lane above. The complete raw ARM64 run remains in
`VKMT-arm64-fex-compatibility.log` so this distinction is auditable.
