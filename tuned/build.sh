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

# resolve_raft_release <variant> <cuda_tag> — download + extract the
# matching zbrad/raft tuned-builds release (see that repo's
# tuned/package.sh/release.sh) into tuned/_raft_release/<variant>-<cuda_tag>/,
# unless already present there. Prints the extracted root on stdout via the
# RAFT_RELEASE_DIR variable set in the caller's scope.
#
# Without this, cpp/cmake/thirdparty/get_raft.cmake's rapids_cpm_find(raft)
# falls through to its default CPM behavior: git-clone rapidsai/raft's main
# branch and build it from source as part of this build (real version
# drift, plus a lot of redundant compile time for a library we already
# publish a matching prebuilt release of). Putting RAFT_RELEASE_DIR on
# CMAKE_PREFIX_PATH below makes find_package(raft) succeed against our own
# published build first, so CPM's fallback never triggers -- same pattern
# zbrad/faiss's tuned/build.sh already uses to consume this repo's own
# published release (see resolve_cuvs_release there).
resolve_raft_release() {
    local variant="$1" cuda_tag="$2"
    RAFT_RELEASE_DIR="${REPODIR}/tuned/_raft_release/${variant}-${cuda_tag}"

    if [[ -n "$(find "${RAFT_RELEASE_DIR}" -maxdepth 4 -iname 'raft-config.cmake' 2>/dev/null)" ]]; then
        echo "raft release already extracted: ${RAFT_RELEASE_DIR} (set FORCE_RAFT_DOWNLOAD=1 to re-fetch)"
        [[ "${FORCE_RAFT_DOWNLOAD:-0}" != "1" ]] && return 0
    fi

    echo "Looking up zbrad/raft tuned-builds release for ${variant}-${cuda_tag}..."
    local tag
    # raft now publishes v<ver>-<variant>-<cuda_tag>, the same order as
    # this repo's own release tags -- match the same way faiss matches
    # cuvs's tags. (Was variant-suffix-only, back when raft's tag order
    # was v<ver>.0-cuda<compact>-<variant>, cuda tag *before* variant --
    # that's been unified to match cuvs's order now.)
    tag="$(gh release list --repo zbrad/raft --json tagName -q '.[].tagName' 2>/dev/null \
        | grep -E -- "-${variant}-${cuda_tag}\$" | head -1)"
    if [[ -z "${tag}" ]]; then
        echo "ERROR: no zbrad/raft release found matching '*-${variant}'." >&2
        echo "  Available releases:" >&2
        gh release list --repo zbrad/raft --json tagName -q '.[].tagName' 2>/dev/null | sed 's/^/    /' >&2
        echo "  Build and publish one first: cd \$(dirname "'"'"${REPODIR}"'"'")/raft && bash tuned/build.sh ${variant} && bash tuned/package.sh ${variant} && bash tuned/release.sh ${variant}" >&2
        exit 1
    fi
    echo "Found release: ${tag}"

    rm -rf "${RAFT_RELEASE_DIR}"
    mkdir -p "${RAFT_RELEASE_DIR}"
    local dl_dir
    dl_dir="$(mktemp -d)"
    gh release download "${tag}" --repo zbrad/raft --pattern '*.tar.bz2' --dir "${dl_dir}"
    local tarball
    tarball="$(ls "${dl_dir}"/*.tar.bz2 | head -1)"
    [[ -z "${tarball}" ]] && { echo "ERROR: release ${tag} has no .tar.bz2 asset." >&2; exit 1; }
    # --strip-components=1: unlike this repo's own tarball (flat, tar -C
    # <prefix> -czf ... . in tuned/package.sh here), raft's tuned/package.sh
    # wraps its tarball's contents in a top-level raft-<ver>-<variant>-
    # <cuda_tag>/ directory (cp -r install/ /tmp/<PKG_NAME>/, tar'd from
    # /tmp) -- confirmed empirically: without this flag, lib/cmake/raft/
    # ends up nested one level too deep for CMAKE_PREFIX_PATH to find.
    tar -xjf "${tarball}" -C "${RAFT_RELEASE_DIR}" --strip-components=1
    rm -rf "${dl_dir}"

    if [[ -z "$(find "${RAFT_RELEASE_DIR}" -maxdepth 4 -iname 'raft-config.cmake' 2>/dev/null)" ]]; then
        echo "ERROR: extracted release ${tag} does not contain lib/cmake/raft/raft-config.cmake" >&2
        echo "  Contents: $(find "${RAFT_RELEASE_DIR}" -maxdepth 2)" >&2
        exit 1
    fi
    echo "Extracted to: ${RAFT_RELEASE_DIR}"
}

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="$1"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1

CUDA_ARCHS="${GPU_TUNED_CUDA_ARCH}-real"
CUVS_LIB_NAME="cuvs-${GPU_TUNED_VARIANT}-${CUDA_TAG}"  # e.g. cuvs-rtx50-cu132

resolve_raft_release "${GPU_TUNED_VARIANT}" "${CUDA_TAG}"

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
  "-DCMAKE_PREFIX_PATH=${RAFT_RELEASE_DIR}" \
  "${CMAKE_LAUNCHER_ARGS[@]}" \
  "${NCCL_CMAKE_ARGS[@]}"

# Surface which raft this configure actually resolved. As of
# resolve_raft_release above, this is now zbrad/raft's own published tuned
# release for this exact variant/cuda_tag (found via CMAKE_PREFIX_PATH),
# not a CPM git-clone-and-build of upstream rapidsai/raft's main branch --
# version drift against upstream is still possible (zbrad/raft's own
# tuned-builds branch isn't pinned to a specific upstream commit either),
# so this stays informational, not a hard gate.
cuvs_check_raft_version "${LIBCUVS_BUILD_DIR}" "${REPODIR}"

cmake --build "${LIBCUVS_BUILD_DIR}" -j"${PARALLEL_LEVEL}" --target cuvs cuvs_c install

# cuvs-config.cmake (installed above) exports cuvs::cuvs with a link
# interface that references raft::raft and rmm::rmm as real CMake
# targets -- RAPIDS' standard assumption is that any consumer already has
# a full conda/RAPIDS environment where those are independently
# installed. Since this tuned build targets a plain venv (no conda), and
# the whole point of publishing a tarball (tuned/package.sh) is a
# self-contained C++ SDK a downstream consumer (zbrad/faiss) can use
# without one, also install raft/rmm's own CPM-fetched build trees into
# the SAME install prefix. Confirmed empirically: cuvs never installs
# these itself (this repo's own INSTALL_PREFIX had zero raft/rmm content
# before this was added -- find_package(cuvs) elsewhere failed outright
# with "target rmm::rmm not found").
#
# CCCL (CUB/Thrust/libcudacxx) is NOT included in this loop -- its
# CPM-fetched build tree (_deps/cccl-build/) has zero install() rules of
# its own (confirmed: rapids-cmake fetches it purely for header-only
# in-build usage, install rules disabled as a subproject), so there's
# nothing to vendor via this cmake -P technique. Consumers instead rely
# on their OWN CUDA toolkit's bundled CCCL satisfying whatever minimum
# version raft/rmm's exported dependencies declare (empirically: CUDA
# 13.3 ships CCCL 3.3.3, which satisfies it; CUDA 13.2 ships only 3.2.0,
# which does not) -- see zbrad/faiss tuned/build.sh's CCCL_DIR pin and
# gpu_tuned_verify_cccl_toolkit_match for how that's enforced on the
# consumer side, rather than silently falling through to whatever CMake's
# broader system search happens to find (which, on a WSL host with
# Windows PATH interop, can be a completely different OS's CUDA install).
#
# rmm-build/raft-build used to be CPM subdirectory builds folded into
# cuvs's single top-level CMakeCache (no CMakeCache.txt of their own), so
# `cmake --install <dir>` (which expects one) didn't apply -- but their
# generated cmake_install.cmake scripts were fully self-contained and
# installable directly via `cmake -P`. That's no longer how raft (and its
# own bundled rmm/rapids_logger) gets resolved here at all: resolve_raft_release
# above makes find_package(raft) succeed against zbrad/raft's own published
# release (via CMAKE_PREFIX_PATH), so raft/rmm are never CPM-built as
# subprojects of this build -- there is no _deps/{raft,rmm}-build/ to
# install from any more. Vendor RAFT_RELEASE_DIR's own already-built
# content into cuvs's INSTALL_PREFIX directly instead (same end goal: a
# self-contained cuvs release tarball) -- it already contains raft, rmm,
# and rapids_logger together (see zbrad/raft tuned/package.sh).
if [[ -n "${RAFT_RELEASE_DIR:-}" && -d "${RAFT_RELEASE_DIR}/lib" ]]; then
    echo "Vendoring zbrad/raft release content (raft+rmm+rapids_logger) from ${RAFT_RELEASE_DIR} into ${INSTALL_PREFIX}..."
    mkdir -p "${INSTALL_PREFIX}"
    cp -rn "${RAFT_RELEASE_DIR}/." "${INSTALL_PREFIX}/"
else
    # Fallback for any consumer of this script that didn't go through
    # resolve_raft_release (e.g. a plain, non-tuned invocation where CPM
    # really did clone+build raft/rmm from source as subprojects) -- keep
    # the old cmake -P vendoring path alive for that case.
    for _dep in rmm raft; do
        _dep_install_script="${LIBCUVS_BUILD_DIR}/_deps/${_dep}-build/cmake_install.cmake"
        if [[ -f "${_dep_install_script}" ]]; then
            echo "Installing CPM-fetched ${_dep} (cuvs::cuvs's link interface requires it)..."
            cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -P "${_dep_install_script}"
        else
            echo "ERROR: ${_dep_install_script} not found -- cuvs::cuvs will be unusable by any" >&2
            echo "  external CMake consumer (missing link-interface target ${_dep}::${_dep})." >&2
            exit 1
        fi
    done
    unset _dep _dep_install_script
fi

# Verify output
LIBDIR="${REPODIR}/cpp/build"
EXPECTED_LIB="${LIBDIR}/lib${CUVS_LIB_NAME}.so"
if [[ -f "${EXPECTED_LIB}" ]]; then
  echo "  Library built: ${EXPECTED_LIB} ($(du -h "${EXPECTED_LIB}" | cut -f1))"
  gpu_tuned_verify_arch "${EXPECTED_LIB}" "${GPU_TUNED_CUDA_ARCH}" || exit 1
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
