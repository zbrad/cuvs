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

# Excluded from the gate: CLUSTER_TEST's KmeansFitBatchedTestF.Result/4.
# It fails ~50% of runs on GB10 (22/50 on CUDA 13.3, 26/50 on 13.4) for
# reasons unrelated to this repo: kmeans::fit is not bit-reproducible
# run-to-run (atomic reductions), and this shape sits exactly on the
# convergence threshold, so the stopping iteration flips between 11 and 14
# and the test's 1e-2 centroid match then fails. Both outcomes are
# equally good clusterings (inertia within ~1e-5). Reproduced with the
# in-memory fit alone, so it is not specific to the batched path.
# Upstream: https://github.com/NVIDIA/cuvs/issues/2657 (see also #2100).
# It is still run once and its result recorded, but it never fails the
# gate. Remove this exclusion once #2657 is resolved upstream.
KNOWN_FLAKY_CLUSTER_CASE='KmeansFitBatchedTests/KmeansFitBatchedTestF.Result/4'

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
FLAKY_RESULT="not run (CLUSTER_TEST not present)"
for bin in "${BINARIES[@]}"; do
    name="$(basename "${bin}")"
    gtest_args=()
    if [[ "${name}" == "CLUSTER_TEST" ]]; then
        gtest_args=("--gtest_filter=-${KNOWN_FLAKY_CLUSTER_CASE}")
    fi
    {
        echo "=== ${name} ==="
        if [[ ${#gtest_args[@]} -gt 0 ]]; then
            echo "(excluding known-flaky ${KNOWN_FLAKY_CLUSTER_CASE}, see NVIDIA/cuvs#2657)"
        fi
    } | tee -a "${RESULTS_FILE}"
    if ! "${bin}" "${gtest_args[@]}" 2>&1 | tee -a "${RESULTS_FILE}"; then
        FAILED+=("${name}")
        STATUS=1
    fi
    if [[ "${name}" == "CLUSTER_TEST" ]]; then
        {
            echo ""
            echo "--- ${name}: known-flaky ${KNOWN_FLAKY_CLUSTER_CASE} run once, INFORMATIONAL ONLY (not gating) ---"
        } | tee -a "${RESULTS_FILE}"
        if "${bin}" "--gtest_filter=${KNOWN_FLAKY_CLUSTER_CASE}" 2>&1 | tee -a "${RESULTS_FILE}"; then
            FLAKY_RESULT="passed this run"
        else
            FLAKY_RESULT="failed this run (expected ~50%; does not affect the gate)"
        fi
    fi
done

{
    echo ""
    echo "=== Full test suite summary: $(( ${#BINARIES[@]} - ${#FAILED[@]} ))/${#BINARIES[@]} binaries passed ==="
    echo "Excluded from gate (known-flaky, NVIDIA/cuvs#2657): ${KNOWN_FLAKY_CLUSTER_CASE} -- ${FLAKY_RESULT}"
    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo "FAILED: ${FAILED[*]}"
    else
        echo "All binaries passed."
    fi
    echo "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee -a "${RESULTS_FILE}"

echo "Results written to ${RESULTS_FILE}"
exit "${STATUS}"
