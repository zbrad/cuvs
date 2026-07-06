#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# cuVS RTX 50 Build Script — Blackwell (x86_64)
#
# Supported GPU Architecture:
#   Blackwell (120): RTX 5080, RTX 5090
#
# This is a single-arch build targeting only owned/verified consumer
# hardware. See gpu-build/docs/WHEEL_NAMING.md for why datacenter Blackwell
# archs (B100/B200, GB200 NVL) were dropped from this repo's build matrix
# entirely rather than bundled in alongside this one.
#
# Library naming convention (see gpu-build/docs/WHEEL_NAMING.md): builds are
# named by GPU codename, mirroring zbrad/vllm's gb10 branch convention:
#   libcuvs-rtx50-cu<tag>.so
#
# To build with a different CUDA version:
#   CUDA_VER=13.3 bash build_rtx50.sh   →  libcuvs-rtx50-cu133.so
#   CUDA_TAG=cu133 bash build_rtx50.sh  →  (same, tag form)
#
# See scripts/cuda_env.sh for the CUDA version knob.
# See build_rtx40.sh for the Ada Lovelace (RTX 4080/4090) build.

set -e

REPODIR=$(cd "$(dirname "$0")"; pwd)

# Source the single CUDA-version knob (sets CUDA_VER, CUDA_TAG, CUDA_HOME)
# shellcheck source=scripts/cuda_env.sh
source "${REPODIR}/scripts/cuda_env.sh"

# Single-arch build: SM 120 (Blackwell consumer) only.
CUDA_ARCHS="120-real"
CUVS_LIB_NAME="cuvs-rtx50-${CUDA_TAG}"  # cuvs-rtx50-cu132

echo "===================================================="
echo "cuVS RTX 50 Build (Blackwell)"
echo "===================================================="
echo ""
echo "  Target GPU : RTX 5080, RTX 5090"
echo "  SM arch    : 120-real (Blackwell)"
echo "  Host arch  : x86_64"
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

echo "Starting lib${CUVS_LIB_NAME} build for RTX 50 (SM 120)..."
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
  -DBUILD_MG_ALGOS=ON \
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
echo "RTX 50 Build Complete!"
echo "===================================================="
echo ""
echo "  ✓ RTX 5080/5090 (Blackwell, SM 120) native binary"
echo "  ✓ Output: ${LIBDIR}/lib${CUVS_LIB_NAME}.so"
