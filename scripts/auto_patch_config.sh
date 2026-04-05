#!/bin/bash

# ==============================================================================
# Kernel Defconfig Auto-Patcher & Updater
# ==============================================================================

# Enable Fail-Fast: Exit immediately if any command fails
set -e

# 1. PATH RESOLUTION: Dynamically locate the kernel root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_ROOT="${KERNEL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export KERNEL_ROOT

# Load shared kernel build parameters (ARCH, CROSS_COMPILE, LLVM, LLVM_IAS, DEFCONFIG, OUT_DIR...)
source "$SCRIPT_DIR/kernel_build_common.sh"

cd "$KERNEL_ROOT"
echo "[INFO] Working directory set to: $KERNEL_ROOT"

TARGET_DEFCONFIG_PATH="arch/$ARCH/configs/$DEFCONFIG"

# 3. INITIALIZATION: Clean environment and load the base configuration
echo "[1/4] Loading base defconfig ($DEFCONFIG)..."
make O="$OUT_DIR" mrproper

make O="$OUT_DIR" "$DEFCONFIG"

# 4. INJECTING CUSTOM OPTIMIZATIONS (The "Wizard" tweaks)
echo "[2/4] Injecting automated..."

# Example
# ./scripts/config --enable CONFIG_TCP_CONG_BBR
# ./scripts/config --set-str CONFIG_DEFAULT_TCP_CONG "bbr"
# ./scripts/config --disable CONFIG_SLUB_DEBUG

./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_SUS_PATH
./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_SUS_MOUNT
./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_SUS_KSTAT
./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
./scripts/config --file "$OUT_DIR/.config" --enable CONFIG_KSU_SUSFS_SPOOF_UNAME

# Disable mấy cái tà đạo dễ gây bootloop
./scripts/config --file "$OUT_DIR/.config" --disable CONFIG_KSU_SUSFS_SUS_OVERLAYFS
./scripts/config --file "$OUT_DIR/.config" --disable CONFIG_KSU_SUSFS_OPEN_REDIRECT
./scripts/config --file "$OUT_DIR/.config" --disable CONFIG_KSU_SUSFS_TRY_UMOUNT

# 5. DEPENDENCY RESOLUTION & SAVING
echo "[3/4] Resolving dependencies and generating minimal defconfig..."
# olddefconfig ensures all new config dependencies are met silently
make O="$OUT_DIR" olddefconfig
# savedefconfig strips default values, keeping only the minimal delta
make O="$OUT_DIR" savedefconfig

# 6. DEPLOYMENT: Update the target file in the source tree
echo "[4/4] Deploying new defconfig to source tree..."
if [ -f "$OUT_DIR/defconfig" ]; then
    cp "$OUT_DIR/defconfig" "$TARGET_DEFCONFIG_PATH"
    echo "[SUCCESS] Defconfig updated successfully at: $TARGET_DEFCONFIG_PATH"
else
    echo "[ERROR] Kbuild failed to generate the 'defconfig' file!"
    exit 1
fi
