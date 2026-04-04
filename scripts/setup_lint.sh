#!/bin/bash

# 🛑 FAIL-FAST: Exit immediately if any command fails to prevent "fake" success
set -e

# 📍 CONTEXT AWARENESS: Resolve absolute path to project root
# B1: Get script's dir -> B2: Navigate to parent -> B3: Capture absolute path
KERNEL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cd "$KERNEL_ROOT"
echo "📍 Root directory set to: $KERNEL_ROOT"

MODE="${1:-clean}"

case "$MODE" in
	clean|fast)
		;;
	*)
		echo "❌ Invalid mode: $MODE"
		echo "Usage: $0 [clean|fast]"
		exit 1
		;;
esac

# --- CONFIGURATION ---
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LLVM=1
export LLVM_IAS=1

DEFCONFIG="vendor/spes-perf_defconfig"

if [[ "$MODE" == "clean" ]]; then
	echo "🔥 [1/5] Cleaning build artifacts..."
	make LLVM=1 LLVM_IAS=1 mrproper

	echo "🛠️ [2/5] Applying $DEFCONFIG..."
	make LLVM=1 LLVM_IAS=1 $DEFCONFIG
else
	if [[ ! -f .config ]]; then
		echo "❌ fast mode requires an existing .config. Run '$0 clean' first."
		exit 1
	fi
	echo "⚡ [1/3] Reusing existing build state..."
fi

echo "🏗️ [$([[ "$MODE" == "clean" ]] && echo "4/5" || echo "2/3")] Preparing Kernel headers and scripts..."
make LLVM=1 LLVM_IAS=1 olddefconfig
make LLVM=1 LLVM_IAS=1 prepare -j$(nproc)
make LLVM=1 LLVM_IAS=1 modules_prepare -j$(nproc)
# make LLVM=1 LLVM_IAS=1 techpack/audio/ -j$(nproc)


echo "🗺️ [$([[ "$MODE" == "clean" ]] && echo "5/5" || echo "3/3")] Generating LSP compile_commands.json..."
python3 scripts/gen_compile_commands.py

echo "✅ SUCCESS: Environment ready. Please reload your IDE/LSP!"
