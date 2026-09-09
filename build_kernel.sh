#!/usr/bin/env bash
# ==============================================================================
# Sina-Amethyst Kernel Local Build Script for WSL2 (Ubuntu)
# Target: Xiaomi Redmi Note 14 Pro+ (amethyst) - Snapdragon 7s Gen 3 (SM7635)
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}    Sina-Amethyst Kernel Local Builder (WSL2/Linux)   ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Source directory where the script lives
ORIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install Dependencies if needed
echo -e "\n${YELLOW}[1/6] Checking build dependencies...${NC}"
REQUIRED_PACKAGES=(
    bc bison binutils-aarch64-linux-gnu ca-certificates cpio curl
    dwarves flex gcc g++ git kmod libelf-dev libssl-dev make
    python3 rsync tar xz-utils zip
)

MISSING_PACKAGES=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
        MISSING_PACKAGES+=("${pkg}")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing packages: ${MISSING_PACKAGES[*]}...${NC}"
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${MISSING_PACKAGES[@]}"
else
    echo -e "${GREEN}All required packages are installed.${NC}"
fi

# 2. Sync to native WSL ext4 filesystem if running from /mnt/c
# (Windows NTFS is case-insensitive and slow for Kbuild; ext4 avoids netfilter case collisions and speeds up build 5x)
if [[ "${ORIG_DIR}" == /mnt/* ]]; then
    BUILD_DIR="${HOME}/amethyst_kernel_build"
    echo -e "\n${CYAN}[Optimization] Syncing source to native Linux ext4 at ${BUILD_DIR}...${NC}"
    mkdir -p "${BUILD_DIR}"
    rsync -au --delete --exclude='out' --exclude='dist' --exclude='.git' "${ORIG_DIR}/" "${BUILD_DIR}/"
    cd "${BUILD_DIR}"
    KERNEL_DIR="${BUILD_DIR}"
else
    cd "${ORIG_DIR}"
    KERNEL_DIR="${ORIG_DIR}"
fi

# 3. Setup AOSP Clang Toolchain (Cached in ~/.android-toolchains)
echo -e "\n${YELLOW}[2/6] Checking AOSP Clang toolchain...${NC}"
TOOLCHAIN_DIR="${HOME}/.android-toolchains/clang-r487747c"
if [ ! -f "${TOOLCHAIN_DIR}/bin/clang" ]; then
    echo -e "${BLUE}Downloading AOSP Clang r487747c (one-time download)...${NC}"
    mkdir -p "${TOOLCHAIN_DIR}"
    CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android14-release/clang-r487747c.tar.gz"
    curl -fSL "${CLANG_URL}" -o /tmp/clang-r487747c.tar.gz
    tar -xzf /tmp/clang-r487747c.tar.gz -C "${TOOLCHAIN_DIR}"
    rm -f /tmp/clang-r487747c.tar.gz
    echo -e "${GREEN}Clang toolchain downloaded and cached successfully.${NC}"
else
    echo -e "${GREEN}Using cached Clang at ${TOOLCHAIN_DIR}${NC}"
fi

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
clang --version | head -n 1

# 4. Setup AnyKernel3 packaging template
echo -e "\n${YELLOW}[3/6] Setting up AnyKernel3 packaging template...${NC}"
if [ ! -d "anykernel/.git" ]; then
    rm -rf anykernel
    git clone https://github.com/WildKernels/AnyKernel3.git -b gki-2.0 --depth=1 anykernel
fi
cp -f .github/anykernel.sh anykernel/anykernel.sh
cp -f .github/banner anykernel/banner

# 5. Configure & Build Kernel
echo -e "\n${YELLOW}[4/6] Compiling Sina-Amethyst Kernel...${NC}"
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export LLVM=1
export LLVM_IAS=1
export LOCALVERSION=""

THREADS=$(nproc --all)
echo -e "${BLUE}Using ${THREADS} CPU threads for compilation...${NC}"

mkdir -p out dist/modules dist/modules_staging

echo -e "${BLUE}--> Generating amethyst_defconfig...${NC}"
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 amethyst_defconfig

echo -e "${BLUE}--> Building kernel Image...${NC}"
make -j"${THREADS}" O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 Image

echo -e "${BLUE}--> Building in-tree modules...${NC}"
make -j"${THREADS}" O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 modules

cp -f out/arch/arm64/boot/Image dist/Image

# 6. Install & Stage Modules
echo -e "\n${YELLOW}[5/6] Staging kernel modules...${NC}"
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 INSTALL_MOD_PATH="${KERNEL_DIR}/dist/modules_staging" INSTALL_MOD_STRIP=1 modules_install
find "${KERNEL_DIR}/dist/modules_staging" -name "*.ko" -exec cp -f {} "${KERNEL_DIR}/dist/modules/" \;
tar -czf "${KERNEL_DIR}/dist/Sina-Amethyst-modules.tar.gz" -C "${KERNEL_DIR}/dist/modules" .

# 7. Package AnyKernel3 Zip and Copy to Windows Desktop
echo -e "\n${YELLOW}[6/6] Packaging flashable zip...${NC}"
cp -f dist/Image anykernel/Image
cd anykernel
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ZIP_NAME="Sina-Amethyst-Kernel-6.1.68-${TIMESTAMP}.zip"
zip -r9 "../dist/${ZIP_NAME}" * -x .git README.md *placeholder
cd "${KERNEL_DIR}"

# Detect Windows Desktop in WSL
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || echo "ASUS")
DESKTOP_DIR="/mnt/c/Users/${WIN_USER}/Desktop"

if [ -d "${DESKTOP_DIR}" ]; then
    cp -f "dist/${ZIP_NAME}" "${DESKTOP_DIR}/"
    echo -e "\n${GREEN}======================================================${NC}"
    echo -e "${GREEN} BUILD COMPLETE! Flashable zip copied to your Desktop:${NC}"
    echo -e "${YELLOW} ${DESKTOP_DIR}/${ZIP_NAME}${NC}"
    echo -e "${GREEN}======================================================${NC}"
else
    echo -e "\n${GREEN}======================================================${NC}"
    echo -e "${GREEN} BUILD COMPLETE! Flashable zip generated at:${NC}"
    echo -e "${YELLOW} ${KERNEL_DIR}/dist/${ZIP_NAME}${NC}"
    echo -e "${GREEN}======================================================${NC}"
fi
