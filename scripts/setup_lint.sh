#!/bin/bash

# 🛑 BEST PRACTICE: Bật chế độ "Fail-Fast"
# Dừng script ngay lập tức nếu bất kỳ lệnh nào trả về mã lỗi (exit code != 0)
# Tránh tình trạng báo lỗi đỏ loét mà cuối cùng vẫn "DONE!" fake.
set -e

# 📍 CONTEXT AWARENESS: Tự động định vị thư mục gốc
# B1: Lấy đường dẫn tuyệt đối của chính cái script này (BASH_SOURCE)
# B2: Dùng dirname để lấy thư mục chứa script (thư mục scripts/)
# B3: Lùi lại 1 cấp (/..) và cd vào đó. Pwd sẽ in ra đường dẫn gốc chuẩn đét!
KERNEL_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Nhảy về thư mục gốc làm việc
cd "$KERNEL_ROOT"
echo "📍 Đã định vị và di chuyển về thư mục gốc: $KERNEL_ROOT"

# --- CONFIGURATION ---
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export LLVM=1
# Lưu ý: Tên config của spes thường là spes_defconfig, bro check lại file nhé!
DEFCONFIG="defconfig"

echo "🔥 [1/5] Cleaning up old mess..."
make LLVM=1 mrproper

echo "🛠️ [2/5] Applying $DEFCONFIG..."
make LLVM=1 $DEFCONFIG

echo "💉 [3/5] Patching Makefile for modern Clang..."
# Dùng sed -i.bak để backup file gốc trước khi sửa (an toàn là bạn)
sed -i.bak 's/-enable-trivial-auto-var-init-zero-knowing-it-will-be-removed-from-clang//g' Makefile
sed -i.bak 's/-ftrivial-auto-var-init=zero//g' Makefile

echo "🏗️ [4/5] Preparing Kernel headers and symlinks..."
make LLVM=1 olddefconfig
make LLVM=1 prepare -j$(nproc)
make LLVM=1 modules_prepare -j$(nproc)

echo "🗺️ [5/5] Generating compile_commands.json..."
# Đã đứng ở thư mục gốc thì gọi relative path chuẩn luôn
python3 scripts/gen_compile_commands.py

echo "✅ DONE XỊN! Mọi thứ đã xanh mượt, mời bro reload window!"
