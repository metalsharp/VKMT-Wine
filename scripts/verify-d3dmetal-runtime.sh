#!/bin/bash
# Verify an optional private D3DMetal provider without starting Wine.
set -euo pipefail

ROOT=""
PROVIDER_ONLY=0

die() {
  echo "verify-d3dmetal-runtime: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
usage: verify-d3dmetal-runtime.sh --runtime-root PATH [--provider-only]

The default mode requires both the private ARM64 provider and a matching
VKMT Wine loader contract. --provider-only verifies only the staged provider
and its legal/provenance receipt.
USAGE
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime-root)
      [ "$#" -ge 2 ] || usage
      ROOT="$2"
      shift 2
      ;;
    --provider-only)
      PROVIDER_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "$ROOT" ] || usage
[ -d "$ROOT" ] || die "runtime root does not exist: $ROOT"
for tool in /usr/bin/file /usr/bin/lipo /usr/bin/find /usr/bin/shasum /usr/bin/sed \
  /usr/bin/readlink /usr/bin/nm /usr/bin/otool; do
  [ -x "$tool" ] || die "required tool not found: $tool"
done

ROOT="$(cd "$ROOT" && pwd -P)"
PROVIDER="$ROOT/graphics/d3dmetal"
EXTERNAL="$PROVIDER/external"
FRAMEWORK="$EXTERNAL/D3DMetal.framework"
SHARED="$EXTERNAL/libd3dshared.dylib"
WINE_EXTERNAL="$ROOT/wine/lib/external"
if [ -x "$ROOT/wine/build-ec/tools/wine/wine" ]; then
  WINE_HOST="$ROOT/wine/build-ec/tools/wine/wine"
else
  WINE_HOST="$ROOT/wine/build-ec/wine"
fi

[ -d "$PROVIDER" ] || die "missing provider root: $PROVIDER"
[ -d "$FRAMEWORK" ] || die "missing D3DMetal.framework: $FRAMEWORK"
[ -f "$FRAMEWORK/Versions/Current/D3DMetal" ] || die "missing framework binary"
[ -f "$FRAMEWORK/Versions/Current/Resources/Info.plist" ] || die "missing framework Info.plist"
[ -f "$SHARED" ] || die "missing libd3dshared.dylib"
[ -f "$PROVIDER/PROVENANCE.txt" ] || die "missing provider provenance"
[ -f "$PROVIDER/SHA256SUMS" ] || die "missing provider hash receipt"
[ -f "$PROVIDER/legal/APPLE-GPTK-LICENSE" ] || die "missing Apple license receipt"
[ -f "$PROVIDER/legal/APPLE-GPTK-ACKNOWLEDGEMENTS" ] || die "missing Apple acknowledgements receipt"

grep -Fqx 'host_architecture=arm64' "$PROVIDER/PROVENANCE.txt" ||
  die "provider provenance does not require ARM64"
grep -Fqx 'distribution=private-noncommercial-only' "$PROVIDER/PROVENANCE.txt" ||
  die "provider provenance lacks private distribution boundary"
grep -Fqx 'wine_loader_contract=required-before-activation' "$PROVIDER/PROVENANCE.txt" ||
  die "provider provenance lacks Wine loader boundary"

# Hash the provider payload before any architecture checks. SHA256SUMS itself is
# intentionally excluded because it is the receipt being read.
(cd "$PROVIDER" && /usr/bin/sed '/  \.\/SHA256SUMS$/d' SHA256SUMS | /usr/bin/shasum -a 256 -c - >/dev/null) ||
  die "provider hash receipt mismatch"

check_link_inside() {
  local link="$1"
  local target
  local resolved
  local provider_real
  [ -L "$link" ] || die "required symlink is missing: $link"
  target="$(readlink "$link")"
  case "$target" in
    /*) die "absolute provider symlink: $link" ;;
  esac
  resolved="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
  provider_real="$(cd "$PROVIDER" && pwd -P)"
  case "$resolved" in
    "$provider_real"/*) ;;
    *) die "provider symlink escapes provider root: $link -> $target" ;;
  esac
}

check_link_inside "$FRAMEWORK/D3DMetal"
check_link_inside "$FRAMEWORK/Resources"
check_link_inside "$FRAMEWORK/Versions/Current"
[ -L "$WINE_EXTERNAL/D3DMetal.framework" ] || die "Wine external framework link is missing"
[ -L "$WINE_EXTERNAL/libd3dshared.dylib" ] || die "Wine external shared-library link is missing"
check_link_inside "$WINE_EXTERNAL/D3DMetal.framework"
check_link_inside "$WINE_EXTERNAL/libd3dshared.dylib"

check_arm64_macho() {
  local path="$1"
  local kind
  local arches
  kind="$(/usr/bin/file "$path")"
  case "$kind" in
    *"Mach-O"*) ;;
    *) die "provider member is not Mach-O: $path ($kind)" ;;
  esac
  arches="$(/usr/bin/lipo -archs "$path" 2>/dev/null)" || die "cannot inspect architectures: $path"
  [ "$arches" = arm64 ] || die "provider member is not arm64-only: $path ($arches)"
}

check_arm64_macho "$SHARED"
while IFS= read -r -d '' path; do
  kind="$(/usr/bin/file "$path")"
  case "$kind" in
    *"Mach-O"*) check_arm64_macho "$path" ;;
  esac
done < <(/usr/bin/find "$FRAMEWORK" -type f -print0)

# Validate the ABI that makes this a Sikarugir/GPTK provider rather than an
# arbitrary framework with a matching filename.  The Unix bridge must export
# Wine's dispatch table; the framework must expose the Direct3D entrypoints
# used by the D3D11/D3D12 guest lanes.
require_symbol() {
  local path="$1"
  local symbol="$2"
  /usr/bin/nm -gU "$path" 2>/dev/null | /usr/bin/grep -Eq "[[:space:]]${symbol}$" ||
    die "provider ABI symbol is missing: $symbol ($path)"
}

require_symbol "$SHARED" '___wine_unix_call_funcs'
require_symbol "$FRAMEWORK/Versions/Current/D3DMetal" '_CreateDXGIFactory'
require_symbol "$FRAMEWORK/Versions/Current/D3DMetal" '_D3D11CreateDevice'
require_symbol "$FRAMEWORK/Versions/Current/D3DMetal" '_D3D12CreateDevice'
require_symbol "$FRAMEWORK/Versions/Current/D3DMetal" '_GFXT_Initialize'

# The current VKMT build is an ARM64 host with FEX guest translation.  An
# ARM64 Mach-O that quietly links Rosetta or advertises an x86 execution path
# would violate that boundary just as surely as an x86_64 slice would.
if /usr/bin/otool -L "$SHARED" "$FRAMEWORK/Versions/Current/D3DMetal" 2>/dev/null |
  /usr/bin/grep -Eiq 'libRosetta|rosetta'; then
  die "provider links a Rosetta dependency; native VKMT D3DMetal is required"
fi

[ "$PROVIDER_ONLY" -eq 1 ] && {
  printf '%s\n' 'VKMT_D3DMETAL_PROVIDER_VERIFIED'
  exit 0
}

[ -x "$WINE_HOST" ] || die "missing ARM64 VKMT Wine host: $WINE_HOST"
[ "$(/usr/bin/lipo -archs "$WINE_HOST")" = arm64 ] ||
  die "VKMT Wine host is not arm64-only"
[ -f "$PROVIDER/VKMT-WINE-CONTRACT.txt" ] ||
  die "missing matching VKMT Wine D3DMetal loader contract"
grep -Fqx 'host_architecture=arm64' "$PROVIDER/VKMT-WINE-CONTRACT.txt" ||
  die "Wine D3DMetal contract host architecture mismatch"
grep -Fqx 'loader_contract=present' "$PROVIDER/VKMT-WINE-CONTRACT.txt" ||
  die "Wine D3DMetal loader contract is not marked present"
grep -Fqx 'guest_lanes=x86_64,i386' "$PROVIDER/VKMT-WINE-CONTRACT.txt" ||
  die "Wine D3DMetal contract does not cover required guest lanes"

printf '%s\n' 'VKMT_D3DMETAL_FULL_CONTRACT_VERIFIED'
