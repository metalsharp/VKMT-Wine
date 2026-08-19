#!/bin/bash
# Verify a VKMT runtime installed from a release archive without touching the
# user's existing prefix.  This is the release-installation form of the P6
# gate; the source-tree P8 runner remains the functional acceptance runner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
RUNTIME_ROOT="${VKMT_RUNTIME_ROOT:-$ROOT}"
EVIDENCE_DIR="${VKMT_P6_RELEASE_EVIDENCE_DIR:-$ROOT/docs/validation/release-architecture-$(date -u +%Y%m%dT%H%M%SZ)}"
LLVM_MINGW="${LLVM_MINGW:-${VKMT_LLVM_MINGW:-/Volumes/AverySSD/VKMT-roadmap-work/toolchain/llvm-mingw-20260616-ucrt-macos-universal}}"

usage() { echo "usage: $0 [--runtime-root PATH] [--evidence-dir PATH]" >&2; exit 2; }
while test "$#" -gt 0; do
  case "$1" in
    --runtime-root) test "$#" -ge 2 || usage; RUNTIME_ROOT="$2"; shift 2 ;;
    --evidence-dir) test "$#" -ge 2 || usage; EVIDENCE_DIR="$2"; shift 2 ;;
    *) usage ;;
  esac
done

die() { echo "P6 release gate: $*" >&2; exit 1; }
test "$(uname -s)" = Darwin || die "VKMT release runtime requires macOS"
test "$(uname -m)" = arm64 || die "VKMT release runtime requires Apple Silicon"
test -x "$RUNTIME_ROOT/wine/build-ec/wine" || die "missing Wine host in $RUNTIME_ROOT"
test -x "$RUNTIME_ROOT/wine/build-ec/server/wineserver" || die "missing wineserver"
test -x "$RUNTIME_ROOT/scripts/stage-runtime-providers.sh" || die "missing provider staging script"
test -d "$RUNTIME_ROOT/source/VKMT/test" || die "release source/test tree is missing"
test -x "$LLVM_MINGW/bin/clang" || die "missing llvm-mingw toolchain: $LLVM_MINGW"
test -x "$LLVM_MINGW/bin/lld-link" || die "missing lld-link"
test -x "$LLVM_MINGW/bin/llvm-dlltool" || die "missing llvm-dlltool"
test -x "$LLVM_MINGW/bin/llvm-readobj" || die "missing llvm-readobj"

for host in "$RUNTIME_ROOT/wine/build-ec/wine" \
    "$RUNTIME_ROOT/wine/build-ec/server/wineserver" \
    "$RUNTIME_ROOT/wine/build-ec/dlls/ntdll/ntdll.so"; do
  test "$(/usr/bin/lipo -archs "$host")" = arm64 || die "non-ARM64 host artifact: $host"
done
if translated="$(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null)"; then
  test "$translated" = 0 || die "Rosetta is active"
fi
test "${FEX_TSOENABLED:-0}" = 0 || die "FEX_TSOENABLED must be zero"
test "${FEX_VECTORTSOENABLED:-0}" = 0 || die "FEX_VECTORTSOENABLED must be zero"
test "${FEX_MEMCPYSETTSOENABLED:-0}" = 0 || die "FEX_MEMCPYSETTSOENABLED must be zero"

SOURCE="$RUNTIME_ROOT/source/VKMT"
BUILD="$RUNTIME_ROOT/wine/build-ec"
RUN_ROOT="$RUNTIME_ROOT/build/release-architecture.$$.${RANDOM}"
PREFIX="$RUN_ROOT/prefix"
mkdir -p "$RUN_ROOT" "$EVIDENCE_DIR"

cleanup() {
  status=$?
  WINEPREFIX="$PREFIX" "$RUNTIME_ROOT/wine/build-ec/server/wineserver" -k >/dev/null 2>&1 || true
  WINEPREFIX="$PREFIX" "$RUNTIME_ROOT/wine/build-ec/server/wineserver" -w >/dev/null 2>&1 || true
  if test -d "$RUN_ROOT"; then
    find "$RUN_ROOT" -maxdepth 1 -type f -name '*.log' -exec cp {} "$EVIDENCE_DIR"/ \; 2>/dev/null || true
    printf 'status=%s\n' "$status" >"$EVIDENCE_DIR/status.txt"
    find "$RUN_ROOT" -depth -delete 2>/dev/null || true
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

cat >"$RUN_ROOT/kernel32.def" <<'EOF'
LIBRARY KERNEL32.dll
EXPORTS
  ExitProcess
EOF
cat >"$RUN_ROOT/exit.c" <<'EOF'
__declspec(dllimport) __declspec(noreturn) void ExitProcess(unsigned int);
void mainCRTStartup(void) { ExitProcess(0); }
EOF

for spec in arm64:arm64 i386:i386 x64:i386:x86-64; do
  name="${spec%%:*}"; machine="${spec#*:}"
  "$LLVM_MINGW/bin/llvm-dlltool" --machine "$machine" \
    --input-def "$RUN_ROOT/kernel32.def" --output-lib "$RUN_ROOT/kernel32-$name.lib" \
    --dllname KERNEL32.dll
done

"$LLVM_MINGW/bin/aarch64-w64-mingw32-clang" -O2 -ffreestanding -fno-stack-protector -nostdlib \
  -c -o "$RUN_ROOT/arm64.obj" "$RUN_ROOT/exit.c"
"$LLVM_MINGW/bin/lld-link" "$RUN_ROOT/arm64.obj" "$RUN_ROOT/kernel32-arm64.lib" \
  /entry:mainCRTStartup /subsystem:console /out:"$RUN_ROOT/arm64.exe"

"$LLVM_MINGW/bin/i686-w64-mingw32-clang" -O2 -ffreestanding -fno-stack-protector -nostdlib \
  -c -o "$RUN_ROOT/i386.obj" "$RUN_ROOT/exit.c"
"$LLVM_MINGW/bin/lld-link" "$RUN_ROOT/i386.obj" "$RUN_ROOT/kernel32-i386.lib" \
  /entry:mainCRTStartup /subsystem:console /safeseh:no /out:"$RUN_ROOT/i386.exe"

"$LLVM_MINGW/bin/x86_64-w64-mingw32-clang" -O2 -ffreestanding -fno-stack-protector -nostdlib \
  -c -o "$RUN_ROOT/x86_64.obj" "$RUN_ROOT/exit.c"
"$LLVM_MINGW/bin/lld-link" "$RUN_ROOT/x86_64.obj" "$RUN_ROOT/kernel32-x64.lib" \
  /entry:mainCRTStartup /subsystem:console /out:"$RUN_ROOT/x86_64.exe"

# The release source carries the canonical ARM64EC hello fixture.  It returns
# 42 by design, while P6's release-installation smoke must be status zero.  A
# temporary test copy changes only its return immediate; the shipped source
# and installed runtime are never modified.  The exact single-byte-pattern
# check prevents accidentally patching an unrelated binary.
cp "$SOURCE/test/x64emu/hello_ec.exe" "$RUN_ROOT/arm64ec.exe"
python3 - "$RUN_ROOT/arm64ec.exe" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
b = bytearray(p.read_bytes())
old = bytes.fromhex("40 05 80 52")
new = bytes.fromhex("00 00 80 52")
assert b.count(old) == 1, "ARM64EC fixture return pattern is not unique"
i = b.index(old)
b[i:i + 4] = new
p.write_bytes(b)
PY

for spec in arm64:IMAGE_FILE_MACHINE_ARM64 arm64ec:IMAGE_FILE_MACHINE_ARM64EC \
    x86_64:IMAGE_FILE_MACHINE_AMD64 i386:IMAGE_FILE_MACHINE_I386; do
  name="${spec%%:*}"; expected="${spec#*:}"
  machine="$("$LLVM_MINGW/bin/llvm-readobj" --file-headers "$RUN_ROOT/$name.exe" | awk '/Machine:/ {print $2; exit}')"
  test "$machine" = "$expected" || die "$name fixture is $machine, expected $expected"
done

export VKMT_RUNTIME_ROOT="$RUNTIME_ROOT"
export WINEBUILDDIR="$BUILD"
export WINEPREFIX="$PREFIX"
export FEX_TSOENABLED=0 FEX_VECTORTSOENABLED=0 FEX_MEMCPYSETTSOENABLED=0
mkdir -p "$PREFIX/drive_c/windows/system32" "$PREFIX/drive_c/windows/syswow64"
while IFS= read -r dll; do install -m 0644 "$dll" "$PREFIX/drive_c/windows/syswow64/$(basename "$dll")"; done \
  < <(find "$BUILD/dlls" -type f -path '*/i386-windows/*.dll' -print | LC_ALL=C sort)

"$RUNTIME_ROOT/scripts/stage-runtime-providers.sh" --prefix "$PREFIX"
"$BUILD/wine" "$BUILD/programs/wineboot/aarch64-windows/wineboot.exe" --init >"$RUN_ROOT/wineboot.log" 2>&1
"$RUNTIME_ROOT/scripts/stage-runtime-providers.sh" --prefix "$PREFIX"
"$RUNTIME_ROOT/scripts/stage-runtime-providers.sh" --verify-prefix "$PREFIX"

run_fixture() {
  local name="$1"
  WINEPREFIX="$PREFIX" WINEBUILDDIR="$BUILD" WINEBOOTSTRAPMODE=1 WINE_NO_EXPLORER=1 \
    WINEDEBUG=-all FEX_TSOENABLED=0 FEX_VECTORTSOENABLED=0 FEX_MEMCPYSETTSOENABLED=0 \
    "$BUILD/wine" "Z:$RUN_ROOT/$name.exe" >"$RUN_ROOT/$name.log" 2>&1
}

run_fixture arm64
echo P6_SINGLE_PREFIX_ARM64_OK
run_fixture arm64ec
grep -q 'hello from arm64ec' "$RUN_ROOT/arm64ec.log"
echo P6_SINGLE_PREFIX_ARM64EC_OK
run_fixture x86_64
echo P6_SINGLE_PREFIX_X86_64_OK
run_fixture i386
echo P6_SINGLE_PREFIX_I386_OK
echo P6_SINGLE_PREFIX_ALL_ARCHITECTURES_OK | tee "$EVIDENCE_DIR/RESULTS.md"
printf 'runtime_root=%s\nprefix=%s\nplatform=%s/%s\nFEX_TSOENABLED=0\nFEX_VECTORTSOENABLED=0\nFEX_MEMCPYSETTSOENABLED=0\n' \
  "$RUNTIME_ROOT" "$PREFIX" "$(uname -s)" "$(uname -m)" >"$EVIDENCE_DIR/environment.txt"
