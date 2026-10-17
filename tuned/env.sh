#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# tuned/env.sh <variant> — single source of truth for a tuned build's CUDA
# toolkit selection AND its device metadata (gb10/rtx40/rtx50). Source this
# file with the variant as $1; do not execute it directly.
#
# Consolidates what used to be scripts/cuda_env.sh (CUDA_VER/CUDA_TAG/
# CUDA_HOME detection, identical logic, just relocated) plus the
# device-specific values that used to be hardcoded separately in each of
# build_gb10.sh/build_rtx40.sh/build_rtx50.sh -- now the shared device files in
# tuned/common-data/devices/<variant>.conf (zbrad/tuned-common), with cuvs's own
# per-variant settings (CUVS_*) in tuned/repo.env.
#
# The toolkit comes from the vendored definitions in tuned/common-data/toolkits/<id>.env
# (zbrad/tuned-common), never from /usr/local/cuda or from what is installed. There is no
# default: name it with EITHER variable (the other is derived):
#
#   CUDA_VER=13.3  bash tuned/build.sh gb10
#   CUDA_TAG=cu133 bash tuned/build.sh gb10
#
# With neither set the loader fails and lists the defined toolkits (at a terminal it asks
# which to use, for that run only). Repo-specific settings live in tuned/repo.env.
#
# Exported variables:
#   CUDA_VER / CUDA_TAG / CUDA_HOME
#     — as before (this repo's own naming, deliberately NOT renamed to
#       raft's CUDA_VERSION/CUDA_VERSION_COMPACT -- mirrors zbrad/faiss
#       gpu-cu/scripts/cuda_env.sh, already referenced by name throughout
#       this repo's docs and by faiss's own build scripts; renaming would
#       break those references for no benefit).
#   GPU_TUNED_VARIANT / GPU_TUNED_PLATFORM / GPU_TUNED_CUDA_ARCH / GPU_TUNED_HW_LABEL
#     — from the shared tuned/common-data/devices/<variant>.conf, re-exported here.
#   CUVS_BUILD_MG_ALGOS / CUVS_DEVICE_LABEL
#     — from tuned/repo.env (per variant).
#
# Also defines gpu_tuned_verify_arch() and cuvs_check_raft_version() -- see
# below.

GPU_TUNED_ARG_VARIANT="$1"
if [[ -z "${GPU_TUNED_ARG_VARIANT}" ]]; then
    echo "ERROR: env.sh requires a variant argument (gb10/rtx40/rtx50)" >&2
    return 1 2>/dev/null || exit 1
fi

GPU_TUNED_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GPU_TUNED_DATA_DIR="${GPU_TUNED_SELF_DIR}/common-data"
# shellcheck source=common-data/devices/gb10.conf
source "${GPU_TUNED_DATA_DIR}/devices/${GPU_TUNED_ARG_VARIANT}.conf" || return 1 2>/dev/null || exit 1
export GPU_TUNED_VARIANT GPU_TUNED_PLATFORM GPU_TUNED_CUDA_ARCH GPU_TUNED_HW_LABEL

# shellcheck source=common.sh
# Vendored from https://github.com/zbrad/tuned-common (pinned commit --
# see common.sh's own header/sync instructions to update). Provides
# gpu_tuned_verify_arch/verify_cuda_compat/assert_platform/
# installed_cuda_toolkits, shared verbatim across the fleet instead of
# hand-copied-and-edited per repo. NOT used for embed_build_info here:
# this repo stamps every package into the SAME .cuvs_build_info section
# rather than one section per package -- kept local on purpose (same
# reasoning as zbrad/raft's tuned/env.sh).
source "${GPU_TUNED_SELF_DIR}/common.sh" || return 1 2>/dev/null || exit 1

# Fail loudly if this script runs on the wrong host, rather than letting a
# mismatched build silently produce wrong-architecture binaries that only
# surface as a confusing failure several steps later. (Previously this check
# only existed for gb10/aarch64 in build_gb10.sh; rtx40/rtx50 had no
# equivalent x86_64 check at all -- this makes it uniform across all three.)
gpu_tuned_assert_platform "${GPU_TUNED_PLATFORM}" "${GPU_TUNED_VARIANT}" || return 1 2>/dev/null || exit 1

# --- CUDA toolkit: chosen from tuned/common-data/toolkits, never inferred from /usr/local/cuda or
#     from what is installed. CUDA_TAG (cu133) or CUDA_VER (13.3) select one; neither set is an
#     error listing the defined ones (no default). Exports CUDA_VER, CUDA_TAG, CUDA_HOME and puts
#     $CUDA_HOME/bin on PATH. ---
_cuvs_tk="${CUDA_TAG:-}"
_cuvs_req_ver="${CUDA_VER:-}"
if [ -z "${_cuvs_tk}" ] && [ -n "${_cuvs_req_ver}" ]; then
    _cuvs_tk="cu${_cuvs_req_ver//./}"                           # 13.3 -> cu133
fi
gpu_tuned_load_toolkit "${GPU_TUNED_DATA_DIR}" "${GPU_TUNED_VARIANT}" "${_cuvs_tk}" || return 1 2>/dev/null || exit 1
if [ -n "${_cuvs_req_ver}" ] && [ "${_cuvs_req_ver}" != "${TOOLKIT_CUDA_VER}" ]; then
    echo "[tuned/env] ERROR: CUDA_VER=${_cuvs_req_ver} conflicts with toolkit ${CUDA_TAG} (CUDA ${TOOLKIT_CUDA_VER})." >&2
    return 1 2>/dev/null || exit 1
fi
unset _cuvs_tk _cuvs_req_ver
gpu_tuned_verify_toolkit || return 1 2>/dev/null || exit 1

# --- Repo-specific settings (per-variant MG algos and device label), loaded last; may not
#     change any shared device/toolkit key. ---
gpu_tuned_load_repo_env "${GPU_TUNED_SELF_DIR}/repo.env" || return 1 2>/dev/null || exit 1
export CUVS_BUILD_MG_ALGOS CUVS_DEVICE_LABEL

# embed_build_info <staged-elf> <component> <release-tag> [name=value...] -- stamps the JSON build info
# (tuned-common, docs/ARCHITECTURE.md "Build info") into <staged-elf>'s .tuned_build_info section; read it with
#   gpu_tuned_read_build_info <elf> | jq .
# The release tag is the identity. Extra fields (deps.*) are passed through; the git fields (fork, upstream)
# are added from the checkout the packager runs in.
embed_build_info() {
    local target="$1" component="$2" release="$3" nvcc_full
    shift 3
    nvcc_full="$("${CUDA_HOME}/bin/nvcc" --version | sed -n 's/.*release [0-9.]*, V\([0-9.]*\).*/\1/p' | head -1)"
    gpu_tuned_embed_build_info_json "${target}" \
        package=cuvs "component=${component}" "release=${release}" "variant=${GPU_TUNED_VARIANT}" \
        "hardware=${GPU_TUNED_HW_LABEL}" "arch=sm_${GPU_TUNED_CUDA_ARCH}" \
        "cuda.tag=${CUDA_TAG}" "cuda.version=${CUDA_VER}" "cuda.nvcc=${nvcc_full:-unknown}" \
        "$@"
}

# cuvs_check_raft_version <libcuvs_build_dir> <cuvs_repodir> — surfaces which
# raft this build actually linked against.
#
# An earlier draft of this asserted raft's fetched VERSION must equal this
# cuVS checkout's own VERSION major.minor, on the assumption that
# get_raft.cmake's tag-pinning guarantees that by construction. Verified
# empirically FALSE: this repo's RAPIDS_BRANCH file is "main" (not a pinned
# "branch-26.08"), so get_raft.cmake's rapids-cmake-checkout-tag resolves to
# upstream rapidsai/raft's current main-branch development version -- which
# routinely runs ahead of this checkout's own declared VERSION during a
# normal RAPIDS release cycle. Confirmed live: a real CMake configure on this
# branch fetched raft main at VERSION 26.10.00 while this repo's own VERSION
# is 26.08.00. A hard equality gate would have failed every normal build on
# this branch, not just genuine drift -- so this deliberately WARNS, it does
# not fail (same precedent as the nvcc-version mismatch check above).
#
# What this DOES catch, meaningfully: this cuVS tuned-builds system has no
# pin to your own raft fork (zbrad/raft) at all -- confirmed, no RAFT_FORK/
# RAFT_PINNED_TAG/CMAKE_PREFIX_PATH override anywhere in tuned/build.sh. It
# always CPM-clones upstream rapidsai/raft's main branch fresh, independent
# of whatever's published/tuned on your own raft fork. This function's real
# job is making that visible -- printing exactly which raft version got
# fetched -- so a future upstream raft API/ABI break doesn't show up as a
# mystery compile failure with no record of what version was actually in
# play.
cuvs_check_raft_version() {
    local build_dir="$1" repodir="$2"
    local raft_version_file="${build_dir}/_deps/raft-src/VERSION"

    if [ ! -f "$raft_version_file" ]; then
        echo "[version_check] WARNING: ${raft_version_file} not found -- raft was not CPM-fetched where expected (or rapids-cmake's CPM staging layout changed since this was written). Skipping version visibility check." >&2
        return 0
    fi

    local raft_version cuvs_version raft_mm cuvs_mm
    # tr -d '\r': defends against CRLF drift (bash's $() strips a trailing
    # \n but not \r) -- see tuned/package.sh's identical note for the real
    # failure mode this empirically caused.
    raft_version="$(tr -d '\r' < "$raft_version_file")"
    cuvs_version="$(tr -d '\r' < "${repodir}/VERSION")"
    raft_mm="$(echo "$raft_version" | grep -oE '^[0-9]+\.[0-9]+')"
    cuvs_mm="$(echo "$cuvs_version" | grep -oE '^[0-9]+\.[0-9]+')"

    echo "[version_check] This build links against upstream rapidsai/raft VERSION ${raft_version} (this cuVS checkout's own VERSION is ${cuvs_version})."
    if [ "$raft_mm" != "$cuvs_mm" ]; then
        echo "[version_check] NOTE: major.minor differs (raft ${raft_mm:-unparseable} vs cuvs ${cuvs_mm:-unparseable}) -- expected during a normal RAPIDS dev cycle since this repo tracks raft's main branch rather than a pinned release, not necessarily a problem. Recorded here so it's visible if something else breaks." >&2
    fi
}

# --- Output layout: one tree per toolkit, tuned/build/<cuda-tag>/ (gitignored via build/), with no
#     variant level: cmake/ (the one fixed compile path), dist/, releases/ (generated checksums and
#     test logs; the tracked RELEASE_NOTES_*.md stay in tuned/releases/), ccache/, timing.tsv.
#     gpu_tuned_out_dir (common.sh) names these; the claim refuses a tree last used by another
#     variant. ---
GPU_TUNED_REPO_ROOT="$(cd "${GPU_TUNED_SELF_DIR}/.." && pwd)"
gpu_tuned_claim_toolkit_tree "${GPU_TUNED_REPO_ROOT}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}" || return 1 2>/dev/null || exit 1
GPU_TUNED_BUILD_ROOT="${GPU_TUNED_REPO_ROOT}/tuned/build/${CUDA_TAG}"
# ccache per toolkit (tuned/build.sh hands it to CMake as the compiler launcher). CCACHE_DIR also
# makes ccache ignore ~/.config/ccache/ccache.conf, so its small default size cap would apply: set
# it here (a RAPIDS build is far larger than 5 GB).
export CCACHE_DIR="${GPU_TUNED_BUILD_ROOT}/ccache"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-40G}"
export GPU_TUNED_BUILD_ROOT
