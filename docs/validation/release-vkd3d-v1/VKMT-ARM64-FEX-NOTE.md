# Native ARM64 FEX lane note

The same x86_64 release DLLs were also loaded in a fresh ARM64 VKMT/FEX
prefix. `d3d12_probe.exe` returned status 0 and logged the Apple M4 adapter,
but the requested feature ladder did not pass through the ARM64 FEX route.
That raw compatibility result was retained during the review and summarized
here before temporary logs were removed. The x86_64 overlay is therefore not
copied over the native ARM64, ARM64EC, or i386 graphics directories.
