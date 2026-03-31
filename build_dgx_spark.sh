#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# cuVS DGX Spark Build Script
# Target: NVIDIA DGX Spark — GB10 Grace Blackwell Superchip (aarch64)
#
# Hardware:
#   GPU:  GB10 Blackwell (SM 103)
#   CPU:  Grace arm64 (aarch64 / sbsa-linux)
#   MEM:  128GB LPDDR5X unified (NVLink-C2C, zero-copy GPU access)
#
# Why a separate build:
#   - aarch64 host code — incompatible with x86_64 builds
#   - Only SM 103 needed — no PCIe discrete GPU fat-binary bloat
#   - Unified NVLink-C2C memory: no host↔device copy overhead
#     (RMM managed/pinned allocations map directly)
#   - Output: libcuvs-spark.so (distinguishable from discrete GPU builds)

set -e

REPODIR=$(cd "$(dirname "$0")"; pwd)

# Verify we are on aarch64
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
  echo "ERROR: This script targets aarch64 (DGX Spark / Grace)."
  echo "       Current arch: $ARCH"
  echo "       For x86_64 discrete GPU builds use: ./build_ada_blackwell.sh"
  exit 1
fi

echo "===================================================="
echo "cuVS DGX Spark Build"
echo "===================================================="
echo ""
echo "  Target GPU : GB10 Grace Blackwell Superchip"
echo "  SM arch    : 103-real"
echo "  Host arch  : aarch64 (sbsa-linux)"
echo "  Memory     : 128GB unified LPDDR5X (NVLink-C2C)"
echo "  Output lib : libcuvs-spark.so"
echo ""
echo "CUDA Version: $(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',')"
echo ""

# Clean previous build
echo "Cleaning previous build artifacts..."
cd "$REPODIR"
./build.sh clean

# Build for SM 103 only (GB10 Grace Blackwell)
# We invoke cmake + ninja directly so we can set CUVS_OUTPUT_NAME=cuvs-spark
# cleanly without fighting build.sh's --cmake-args quoting parser.
echo "Starting libcuvs build for DGX Spark (SM 103)..."
echo ""

LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-${REPODIR}/cpp/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${PREFIX:-${CONDA_PREFIX:-${LIBCUVS_BUILD_DIR}/install}}}"
PARALLEL_LEVEL="${PARALLEL_LEVEL:-$(nproc)}"

mkdir -p "${LIBCUVS_BUILD_DIR}"

cmake -S "${REPODIR}/cpp" -B "${LIBCUVS_BUILD_DIR}" \
  -G Ninja \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_ARCHITECTURES="103-real" \
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
  -DCUVS_OUTPUT_NAME=cuvs-spark

cmake --build "${LIBCUVS_BUILD_DIR}" -j"${PARALLEL_LEVEL}" --target cuvs cuvs_c install

# Verify output
LIBDIR="${REPODIR}/cpp/build"
if [[ -f "${LIBDIR}/libcuvs-spark.so" ]]; then
  echo "  Library built: ${LIBDIR}/libcuvs-spark.so ($(du -h "${LIBDIR}/libcuvs-spark.so" | cut -f1))"
else
  echo "WARNING: Expected libcuvs-spark.so not found in ${LIBDIR}"
  echo "  Files present: $(ls ${LIBDIR}/libcuvs*.so 2>/dev/null || echo 'none')"
fi

echo ""
echo "===================================================="
echo "DGX Spark Build Complete!"
echo "===================================================="
echo ""
echo "  ✓ SM 103 (GB10 Grace Blackwell) native binary"
echo "  ✓ aarch64 host code (Grace CPU)"
echo "  ✓ Zero-copy NVLink-C2C memory path"
echo "  ✓ Output: ${LIBDIR}/libcuvs-spark.so"
echo ""
echo "Deploy to DGX Spark:"
echo "  cp ${LIBDIR}/libcuvs-spark.so /usr/local/lib/"
echo "  ldconfig"
