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
AUTO_PATCH="${AUTO_PATCH:-1}"

case "$MODE" in
	clean|fast)
		;;
	*)
		echo "❌ Invalid mode: $MODE"
		echo "Usage: $0 [clean|fast]"
		exit 1
		;;
esac

if [[ "$AUTO_PATCH" != "0" && "$AUTO_PATCH" != "1" ]]; then
	echo "❌ Invalid AUTO_PATCH value: $AUTO_PATCH"
	echo "Use AUTO_PATCH=1 (enabled) or AUTO_PATCH=0 (disabled)"
	exit 1
fi

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
	if [[ "$AUTO_PATCH" == "1" ]]; then
		echo "🧩 [1/4] Running auto_patch_config.sh to patch and update $DEFCONFIG..."
		"$KERNEL_ROOT/scripts/auto_patch_config.sh"
	else
		echo "🔥 [1/5] Cleaning build artifacts..."
		make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" mrproper

		echo "🛠️ [2/5] Applying $DEFCONFIG..."
		make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" KBUILD_DEFCONFIG="$DEFCONFIG" defconfig
	fi
else
	if [[ ! -f "$OUT_DIR/.config" ]]; then
		echo "❌ fast mode requires an existing config in $OUT_DIR/.config"
		echo "Run: $0 clean"
		exit 1
	fi
	clean_source_tree_state
	echo "⚡ [1/3] Reusing existing build state..."
fi

if [[ "$MODE" == "clean" && "$AUTO_PATCH" == "1" ]]; then
	PREP_STEP="2/4"
	GEN_STEP="3/4"
elif [[ "$MODE" == "clean" ]]; then
	PREP_STEP="4/5"
	GEN_STEP="5/5"
else
	PREP_STEP="2/3"
	GEN_STEP="3/3"
fi

echo "🏗️ [$PREP_STEP] Preparing Kernel headers and scripts..."
make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" olddefconfig
make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" prepare -j$(nproc)
make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" modules_prepare -j$(nproc)
# make O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" techpack/audio/ -j$(nproc)


echo "🗺️ [$GEN_STEP] Generating LSP compile_commands.json..."
python3 scripts/gen_compile_commands.py \
	--directory "$COMPILE_COMMANDS_DIR" \
	--output "$COMPILE_COMMANDS_OUT"

echo "✅ SUCCESS: Environment ready. Please reload your IDE/LSP!"
