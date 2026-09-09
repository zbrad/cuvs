#!/bin/bash
# tuned/full_test.sh <variant> — run every built gtest binary
# (cpp/build/gtests/*) for a GPU_TUNED_BUILD_TESTS=1 build. cuvs's tuned
# build normally skips tests entirely (-DBUILD_TESTS=OFF, see build.sh) --
# this is the opt-in path: rebuild with GPU_TUNED_BUILD_TESTS=1 first,
# then run this before publishing.
#
# Writes a timestamped results log to tuned/releases/, which
# package.sh's publish step requires (fresher than the built .so,
# containing the success marker) before it will publish, and attaches as
# a release asset -- see package.sh's own comment for why. Mirrors
# zbrad/raft's tuned/full_test.sh + tuned/raft_test_common.sh.
set -euo pipefail

GPU_TUNED_ARG_VARIANT="$1"
REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-${REPODIR}/cpp/build}"
GTESTS_DIR="${LIBCUVS_BUILD_DIR}/gtests"

if [[ ! -d "${GTESTS_DIR}" ]]; then
    echo "ERROR: ${GTESTS_DIR} not found -- build with GPU_TUNED_BUILD_TESTS=1 bash tuned/build.sh ${GPU_TUNED_ARG_VARIANT} first." >&2
    exit 1
fi

mkdir -p "${REPODIR}/tuned/releases"
RESULTS_FILE="${REPODIR}/tuned/releases/TEST_RESULTS_${GPU_TUNED_ARG_VARIANT}.log"

{
    echo "cuvs full test suite -- variant=${GPU_TUNED_ARG_VARIANT}"
    echo "started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "commit:  $(git -C "${REPODIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo ""
} > "${RESULTS_FILE}"

mapfile -d '' -t BINARIES < <(find "${GTESTS_DIR}" -maxdepth 1 -type f -executable -print0 | sort -z)
if [[ ${#BINARIES[@]} -eq 0 ]]; then
    echo "ERROR: no test binaries found under ${GTESTS_DIR}" >&2
    exit 1
fi

FAILED=()
STATUS=0
for bin in "${BINARIES[@]}"; do
    name="$(basename "${bin}")"
    {
        echo "=== ${name} ==="
    } | tee -a "${RESULTS_FILE}"
    if ! "${bin}" 2>&1 | tee -a "${RESULTS_FILE}"; then
        # CLUSTER_TEST only: confirmed flaky, not a regression -- reproduced
        # 2 failures / 1 pass across 3 back-to-back reruns with zero code
        # changes, isolated to KmeansFitBatchedTestF's KMeans++ random
        # subsample (centroids_match tolerance miss at a single coordinate,
        # cpp/tests/cluster/kmeans.cu:682). Pre-existing upstream behavior,
        # unrelated to any change in this repo -- retry this one binary
        # once rather than cost a ~2h full-suite rerun on a coin-flip. A
        # failure on the retry is treated as real and still fails the gate.
        if [[ "${name}" == "CLUSTER_TEST" ]]; then
            {
                echo ""
                echo "--- ${name} failed; retrying once (known-flaky KMeans++ random subsample, see tuned/docs/RELEASE_PINS.md) ---"
            } | tee -a "${RESULTS_FILE}"
            if ! "${bin}" 2>&1 | tee -a "${RESULTS_FILE}"; then
                FAILED+=("${name}")
                STATUS=1
            fi
        else
            FAILED+=("${name}")
            STATUS=1
        fi
    fi
done

{
    echo ""
    echo "=== Full test suite summary: $(( ${#BINARIES[@]} - ${#FAILED[@]} ))/${#BINARIES[@]} binaries passed ==="
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo "FAILED: ${FAILED[*]}"
    else
        echo "All binaries passed."
    fi
    echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee -a "${RESULTS_FILE}"

echo "Results written to ${RESULTS_FILE}"
exit "${STATUS}"
