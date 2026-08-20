#!/bin/bash
# Stage a user-supplied Apple D3DMetal/GPTK provider into an isolated VKMT
# runtime. This never downloads, modifies, or reverse-engineers Apple software.
set -euo pipefail

ROOT=""
SOURCE=""
LICENSE=""
ACKNOWLEDGEMENTS=""
VERSION="unidentified"
STAGE_DIR=""
MOVED_PROVIDER=0
CREATED_FRAMEWORK_LINK=0
CREATED_SHARED_LINK=0
SUCCESS=0

die() {
  echo "stage-d3dmetal-runtime: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
usage: stage-d3dmetal-runtime.sh --runtime-root PATH --source PATH \
  --license PATH --acknowledgements PATH [--version VALUE]

SOURCE must be an Apple-provided GPTK/D3DMetal payload root containing:
  external/D3DMetal.framework
  external/libd3dshared.dylib

Only a complete ARM64 Mach-O provider is accepted. Sikarugir source and
documentation repositories do not contain this binary payload. The license
and acknowledgements are copied into the private runtime receipt; no public
redistribution permission is inferred.
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
    --source)
      [ "$#" -ge 2 ] || usage
      SOURCE="$2"
      shift 2
      ;;
    --license)
      [ "$#" -ge 2 ] || usage
      LICENSE="$2"
      shift 2
      ;;
    --acknowledgements)
      [ "$#" -ge 2 ] || usage
      ACKNOWLEDGEMENTS="$2"
      shift 2
      ;;
    --version)
      [ "$#" -ge 2 ] || usage
      VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ -n "$ROOT" ] || usage
[ -n "$SOURCE" ] || usage
[ -n "$LICENSE" ] || usage
[ -n "$ACKNOWLEDGEMENTS" ] || usage
[ -d "$ROOT" ] || die "runtime root does not exist: $ROOT"
[ -d "$SOURCE" ] || die "source root does not exist: $SOURCE"
[ -f "$LICENSE" ] || die "license receipt does not exist: $LICENSE"
[ -f "$ACKNOWLEDGEMENTS" ] || die "acknowledgements receipt does not exist: $ACKNOWLEDGEMENTS"
[ "$(uname -s)" = Darwin ] || die "D3DMetal staging requires macOS"

for tool in /usr/bin/file /usr/bin/lipo /usr/bin/shasum /bin/cp /bin/mkdir \
  /bin/mv /bin/rm /usr/bin/find /bin/ln /usr/bin/readlink; do
  [ -x "$tool" ] || die "required tool not found: $tool"
done

SOURCE="$(cd "$SOURCE" && pwd -P)"
ROOT="$(cd "$ROOT" && pwd -P)"
LICENSE="$(cd "$(dirname "$LICENSE")" && pwd -P)/$(basename "$LICENSE")"
ACKNOWLEDGEMENTS="$(cd "$(dirname "$ACKNOWLEDGEMENTS")" && pwd -P)/$(basename "$ACKNOWLEDGEMENTS")"
EXTERNAL="$SOURCE/external"
FRAMEWORK="$EXTERNAL/D3DMetal.framework"
SHARED="$EXTERNAL/libd3dshared.dylib"
TARGET="$ROOT/graphics/d3dmetal"
WINE_EXTERNAL="$ROOT/wine/build-ec/lib/external"

[ -d "$FRAMEWORK" ] || die "missing $FRAMEWORK"
[ -f "$SHARED" ] || die "missing $SHARED"
[ -f "$FRAMEWORK/Versions/Current/D3DMetal" ] || die "incomplete D3DMetal.framework"
[ -f "$FRAMEWORK/Versions/Current/Resources/Info.plist" ] || die "missing D3DMetal Info.plist"

case "$VERSION" in
  ""|*[!A-Za-z0-9._+-]*) die "version contains unsupported characters: $VERSION" ;;
esac

# Resolve every framework symlink and reject a payload that escapes the
# framework directory. This prevents path traversal from entering the runtime.
for link in "$FRAMEWORK/D3DMetal" "$FRAMEWORK/Resources" "$FRAMEWORK/Versions/Current"; do
  [ -L "$link" ] || die "required framework symlink is missing: $link"
  target="$(readlink "$link")"
  case "$target" in
    /*) die "absolute framework symlink: $link" ;;
  esac
  resolved="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
  framework_real="$(cd "$FRAMEWORK" && pwd -P)"
  case "$resolved" in
    "$framework_real"/*) ;;
    *) die "framework symlink escapes framework: $link -> $target" ;;
  esac
done

check_arm64_macho() {
  local path="$1"
  local kind
  local arches
  kind="$(/usr/bin/file "$path")"
  case "$kind" in
    *"Mach-O"*) ;;
    *) die "not a Mach-O provider: $path ($kind)" ;;
  esac
  arches="$(/usr/bin/lipo -archs "$path" 2>/dev/null)" || die "cannot inspect architectures: $path"
  [ "$arches" = arm64 ] || die "provider must be arm64-only: $path ($arches)"
}

check_arm64_macho "$SHARED"
while IFS= read -r -d '' path; do
  kind="$(/usr/bin/file "$path")"
  case "$kind" in
    *"Mach-O"*) check_arm64_macho "$path" ;;
  esac
done < <(/usr/bin/find "$FRAMEWORK" -type f -print0)

[ ! -e "$TARGET" ] && [ ! -L "$TARGET" ] || die "refusing to replace existing provider: $TARGET"
[ -d "$ROOT/wine/build-ec" ] || die "missing current VKMT Wine build: $ROOT/wine/build-ec"
mkdir -p "$ROOT/graphics" "$WINE_EXTERNAL"
STAGE_DIR="$(mktemp -d "$ROOT/.d3dmetal-stage.XXXXXX")"

cleanup() {
  if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
    /usr/bin/find "$STAGE_DIR" -depth -delete 2>/dev/null || true
  fi
  if [ "$SUCCESS" -eq 0 ]; then
    [ "$CREATED_FRAMEWORK_LINK" -eq 1 ] && /bin/rm -f "$WINE_EXTERNAL/D3DMetal.framework"
    [ "$CREATED_SHARED_LINK" -eq 1 ] && /bin/rm -f "$WINE_EXTERNAL/libd3dshared.dylib"
    [ "$MOVED_PROVIDER" -eq 1 ] && /bin/rm -rf "$TARGET"
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$STAGE_DIR/graphics/d3dmetal/external" "$STAGE_DIR/graphics/d3dmetal/legal"
cp -R "$FRAMEWORK" "$STAGE_DIR/graphics/d3dmetal/external/"
cp "$SHARED" "$STAGE_DIR/graphics/d3dmetal/external/"
cp "$LICENSE" "$STAGE_DIR/graphics/d3dmetal/legal/APPLE-GPTK-LICENSE"
cp "$ACKNOWLEDGEMENTS" "$STAGE_DIR/graphics/d3dmetal/legal/APPLE-GPTK-ACKNOWLEDGEMENTS"

cat > "$STAGE_DIR/graphics/d3dmetal/PROVENANCE.txt" <<PROVENANCE
provider=D3DMetal
provider_version=$VERSION
source_root=$SOURCE
framework_source=$FRAMEWORK
shared_library_source=$SHARED
host_architecture=arm64
distribution=private-noncommercial-only
wine_loader_contract=required-before-activation
source_repository=https://github.com/Sikarugir-App/Sikarugir
source_repository_contains_binary_payload=no
PROVENANCE

(
  cd "$STAGE_DIR/graphics/d3dmetal"
  /usr/bin/find . -type f ! -name SHA256SUMS -print | LC_ALL=C sort | while IFS= read -r path; do
    /usr/bin/shasum -a 256 "$path"
  done
) > "$STAGE_DIR/graphics/d3dmetal/SHA256SUMS"

mv "$STAGE_DIR/graphics/d3dmetal" "$TARGET"
MOVED_PROVIDER=1
ln -s "../../../../graphics/d3dmetal/external/D3DMetal.framework" "$WINE_EXTERNAL/D3DMetal.framework"
CREATED_FRAMEWORK_LINK=1
ln -s "../../../../graphics/d3dmetal/external/libd3dshared.dylib" "$WINE_EXTERNAL/libd3dshared.dylib"
CREATED_SHARED_LINK=1

"$ROOT/scripts/verify-d3dmetal-runtime.sh" --runtime-root "$ROOT" --provider-only
printf '%s\n' 'VKMT_D3DMETAL_PROVIDER_STAGED'
printf 'provider_root=%s\n' "$TARGET"
printf '%s\n' 'activation=blocked until a matching ARM64 VKMT Wine loader contract is installed'
SUCCESS=1
