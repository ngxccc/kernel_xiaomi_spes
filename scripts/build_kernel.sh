#!/bin/bash

set -euo pipefail

KERNEL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$KERNEL_ROOT"

MODE="${1:-clean}"
OUT_DIR="${OUT_DIR:-$KERNEL_ROOT/out}"
DEFCONFIG="${DEFCONFIG:-vendor/spes-perf_defconfig}"
TARGET="${TARGET:-Image.gz-dtb}"

case "$MODE" in
	clean|fast)
		;;
	*)
		echo "Usage: $0 [clean|fast]"
		exit 1
		;;
esac

export ARCH="${ARCH:-arm64}"
export SUBARCH="${SUBARCH:-arm64}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32:-arm-linux-gnueabi-}"
export LLVM="${LLVM:-1}"
export LLVM_IAS="${LLVM_IAS:-1}"

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

if [[ "$MODE" == "clean" ]]; then
	rm -rf "$OUT_DIR"
	mkdir -p "$OUT_DIR"
	make -s O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" KBUILD_DEFCONFIG="$DEFCONFIG" defconfig
else
	if [[ ! -f "$OUT_DIR/.config" ]]; then
		echo "❌ fast mode requires an existing config in $OUT_DIR/.config"
		echo "Run: $0 clean"
		exit 1
	fi
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
