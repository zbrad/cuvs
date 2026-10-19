#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# tuned/release.sh <variant> — run the release gates for the tarball tuned/package.sh made. If every gate
# passes, it writes a ready-marker (tuned/build/<cuda>/releases/RELEASE_READY_<variant>) that
# tuned/publish.sh <variant> publishes from. It never publishes and never tags: running it changes nothing
# on GitHub. Same stage order as raft, faiss and llama.cpp:
#   tuned/build.sh -> tuned/full_test.sh -> tuned/package.sh -> tuned/smoke_test.sh
#   -> (review and commit tuned/releases/RELEASE_NOTES_<label>_<variant>_<cuda>.md) -> this
#   -> tuned/publish.sh <variant>
# It never builds, tests or packages. The gates are gpu_tuned_release_gates in tuned/common.sh (vendored
# from zbrad/tuned-common); this script adds none of its own. docs/ARCHITECTURE.md (tuned-common) lists them.
#
# The release is named by the date label package.sh allocated (the native tag
# v0.<YYYYMMDD>.<seq>-<variant>-<cuda>), read from package-info.txt and never recomputed here: the notes
# commit moves HEAD and its date. The upstream version only appears in the title.
#
# Usage:
#   bash tuned/build.sh gb10 && bash tuned/full_test.sh gb10 && bash tuned/package.sh gb10
#   bash tuned/smoke_test.sh gb10
#   bash tuned/release.sh gb10      # gates only; writes the ready-marker, publishes nothing
#   bash tuned/publish.sh gb10      # publishes what the gates saw
set -uo pipefail

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="${1:?usage: bash tuned/release.sh <variant>}"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1
cd "${REPODIR}"

CUVS_LIB_NAME="cuvs-${GPU_TUNED_VARIANT}-${CUDA_TAG}"
LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-"$(gpu_tuned_out_dir build "${REPODIR}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}")"}"
DIST_DIR="$(gpu_tuned_out_dir dist "${REPODIR}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}")"
RELEASES_DIR="$(gpu_tuned_out_dir releases "${REPODIR}" "${CUDA_TAG}")"
INFO="${DIST_DIR}/package-info.txt"
TEST_RESULTS_FILE="${RELEASES_DIR}/TEST_RESULTS_${GPU_TUNED_VARIANT}.log"
SMOKE_FILE="${RELEASES_DIR}/SMOKE_RESULTS_${GPU_TUNED_VARIANT}.log"
MARKER="${RELEASES_DIR}/RELEASE_READY_${GPU_TUNED_VARIANT}"
# Compare against the BUILD-TREE library (what the test binaries link), not the installed one:
# tuned/package.sh rewrites the installed copy (objcopy) on every run, so its mtime moves past the test
# results and the gate would pass only once per test run.
BUILT_LIB="${LIBCUVS_BUILD_DIR}/lib${CUVS_LIB_NAME}.so"

# A run that fails, or is re-run, must not leave a marker from an earlier passing run behind.
gpu_tuned_release_marker_clear "${MARKER}"

if [[ ! -f "${INFO}" ]]; then
    echo "ERROR: ${INFO} not found -- run 'bash tuned/package.sh ${GPU_TUNED_VARIANT}' at the commit being released first." >&2
    exit 1
fi
info() { sed -n "s/^$1=//p" "${INFO}"; }
RELEASE_TAG="$(info release_tag)"; TARBALL="${DIST_DIR}/$(info tarball)"; SHA_FILE="${TARBALL}.sha256"
UPSTREAM_VERSION="$(info upstream_version)"; PACKAGED_COMMIT="$(info commit)"
SHORT_VER="$(gpu_tuned_short_ver "${UPSTREAM_VERSION}")" || exit 1
RELEASE_NOTES_FILE="tuned/releases/RELEASE_NOTES_${RELEASE_TAG#v}.md"
RELEASE_TITLE="cuVS ${SHORT_VER} — ${GPU_TUNED_HW_LABEL} (${CUDA_TAG}, ${RELEASE_TAG#v})"

echo "Release ${RELEASE_TAG} (cuVS ${SHORT_VER}, packaged at ${PACKAGED_COMMIT}):"

gpu_tuned_release_gates \
    tag="${RELEASE_TAG}" variant="${GPU_TUNED_VARIANT}" cuda="${CUDA_TAG}" info="${INFO}" \
    built="${BUILT_LIB}" test_log="${TEST_RESULTS_FILE}" test_pass='All binaries passed\.' \
    tarball="${TARBALL}" smoke_log="${SMOKE_FILE}" notes="${RELEASE_NOTES_FILE}" \
    packaged="${PACKAGED_COMMIT}" \
    || { echo "" >&2; echo "ERROR: gate(s) failed; no ready-marker written, nothing published." >&2; exit 1; }

gpu_tuned_release_ready "${MARKER}" "zbrad/cuvs" "${RELEASE_TAG}" "${RELEASE_TITLE}" "${RELEASE_NOTES_FILE}" \
    "${TARBALL}#$(basename "${TARBALL}")" \
    "${SHA_FILE}#SHA-256 checksum" \
    "${TEST_RESULTS_FILE}#Full test suite results (${GPU_TUNED_VARIANT})" \
    "${SMOKE_FILE}#Package smoke test results (${GPU_TUNED_VARIANT})" \
    || exit 1
echo "Done. Nothing was published; publish with: bash tuned/publish.sh ${GPU_TUNED_VARIANT}"
