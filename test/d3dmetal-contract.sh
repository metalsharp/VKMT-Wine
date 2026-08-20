#!/bin/bash
# Exercise the D3DMetal safety boundary without requiring proprietary Apple
# binaries or a GPU runner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d /tmp/vkmt-d3dmetal-contract.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

bash -n "$ROOT/scripts/stage-d3dmetal-runtime.sh"
bash -n "$ROOT/scripts/verify-d3dmetal-runtime.sh"
bash -n "$ROOT/scripts/vkmt-d3dmetal-env.sh"

if "$ROOT/scripts/verify-d3dmetal-runtime.sh" \
  --runtime-root "$TMP" --provider-only 2>"$TMP/error"; then
  echo "D3DMetal verifier accepted an absent provider" >&2
  exit 1
fi
grep -Eq 'missing provider root|required tool not found' "$TMP/error"

grep -Fq 'VKMT_D3DMETAL_ENABLE' "$ROOT/scripts/vkmt-runtime-env.sh"
grep -Fq 'D3DMETAL_RUNTIME_DIR=' "$ROOT/scripts/vkmt-d3dmetal-env.sh"
grep -Fq 'D3DMETAL_UNIXLIB_DIR=' "$ROOT/scripts/vkmt-d3dmetal-env.sh"
grep -Fq 'D3DMETAL_EXTERNAL_DIR=' "$ROOT/scripts/vkmt-d3dmetal-env.sh"
if grep -Eq 'MTL_CAPTURE_ENABLED=1|D3DM_DXIL_PROCESS_DEBUG_INFORMATION=1|ROSETTA_ADVERTISE_AVX=1' \
  "$ROOT/scripts/vkmt-d3dmetal-env.sh"; then
  echo "D3DMetal environment enables diagnostics or Rosetta" >&2
  exit 1
fi

if grep -Eq 'DYLD_INSERT_LIBRARIES|WINEDEBUG=.*(trace|\+all)|D3DM.*(HUD|DEBUG).*=[1yY]' \
  "$ROOT/scripts/vkmt-d3dmetal-env.sh"; then
  echo "D3DMetal environment enables an injected diagnostic or tracing path" >&2
  exit 1
fi

printf '%s\n' 'D3DMETAL_GUARD_CONTRACT_OK'
