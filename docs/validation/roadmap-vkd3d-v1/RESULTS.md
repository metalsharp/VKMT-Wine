# VKD3D-Proton-MacOS v1.0 release input

- archive: /Volumes/AverySSD/VKMT-roadmap-work/vkd3d-proton-macos-v1.0/vkd3d-proton-macos.tar.zst
- archive SHA-256: f1eabd729a65f0a62bcba9a3a8054bdef9895981351dc8896993a8cffa12299c
- host: Darwin arm64

---
/var/folders/0f/j2215w_s6yn7fv2w6l0crqnr0000gn/T//vkmt-vkd3d-release.iQC1uA/vkd3d-proton-macos/d3d12.dll:         PE32+ executable (DLL) (GUI) x86-64, for MS Windows
/var/folders/0f/j2215w_s6yn7fv2w6l0crqnr0000gn/T//vkmt-vkd3d-release.iQC1uA/vkd3d-proton-macos/d3d12core.dll:     PE32+ executable (DLL) (GUI) x86-64, for MS Windows
/var/folders/0f/j2215w_s6yn7fv2w6l0crqnr0000gn/T//vkmt-vkd3d-release.iQC1uA/vkd3d-proton-macos/dxgi.dll:          PE32+ executable (DLL) (console) x86-64, for MS Windows
/var/folders/0f/j2215w_s6yn7fv2w6l0crqnr0000gn/T//vkmt-vkd3d-release.iQC1uA/vkd3d-proton-macos/libMoltenVK.dylib: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit dynamically linked shared library x86_64] [arm64]
/var/folders/0f/j2215w_s6yn7fv2w6l0crqnr0000gn/T//vkmt-vkd3d-release.iQC1uA/vkd3d-proton-macos/libMoltenVK.dylib (for architecture x86_64):	Mach-O 64-bit dynamically linked shared library x86_64
/var/folders/0f/j2215w_s6yn7fv2w6l0crqnr0000gn/T//vkmt-vkd3d-release.iQC1uA/vkd3d-proton-macos/libMoltenVK.dylib (for architecture arm64):	Mach-O 64-bit dynamically linked shared library arm64
d3d12.dll: OK
d3d12core.dll: OK
dxgi.dll: OK
libMoltenVK.dylib: OK
MoltenVK_icd.json: OK
README.md: OK
---

The published DLL set is x86_64 PE for Wine/Rosetta. It is promoted only as
the explicit x86_64 graphics overlay; VKMT's native ARM64/ARM64EC/i386
directories retain their architecture-matched artifacts. A raw ARM64/FEX
compatibility run is retained separately and is not represented as a pass.
