#!/bin/bash

# ==============================================================================
# Local KernelSU-Next Patcher & Config Optimizer
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_ROOT="${KERNEL_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export KERNEL_ROOT
export KSU_REF=v3.1.0-legacy-susfs

# Load shared kernel build parameters (ARCH, CROSS_COMPILE, LLVM, DEFCONFIG, OUT_DIR, ...)
source "$SCRIPT_DIR/kernel_build_common.sh"

cd "$KERNEL_ROOT"

echo "🚀 [1/3] Cloning and injecting KernelSU-Next into the source tree..."
KSU_REF="${KSU_REF:-}"
if [ -n "$KSU_REF" ]; then
	echo "📌 Using KSU_REF=$KSU_REF"
	bash "$SCRIPT_DIR/kernel_su_next_setup.sh" "$KSU_REF"
else
	echo "📌 KSU_REF is not set, using latest stable tag"
	bash "$SCRIPT_DIR/kernel_su_next_setup.sh"
fi

echo "🛠️ [2/3] Enabling KSU mandatory features in defconfig..."
CONFIG_FILE="arch/$ARCH/configs/$DEFCONFIG"

# Inject Kprobes and OverlayFS for KSU functionality
./scripts/config --file $CONFIG_FILE --enable CONFIG_KPROBES
./scripts/config --file $CONFIG_FILE --enable CONFIG_HAVE_KPROBES
./scripts/config --file $CONFIG_FILE --enable CONFIG_KPROBE_EVENTS
./scripts/config --file $CONFIG_FILE --enable CONFIG_OVERLAY_FS

# Bật SUSFS (Vì nhánh này đã có sẵn code SUSFS rồi, chỉ cần bật cờ là chạy)
./scripts/config --file $CONFIG_FILE --enable CONFIG_KSU_SUSFS
./scripts/config --file $CONFIG_FILE --enable CONFIG_KSU_SUSFS_SUS_PATH
./scripts/config --file $CONFIG_FILE --enable CONFIG_KSU_SUSFS_SUS_MOUNT
./scripts/config --file $CONFIG_FILE --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT

echo "🧹 [3/3] Re-formatting defconfig via Kbuild..."
# Standardize the defconfig so it looks neat and resolves any missing dependencies
make O="$OUT_DIR" mrproper
make O="$OUT_DIR" "$DEFCONFIG"
make O="$OUT_DIR" savedefconfig
cp "$OUT_DIR/defconfig" "$CONFIG_FILE"

echo "✅ DONE! KSU Next is now permanently embedded in your source code."
