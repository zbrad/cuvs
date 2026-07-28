#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# tuned/package.sh <variant> — package an already-built (tuned/build.sh
# <variant>) cmake-install tree into a tarball and publish it as a real
# GitHub release, so downstream C++ consumers (zbrad/faiss) can pull a
# published cuVS build instead of reaching into a local sibling checkout.
#
# Not a Python wheel (unlike raft/flashinfer/pytorch's tuned/wheel.sh) --
# faiss links cuvs::cuvs as a C++ CMake target at configure time, not a
# Python runtime import, so the released artifact needs to be a tarball of
# the cmake --install output (lib/, include/, lib/cmake/cuvs/*.cmake), not
# a .whl. Naming follows tuned/docs/WHEEL_NAMING.md's GPU-codename
# convention (already used for the .so itself); the one pre-existing
# release (v26.06.00-spark) predates that convention and is not reused
# as a pattern here.
#
# Usage:
#   bash tuned/build.sh rtx50      # first, produces the install tree
#   bash tuned/package.sh rtx50    # then, packages + publishes it
set -euo pipefail

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="$1"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1

CUVS_LIB_NAME="cuvs-${GPU_TUNED_VARIANT}-${CUDA_TAG}"
# tr -d '\r': defends against CRLF drift in VERSION (bash's $() only
# strips a trailing \n, not \r) -- a real, empirically-hit failure mode:
# an embedded \r here silently corrupted both the release tag_name (gh
# rejected it as "not well-formed") and the tarball filename (a hidden \r
# byte made ls/find LOOK like a normal name on screen while stat/gh/cp all
# correctly reported "no such file" for the literal name being typed).
CUVS_VERSION="$(tr -d '\r' < "${REPODIR}/VERSION")"

# Must match tuned/build.sh's own default resolution exactly -- this script
# does not rebuild, it packages whatever tuned/build.sh already installed.
LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-${REPODIR}/cpp/build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${PREFIX:-${CONDA_PREFIX:-${LIBCUVS_BUILD_DIR}/install}}}"

echo "===================================================="
echo "cuVS ${GPU_TUNED_DEVICE_LABEL} Package"
echo "===================================================="
echo ""
echo "  Install tree : ${INSTALL_PREFIX}"
echo "  Library      : lib${CUVS_LIB_NAME}.so"
echo "  Version      : ${CUVS_VERSION} (${CUDA_TAG})"
echo ""

INSTALLED_LIB="${INSTALL_PREFIX}/lib/lib${CUVS_LIB_NAME}.so"
if [[ ! -f "${INSTALLED_LIB}" ]]; then
    echo "ERROR: ${INSTALLED_LIB} not found." >&2
    echo "  Run 'bash tuned/build.sh ${GPU_TUNED_VARIANT}' first (with the same" >&2
    echo "  INSTALL_PREFIX/PREFIX/CONDA_PREFIX this script resolved above)." >&2
    exit 1
fi
gpu_tuned_verify_arch "${INSTALLED_LIB}" || exit 1
gpu_tuned_verify_cuda_compat "${INSTALLED_LIB}" "${CUDA_VER}" || exit 1
embed_build_info "${INSTALLED_LIB}" "${GPU_TUNED_VARIANT}" "cuvs" "${CUVS_VERSION}+${CUDA_TAG}"

CUVS_CMAKE_CONFIG="$(find "${INSTALL_PREFIX}" -maxdepth 4 -iname 'cuvs-config.cmake' 2>/dev/null | head -1)"
if [[ -z "${CUVS_CMAKE_CONFIG}" ]]; then
    echo "ERROR: no cuvs-config.cmake found under ${INSTALL_PREFIX} -- the" >&2
    echo "  install tree looks incomplete (expected rapids_export's cmake" >&2
    echo "  package config alongside the .so). Re-run tuned/build.sh." >&2
    exit 1
fi
echo "  cmake config : ${CUVS_CMAKE_CONFIG}"

DIST_DIR="${REPODIR}/dist/${GPU_TUNED_VARIANT}"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
TARBALL="${DIST_DIR}/libcuvs-${GPU_TUNED_VARIANT}-${CUVS_VERSION}-${CUDA_TAG}.tar.gz"

echo ""
echo "Packaging ${INSTALL_PREFIX} -> ${TARBALL}..."
tar -C "${INSTALL_PREFIX}" -czf "${TARBALL}" .
echo "Tarball: $(basename "${TARBALL}") ($(du -sh "${TARBALL}" | awk '{print $1}'))"

RELEASE_TAG="v${CUVS_VERSION}-${GPU_TUNED_VARIANT}-${CUDA_TAG}"
RELEASE_TITLE="cuVS ${CUVS_VERSION} — ${GPU_TUNED_HW_LABEL} (${CUDA_TAG})"

echo ""
echo "Publishing to GitHub release ${RELEASE_TAG}..."
gh release create "${RELEASE_TAG}" \
    --repo zbrad/cuvs \
    --title "${RELEASE_TITLE}" \
    --target "tuned-builds" \
    --notes "lib${CUVS_LIB_NAME}.so ${CUVS_VERSION} cmake-install tree (lib/, include/, lib/cmake/cuvs/) for ${GPU_TUNED_HW_LABEL}, single-arch (sm_${GPU_TUNED_CUDA_ARCH}). Extract and point -Dcuvs_DIR=<extracted>/lib/cmake/cuvs at it (see zbrad/faiss tuned/build.sh)." \
    "${TARBALL}#$(basename "${TARBALL}")"

echo ""
echo "Release: https://github.com/zbrad/cuvs/releases/tag/${RELEASE_TAG}"
echo "Done."
