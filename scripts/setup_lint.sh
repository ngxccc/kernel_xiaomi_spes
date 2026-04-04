#!/bin/bash

# 🛑 FAIL-FAST: Exit immediately if any command fails to prevent "fake" success
set -e

# 📍 CONTEXT AWARENESS: Resolve absolute path to project root
# B1: Get script's dir -> B2: Navigate to parent -> B3: Capture absolute path
KERNEL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cd "$KERNEL_ROOT"
echo "📍 Root directory set to: $KERNEL_ROOT"

. "$KERNEL_ROOT/scripts/kernel_build_common.sh"

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

clean_source_tree_state() {
	rm -f \
		"$KERNEL_ROOT/.config" \
		"$KERNEL_ROOT/.config.old" \
		"$KERNEL_ROOT/Module.symvers" \
		"$KERNEL_ROOT/System.map" \
		"$KERNEL_ROOT/vmlinux" \
		"$KERNEL_ROOT/.tmp_"* 2>/dev/null || true
	if command -v find >/dev/null 2>&1; then
		find "$KERNEL_ROOT" -maxdepth 1 -type f -name '.tmp_*' -delete
	fi
}

if [[ "$MODE" == "clean" ]]; then
	echo "🔥 [1/5] Cleaning build artifacts..."
	make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" mrproper

	echo "🛠️ [2/5] Applying $DEFCONFIG..."
	make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" KBUILD_DEFCONFIG="$DEFCONFIG" defconfig
else
	if [[ ! -f "$OUT_DIR/.config" ]]; then
		echo "❌ fast mode requires an existing config in $OUT_DIR/.config"
		echo "Run: $0 clean"
		exit 1
	fi
	clean_source_tree_state
	echo "⚡ [1/3] Reusing existing build state..."
fi

echo "🏗️ [$([[ "$MODE" == "clean" ]] && echo "4/5" || echo "2/3")] Preparing Kernel headers and scripts..."
make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" olddefconfig
make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" prepare -j$(nproc)
make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" modules_prepare -j$(nproc)
# make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" techpack/audio/ -j$(nproc)


echo "🗺️ [$([[ "$MODE" == "clean" ]] && echo "5/5" || echo "3/3")] Generating LSP compile_commands.json..."
python3 scripts/gen_compile_commands.py \
	--directory "$COMPILE_COMMANDS_DIR" \
	--output "$COMPILE_COMMANDS_OUT"

echo "✅ SUCCESS: Environment ready. Please reload your IDE/LSP!"
