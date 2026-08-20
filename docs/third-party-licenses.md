# VKMT third-party license and provenance index

This index documents the third-party software, source snapshots, runtime
payloads, legal receipts, and redistribution boundaries for VKMT. It is paired
with the [complete runtime inventory](runtime-inventory.md).

The paths in this document are relative to an installed runtime root unless
the path is explicitly described as a repository path. The release manifest,
metadata/SHA256SUMS, and the legal files shipped beside a component control the
exact contents of a particular build.

## Read this first

VKMT is an integration, not a relicensing of the software it packages.

1. The root LICENSE applies to VKMT-authored material in the current source
   repository where no more specific upstream notice applies.
2. Wine, FEX, DXMT, DXVK, VKD3D-Proton, MoltenVK, Mono, SDL, Java, GStreamer,
   browser, media, and utility components retain their own licenses.
3. A patch that contains or modifies upstream code remains governed by that
   upstream license. The MIT badge on the repository does not turn an LGPL,
   GPL, Apache, zlib, proprietary, or mixed-license component into MIT.
4. The VKMT-1.0 archive contains an older embedded source snapshot. Its
   source/SOURCE-PROVENANCE.txt identifies PolyForm Noncommercial terms for
   identified MetalSharp-owned files in that snapshot. The current repository
   LICENSE does not retroactively change the terms recorded inside that
   already-published archive.
5. Before redistributing a new runtime, retain the component notices, provide
   source or the required written offer for copyleft components, and remove
   private or unreceipted payloads.

This is a provenance and packaging index, not a substitute for the license
texts or legal advice.

## License and release identity

| Item | Current status | Evidence |
| --- | --- | --- |
| VKMT-authored current repository material | MIT, subject to upstream notices and file-level exceptions | LICENSE |
| Public runtime release | VKMT-1.0 | GitHub release tag and .metalsharp-runtime-install in the staged runtime |
| Published runtime archive | Runtime-only archive with embedded legal/provenance material | source/SOURCE-PROVENANCE.txt, metadata/PROVENANCE.txt |
| Third-party license index in the release | Included with the source snapshot | source/third-party-licenses/README.md |
| Exact release bytes | Receipt-controlled | metadata/SHA256SUMS, release asset manifest, PARTS-SHA256SUMS.txt |

## Component ledger

### Core execution and graphics

| Component | Runtime paths | Version or revision | License | Local evidence and status |
| --- | --- | --- | --- | --- |
| Wine | wine/build-ec/wine, server, dlls, programs, libs, fonts | Wine 11.12; commit 14c236a84fdb | LGPL-2.1-or-later | source/third-party-licenses/Wine-LICENSE.txt and Wine-LGPL-2.1.txt; included |
| VKMT Wine modifications | Wine-derived files and patches | VKMT patch set | Wine/upstream terms for derived code | patches/, source/nested-source/Wine-14c236a84fdb/, and NOTICE-METALSHARP.md; not a blanket MIT relicensing |
| FEX | FEX-backed WoW64 execution | commit a4128f01913d25d49f0d1cd1f62668327de1815e | MIT | source/third-party-licenses/FEX-LICENSE.txt; included through the required providers |
| FEXCore | FEX JIT/core implementation | pinned with FEX | MIT | source/third-party-licenses/FEXCore-LICENSE.txt; included through FEX |
| xtajit | Required i386/WoW64 provider | Wine/FEX VKMT integration | Wine and FEX applicable terms | providers/xtajit-arm64-known-good.dll and wine/wine-11.12/runtime-providers; required, retained |
| xtajit64 | Required x86_64 provider | Wine/FEX VKMT integration | Wine and FEX applicable terms | providers/xtajit64-arm64ec-known-good.dll and wine/wine-11.12/runtime-providers; required, retained |
| DXMT | Metal D3D10/D3D11/DXGI and winemetal bridges | v0.80; commit 00754a65ec36458ec6045109355ed7eb8777d08e | MIT | source/third-party-licenses/DXMT-LICENSE.txt; included |
| DXVK / DXVK-MacOS | D3D8/9/10/10.1/11 and DXGI guest lanes | Release-specific build; source path graphics/dxvk | zlib/libpng | source/third-party-licenses/DXVK-LICENSE.txt; included |
| VKD3D-Proton | D3D12 and D3D12core guest lanes | Release-specific build; source path graphics/vkd3d-proton | LGPL-2.1-or-later | source/third-party-licenses/vkd3d-proton-COPYING.txt and vkd3d-proton-LICENSE.txt; included |
| MoltenVK | Vulkan-to-Metal runtime | commit 1be06988d7363934bc8934ebce44976399009e1b | Apache-2.0 | source/third-party-licenses/MoltenVK-LICENSE.txt; included |
| innoextract | Native ARM64 installer extraction | commit 67b64201771960eff32e41e88426553df255f370 | Permissive three-clause license | source/third-party-licenses/innoextract-LICENSE.txt; included in installer-runtime |
| MetalSharp OpenGL sidecar | Native ARM64 OpenGL/Metal route | VKMT build output | VKMT/project or upstream terms as marked by the source | graphics/opengl-metal and source provenance; inspect the component notice before redistribution |
| D3DMetal/GPTK | Optional private Apple graphics bridge; not in VKMT-1.0 | Sikarugir documents 1.1, 2.0, 2.1, and 3.0; no source or binary in Sikarugir | Apple proprietary, non-commercial GPTK terms plus listed open-source notices | D3DMetal.md, scripts/stage-d3dmetal-runtime.sh, and a user-supplied Apple license/acknowledgements receipt; never assume MIT or public-release eligibility |

The x86_64 and i386 execution providers are not optional diagnostics. Their
binaries, candidate variants, hashes, and runtime-provider copies remain part
of the supported runtime coverage.

### Managed runtimes, media, and system libraries

| Component | Runtime paths | Version or revision | License | Local evidence and status |
| --- | --- | --- | --- | --- |
| Wine Mono | dependencies/wine-mono/wine-mono-11.2.0 | 11.2.0 | Mixed GPL, LGPL, MIT/X11, Apache, BSD, MSPL, and dependency-specific terms | source/third-party-licenses/Wine-Mono-COPYING.txt and runtime-manifests/wine-mono-11.2.0.txt; included |
| FNA/XNA/FAudio managed assets | Wine Mono lib/mono and lib/x86, lib/x86_64 | Shipped with Wine Mono 11.2.0 | Mixed; FNA dependencies include zlib, MIT, and MSPL components | Wine-Mono-COPYING.txt; included compatibility route |
| FAudio native build | wine/build-ec/libs/faudio | VKMT per-guest build outputs | FAudio upstream terms | FAudio is part of the Wine Mono/FAudio compatibility closure; retain upstream notice |
| Unity Technologies Mono | dependencies/unity-mono/unity-main-6.13.0 | revision 54681c7b4fdf8316b86063a8e8dcf2a0d99bdd03 | Unity Technologies Mono terms and included notices | runtime-manifests/unity-mono-6.13.0.txt; included ARM64 engine |
| Unity 6000.1 Mono | dependencies/unity-mono/unity-6000.1-mbe-6.13.0 | revision e350143e2a9d66fad73c5d575a874b9901978395 | Unity Technologies Mono terms and included notices | runtime-manifests/unity-mono-6000.1-mbe-6.13.0.txt; included ARM64 engine |
| Unity 2022.3 Mono | dependencies/unity-mono/unity-2022.3-mbe-6.13.0 | revision b8eb56fab45dd52845fabba7b7ddc9a80b2b0498 | Unity Technologies Mono terms and included notices | runtime-manifests/unity-mono-2022.3-mbe-6.13.0.txt; included ARM64 engine |
| GStreamer | wine/build-ec/runtime/gstreamer-arm64 and dependencies/gstreamer-arm64 | Staged ARM64 closure | LGPL core with plugin- and codec-specific terms | MANIFEST.sha256 controls the files; retain GStreamer and plugin notices for each release |
| GnuTLS | dependencies/gnutls-arm64 | ARM64 closure | GnuTLS library/tool license set; library is LGPL-family, dependencies retain their own terms | crypt32/secur32 and native closure are staged; standalone release notice should accompany the closure |
| FreeType | dependencies/libfreetype.6.dylib and Wine font closure | Staged ARM64 library | FreeType License or GPL-2.0-or-later alternative | Native dylib is included; retain FreeType notice |
| FFmpeg | wine/build-ec/libs/ffmpeg and GStreamer codec plugins | Build-dependent | LGPL/GPL components depending on enabled codecs and configuration | Do not summarize the entire codec closure as one license; inspect enabled components |
| FluidSynth | wine/build-ec/libs/fluidsynth and media closure | Build output | LGPL-2.1-or-later | Retain upstream notice |
| SDL2 | wine/build-ec/sdl-runtime/aarch64, arm64ec, x86_64, i386 | 2.32.10; upstream 5d249570393f7a37e037abf22cd6012a4cc56a71; build 8f57bf76c15f5ddade4a1156ed24462da5ef5fe2 | zlib | sdl-runtime/manifest.txt and SDL2 SDL_copying.h; included |
| SDL3 | wine/build-ec/sdl-runtime/aarch64, arm64ec, x86_64, i386 | 3.4.10; upstream 8e37db5e797b6167f3a00d697d816a684bd259c7; build 1f46ec8b0761a248448371735ee020f1f58703e4 | zlib | sdl-runtime/manifest.txt and SDL3 source notice; included |
| Wine CoreAudio | wine/build-ec/dlls/winecoreaudio.drv | Wine module | Wine LGPL terms plus Apple system API terms | Included as part of Wine; no separate proprietary CoreAudio SDK is packaged |

The Wine build also contains library families under wine/build-ec/libs for
ICU, libjpeg, JPEG XR, LCMS2, LDAP, mpg123, PNG, SQLite3, TIFF, XML2, XSLT,
zlib, musl/compiler runtime support, and related compatibility libraries.
Those libraries retain their own upstream terms. Internal Wine GUID, import,
CRT, and compatibility objects are governed by Wine or their source notices;
the directory name alone is not a license declaration.

### Upstream source index

These are the source authorities for the component families in the ledger:

- [Wine](https://github.com/wine-mirror/wine)
- [FEX](https://github.com/FEX-Emu/FEX) and FEXCore
- [DXMT](https://github.com/3Shain/dxmt)
- [DXVK-MacOS](https://github.com/Gcenx/DXVK-macOS) and
  [DXVK](https://github.com/doitsujin/dxvk)
- [VKD3D-Proton](https://github.com/HansKristian-Work/vkd3d-proton)
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK)
- [innoextract](https://github.com/dscharrer/innoextract)
- [Wine Mono](https://github.com/wine-mono/wine-mono) and its FNA/XNA/FAudio
  compatibility dependencies
- [Unity Technologies Mono](https://github.com/Unity-Technologies/mono)
- [SDL](https://github.com/libsdl-org/SDL)
- [GStreamer](https://gstreamer.freedesktop.org/)
- [GnuTLS](https://gitlab.com/gnutls/gnutls)
- [FreeType](https://gitlab.freedesktop.org/freetype/freetype)
- [Wine Gecko](https://gitlab.winehq.org/wine/wine-gecko)
- [Eclipse Temurin](https://github.com/adoptium/temurin8-binaries)
- [Eclipse ECJ](https://projects.eclipse.org/projects/eclipse.jdt.core)
- [Heroic gogdl](https://github.com/Heroic-Games-Launcher/heroic-gogdl)
- [xdelta3](https://github.com/jmacd/xdelta)
- [PyInstaller](https://pyinstaller.org/), [requests](https://requests.readthedocs.io/),
  and [urllib3](https://urllib3.readthedocs.io/)

Source URLs are references, not substitutes for the revision, hash, or legal
receipt shipped with the runtime.

### Browser, Java, and integration payloads

| Component | Runtime paths | Version or revision | License | Local evidence and status |
| --- | --- | --- | --- | --- |
| Wine Gecko | dependencies/wine-gecko/wine-gecko-2.47.4-x86 and wine-gecko-2.47.4-x86_64 | 2.47.4 | Mozilla/Wine Gecko component license set, including MPL/GPL/LGPL-covered code and notices | Included x86 and x86_64 browser payloads; retain the package's legal files |
| Eclipse Temurin JRE | wine/build-ec/java-runtime/i386 and x86_64 | 8u472-b08 i386; 8u492-b09 x86_64 | GPL-2.0 with Classpath Exception, plus third-party notices | Each staged Java tree contains LICENSE, NOTICE, THIRD_PARTY_README, and PROVENANCE.txt |
| Oracle JRE | Manifest only: runtime-manifests/oracle-jre-8u501-arm64.txt | 8u501 ARM64 | Oracle proprietary terms | Marked private and do not redistribute; not a release payload |
| Eclipse ECJ | Build manifest: runtime-manifests/eclipse-ecj-4.6.1.txt | 4.6.1 | Eclipse Public License terms | Build-only Java fixture compiler; not part of the shipped Oracle JRE or release runtime |
| Heroic gogdl | integration/gog/bin/gogdl | 1.2.2; revision 4928e46d1fc4e8f230fe45de277acb8358cbdd69 | GPL-3.0 | integration/gog/licenses/heroic-gogdl-GPL-3.0.txt and PROVENANCE.tsv; included |
| xdelta3 | Bundled through integration/gog | 3.x; revision 0525275fe4b553a10f38e455d30c60dc6ed9b45d | Apache-2.0 | integration/gog/metadata/PROVENANCE.tsv; included dependency |
| PyInstaller | Bundled GOG executable dependency | 6.16.0 | GPL-2.0-or-later with bootloader exception | integration/gog/metadata/PROVENANCE.tsv; included dependency |
| requests | Bundled GOG Python dependency | 2.32.5 | Apache-2.0 | integration/gog/metadata/PROVENANCE.tsv |
| urllib3 | Bundled GOG Python dependency | 1.26.20 | MIT | integration/gog/metadata/PROVENANCE.tsv |
| Steam WebHelper wrapper | integration/steam-webhelper and source/MetalSharp-WebHelper | VKMT integration | Historical MIT grant for the wrapper; embedded Steam payload retains its own terms | source/third-party-licenses/MetalSharp-MIT-Legacy.txt; do not use this file to license the whole runtime |

## Exact legal receipts in VKMT-1.0

The published runtime source snapshot contains these primary license texts:

~~~text
source/third-party-licenses/DXMT-LICENSE.txt
source/third-party-licenses/DXVK-LICENSE.txt
source/third-party-licenses/FEX-LICENSE.txt
source/third-party-licenses/FEXCore-LICENSE.txt
source/third-party-licenses/innoextract-LICENSE.txt
source/third-party-licenses/MetalSharp-MIT-Legacy.txt
source/third-party-licenses/MoltenVK-LICENSE.txt
source/third-party-licenses/vkd3d-proton-COPYING.txt
source/third-party-licenses/vkd3d-proton-LICENSE.txt
source/third-party-licenses/Wine-LGPL-2.1.txt
source/third-party-licenses/Wine-LICENSE.txt
source/third-party-licenses/Wine-Mono-COPYING.txt
source/third-party-licenses/README.md
~~~

Additional component-local receipts are:

~~~text
wine/build-ec/java-runtime/i386/LICENSE
wine/build-ec/java-runtime/i386/NOTICE
wine/build-ec/java-runtime/i386/THIRD_PARTY_README
wine/build-ec/java-runtime/i386/PROVENANCE.txt
wine/build-ec/java-runtime/x86_64/LICENSE
wine/build-ec/java-runtime/x86_64/NOTICE
wine/build-ec/java-runtime/x86_64/THIRD_PARTY_README
wine/build-ec/java-runtime/x86_64/PROVENANCE.txt
integration/gog/licenses/heroic-gogdl-GPL-3.0.txt
integration/gog/metadata/PROVENANCE.tsv
integration/gog/metadata/SHA256SUMS
wine/build-ec/sdl-runtime/manifest.txt
wine/build-ec/runtime/gstreamer-arm64/MANIFEST.sha256
metadata/PROVENANCE.txt
metadata/SHA256SUMS
~~~

The license index file in the release is the authoritative map for those
copied texts. A future package must not remove a legal file merely because the
corresponding binary is not selected on the default launch path.

## Receipt coverage and open documentation items

The following table makes the current legal-receipt boundary explicit. A
component marked “upstream notice required” is documented here but should have
its full notice copied into the next release's source/third-party-licenses/
directory before redistribution.

| Component family | Current receipt state | Required next-release action |
| --- | --- | --- |
| Wine, FEX/FEXCore, DXMT, DXVK, VKD3D-Proton, MoltenVK, innoextract | Primary license texts are present in source/third-party-licenses/ | Keep texts, source revisions, patches, and hashes together |
| Wine Mono and FNA/XNA/FAudio | Wine-Mono-COPYING and version manifest present | Preserve the mixed-license dependency notices from the Wine Mono source |
| SDL2/SDL3 | Version/commit manifest and SDL copying headers present | Preserve the upstream SDL notice with every staged version |
| Temurin Java | LICENSE, NOTICE, THIRD_PARTY_README, and PROVENANCE present per architecture | Preserve the legal files beside both Java trees |
| GOG integration | GPL notice, dependency provenance, and SHA256SUMS present | Preserve all five dependency rows and the GPL notice |
| Unity Mono | Build/version manifests present; Unity source notices are referenced | Retain the Unity source notice set beside all three engines |
| GStreamer and codec plugins | Closure hash manifest present; plugin licenses vary | Add or retain a complete plugin/codec notice set for the exact manifest |
| GnuTLS and native dependency closure | Staged and hashed; no standalone aggregate notice in the current index | Copy upstream GnuTLS and dependency notices before a new redistribution |
| FreeType | Staged native library; no standalone release notice in the current index | Copy the FreeType notice beside the staged dylib |
| Wine Gecko | x86/x86_64 payloads staged; package-specific legal files are not in the primary index | Retain Wine Gecko/Mozilla legal files for the exact package build |
| FFmpeg, FluidSynth, and Wine media libraries | Present through Wine/GStreamer build outputs; component licenses vary | Record enabled codecs and copy the corresponding notices |
| MetalSharp OpenGL sidecar | Present in the runtime; ownership notice is not represented by a primary upstream license file here | Add an explicit source/license receipt before the next package |

This table is intentional: documentation must not imply a clean legal receipt
where the current staged artifact only has a hash or a provenance line.

## Source provenance and pinned revisions

The current VKMT-1.0 runtime receipt records:

| Source | Revision |
| --- | --- |
| VKMT integration | 6a5140a767f51530c3860821c43107202e17b579 |
| Wine | 14c236a84fdb |
| FEX | a4128f01913d25d49f0d1cd1f62668327de1815e |
| DXMT | 00754a65ec36458ec6045109355ed7eb8777d08e |
| MoltenVK | 1be06988d7363934bc8934ebce44976399009e1b |
| innoextract | 67b64201771960eff32e41e88426553df255f370 |

SDL, Unity Mono, Wine Mono, Java, GOG, and other dependency revisions are
recorded in runtime-manifests, sdl-runtime/manifest.txt, integration/gog/
metadata/PROVENANCE.tsv, and component-local PROVENANCE.txt files. Do not
replace those receipts with a generic “third-party dependencies” statement.

## Included, private, build-only, and excluded

### Included under upstream terms

The VKMT-1.0 runtime includes the Wine/FEX/DXMT/DXVK/VKD3D-Proton/MoltenVK
graphics and execution stack, Wine Mono/FNA/XNA/FAudio, Unity Mono engines,
GStreamer, GnuTLS, FreeType, SDL2/SDL3, Wine Gecko, Temurin Java, innoextract,
GOG support, and the associated notices listed above.

### Private or not redistributable

- Oracle JRE 8u501 ARM64 is only represented by a private manifest and is not
  a redistributable VKMT release asset.
- Any payload with a missing or incompatible license receipt must remain
  outside a release until its terms are verified.
- FMOD SDK/runtime binaries are not included because no redistributable SDK
  receipt is present.

### Build-only inputs

- Eclipse ECJ is a build-only Java fixture dependency.
- Inno Setup executables under third_party/ are fixture/build inputs, not
  runtime components.
- Toolchains, ignored upstream build trees, and disposable test assets are
  not release payloads.
- Download-only CEF, Electron, WebView2, and other browser SDKs used by
  optional build scripts are not asserted as included unless a release
  manifest explicitly lists them.

### Explicitly outside VKMT scope

Rosetta, proprietary Apple or Microsoft runtime packages, commercial FMOD SDK
content, and unrelated MetalSharp application bundles are not part of the
public VKMT runtime. D3DMetal/GPTK is documented as a private, opt-in
provider only; it is not included or licensed by the public VKMT release.

## Redistribution checklist

Before publishing a new VKMT runtime:

- keep LICENSE and this index in the source snapshot;
- copy every primary upstream notice required by a shipped component;
- keep the source snapshot, patch set, and provenance for Wine/FEX/DXMT and
  every LGPL/GPL-derived component;
- retain Java LICENSE, NOTICE, THIRD_PARTY_README, and PROVENANCE files;
- retain the GOG GPL notice and its complete dependency provenance;
- verify the release manifest and metadata/SHA256SUMS after legal files are
  staged;
- exclude Oracle JRE, FMOD, public GPTK/D3DMetal payloads, and any unreceipted payload;
- require the separate D3DMetal provider and Wine-loader receipts before any
  private, non-commercial staging;
- do not remove xtajit64, xtajit, candidate provider variants, or other
  required runtime DLLs under the cleanup policy; and
- rerun the runtime verifier after any legal-file or package-layout change.

The clean-runtime policy removes development audits, roadmaps, probes, logs,
prefixes, and validation evidence. It does not remove required runtime
binaries or their license notices.
