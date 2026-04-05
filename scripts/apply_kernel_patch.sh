#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_ROOT="${KERNEL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
KERNELSU_PATH="${KERNELSU_PATH:-$KERNEL_ROOT/KernelSU-Next}"
KERNELSU_KERNEL_DIR="${KERNELSU_KERNEL_DIR:-$KERNELSU_PATH/kernel}"

if [[ $# -lt 1 ]]; then
	echo "Usage: $0 <patch-file>"
	exit 1
fi

PATCH_FILE="$1"

if [[ ! -f "$PATCH_FILE" ]]; then
	echo "❌ Patch file not found: $PATCH_FILE"
	exit 1
fi

if [[ ! -d "$KERNELSU_PATH" || ! -d "$KERNELSU_KERNEL_DIR" ]]; then
	echo "📦 Initializing KernelSU-Next submodule..."
	git -C "$KERNEL_ROOT" submodule update --init --recursive KernelSU-Next
fi

if ! git -C "$KERNELSU_KERNEL_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "❌ Not a git repository: $KERNELSU_KERNEL_DIR"
	exit 1
fi

echo "📥 Applying patch to: $KERNELSU_KERNEL_DIR"
echo "📝 Patch file: $PATCH_FILE"

git -C "$KERNELSU_KERNEL_DIR" apply --binary --whitespace=nowarn "$PATCH_FILE"

echo "✅ Patch applied successfully"
