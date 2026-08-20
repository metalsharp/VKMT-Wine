#!/bin/bash
# Build the redistributable VKMT runtime from a verified runtime tree.
# Development probes, disposable evidence, audits, roadmaps, and prefixes are
# deliberately removed from the package; the source repository remains the
# place for reproducible development inputs.
set -euo pipefail

VKMT="$(cd "$(dirname "$0")/.." && pwd -P)"
RUNTIME_ROOT="${VKMT_RELEASE_RUNTIME_ROOT:-}"
OUTPUT_DIR="${VKMT_RELEASE_OUTPUT_DIR:-}"
ARCHIVE_NAME="${VKMT_RELEASE_ARCHIVE_NAME:-MetalSharp-Wine-Runtime-COMPLETE-all-arch-2026-07-31.tar.zst}"
PACKAGE_ROOT="${VKMT_RELEASE_PACKAGE_ROOT:-MetalSharp-Wine-Runtime-COMPLETE-all-arch-2026-07-31}"
PART_SIZE=400000000
STAGE_DIR=""

die() { echo "package-runtime-release: $*" >&2; exit 1; }
usage() {
  cat >&2 <<'USAGE'
usage: package-runtime-release.sh --runtime-root PATH --output-dir PATH

The runtime root must already have passed the release architecture gate.
The output directory receives the reassembled archive, four ordered parts,
the part checksums, and a member manifest. Existing output files are refused.
USAGE
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime-root) [ "$#" -ge 2 ] || usage; RUNTIME_ROOT="$2"; shift 2 ;;
    --output-dir) [ "$#" -ge 2 ] || usage; OUTPUT_DIR="$2"; shift 2 ;;
    --archive-name) [ "$#" -ge 2 ] || usage; ARCHIVE_NAME="$2"; shift 2 ;;
    --package-root) [ "$#" -ge 2 ] || usage; PACKAGE_ROOT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "$RUNTIME_ROOT" ] || usage
[ -n "$OUTPUT_DIR" ] || usage
[ -d "$RUNTIME_ROOT" ] || die "runtime root does not exist: $RUNTIME_ROOT"
if [ -x "$RUNTIME_ROOT/wine/build-ec/tools/wine/wine" ]; then
  WINE_HOST="$RUNTIME_ROOT/wine/build-ec/tools/wine/wine"
else
  WINE_HOST="$RUNTIME_ROOT/wine/build-ec/wine"
fi
[ -x "$WINE_HOST" ] || die "missing ARM64 Wine host"
[ -x "$RUNTIME_ROOT/wine/build-ec/server/wineserver" ] || die "missing ARM64 wineserver"
[ -f "$RUNTIME_ROOT/.metalsharp-runtime-install" ] || die "missing install receipt"
[ ! -e "$RUNTIME_ROOT/graphics/d3dmetal" ] && [ ! -L "$RUNTIME_ROOT/graphics/d3dmetal" ] || die "private D3DMetal payload cannot enter the public package"
[ ! -e "$RUNTIME_ROOT/wine/build-ec/lib/external/D3DMetal.framework" ] && [ ! -L "$RUNTIME_ROOT/wine/build-ec/lib/external/D3DMetal.framework" ] || die "private D3DMetal framework link cannot enter the public package"
[ ! -e "$RUNTIME_ROOT/wine/build-ec/lib/external/libd3dshared.dylib" ] && [ ! -L "$RUNTIME_ROOT/wine/build-ec/lib/external/libd3dshared.dylib" ] || die "private D3DMetal shared-library link cannot enter the public package"

for tool in cp find rm tar zstd shasum awk sort split file mktemp; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

mkdir -p "$OUTPUT_DIR"
for output in "$OUTPUT_DIR/$ARCHIVE_NAME" \
    "$OUTPUT_DIR/$ARCHIVE_NAME.part01" "$OUTPUT_DIR/$ARCHIVE_NAME.part02" \
    "$OUTPUT_DIR/$ARCHIVE_NAME.part03" "$OUTPUT_DIR/$ARCHIVE_NAME.part04" \
    "$OUTPUT_DIR/PARTS-SHA256SUMS.txt" "$OUTPUT_DIR/$ARCHIVE_NAME.manifest.txt"; do
  [ ! -e "$output" ] || die "refusing to overwrite existing output: $output"
done

cleanup() {
  if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
    find "$STAGE_DIR" -depth -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

STAGE_DIR="$(mktemp -d "$(dirname "$OUTPUT_DIR")/.vkmt-package-stage.XXXXXX")"
stage_root="$STAGE_DIR/$PACKAGE_ROOT"
mkdir -p "$stage_root"

# Copy with clonefile support on APFS. Falling back to a normal recursive copy
# keeps the script usable on other Unix filesystems.
if ! cp -cR "$RUNTIME_ROOT"/. "$stage_root" 2>/dev/null; then
  cp -R "$RUNTIME_ROOT"/. "$stage_root"
fi

# Replace the public project snapshot with the current normalized source tree,
# while retaining the independently licensed nested upstream source bundle.
rm -rf "$stage_root/source/VKMT"
mkdir -p "$stage_root/source/VKMT"
(cd "$VKMT" && tar -cf - \
    --exclude='./.git' --exclude='./.github' --exclude='./build' --exclude='./ci' --exclude='./wine' \
    --exclude='./third_party' --exclude='./toolchains' --exclude='./docs/validation' --exclude='./D3DMetal.md' \
    .) | tar -xf - -C "$stage_root/source/VKMT"

# The package is a runtime, not a development checkout. Remove all probe
# runners and generated/test evidence from both runtime and source namespaces.
find "$stage_root/scripts" "$stage_root/source/VKMT/scripts" -type f \
  \( -name 'probe-*.sh' -o -name '*_probe.sh' -o -name '*-probe.sh' \
     -o -name '*phase*.sh' -o -name '*p[1-8]*.sh' \) -delete 2>/dev/null || true
rm -rf "$stage_root/source/VKMT/test" "$stage_root/source/VKMT/docs/validation" \
  "$stage_root/build"
# The standalone installer is shipped at the archive root. Keeping a second
# copy inside the source snapshot would create a self-referential checksum
# problem whenever its pinned archive hash changes.
rm -f "$stage_root/source/VKMT/scripts/install-vkmt-runtime.sh"
find "$stage_root/source/VKMT/docs" -type f \
  \( -iname 'audit*.md' -o -iname '*roadmap*.md' -o -iname 'plan.md' \
     -o -iname '*plan*.md' -o -iname '*phase*.md' \) -delete 2>/dev/null || true
find "$stage_root/source/VKMT" -type f \( -iname 'Audit*.md' -o -iname 'Audit*.MD' \) -delete 2>/dev/null || true
find "$stage_root/source/VKMT/patches" -type f -iname '*phase*' -delete 2>/dev/null || true

# Activate the checked-in default DXMT profile and launcher environment.
mkdir -p "$stage_root/runtime" "$stage_root/source/VKMT/runtime"
cp "$VKMT/runtime/dxmt.conf" "$stage_root/runtime/dxmt.conf"
cp "$VKMT/runtime/dxmt.conf" "$stage_root/source/VKMT/runtime/dxmt.conf"
cp "$VKMT/scripts/vkmt-runtime-env.sh" "$stage_root/scripts/vkmt-runtime-env.sh"
cp "$VKMT/scripts/verify-runtime.sh" "$stage_root/scripts/verify-runtime.sh"

cat > "$stage_root/README.txt" <<'README'
VKMT MetalSharp runtime

This package is an Apple-Silicon-native Wine runtime. The host Wine,
wineserver, Unix providers, and native media libraries are ARM64. Windows
guest modules cover ARM64/AArch64, ARM64EC, x86_64, and i386/WoW64.

FEX xtajit64 and xtajit are required providers for the x86_64 and i386/WoW64
guest lanes. The complete component inventory is in
source/VKMT/docs/runtime-inventory.md.

Installation and launch instructions are in
source/VKMT/docs/quick-start.md. The architecture and integration model is
in source/VKMT/docs/architecture.md.

Use wine/bin/metalsharp-wine or wine/bin/wine. Set WINEPREFIX to a prefix
outside this runtime. The launcher sets the no-TSO contract and loads the
default runtime/dxmt.conf profile. Disposable validation tools and evidence
are intentionally not shipped.
README

cat > "$stage_root/metadata/RELEASE-CLEANUP.txt" <<'CLEANUP'
This redistributable contains runtime assets only.
Development probes, test fixtures, temporary prefixes, logs, audits,
roadmaps, and validation evidence were removed before packaging.
The source tree retains only normalized project documentation and build
provenance needed to identify the shipped artifacts.
CLEANUP

if [ -f "$stage_root/metadata/PROVENANCE.txt" ]; then
  {
    cat "$stage_root/metadata/PROVENANCE.txt"
    printf '%s\n' 'runtime_config=runtime/dxmt.conf'
    printf '%s\n' 'diagnostics_in_release=0'
    printf '%s\n' 'fex_tso_policy=all-zero'
  } > "$stage_root/metadata/PROVENANCE.txt.tmp"
  mv "$stage_root/metadata/PROVENANCE.txt.tmp" "$stage_root/metadata/PROVENANCE.txt"
fi

# Rebuild the package receipt after all content changes. Symlinks are kept in
# the tarball but are intentionally not hashed as regular payload files.
rm -f "$stage_root/metadata/SHA256SUMS"
(cd "$stage_root" && find . -type f ! -path './metadata/SHA256SUMS' -print | LC_ALL=C sort | while IFS= read -r path; do
  shasum -a 256 "$path"
done) > "$stage_root/metadata/SHA256SUMS"

tar -cf - -C "$STAGE_DIR" "$PACKAGE_ROOT" | \
  zstd -T0 -19 --long=31 -o "$OUTPUT_DIR/$ARCHIVE_NAME"
zstd -q --long=31 -t "$OUTPUT_DIR/$ARCHIVE_NAME"

archive_size="$(stat -f %z "$OUTPUT_DIR/$ARCHIVE_NAME" 2>/dev/null || stat -c %s "$OUTPUT_DIR/$ARCHIVE_NAME")"
[ "$archive_size" -gt "$PART_SIZE" ] || die "archive unexpectedly small: $archive_size bytes"
split -b "$PART_SIZE" -d -a 2 "$OUTPUT_DIR/$ARCHIVE_NAME" \
  "$OUTPUT_DIR/.${ARCHIVE_NAME}.part"
parts=("$OUTPUT_DIR"/."$ARCHIVE_NAME".part*)
[ "${#parts[@]}" -eq 4 ] || die "expected four parts, got ${#parts[@]}"
for i in 0 1 2 3; do
  mv "${parts[$i]}" "$OUTPUT_DIR/$ARCHIVE_NAME.part$(printf '%02d' "$((i + 1))")"
done

(cd "$OUTPUT_DIR" && shasum -a 256 "$ARCHIVE_NAME.part01" "$ARCHIVE_NAME.part02" \
  "$ARCHIVE_NAME.part03" "$ARCHIVE_NAME.part04") > "$OUTPUT_DIR/PARTS-SHA256SUMS.txt"
zstd -q --long=31 -dc "$OUTPUT_DIR/$ARCHIVE_NAME" | tar -tf - > \
  "$OUTPUT_DIR/$ARCHIVE_NAME.manifest.txt"

printf 'VKMT_RUNTIME_PACKAGE_OK\narchive=%s\narchive_sha256=%s\nparts=%s\n' \
  "$OUTPUT_DIR/$ARCHIVE_NAME" \
  "$(shasum -a 256 "$OUTPUT_DIR/$ARCHIVE_NAME" | awk '{print $1}')" \
  "$OUTPUT_DIR/PARTS-SHA256SUMS.txt"
