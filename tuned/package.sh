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
# Derive short version (e.g. 26.08.00 -> 26.8), matching zbrad/raft's own
# tuned/package.sh convention -- used for the tarball name/release tag/
# title below; CUVS_VERSION (full, unshortened) stays in the build-info
# stamp and the informational "Version:" line above, where precision
# matters more than brevity.
SHORT_VER="$(gpu_tuned_short_ver "${CUVS_VERSION}")" || exit 1
# -g<short-sha> suffix: SHORT_VER alone collides across genuinely
# different rebuilds (VERSION only bumps on a real upstream release cut)
# -- matches zbrad/raft's tuned/package.sh, which hit exactly this
# collision 2026-09-08 (had to delete-and-recreate a tag to republish).
SHORT_SHA="$(git -C "${REPODIR}" rev-parse --short HEAD)"

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
gpu_tuned_verify_arch "${INSTALLED_LIB}" "${GPU_TUNED_CUDA_ARCH}" || exit 1
gpu_tuned_verify_cuda_compat "${INSTALLED_LIB}" "${CUDA_VER}" || exit 1

# Publish gate: refuse without a fresh, passing full-test-suite run.
# "Fresh" = newer than the built .so, not just present -- a stale pass
# from before the last code change would otherwise silently satisfy this
# check. See tuned/full_test.sh (GPU_TUNED_BUILD_TESTS=1 rebuild
# required first -- this repo's default build skips tests entirely),
# which writes this file and is the only thing that should. Runs BEFORE
# embed_build_info below, which rewrites INSTALLED_LIB's mtime (objcopy)
# -- checking after that would make a genuinely fresh, clean test run
# fail this gate every single time.
TEST_RESULTS_FILE="${REPODIR}/tuned/releases/TEST_RESULTS_${GPU_TUNED_VARIANT}.log"
if [[ ! -f "${TEST_RESULTS_FILE}" ]]; then
    echo "ERROR: ${TEST_RESULTS_FILE} not found." >&2
    echo "  Run: GPU_TUNED_BUILD_TESTS=1 bash tuned/build.sh ${GPU_TUNED_VARIANT} && bash tuned/full_test.sh ${GPU_TUNED_VARIANT}" >&2
    exit 1
fi
if [[ "${INSTALLED_LIB}" -nt "${TEST_RESULTS_FILE}" ]]; then
    echo "ERROR: ${INSTALLED_LIB} is newer than ${TEST_RESULTS_FILE} -- the test results predate the current build." >&2
    echo "  Re-run tuned/full_test.sh ${GPU_TUNED_VARIANT} before publishing." >&2
    exit 1
fi
if ! grep -q "All binaries passed\." "${TEST_RESULTS_FILE}"; then
    echo "ERROR: ${TEST_RESULTS_FILE} does not show a clean pass -- not publishing." >&2
    echo "  Last lines:" >&2
    tail -20 "${TEST_RESULTS_FILE}" >&2
    exit 1
fi
echo "Test gate: ${TEST_RESULTS_FILE} shows a clean pass, newer than the built library. Proceeding."

embed_build_info "${INSTALLED_LIB}" "${GPU_TUNED_VARIANT}" "cuvs" "${CUVS_VERSION}+${CUDA_TAG}" "${GPU_TUNED_HW_LABEL}"
# Confirm the stamp actually landed before archiving -- the tarball is a
# straight `tar -czf` of INSTALL_PREFIX below with no further build/install
# pass, so this should always pass, but every other repo in this fleet
# validates its stamp right after writing it rather than assuming.
gpu_tuned_verify_build_info "${INSTALLED_LIB}" "cuvs" "${CUVS_VERSION}+${CUDA_TAG}" || exit 1

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
TARBALL="${DIST_DIR}/libcuvs-${SHORT_VER}-${GPU_TUNED_VARIANT}-${CUDA_TAG}-g${SHORT_SHA}.tar.gz"

echo ""
echo "Packaging ${INSTALL_PREFIX} -> ${TARBALL}..."
tar -C "${INSTALL_PREFIX}" -czf "${TARBALL}" .
echo "Tarball: $(basename "${TARBALL}") ($(du -sh "${TARBALL}" | awk '{print $1}'))"

RELEASE_TAG="v${SHORT_VER}-${GPU_TUNED_VARIANT}-${CUDA_TAG}-g${SHORT_SHA}"
RELEASE_TITLE="cuVS ${SHORT_VER} — ${GPU_TUNED_HW_LABEL} (${CUDA_TAG})"

echo ""
echo "Publishing to GitHub release ${RELEASE_TAG}..."
gpu_tuned_publish_release "zbrad/cuvs" "${RELEASE_TAG}" "${RELEASE_TITLE}" \
    "lib${CUVS_LIB_NAME}.so ${SHORT_VER} cmake-install tree (lib/, include/, lib/cmake/cuvs/) for ${GPU_TUNED_HW_LABEL}, single-arch (sm_${GPU_TUNED_CUDA_ARCH}). Extract and point -Dcuvs_DIR=<extracted>/lib/cmake/cuvs at it (see zbrad/faiss tuned/build.sh)." \
    "${TARBALL}#$(basename "${TARBALL}")" \
    "${TEST_RESULTS_FILE}#Full test suite results (${GPU_TUNED_VARIANT})"

echo ""
echo "Release: https://github.com/zbrad/cuvs/releases/tag/${RELEASE_TAG}"
echo "Done."
