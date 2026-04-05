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

echo "[PATCH] Applying KernelSU + SUSFS config modifications to $CONFIG_FILE..."

# Enable KernelSU Core
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS

# Enable SUSFS Features
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_SUS_PATH
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_SUS_MOUNT
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_SUS_KSTAT
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
./scripts/config --file "$CONFIG_FILE" --enable CONFIG_KSU_SUSFS_SPOOF_UNAME

# Disable problematic features
./scripts/config --file "$CONFIG_FILE" --disable CONFIG_KSU_SUSFS_SUS_OVERLAYFS
./scripts/config --file "$CONFIG_FILE" --disable CONFIG_KSU_SUSFS_OPEN_REDIRECT
./scripts/config --file "$CONFIG_FILE" --disable CONFIG_KSU_SUSFS_TRY_UMOUNT

echo "[SUCCESS] Config patches applied to: $CONFIG_FILE"
