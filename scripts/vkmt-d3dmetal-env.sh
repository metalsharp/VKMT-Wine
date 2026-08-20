#!/bin/bash
# Load the optional private D3DMetal profile after full provider validation.
# This file is sourced by vkmt-runtime-env.sh; it is not a standalone launcher.
set -euo pipefail

ROOT="$VKMT_RUNTIME_ROOT"
"$ROOT/scripts/verify-d3dmetal-runtime.sh" --runtime-root "$ROOT" >/dev/null

export VKMT_D3DMETAL_ROOT="$ROOT/graphics/d3dmetal"
export VKMT_D3DMETAL_MODE=private-noncommercial
export D3DM_SUPPORT_DXR="\${VKMT_D3DM_SUPPORT_DXR:-0}"
export D3DM_ENABLE_METALFX="\${VKMT_D3DM_ENABLE_METALFX:-0}"
export DYLD_LIBRARY_PATH="$ROOT/wine/build-ec/lib/external\${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
