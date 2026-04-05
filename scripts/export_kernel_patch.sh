#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_ROOT="${KERNEL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
KERNELSU_KERNEL_DIR="${KERNELSU_KERNEL_DIR:-$KERNEL_ROOT/KernelSU-Next/kernel}"
DEFAULT_PATCH_FILE="${KERNEL_ROOT}/kernel-patch/ksu-next-4.19-$(date +'%Y%m%d-%H%M%S').patch"
PATCH_FILE="${1:-$DEFAULT_PATCH_FILE}"

if [[ ! -d "$KERNELSU_KERNEL_DIR" ]]; then
	echo "❌ KernelSU-Next/kernel directory not found: $KERNELSU_KERNEL_DIR"
	exit 1
fi

if ! git -C "$KERNELSU_KERNEL_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "❌ Not a git repository: $KERNELSU_KERNEL_DIR"
	exit 1
fi

mkdir -p "$(dirname "$PATCH_FILE")"

echo "📦 Exporting git diff from: $KERNELSU_KERNEL_DIR"
echo "📝 Patch file: $PATCH_FILE"

git -C "$KERNELSU_KERNEL_DIR" diff --binary --no-ext-diff HEAD -- . > "$PATCH_FILE"

if [[ ! -s "$PATCH_FILE" ]]; then
	echo "⚠️ Patch file is empty: $PATCH_FILE"
else
	echo "✅ Patch exported successfully"
fi
