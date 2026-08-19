#!/bin/bash
# Verify the latest VKD3D-Proton-MacOS release as an input artifact.
# This does not promote an x86_64/Rosetta asset into the no-Rosetta VKMT lane.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TAG="${VKD3D_MACOS_TAG:-v1.0}"
ASSET="vkd3d-proton-macos.tar.zst"
EXPECTED_SHA256="f1eabd729a65f0a62bcba9a3a8054bdef9895981351dc8896993a8cffa12299c"
ARCHIVE="${VKD3D_MACOS_ARCHIVE:-}"
EVIDENCE_DIR="${VKD3D_MACOS_EVIDENCE_DIR:-$ROOT/docs/validation/release-vkd3d-v1}"
LOCAL_ONLY=0

usage() { echo "usage: $0 [--archive PATH] [--evidence-dir PATH] [--local-only]" >&2; exit 2; }
while test "$#" -gt 0; do
  case "$1" in
    --archive) test "$#" -ge 2 || usage; ARCHIVE="$2"; shift 2 ;;
    --evidence-dir) test "$#" -ge 2 || usage; EVIDENCE_DIR="$2"; shift 2 ;;
    --local-only) LOCAL_ONLY=1; shift ;;
    *) usage ;;
  esac
done

die() { echo "VKD3D release verification: $*" >&2; exit 1; }
for tool in shasum zstd tar file awk grep mktemp; do command -v "$tool" >/dev/null || die "missing tool: $tool"; done

if test -z "$ARCHIVE"; then
  ARCHIVE="$ROOT/build/$ASSET"
  if test ! -s "$ARCHIVE"; then
    test "$LOCAL_ONLY" = 0 || die "archive is not local: $ARCHIVE"
    mkdir -p "$(dirname "$ARCHIVE")"
    curl --fail --location --retry 4 --output "$ARCHIVE.partial" \
      "https://github.com/metalsharp/VKD3D-Proton-MacOS/releases/download/$TAG/$ASSET"
    mv "$ARCHIVE.partial" "$ARCHIVE"
  fi
fi
test -s "$ARCHIVE" || die "archive is empty: $ARCHIVE"
actual="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
test "$actual" = "$EXPECTED_SHA256" || die "SHA-256 mismatch: $actual"
zstd -q -t "$ARCHIVE"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/vkmt-vkd3d-release.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM
zstd -q -dc "$ARCHIVE" | tar -xf - -C "$TMP"
PKG="$TMP/vkd3d-proton-macos"
test -d "$PKG" || die "package root is missing"
for f in d3d12.dll d3d12core.dll dxgi.dll libMoltenVK.dylib MoltenVK_icd.json README.md SHA256SUMS; do
  test -f "$PKG/$f" || die "required package file missing: $f"
done
(cd "$PKG" && shasum -a 256 -c SHA256SUMS >/dev/null)

file "$PKG/d3d12.dll" | grep -q 'PE32+.*x86-64' || die "d3d12.dll is not x86_64 PE"
file "$PKG/d3d12core.dll" | grep -q 'PE32+.*x86-64' || die "d3d12core.dll is not x86_64 PE"
file "$PKG/dxgi.dll" | grep -q 'PE32+.*x86-64' || die "dxgi.dll is not x86_64 PE"
file "$PKG/libMoltenVK.dylib" | grep -q 'universal binary' || die "MoltenVK is not universal"
grep -q 'x86_64 PE' "$PKG/README.md" || die "release architecture disclosure missing"
grep -q '12_2' "$PKG/README.md" || die "release capability disclosure missing"

mkdir -p "$EVIDENCE_DIR"
{
  echo "# VKD3D-Proton-MacOS $TAG release input"
  echo
  echo "- archive: $ARCHIVE"
  echo "- archive SHA-256: $actual"
  echo "- host: $(uname -s) $(uname -m)"
  echo
  echo '---'
  file "$PKG/d3d12.dll" "$PKG/d3d12core.dll" "$PKG/dxgi.dll" "$PKG/libMoltenVK.dylib"
  (cd "$PKG" && shasum -a 256 -c SHA256SUMS)
  echo '---'
  echo
  echo "The published DLL set is x86_64 PE for Wine/Rosetta. It is verified as"
  echo "an upstream input but is not promoted as VKMT's no-Rosetta all-architecture"
  echo "runtime until an architecture-matched VKMT compatibility gate passes."
} >"$EVIDENCE_DIR/RESULTS.md"
cp "$PKG/SHA256SUMS" "$EVIDENCE_DIR/SHA256SUMS"
echo VKD3D_PROTON_MACOS_V1_ASSET_VERIFIED
