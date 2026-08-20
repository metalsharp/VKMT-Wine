#!/bin/bash
# Load the optional private D3DMetal profile after full provider validation.
# This file is sourced by vkmt-runtime-env.sh; it is not a standalone launcher.
set -euo pipefail

ROOT="$VKMT_RUNTIME_ROOT"
"$ROOT/scripts/verify-d3dmetal-runtime.sh" --runtime-root "$ROOT" >/dev/null

export VKMT_D3DMETAL_ROOT="$ROOT/graphics/d3dmetal"
export VKMT_D3DMETAL_MODE=private-noncommercial
# Keep the Sikarugir/GPTK lookup vocabulary explicit.  The Wine loader uses
# these paths to select the provider's external framework and Unix bridge; do
# not rely on the process working directory or an inherited search path.
export D3DMETAL_RUNTIME_DIR="$VKMT_D3DMETAL_ROOT"
export D3DMETAL_UNIXLIB_DIR="$VKMT_D3DMETAL_ROOT/wine/x86_64-unix"
export D3DMETAL_EXTERNAL_DIR="$VKMT_D3DMETAL_ROOT/external"
export D3DM_SUPPORT_DXR="\${VKMT_D3DM_SUPPORT_DXR:-0}"
export D3DM_ENABLE_METALFX="\${VKMT_D3DM_ENABLE_METALFX:-0}"
export DYLD_LIBRARY_PATH="$ROOT/wine/build-ec/lib/external\${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
