#!/bin/bash

: "${KERNEL_ROOT:?KERNEL_ROOT must be set before sourcing kernel_build_common.sh}"

export ARCH="${ARCH:-arm64}"
export SUBARCH="${SUBARCH:-arm64}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
export CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32:-arm-linux-gnueabi-}"
export LLVM="${LLVM:-1}"
export LLVM_IAS="${LLVM_IAS:-1}"

DEFCONFIG="${DEFCONFIG:-vendor/spes-perf_defconfig}"
OUT_DIR="${OUT_DIR:-$KERNEL_ROOT/out}"
TARGET="${TARGET:-Image.gz-dtb}"
COMPILE_COMMANDS_DIR="${COMPILE_COMMANDS_DIR:-$OUT_DIR}"
COMPILE_COMMANDS_OUT="${COMPILE_COMMANDS_OUT:-$KERNEL_ROOT/compile_commands.json}"

# Common artifact/config paths used by build scripts
TARGET_DEFCONFIG_PATH="${TARGET_DEFCONFIG_PATH:-arch/$ARCH/configs/$DEFCONFIG}"
IMAGE_GZ_PATH="${IMAGE_GZ_PATH:-$OUT_DIR/arch/arm64/boot/Image.gz}"
DTBO_DIR="${DTBO_DIR:-$OUT_DIR/arch/arm64/boot/dts/vendor/qcom}"
RESULT_DIR="${RESULT_DIR:-$KERNEL_ROOT/out/result}"
DTBO_IMAGE="${DTBO_IMAGE:-$RESULT_DIR/dtbo.img}"
