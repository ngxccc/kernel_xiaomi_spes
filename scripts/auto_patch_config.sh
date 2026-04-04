#!/bin/bash

# ==============================================================================
# Kernel Defconfig Auto-Patcher & Updater
# ==============================================================================

# Enable Fail-Fast: Exit immediately if any command fails
set -e

# 1. PATH RESOLUTION: Dynamically locate the kernel root directory
KERNEL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$KERNEL_ROOT"
echo "[INFO] Working directory set to: $KERNEL_ROOT"

# 2. ENVIRONMENT CONFIGURATION
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LLVM=1
export LLVM_IAS=1

# Define the target defconfig path (Adjust if necessary)
BASE_DEFCONFIG="vendor/spes-perf_defconfig"
TARGET_DEFCONFIG_PATH="arch/arm64/configs/$BASE_DEFCONFIG"

# 3. INITIALIZATION: Clean environment and load the base configuration
echo "[1/4] Loading base defconfig ($BASE_DEFCONFIG)..."
make LLVM=1 LLVM_IAS=1 mrproper

make LLVM=1 LLVM_IAS=1 $BASE_DEFCONFIG

# 4. INJECTING CUSTOM OPTIMIZATIONS (The "Wizard" tweaks)
echo "[2/4] Injecting automated..."

# Example
# ./scripts/config --enable CONFIG_TCP_CONG_BBR
# ./scripts/config --set-str CONFIG_DEFAULT_TCP_CONG "bbr"
# ./scripts/config --disable CONFIG_SLUB_DEBUG

./scripts/config --enable CONFIG_NOPMI_CHARGER

# 5. DEPENDENCY RESOLUTION & SAVING
echo "[3/4] Resolving dependencies and generating minimal defconfig..."
# olddefconfig ensures all new config dependencies are met silently
make LLVM=1 LLVM_IAS=1 olddefconfig
# savedefconfig strips default values, keeping only the minimal delta
make LLVM=1 LLVM_IAS=1 savedefconfig

# 6. DEPLOYMENT: Update the target file in the source tree
echo "[4/4] Deploying new defconfig to source tree..."
if [ -f "defconfig" ]; then
    cp defconfig "$TARGET_DEFCONFIG_PATH"
    rm defconfig
    echo "[SUCCESS] Defconfig updated successfully at: $TARGET_DEFCONFIG_PATH"
else
    echo "[ERROR] Kbuild failed to generate the 'defconfig' file!"
    exit 1
fi
