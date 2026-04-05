#!/bin/bash

# ==============================================================================
# Kernel Defconfig Auto-Patcher (Pure Config Modification - No Make Steps)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_ROOT="${KERNEL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

source "$SCRIPT_DIR/kernel_build_common.sh"

cd "$KERNEL_ROOT"

CONFIG_FILE="${1:-$OUT_DIR/.config}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "[PATCH] Applying config modifications to $CONFIG_FILE..."

# ./scripts/config --file "$CONFIG_FILE" --enable CONFIG
# ./scripts/config --file "$CONFIG_FILE" --disable CONFIG

echo "[SUCCESS] Config patches applied to: $CONFIG_FILE"
