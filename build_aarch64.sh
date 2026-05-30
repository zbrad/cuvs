#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# cuVS aarch64 Build Script
# Target: NVIDIA DGX Spark — GB10 Grace Blackwell Superchip (aarch64)
#
# Hardware:
#   GPU:  GB10 Blackwell (SM 103)
#   CPU:  Grace arm64 (aarch64 / sbsa-linux)
#   MEM:  128GB LPDDR5X unified (NVLink-C2C, zero-copy GPU access)
#
# Library naming convention (mirrors zbrad/faiss gpu-cu/docs/WHEEL_NAMING.md):
#   Single-arch build → libcuvs-aarch64-cu<tag>-sm103.so
#
# To build with a different CUDA version:
#   CUDA_VER=13.3 bash build_aarch64.sh   →  libcuvs-aarch64-cu133-sm103.so
#   CUDA_TAG=cu133 bash build_aarch64.sh  →  (same, tag form)
#
# See scripts/cuda_env.sh for the CUDA version knob.

set -e

REPODIR=$(cd "$(dirname "$0")"; pwd)

# Source the single CUDA-version knob (sets CUDA_VER, CUDA_TAG, CUDA_HOME, cuvs_sm_suffix)
# shellcheck source=scripts/cuda_env.sh
source "${REPODIR}/scripts/cuda_env.sh"

# Verify we are on aarch64
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
  echo "ERROR: This script targets aarch64 (DGX Spark / Grace)."
  echo "       Current arch: $ARCH"
  echo "       For x86_64 discrete GPU builds use: ./build_x86_64.sh"
  exit 1
fi

# Single GPU arch → include -sm suffix in library name
CUDA_ARCHS="103-real"
SM_SUFFIX=$(cuvs_sm_suffix "$CUDA_ARCHS")              # -sm103
CUVS_LIB_NAME="cuvs-aarch64-${CUDA_TAG}${SM_SUFFIX}"  # cuvs-aarch64-cu132-sm103

echo "===================================================="
echo "cuVS aarch64 Build (DGX Spark)"
echo "===================================================="
echo ""
echo "  Target GPU : GB10 Grace Blackwell Superchip"
echo "  SM arch    : 103-real"
echo "  Host arch  : aarch64 (sbsa-linux)"
echo "  Memory     : 128GB unified LPDDR5X (NVLink-C2C)"
echo "  CUDA ver   : ${CUDA_VER} (${CUDA_TAG})"
echo "  CUDA home  : ${CUDA_HOME}"
echo "  Output lib : lib${CUVS_LIB_NAME}.so"
echo ""
echo "CUDA Version: $(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',')"
echo ""

# Clean previous build
echo "Cleaning previous build artifacts..."
cd "$REPODIR"
./build.sh clean

echo "Starting lib${CUVS_LIB_NAME} build for DGX Spark (SM 103)..."
echo ""

LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-${REPODIR}/cpp/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${PREFIX:-${CONDA_PREFIX:-${LIBCUVS_BUILD_DIR}/install}}}"
PARALLEL_LEVEL="${PARALLEL_LEVEL:-$(nproc)}"

mkdir -p "${LIBCUVS_BUILD_DIR}"

cmake -S "${REPODIR}/cpp" -B "${LIBCUVS_BUILD_DIR}" \
  -G Ninja \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
  -DBUILD_C_LIBRARY=ON \
  -DCUVS_NVTX=ON \
  -DCUDA_LOG_COMPILE_TIME=OFF \
  -DDISABLE_DEPRECATION_WARNINGS=ON \
  -DBUILD_TESTS=OFF \
  -DBUILD_C_TESTS=OFF \
  -DBUILD_CUVS_BENCH=OFF \
  -DBUILD_CPU_ONLY=OFF \
  -DBUILD_MG_ALGOS=OFF \
  -DBUILD_SHARED_LIBS=ON \
  "-DCUVS_OUTPUT_NAME=${CUVS_LIB_NAME}"

cmake --build "${LIBCUVS_BUILD_DIR}" -j"${PARALLEL_LEVEL}" --target cuvs cuvs_c install

# Verify output
LIBDIR="${REPODIR}/cpp/build"
EXPECTED_LIB="${LIBDIR}/lib${CUVS_LIB_NAME}.so"
if [[ -f "${EXPECTED_LIB}" ]]; then
  echo "  Library built: ${EXPECTED_LIB} ($(du -h "${EXPECTED_LIB}" | cut -f1))"
else
  echo "WARNING: Expected lib${CUVS_LIB_NAME}.so not found in ${LIBDIR}"
  echo "  Files present: $(ls "${LIBDIR}"/libcuvs*.so 2>/dev/null || echo 'none')"
fi

echo ""
echo "===================================================="
echo "aarch64 Build Complete!"
echo "===================================================="
echo ""
echo "  ✓ SM 103 (GB10 Grace Blackwell) native binary"
echo "  ✓ aarch64 host code (Grace CPU)"
echo "  ✓ Zero-copy NVLink-C2C memory path"
echo "  ✓ Output: ${LIBDIR}/lib${CUVS_LIB_NAME}.so"
echo ""
echo "Deploy to DGX Spark:"
echo "  cp ${LIBDIR}/lib${CUVS_LIB_NAME}.so /usr/local/lib/"
echo "  ldconfig"
echo ""
echo "NOTE for faiss consumers (zbrad/faiss gpu-cu/scripts/build_lib_aarch64.sh):"
echo "  Library is now: ${LIBDIR}/lib${CUVS_LIB_NAME}.so"
echo "  Update libcuvs-spark.so references in build_lib_aarch64.sh and build_pkg_aarch64.sh."
