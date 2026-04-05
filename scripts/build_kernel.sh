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

  # Update the defconfig with the final build configuration (minimal format)
  if [[ -d "$(dirname "$TARGET_DEFCONFIG_PATH")" ]]; then
    echo "📝 Generating minimal defconfig: $TARGET_DEFCONFIG_PATH"
    make -s O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" savedefconfig
    if [[ -f "$OUT_DIR/defconfig" ]]; then
      cp "$OUT_DIR/defconfig" "$TARGET_DEFCONFIG_PATH"
      echo "✅ Defconfig updated successfully"
    else
      echo "⚠️ savedefconfig failed to generate defconfig"
    fi
  else
    echo "⚠️ Could not update defconfig (target directory missing)"
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
    echo "❌ [FATAL] Fast mode requires an existing config in $OUT_DIR/.config"
    exit 1
  fi
  clean_source_tree_state
fi

make -s O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" olddefconfig

echo "⚙️ Applying config patches..."
if "$KERNEL_ROOT/scripts/auto_patch_config.sh" "$OUT_DIR/.config"; then
  make -s O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" olddefconfig
  echo "✅ Config patches applied"
fi

# Calculate dynamic build jobs based on total system memory to prevent OOM kills
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

echo "🏗️ Building | mode=$MODE | jobs=$BUILD_JOBS | out=$OUT_DIR"
make -s -j"$BUILD_JOBS" O="$OUT_DIR" LLVM="$LLVM" LLVM_IAS="$LLVM_IAS" "$TARGET"

# --- PACKAGING PHASE ---
# Use a temporary staging directory to avoid polluting the final output dir during packaging
STAGING_DIR="$OUT_DIR/staging_ak3"
remove_dir "$STAGING_DIR"
ensure_dir "$STAGING_DIR"
remove_dir "$RESULT_DIR"
ensure_dir "$RESULT_DIR"

echo "🧩 Packing dtbo.img..."
if compgen -G "$DTBO_DIR/spes*.dtbo" >/dev/null; then
  python3 scripts/mkdtboimg.py create "$STAGING_DIR/dtbo.img" "$DTBO_DIR"/spes*.dtbo
  echo "✅ dtbo.img packed"
else
  echo "❌ [FATAL] No spes*.dtbo files found in: $DTBO_DIR"
  exit 1
fi

echo "📦 Preparing AnyKernel3 package..."
git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$STAGING_DIR/AnyKernel3"
rm -rf "$STAGING_DIR/AnyKernel3/.git" "$STAGING_DIR/AnyKernel3/README.md"

if [[ ! -f "$IMAGE_GZ_PATH" ]]; then
  echo "❌ [FATAL] Image.gz not found at $IMAGE_GZ_PATH"
  exit 1
fi

cp "$IMAGE_GZ_PATH" "$STAGING_DIR/AnyKernel3/"
cp "$STAGING_DIR/dtbo.img" "$STAGING_DIR/AnyKernel3/"

# Generate AnyKernel3 init script dynamically
cat << 'EOF' > "$STAGING_DIR/AnyKernel3/anykernel.sh"
### AnyKernel3 Ramdisk Mod Script
properties() { '
kernel.string=Spes Custom Kernel by n_gxc
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=spes
device.name2=spesn
'; }

block=boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh;
dump_boot;
write_boot;
flash_dtbo;
EOF

# Create final flashable zip and isolated kernel directory
KERNEL_DIR_NAME="Spes-$(date +'%Y%m%d-%H%M')"
KERNEL_DIR_PATH="$RESULT_DIR/$KERNEL_DIR_NAME"
ZIP_NAME="$KERNEL_DIR_NAME.zip"

echo "📁 Exporting artifacts..."
mv "$STAGING_DIR/AnyKernel3" "$KERNEL_DIR_PATH"

(
  cd "$RESULT_DIR"
  zip -r9q "$ZIP_NAME" "$KERNEL_DIR_NAME"
)

cp "$IMAGE_GZ_PATH" "$RESULT_DIR/"
cp "$STAGING_DIR/dtbo.img" "$RESULT_DIR/"

# Cleanup staging
remove_dir "$STAGING_DIR"

echo "🎉 Build & Packaging Successful!"
echo "📌 ZIP: $RESULT_DIR/$ZIP_NAME"
