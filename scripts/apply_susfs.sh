#!/usr/bin/env bash
set -euo pipefail

SUSFS_TMP_DIR="/tmp/susfs4ksu"
SUSFS_REPO="https://gitlab.com/simonpunk/susfs4ksu.git"
PATCH_FILE="${SUSFS_TMP_DIR}/kernel_patches/kernel_versions/4.19/50_macuser_hook_susfs_on_vfs.patch"

cleanup() {
  rm -rf "${SUSFS_TMP_DIR}"
}

trap cleanup EXIT

echo "🚀 Đang tải lõi SUSFS..."
rm -rf "${SUSFS_TMP_DIR}"
git clone -b kernel-4.19 --depth=1 "${SUSFS_REPO}" "${SUSFS_TMP_DIR}"

echo "🧬 [2/4] Đang bơm TẤT CẢ tế bào gốc (*.c và *.h) vào lõi..."
# Dùng *.c và *.h để hốt trọn ổ susfs.c, sus_su.c, susfs_def.h,...
cp ${SUSFS_TMP_DIR}/kernel_patches/fs/*.c fs/
cp ${SUSFS_TMP_DIR}/kernel_patches/include/linux/*.h include/linux/

echo "🔪 [3/4] Đang khâu Hook vào VFS (Dùng đúng patch mới)..."
PATCH_FILE="${SUSFS_TMP_DIR}/kernel_patches/50_add_susfs_in_kernel-4.19.patch"
patch -p1 < "${PATCH_FILE}"

patch -p1 < "${SUSFS_TMP_DIR}/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"

echo "🛠️ [4/4] Đang cập nhật Makefile cho cả 2 module..."
# Cập nhật Makefile để build cả susfs.o và sus_su.o
grep -q "susfs.o" fs/Makefile || echo "obj-\$(CONFIG_KSU_SUSFS) += susfs.o sus_su.o" >> fs/Makefile

echo "✅ Xong! Lần này bao mượt, gõ lệnh Make build kernel đi bro!"
