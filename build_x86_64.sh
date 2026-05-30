#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# cuVS x86_64 Build Script — RTX 4080 through RTX 5090 & Datacenter GPUs
#
# Supported GPU Architectures:
#   Ada Lovelace  (89):    RTX 4080, RTX 4090, RTX 6000 Ada, L40, L40S
#   Hopper       (90a):   H100 PCIe, H100 SXM, H200
#   Blackwell DC (100f):  B100, B200
#   Blackwell DC (101):   B10x mid-tier
#   DGX Spark    (103):   GB10 Grace Blackwell Superchip
#   Blackwell NVL(120a):  GB200 NVL72 tensor-optimized
#   Blackwell    (120):   RTX 5080, RTX 5090, GB200 NVL systems
#   Blackwell    (121):   GB201/GB202 follow-on variants
#
# Library naming convention (mirrors zbrad/faiss gpu-cu/docs/WHEEL_NAMING.md):
#   Multi-arch build → libcuvs-x86_64-cu<tag>.so  (no -sm suffix)
#
# To build with a different CUDA version:
#   CUDA_VER=13.3 bash build_x86_64.sh   →  libcuvs-x86_64-cu133.so
#   CUDA_TAG=cu133 bash build_x86_64.sh  →  (same, tag form)
#
# See scripts/cuda_env.sh for the CUDA version knob.

set -e

REPODIR=$(cd "$(dirname "$0")"; pwd)

# Source the single CUDA-version knob (sets CUDA_VER, CUDA_TAG, CUDA_HOME, cuvs_sm_suffix)
# shellcheck source=scripts/cuda_env.sh
source "${REPODIR}/scripts/cuda_env.sh"

# Multi-arch: all supported SM arches → cuvs_sm_suffix returns empty → no -sm in name
CUDA_ARCHS="89-real;90a-real;100f-real;101-real;103-real;120a-real;120;121-real"
SM_SUFFIX=$(cuvs_sm_suffix "$CUDA_ARCHS")    # empty for multi-arch
CUVS_LIB_NAME="cuvs-x86_64-${CUDA_TAG}${SM_SUFFIX}"  # cuvs-x86_64-cu132

echo "===================================================="
echo "cuVS x86_64 Build: RTX 4080 → 5090 & Datacenter"
echo "===================================================="
echo ""
echo "  CUDA ver   : ${CUDA_VER} (${CUDA_TAG})"
echo "  CUDA home  : ${CUDA_HOME}"
echo "  Output lib : lib${CUVS_LIB_NAME}.so"
echo ""
echo "Consumer GPU Support:"
echo "  [ENTRY]    - Ada Lovelace  (89-real):  RTX 4080, RTX 4090"
echo "  [NEXT-GEN] - Blackwell     (120):      RTX 5080, RTX 5090"
echo ""
echo "Datacenter & Professional:"
echo "  - Hopper        (90a-real):  H100 PCIe, H100 SXM, H200"
echo "  - Blackwell DC  (100f-real): B100, B200"
echo "  - Blackwell DC  (101-real):  B10x mid-tier"
echo "  - DGX Spark     (103-real):  GB10 Grace Blackwell"
echo "  - Blackwell NVL (120a-real): GB200 tensor optimized"
echo "  - Blackwell NVL (120):       GB200 NVL72, RTX 5080/5090"
echo "  - Blackwell NVL (121-real):  GB201/GB202 follow-on"
echo ""
echo "CUDA Version: $(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',')"
echo "Build Type: Release"
echo ""

# Clean previous build
echo "Cleaning previous build artifacts..."
cd "$REPODIR"
./build.sh clean

echo "Starting lib${CUVS_LIB_NAME} build for x86_64 (multi-arch)..."
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
echo "x86_64 Build Complete!"
echo "===================================================="
echo ""
echo "Consumer support:"
echo "  ✓ RTX 4080/4090  (Ada,       SM  89)"
echo "  ✓ RTX 5080/5090  (Blackwell, SM 120)"
echo ""
echo "Datacenter support:"
echo "  ✓ H100, H200     (Hopper,    SM  90a)"
echo "  ✓ B100, B200     (Blackwell, SM 100f)"
echo "  ✓ B10x mid-tier  (Blackwell, SM 101)"
echo "  ✓ DGX Spark GB10 (Blackwell, SM 103)"
echo "  ✓ GB200 NVL72    (Blackwell, SM 120a/121)"
echo ""
echo "Output: ${LIBDIR}/lib${CUVS_LIB_NAME}.so"
