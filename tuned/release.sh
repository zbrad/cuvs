#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# tuned/release.sh <variant> — publish the tarball tuned/package.sh produced as a GitHub release,
# after the gates: a fresh, clean full-test run and non-draft release notes. Split from package.sh
# so the packaged tarball can be used and inspected before anything is published.
#
# Usage:
#   bash tuned/build.sh gb10 && bash tuned/full_test.sh gb10 && bash tuned/package.sh gb10
#   bash tuned/release.sh gb10
set -euo pipefail

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="$1"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1

CUVS_LIB_NAME="cuvs-${GPU_TUNED_VARIANT}-${CUDA_TAG}"
CUVS_VERSION="$(tr -d '\r' < "${REPODIR}/VERSION")"
SHORT_VER="$(gpu_tuned_short_ver "${CUVS_VERSION}")" || exit 1
SHORT_SHA="$(git -C "${REPODIR}" rev-parse --short HEAD)"
LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-"$(gpu_tuned_out_dir build "${REPODIR}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}")"}"
DIST_DIR="$(gpu_tuned_out_dir dist "${REPODIR}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}")"
TARBALL="${DIST_DIR}/libcuvs-${SHORT_VER}-${GPU_TUNED_VARIANT}-${CUDA_TAG}-g${SHORT_SHA}.tar.gz"
if [[ ! -f "${TARBALL}" ]]; then
    echo "ERROR: ${TARBALL} not found -- run 'bash tuned/package.sh ${GPU_TUNED_VARIANT}' at this commit first." >&2
    exit 1
fi

# Publish gate: refuse without a fresh, passing full-test-suite run.
# "Fresh" = newer than the built .so, not just present -- a stale pass
# from before the last code change would otherwise silently satisfy this
# check. See tuned/full_test.sh (GPU_TUNED_BUILD_TESTS=1 rebuild
# required first -- this repo's default build skips tests entirely),
# which writes this file and is the only thing that should.
#
# Compare against the BUILD-TREE library (what the test binaries link), not
# INSTALLED_LIB: tuned/package.sh rewrites INSTALLED_LIB (objcopy) on
# every packaging run, so its mtime moves past the test results and the gate
# would pass only once per test run. Same approach as zbrad/raft's release.sh.
TEST_RESULTS_FILE="$(gpu_tuned_out_dir releases "${REPODIR}" "${CUDA_TAG}")/TEST_RESULTS_${GPU_TUNED_VARIANT}.log"
BUILT_LIB="${LIBCUVS_BUILD_DIR}/lib${CUVS_LIB_NAME}.so"
if [[ ! -f "${BUILT_LIB}" ]]; then
    echo "ERROR: ${BUILT_LIB} not found -- cannot tell whether the test results are fresh." >&2
    echo "  Run 'bash tuned/build.sh ${GPU_TUNED_VARIANT}' first." >&2
    exit 1
fi
if [[ ! -f "${TEST_RESULTS_FILE}" ]]; then
    echo "ERROR: ${TEST_RESULTS_FILE} not found." >&2
    echo "  Run: GPU_TUNED_BUILD_TESTS=1 bash tuned/build.sh ${GPU_TUNED_VARIANT} && bash tuned/full_test.sh ${GPU_TUNED_VARIANT}" >&2
    exit 1
fi
if [[ "${BUILT_LIB}" -nt "${TEST_RESULTS_FILE}" ]]; then
    echo "ERROR: ${BUILT_LIB} is newer than ${TEST_RESULTS_FILE} -- the test results predate the current build." >&2
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

# Release notes: use tuned/releases/RELEASE_NOTES_<short_ver>_<variant>_<cuda_tag>.md as
# the release body when present; a draft still carrying the DRAFT banner must not ship.
RELEASE_NOTES_FILE="${REPODIR}/tuned/releases/RELEASE_NOTES_${SHORT_VER}_${GPU_TUNED_VARIANT}_${CUDA_TAG}.md"
if [[ -f "${RELEASE_NOTES_FILE}" ]] && grep -q 'DRAFT — not yet published' "${RELEASE_NOTES_FILE}"; then
    echo "ERROR: ${RELEASE_NOTES_FILE} is still a draft (DRAFT banner present) -- not publishing." >&2
    exit 1
fi


RELEASE_TAG="v${SHORT_VER}-${GPU_TUNED_VARIANT}-${CUDA_TAG}-g${SHORT_SHA}"
RELEASE_TITLE="cuVS ${SHORT_VER} — ${GPU_TUNED_HW_LABEL} (${CUDA_TAG})"

echo ""
echo "Publishing to GitHub release ${RELEASE_TAG}..."
gpu_tuned_publish_release "zbrad/cuvs" "${RELEASE_TAG}" "${RELEASE_TITLE}" \
    "$([[ -f "${RELEASE_NOTES_FILE}" ]] && echo "@${RELEASE_NOTES_FILE}" || echo "lib${CUVS_LIB_NAME}.so ${SHORT_VER} cmake-install tree (lib/, include/, lib/cmake/cuvs/) for ${GPU_TUNED_HW_LABEL}, single-arch (sm_${GPU_TUNED_CUDA_ARCH}). Extract and point -Dcuvs_DIR=<extracted>/lib/cmake/cuvs at it (see zbrad/faiss tuned/build.sh).")" \
    "${TARBALL}#$(basename "${TARBALL}")" \
    "${TEST_RESULTS_FILE}#Full test suite results (${GPU_TUNED_VARIANT})"

echo ""
echo "Release: https://github.com/zbrad/cuvs/releases/tag/${RELEASE_TAG}"
echo "Done."
