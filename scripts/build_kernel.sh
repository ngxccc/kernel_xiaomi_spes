#!/bin/bash

set -euo pipefail

KERNEL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$KERNEL_ROOT"

. "$KERNEL_ROOT/scripts/kernel_build_common.sh"

MODE="${1:-clean}"
GEN_COMPILE_COMMANDS="${GEN_COMPILE_COMMANDS:-1}"
BUILD_ATTEMPTED=0

case "$MODE" in
	clean|fast)
		;;
	*)
		echo "Usage: $0 [clean|fast]"
		exit 1
		;;
esac

if [[ "$GEN_COMPILE_COMMANDS" != "0" && "$GEN_COMPILE_COMMANDS" != "1" ]]; then
	echo "❌ Invalid GEN_COMPILE_COMMANDS value: $GEN_COMPILE_COMMANDS"
	echo "Use GEN_COMPILE_COMMANDS=1 (enabled) or GEN_COMPILE_COMMANDS=0 (disabled)"
	exit 1
fi

on_exit() {
	local build_status="$1"
	local gen_status=0

	if [[ "$BUILD_ATTEMPTED" == "1" && "$GEN_COMPILE_COMMANDS" == "1" ]]; then
		echo "🗺️ Generating compile_commands.json from $COMPILE_COMMANDS_DIR..."
		set +e
		python3 scripts/gen_compile_commands.py \
			--directory "$COMPILE_COMMANDS_DIR" \
			--output "$COMPILE_COMMANDS_OUT"
		gen_status=$?
		set -e

		if [[ "$gen_status" -eq 0 ]]; then
			echo "✅ compile_commands generated: $COMPILE_COMMANDS_OUT"
		else
			echo "⚠️ Failed to generate compile_commands (exit $gen_status), keeping build status: $build_status"
		fi
	fi

	return "$build_status"
}

trap 'on_exit "$?"' EXIT

if command -v ccache >/dev/null 2>&1; then
	export CC="${CC:-ccache clang}"
else
	export CC="${CC:-clang}"
fi

if [[ -n "${KBUILD_BUILD_USER:-}" ]]; then
	export KBUILD_BUILD_USER
fi

if [[ -n "${KBUILD_BUILD_HOST:-}" ]]; then
	export KBUILD_BUILD_HOST
fi

remove_dir() {
	local target_dir="$1"
	if [[ ! -e "$target_dir" ]]; then
		return 0
	fi
	if rm -rf "$target_dir"; then
		return 0
	fi
	if command -v sudo >/dev/null 2>&1; then
		sudo rm -rf "$target_dir"
		return 0
	fi
	echo "❌ Cannot remove $target_dir. Check permissions or run the script with sudo."
	exit 1
}

ensure_dir() {
	local target_dir="$1"
	if mkdir -p "$target_dir"; then
		return 0
	fi
	if command -v sudo >/dev/null 2>&1; then
		sudo mkdir -p "$target_dir"
		return 0
	fi
	echo "❌ Cannot create $target_dir. Check permissions or run the script with sudo."
	exit 1
}

clean_source_tree_state() {
	remove_dir "$KERNEL_ROOT/include/generated"
	remove_dir "$KERNEL_ROOT/arch/arm64/include/generated"
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

BUILD_ATTEMPTED=1

if [[ "$MODE" == "clean" ]]; then
	remove_dir "$OUT_DIR"
	ensure_dir "$OUT_DIR"
	make -s O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" KBUILD_DEFCONFIG="$DEFCONFIG" defconfig
else
	if [[ ! -f "$OUT_DIR/.config" ]]; then
		echo "❌ fast mode requires an existing config in $OUT_DIR/.config"
		echo "Run: $0 clean"
		exit 1
	fi
	clean_source_tree_state
fi

make -s O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" olddefconfig

TOTAL_MEM_GB=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
CPU_CORES=$(nproc --all)
if [[ -n "${JOBS:-}" ]]; then
	BUILD_JOBS="$JOBS"
elif [[ "$TOTAL_MEM_GB" -le 8 ]]; then
	BUILD_JOBS=$((CPU_CORES / 2))
elif [[ "$TOTAL_MEM_GB" -le 12 ]]; then
	BUILD_JOBS=$((CPU_CORES * 2 / 3))
else
	BUILD_JOBS="$CPU_CORES"
fi

[[ "$BUILD_JOBS" -lt 1 ]] && BUILD_JOBS=1

echo "🏗️ Building $TARGET | mode=$MODE | jobs=$BUILD_JOBS | out=$OUT_DIR"
make -s -j"$BUILD_JOBS" O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" "$TARGET"

IMAGE_PATH="$OUT_DIR/arch/arm64/boot/$TARGET"
if [[ ! -f "$IMAGE_PATH" ]]; then
	echo "❌ Build finished but image not found: $IMAGE_PATH"
	exit 1
fi

echo "✅ Build complete: $IMAGE_PATH"
