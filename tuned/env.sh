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
# build_gb10.sh/build_rtx40.sh/build_rtx50.sh -- now in
# tuned/devices/<variant>.conf, one file per variant, following the same
# GPU_TUNED_* convention as zbrad/raft's tuned/env.sh.
#
# Specify the CUDA version at build time with EITHER variable (the other is
# derived), same as before:
#
#   CUDA_VER=13.3  bash tuned/build.sh gb10
#   CUDA_TAG=cu133 bash tuned/build.sh gb10
#
# Defaults to CUDA 13.2 (cu132) when neither is set.
#
# Exported variables:
#   CUDA_VER / CUDA_TAG / CUDA_HOME
#     — as before (this repo's own naming, deliberately NOT renamed to
#       raft's CUDA_VERSION/CUDA_VERSION_COMPACT -- mirrors zbrad/faiss
#       gpu-cu/scripts/cuda_env.sh, already referenced by name throughout
#       this repo's docs and by faiss's own build scripts; renaming would
#       break those references for no benefit).
#   GPU_TUNED_VARIANT / GPU_TUNED_PLATFORM / GPU_TUNED_CUDA_ARCH /
#   GPU_TUNED_BUILD_MG_ALGOS / GPU_TUNED_HW_LABEL / GPU_TUNED_DEVICE_LABEL
#     — from tuned/devices/<variant>.conf, re-exported here.
#
# Also defines gpu_tuned_verify_arch() and cuvs_check_raft_version() -- see
# below.

GPU_TUNED_ARG_VARIANT="$1"
if [[ -z "${GPU_TUNED_ARG_VARIANT}" ]]; then
    echo "ERROR: env.sh requires a variant argument (gb10/rtx40/rtx50)" >&2
    return 1 2>/dev/null || exit 1
fi

GPU_TUNED_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=devices/rtx50.conf
source "${GPU_TUNED_SELF_DIR}/devices/${GPU_TUNED_ARG_VARIANT}.conf" || return 1 2>/dev/null || exit 1
export GPU_TUNED_VARIANT GPU_TUNED_PLATFORM GPU_TUNED_CUDA_ARCH GPU_TUNED_BUILD_MG_ALGOS GPU_TUNED_HW_LABEL GPU_TUNED_DEVICE_LABEL

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

# --- Resolve CUDA_VER / CUDA_TAG (specify either, derive the other) ---
if [ -n "${CUDA_VER:-}" ]; then
    : "${CUDA_TAG:=cu${CUDA_VER//./}}"                          # 13.3 -> cu133
elif [ -n "${CUDA_TAG:-}" ]; then
    _cuda_digits="${CUDA_TAG#cu}"                               # cu133 -> 133
    : "${CUDA_VER:=${_cuda_digits%?}.${_cuda_digits: -1}}"     # 133 -> 13.3
    unset _cuda_digits
fi
if [ -z "${CUDA_VER:-}" ]; then
    _cuvs_latest="$(gpu_tuned_installed_cuda_toolkits | tail -1)"
    CUDA_VER="${_cuvs_latest:-13.2}"  # last-resort fallback if nothing is installed yet
    unset _cuvs_latest
fi
export CUDA_VER
export CUDA_TAG="${CUDA_TAG:-cu${CUDA_VER//./}}"

# --- Resolve CUDA_HOME to the matching toolkit when not explicitly set ---
if [ -z "${CUDA_HOME:-}" ]; then
    if [ -d "/usr/local/cuda-${CUDA_VER}" ]; then
        export CUDA_HOME="/usr/local/cuda-${CUDA_VER}"
    else
        echo "[tuned/env] WARNING: /usr/local/cuda-${CUDA_VER} not found; falling back to /usr/local/cuda (whatever version that symlinks to)." >&2
        _cuvs_installed="$(gpu_tuned_installed_cuda_toolkits | tr '\n' ' ')"
        if [ -n "$_cuvs_installed" ]; then
            echo "[tuned/env]          Installed toolkits: ${_cuvs_installed}. Set CUDA_VER to one of these, or CUDA_HOME to an explicit path." >&2
        else
            echo "[tuned/env]          No /usr/local/cuda-<ver> toolkits found at all." >&2
        fi
        unset _cuvs_installed
        export CUDA_HOME="/usr/local/cuda"
    fi
fi
export PATH="$CUDA_HOME/bin:$PATH"

# --- Sanity: warn if the resolved nvcc does not match the requested version ---
if command -v nvcc >/dev/null 2>&1; then
    _nvcc_ver="$(nvcc --version 2>/dev/null | grep -oE 'release [0-9]+\.[0-9]+' | awk '{print $2}')"
    if [ -n "$_nvcc_ver" ] && [ "$_nvcc_ver" != "$CUDA_VER" ]; then
        echo "[tuned/env] WARNING: nvcc reports CUDA $_nvcc_ver but CUDA_VER=$CUDA_VER" >&2
        echo "[tuned/env]          (CUDA_HOME=$CUDA_HOME). Set CUDA_HOME or CUDA_VER to match." >&2
        _cuvs_installed="$(gpu_tuned_installed_cuda_toolkits | tr '\n' ' ')"
        [ -n "$_cuvs_installed" ] && echo "[tuned/env]          Installed toolkits: ${_cuvs_installed}" >&2
        unset _cuvs_installed
    fi
    unset _nvcc_ver
fi

# embed_build_info now comes from common.sh (gpu_tuned_embed_build_info) --
# this repo's every call site already passes package="cuvs" (matching
# every call: package.sh's tuned/package.sh), so the shared function's
# package-derived section name naturally lands on the same
# .cuvs_build_info this repo always used, and its message format
# (`<package>-<variant> build: <package> v<version> (<hw_label>), <repo_url>,
# built <date>`) is byte-identical to what the old local version produced.
# Wrap it just to keep call sites unchanged (repo_url baked in here).
embed_build_info() {
    gpu_tuned_embed_build_info "$1" "$2" "$3" "$4" "$5" "https://github.com/zbrad/cuvs"
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
