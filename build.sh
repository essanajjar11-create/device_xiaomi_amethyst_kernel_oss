#!/usr/bin/env bash
#
# Build script for Xiaomi Redmi Note 14 Pro+ 5G (amethyst) OSS Kernel
# Target Platform: Qualcomm SM7635 Snapdragon 7s Gen 3 (volcano)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

ARCH="arm64"
SUBARCH="arm64"
DEFCONFIG="amethyst_defconfig"
OUT_DIR="${SCRIPT_DIR}/out"
DIST_DIR="${SCRIPT_DIR}/dist"
JOBS="$(nproc --all 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 8)"

CLANG_VERSION="r487747c"
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android14-release/clang-${CLANG_VERSION}.tar.gz"
TOOLCHAIN_DIR="${SCRIPT_DIR}/toolchain/clang"

DO_CLEAN=false
DO_MRPROPER=false
DO_MENUCONFIG=false
DO_MODULES=true
DO_DEPLOY=false
PREBUILT_KERNEL_DIR="${SCRIPT_DIR}/../device_xiaomi_amethyst-kernel"

function print_help() {
    cat << EOF
Usage: ./build.sh [OPTIONS]

Options:
  -c, --clean            Clean build output directory (make clean)
  -m, --mrproper         Full clean (make mrproper and remove out/)
  -d, --defconfig <cfg>  Specify custom defconfig (default: amethyst_defconfig)
  --menuconfig           Run menuconfig before building
  --no-modules           Skip module compilation (build Image only)
  --deploy               Deploy compiled Image and in-tree modules to device_xiaomi_amethyst-kernel
  -j, --jobs <num>       Specify parallel compilation jobs (default: all CPU cores)
  -h, --help             Show this help message
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean)
            DO_CLEAN=true
            shift
            ;;
        -m|--mrproper)
            DO_MRPROPER=true
            shift
            ;;
        -d|--defconfig)
            DEFCONFIG="$2"
            shift 2
            ;;
        --menuconfig)
            DO_MENUCONFIG=true
            shift
            ;;
        --no-modules)
            DO_MODULES=false
            shift
            ;;
        --deploy)
            DO_DEPLOY=true
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

echo "============================================================"
echo " Building OSS Kernel for Xiaomi Redmi Note 14 Pro+ 5G (amethyst)"
echo " SoC: Qualcomm SM7635 Snapdragon 7s Gen 3 (volcano)"
echo " Defconfig: ${DEFCONFIG}"
echo " Jobs: ${JOBS}"
echo "============================================================"

# Ensure toolchain is available
if [ -z "${CLANG_PATH}" ]; then
    if [ -f "${TOOLCHAIN_DIR}/bin/clang" ]; then
        CLANG_PATH="${TOOLCHAIN_DIR}"
    elif command -v clang >/dev/null 2>&1 && clang --version | grep -q "clang version"; then
        CLANG_PATH="$(dirname $(dirname $(which clang)))"
    else
        echo "--> Clang toolchain not detected. Downloading AOSP Clang ${CLANG_VERSION}..."
        mkdir -p "${TOOLCHAIN_DIR}"
        curl -fSL "${CLANG_URL}" -o /tmp/clang.tar.gz
        tar -xzf /tmp/clang.tar.gz -C "${TOOLCHAIN_DIR}"
        rm -f /tmp/clang.tar.gz
        CLANG_PATH="${TOOLCHAIN_DIR}"
    fi
fi

echo "--> Using Clang: ${CLANG_PATH}/bin/clang"
export PATH="${CLANG_PATH}/bin:${PATH}"

# Build variables
export ARCH="${ARCH}"
export SUBARCH="${SUBARCH}"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
export LLVM=1
export LLVM_IAS=1

mkdir -p "${OUT_DIR}"
mkdir -p "${DIST_DIR}"

if [ "${DO_MRPROPER}" = true ]; then
    echo "--> Running mrproper..."
    make O="${OUT_DIR}" mrproper
    rm -rf "${OUT_DIR}"/* "${DIST_DIR}"/*
fi

if [ "${DO_CLEAN}" = true ]; then
    echo "--> Cleaning output directory..."
    make O="${OUT_DIR}" clean
fi

# 1. Configure defconfig
echo "--> Generating defconfig: ${DEFCONFIG}..."
make O="${OUT_DIR}" "${DEFCONFIG}"

if [ "${DO_MENUCONFIG}" = true ]; then
    make O="${OUT_DIR}" menuconfig
fi

# 2. Compile Kernel Image
echo "--> Compiling Kernel Image..."
make -j"${JOBS}" O="${OUT_DIR}" Image

if [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/Image" "${DIST_DIR}/Image"
    echo "--> Successfully built: ${DIST_DIR}/Image"
else
    echo "ERROR: Kernel Image not found at ${OUT_DIR}/arch/arm64/boot/Image"
    exit 1
fi

# 3. Compile Modules (if requested)
if [ "${DO_MODULES}" = true ]; then
    echo "--> Compiling Kernel Modules..."
    make -j"${JOBS}" O="${OUT_DIR}" modules

    MODULES_STAGING="${DIST_DIR}/modules_staging"
    rm -rf "${MODULES_STAGING}"
    mkdir -p "${MODULES_STAGING}"

    echo "--> Installing modules to staging..."
    make O="${OUT_DIR}" INSTALL_MOD_PATH="${MODULES_STAGING}" INSTALL_MOD_STRIP=1 modules_install

    # Gather in-tree .ko files
    mkdir -p "${DIST_DIR}/modules"
    find "${MODULES_STAGING}" -name "*.ko" -exec cp {} "${DIST_DIR}/modules/" \;
    echo "--> Collected $(find "${DIST_DIR}/modules" -name "*.ko" | wc -l) modules in ${DIST_DIR}/modules/"
fi

# 4. Optional: Deploy to prebuilt repository
if [ "${DO_DEPLOY}" = true ]; then
    echo "--> Deploying artifacts to ${PREBUILT_KERNEL_DIR}..."
    if [ ! -d "${PREBUILT_KERNEL_DIR}" ]; then
        echo "ERROR: Prebuilt kernel directory not found at ${PREBUILT_KERNEL_DIR}"
        exit 1
    fi

    # Update Image
    cp "${DIST_DIR}/Image" "${PREBUILT_KERNEL_DIR}/images/kernel"
    echo "  [OK] Updated ${PREBUILT_KERNEL_DIR}/images/kernel"

    # Update matching in-tree modules in vendor_dlkm if present
    if [ -d "${DIST_DIR}/modules" ] && [ -d "${PREBUILT_KERNEL_DIR}/modules/vendor_dlkm" ]; then
        for ko in "${DIST_DIR}/modules"/*.ko; do
            ko_name="$(basename "${ko}")"
            if [ -f "${PREBUILT_KERNEL_DIR}/modules/vendor_dlkm/${ko_name}" ]; then
                cp "${ko}" "${PREBUILT_KERNEL_DIR}/modules/vendor_dlkm/${ko_name}"
                echo "  [OK] Replaced vendor_dlkm module: ${ko_name}"
            fi
        done
    fi
    echo "--> Deployment complete!"
fi

echo "============================================================"
echo " Build finished successfully!"
echo " Kernel Image: ${DIST_DIR}/Image"
if [ "${DO_MODULES}" = true ]; then
    echo " Modules Directory: ${DIST_DIR}/modules/"
fi
echo "============================================================"
