#!/bin/bash
set -euo pipefail
ROOT="${VKMT_RUNTIME_ROOT:-}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime-root|--package-root) [ "$#" -ge 2 ] || exit 2; ROOT="$2"; shift 2 ;;
    --inventory) shift ;;
    *) echo "usage: verify-preservation.sh [--runtime-root PATH]" >&2; exit 2 ;;
  esac
done
[ -n "$ROOT" ] || { echo "runtime root is required" >&2; exit 2; }
exec "$(cd "$(dirname "$0")" && pwd)/verify-runtime.sh" --runtime-root "$ROOT"
