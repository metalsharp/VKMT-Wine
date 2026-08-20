#!/bin/bash
# Verify a staged VKMT runtime without creating a prefix or starting Wine.
set -euo pipefail

ROOT="${VKMT_RUNTIME_ROOT:-}"
usage() { echo "usage: verify-runtime.sh --runtime-root PATH" >&2; exit 2; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime-root) [ "$#" -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

die() { echo "verify-runtime: $*" >&2; exit 1; }
[ -n "$ROOT" ] && [ -d "$ROOT" ] || usage

required=(
  "$ROOT/.metalsharp-runtime-install"
  "$ROOT/wine/build-ec/wine"
  "$ROOT/wine/build-ec/server/wineserver"
  "$ROOT/wine/build-ec/programs/wineboot/aarch64-windows/wineboot.exe"
  "$ROOT/wine/build-ec/dxmt-v0.80/aarch64-unix/winemetal.so"
  "$ROOT/wine/build-ec/dxmt-v0.80/aarch64-windows/winemetal.dll"
  "$ROOT/wine/build-ec/dxmt-v0.80/i386-windows/winemetal.dll"
  "$ROOT/runtime/dxmt.conf"
  "$ROOT/scripts/vkmt-runtime-env.sh"
  "$ROOT/metadata/SHA256SUMS"
)
for path in "${required[@]}"; do
  [ -e "$path" ] || die "missing $path"
done

unity_mono_roots=(
  "$ROOT/dependencies/unity-mono/unity-main-6.13.0"
  "$ROOT/dependencies/unity-mono/unity-6000.1-mbe-6.13.0"
  "$ROOT/dependencies/unity-mono/unity-2022.3-mbe-6.13.0"
)
for unity_root in "${unity_mono_roots[@]}"; do
  [ -x "$unity_root/bin/mono" ] || die "missing Unity Mono engine: $unity_root"
  [ -f "$unity_root/lib/libmonosgen-2.0.1.dylib" ] || die "missing Unity Mono SGen: $unity_root"
  [ "$(/usr/bin/lipo -archs "$unity_root/bin/mono")" = arm64 ] || die "non-ARM64 Unity Mono engine: $unity_root"
  [ "$(/usr/bin/lipo -archs "$unity_root/lib/libmonosgen-2.0.1.dylib")" = arm64 ] || die "non-ARM64 Unity Mono SGen: $unity_root"
  grep -Fqx 'version=6.13.0' "$unity_root/BUILD-INFO.txt" || die "Unity Mono metadata mismatch: $unity_root"
done

for host in "$ROOT/wine/build-ec/wine" "$ROOT/wine/build-ec/server/wineserver"; do
  [ "$(/usr/bin/lipo -archs "$host")" = arm64 ] || die "non-ARM64 host: $host"
done
if translated="$(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null)"; then
  [ "$translated" = 0 ] || die "Rosetta is active"
fi

grep -Fqx 'dxmt.metalShaderVersion = 310' "$ROOT/runtime/dxmt.conf" || die 'DXMT shader version mismatch'
grep -Fqx 'd3d11.maxFeatureLevel = 12_1' "$ROOT/runtime/dxmt.conf" || die 'DXMT feature level mismatch'
grep -Fqx 'd3d11.metalSpatialUpscaleFactor = 2.0' "$ROOT/runtime/dxmt.conf" || die 'DXMT upscale mismatch'
grep -Fqx 'd3d11.preferredMaxFrameRate = 60' "$ROOT/runtime/dxmt.conf" || die 'DXMT frame-rate mismatch'
grep -Fqx 'export FEX_TSOENABLED=0' "$ROOT/scripts/vkmt-runtime-env.sh" || die 'TSO policy missing'
grep -Fqx 'export FEX_VECTORTSOENABLED=0' "$ROOT/scripts/vkmt-runtime-env.sh" || die 'vector TSO policy missing'
grep -Fqx 'export FEX_MEMCPYSETTSOENABLED=0' "$ROOT/scripts/vkmt-runtime-env.sh" || die 'memcpy TSO policy missing'

for arch in aarch64 arm64ec x86_64 i386; do
  for dll in d3d11.dll d3d9.dll dxgi.dll; do
    [ -f "$ROOT/graphics/dxvk/$arch/$dll" ] || die "missing DXVK $arch/$dll"
  done
done
for dll in d3d10core.dll d3d10.dll d3d10_1.dll; do
  [ -f "$ROOT/graphics/dxvk/aarch64/$dll" ] || die "missing DXVK aarch64/$dll"
done
for arch in arm64ec x86_64 i386; do
  [ -f "$ROOT/graphics/dxvk/$arch/d3d10core.dll" ] || die "missing DXVK $arch/d3d10core.dll"
done
for arch in aarch64 arm64ec x86_64 i386; do
  [ -f "$ROOT/graphics/vkd3d-proton/$arch/d3d12.dll" ] || die "missing VKD3D $arch/d3d12.dll"
  [ -f "$ROOT/graphics/vkd3d-proton/$arch/d3d12core.dll" ] || die "missing VKD3D core $arch"
done

if [ -f "$ROOT/metadata/MACHO-WITHOUT-ARM64.txt" ] &&
   [ -s "$ROOT/metadata/MACHO-WITHOUT-ARM64.txt" ]; then
  die 'runtime contains a Mach-O without ARM64'
fi
# The installer writes a fresh timestamped receipt after activation, so that
# one mutable file cannot be covered by the immutable package checksum list.
(cd "$ROOT" && sed '/  \.\/\.metalsharp-runtime-install$/d' metadata/SHA256SUMS | \
  shasum -a 256 -c - >/dev/null) || die 'payload hash mismatch'

for pattern in 'probe-*.sh' 'Audit*.md' 'audit*.md' '*roadmap*.md' 'PLAN.md' '*PLAN*.md'; do
  if find "$ROOT" -type f -iname "$pattern" -print -quit | grep -q .; then
    die "development artifact remains: $pattern"
  fi
done
[ ! -d "$ROOT/build" ] || [ -z "$(find "$ROOT/build" -mindepth 1 -print -quit)" ] || die 'build artifacts remain'

if grep -RIl --exclude='SHA256SUMS' --exclude='*.md' --exclude='verify-runtime.sh' \
    -E 'FEX_TRACE|VKMT_TRACE|WINEDEBUG=\+[a-z]' \
    "$ROOT/scripts" "$ROOT/runtime" 2>/dev/null | grep -q .; then
  die 'runtime tracing configuration remains'
fi

printf '%s\n' 'VKMT_RUNTIME_VERIFIED'
