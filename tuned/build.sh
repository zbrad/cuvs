#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# tuned/build.sh <variant> — build cuVS's C++ shared library for a single
# GPU variant (gb10/rtx40/rtx50), single-arch, named by GPU codename per
# tuned/docs/WHEEL_NAMING.md:
#   libcuvs-<variant>-cu<tag>.so
#
# Consolidates what used to be three ~90%-identical root-level scripts
# (build_gb10.sh, build_rtx40.sh, build_rtx50.sh, plus the build_dgx_spark.sh/
# build_ada_blackwell.sh compat shims that pointed at them) into one,
# parameterized by tuned/devices/<variant>.conf. All of that non-upstream
# tooling now lives under tuned/ -- see tuned/docs/BINARY_BUILD_INFO.md's
# "Deprecated script names" table for the old-name -> new-invocation mapping.
#
# Usage:
#   bash tuned/build.sh gb10
#   bash tuned/build.sh rtx40
#   bash tuned/build.sh rtx50
#
# To build with a different CUDA version:
#   CUDA_VER=13.3 bash tuned/build.sh gb10   →  libcuvs-gb10-cu133.so
#   CUDA_TAG=cu133 bash tuned/build.sh gb10  →  (same, tag form)
#
# See tuned/env.sh for the CUDA version knob and device config.

set -e

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="$1"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1

CUDA_ARCHS="${GPU_TUNED_CUDA_ARCH}-real"
CUVS_LIB_NAME="cuvs-${GPU_TUNED_VARIANT}-${CUDA_TAG}"  # e.g. cuvs-rtx50-cu132

echo "===================================================="
echo "cuVS ${GPU_TUNED_DEVICE_LABEL} Build"
echo "===================================================="
echo ""
echo "  Target GPU : ${GPU_TUNED_HW_LABEL}"
echo "  SM arch    : ${CUDA_ARCHS}"
echo "  Host arch  : ${GPU_TUNED_PLATFORM}"
echo "  CUDA ver   : ${CUDA_VER} (${CUDA_TAG})"
echo "  CUDA home  : ${CUDA_HOME}"
echo "  Output lib : lib${CUVS_LIB_NAME}.so"
echo ""
echo "CUDA Version: $(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',')"
echo ""

# Clean previous build (this repo's own top-level build.sh, the standard
# rapids build-orchestrator script -- unrelated to this file despite the
# shared basename; REPODIR keeps the two unambiguous).
echo "Cleaning previous build artifacts..."
cd "$REPODIR"
./build.sh clean

echo "Starting lib${CUVS_LIB_NAME} build for ${GPU_TUNED_HW_LABEL}..."
echo ""

LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-${REPODIR}/cpp/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${PREFIX:-${CONDA_PREFIX:-${LIBCUVS_BUILD_DIR}/install}}}"
PARALLEL_LEVEL="${PARALLEL_LEVEL:-$(nproc)}"

# Use ccache as the compiler launcher when available -- a cold cache gets
# no benefit (this build's own header-heavy CUTLASS/raft templates make a
# first compile inherently slow), but every subsequent rebuild against the
# same sources (iterating on this repo, or rebuilding after a clean) hits
# the cache instead of recompiling from scratch. No-op, not an error, when
# ccache isn't installed.
CMAKE_LAUNCHER_ARGS=()
if command -v ccache >/dev/null 2>&1; then
    echo "ccache found -- using as compiler launcher (CCACHE_DIR=${CCACHE_DIR:-\$HOME/.cache/ccache})"
    CMAKE_LAUNCHER_ARGS=(
        -DCMAKE_CUDA_COMPILER_LAUNCHER=ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
        -DCMAKE_C_COMPILER_LAUNCHER=ccache
    )
fi

# BUILD_MG_ALGOS=ON (rtx40/rtx50, see tuned/devices/<variant>.conf) makes
# cpp/CMakeLists.txt's find_package(NCCL REQUIRED) unconditional. The pip
# nvidia-nccl-cu13 wheel only ships a versioned libnccl.so.2 -- no
# unversioned libnccl.so symlink FindNCCL.cmake's default find_library()
# name search expects -- so point NCCL_LIBRARY/NCCL_INCLUDE_DIR at the
# exact wheel paths directly, same fix zbrad/raft's tuned/wheel.sh already
# needed for the same reason (see that file's NCCL section). gb10 has
# BUILD_MG_ALGOS=OFF, so find_package(NCCL) never runs there -- no NCCL
# wiring needed.
NCCL_CMAKE_ARGS=()
if [[ "${GPU_TUNED_BUILD_MG_ALGOS}" == "ON" ]]; then
    NCCL_PY_PREFIX="$(python3 -c 'import nvidia.nccl as m; print(list(m.__path__)[0])' 2>/dev/null)" || true
    if [[ -z "${NCCL_PY_PREFIX}" ]]; then
        echo "ERROR: BUILD_MG_ALGOS=ON requires NCCL, but 'python3 -c import nvidia.nccl'" >&2
        echo "  failed. Install it: pip install nvidia-nccl-cu13" >&2
        exit 1
    fi
    NCCL_LIB="$(ls "${NCCL_PY_PREFIX}"/lib/libnccl.so* 2>/dev/null | head -1)"
    if [[ -z "${NCCL_LIB}" ]]; then
        echo "ERROR: no libnccl.so* found under ${NCCL_PY_PREFIX}/lib" >&2
        exit 1
    fi
    echo "NCCL found via nvidia-nccl-cu13: ${NCCL_LIB}"
    NCCL_CMAKE_ARGS=(
        -DNCCL_LIBRARY="${NCCL_LIB}"
        -DNCCL_INCLUDE_DIR="${NCCL_PY_PREFIX}/include"
    )
fi

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
  -DBUILD_MG_ALGOS="${GPU_TUNED_BUILD_MG_ALGOS}" \
  -DBUILD_SHARED_LIBS=ON \
  "-DCUVS_OUTPUT_NAME=${CUVS_LIB_NAME}" \
  "${CMAKE_LAUNCHER_ARGS[@]}" \
  "${NCCL_CMAKE_ARGS[@]}"

# Surface which raft this configure actually fetched (this repo tracks
# upstream raft's main branch, not a pinned release, so version drift here
# is expected -- see tuned/env.sh's cuvs_check_raft_version for why this is
# informational, not a hard gate).
cuvs_check_raft_version "${LIBCUVS_BUILD_DIR}" "${REPODIR}"

cmake --build "${LIBCUVS_BUILD_DIR}" -j"${PARALLEL_LEVEL}" --target cuvs cuvs_c install

# Verify output
LIBDIR="${REPODIR}/cpp/build"
EXPECTED_LIB="${LIBDIR}/lib${CUVS_LIB_NAME}.so"
if [[ -f "${EXPECTED_LIB}" ]]; then
  echo "  Library built: ${EXPECTED_LIB} ($(du -h "${EXPECTED_LIB}" | cut -f1))"
  gpu_tuned_verify_arch "${EXPECTED_LIB}" || exit 1
else
  echo "WARNING: Expected lib${CUVS_LIB_NAME}.so not found in ${LIBDIR}"
  echo "  Files present: $(ls "${LIBDIR}"/libcuvs*.so 2>/dev/null || echo 'none')"
fi

echo ""
echo "===================================================="
echo "${GPU_TUNED_DEVICE_LABEL} Build Complete!"
echo "===================================================="
echo ""
echo "  ✓ ${GPU_TUNED_HW_LABEL} native binary"
echo "  ✓ Output: ${LIBDIR}/lib${CUVS_LIB_NAME}.so"

# GB10-only footer: deploy instructions + faiss-consumer note (the other two
# variants don't need these -- rtx40/rtx50 are desktop dev boxes, not an
# appliance you flash and hand off).
if [[ "${GPU_TUNED_VARIANT}" == "gb10" ]]; then
  echo ""
  echo "  ✓ aarch64 host code (Grace CPU)"
  echo "  ✓ Zero-copy NVLink-C2C memory path"
  echo ""
  echo "Deploy to DGX Spark:"
  echo "  cp ${LIBDIR}/lib${CUVS_LIB_NAME}.so /usr/local/lib/"
  echo "  ldconfig"
  echo ""
  echo "NOTE for faiss consumers (zbrad/faiss gpu-cu/scripts/build_lib_gb10.sh):"
  echo "  Library is now: ${LIBDIR}/lib${CUVS_LIB_NAME}.so"
fi
