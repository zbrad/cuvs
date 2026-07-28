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

# Fail loudly if this script runs on the wrong host, rather than letting a
# mismatched build silently produce wrong-architecture binaries that only
# surface as a confusing failure several steps later. (Previously this check
# only existed for gb10/aarch64 in build_gb10.sh; rtx40/rtx50 had no
# equivalent x86_64 check at all -- this makes it uniform across all three.)
if [[ "$(uname -m)" != "${GPU_TUNED_PLATFORM}" ]]; then
    echo "ERROR: tuned/env.sh: expected platform '${GPU_TUNED_PLATFORM}' for" \
         "variant '${GPU_TUNED_VARIANT}', but uname -m reports '$(uname -m)'." >&2
    return 1 2>/dev/null || exit 1
fi

# List installed toolkits under /usr/local/cuda-<ver> (glob, sorted). Used
# both to derive the default CUDA_VER below (highest installed, not a
# hardcoded version that inevitably goes stale -- e.g. this default was
# "13.2" even after 13.3 was installed here) and to give actionable
# guidance instead of a bare "wrong version" warning.
cuvs_installed_cuda_toolkits() {
    local d
    for d in /usr/local/cuda-[0-9]*; do
        [ -d "$d" ] && basename "$d" | sed 's/^cuda-//'
    done | sort -V
}

# --- Resolve CUDA_VER / CUDA_TAG (specify either, derive the other) ---
if [ -n "${CUDA_VER:-}" ]; then
    : "${CUDA_TAG:=cu${CUDA_VER//./}}"                          # 13.3 -> cu133
elif [ -n "${CUDA_TAG:-}" ]; then
    _cuda_digits="${CUDA_TAG#cu}"                               # cu133 -> 133
    : "${CUDA_VER:=${_cuda_digits%?}.${_cuda_digits: -1}}"     # 133 -> 13.3
    unset _cuda_digits
fi
if [ -z "${CUDA_VER:-}" ]; then
    _cuvs_latest="$(cuvs_installed_cuda_toolkits | tail -1)"
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
        _cuvs_installed="$(cuvs_installed_cuda_toolkits | tr '\n' ' ')"
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
        _cuvs_installed="$(cuvs_installed_cuda_toolkits | tr '\n' ' ')"
        [ -n "$_cuvs_installed" ] && echo "[tuned/env]          Installed toolkits: ${_cuvs_installed}" >&2
        unset _cuvs_installed
    fi
    unset _nvcc_ver
fi

# gpu_tuned_verify_arch <path-to-.so> — empirical "did the build actually do
# what we asked" check: confirms a compiled library's embedded cubin(s) are
# EXACTLY sm_${GPU_TUNED_CUDA_ARCH}, via cuobjdump, catching either a fat
# multi-arch build or CMake/nvcc silently normalizing to a different arch --
# neither of which a bare file-existence check (this repo's only prior
# verification) can detect. Same name/signature as zbrad/raft's tuned/env.sh
# equivalent.
gpu_tuned_verify_arch() {
    local so_file="$1"
    if [[ ! -f "${so_file}" ]]; then
        echo "ERROR: gpu_tuned_verify_arch: no such file: ${so_file}" >&2
        return 1
    fi
    command -v cuobjdump >/dev/null 2>&1 || {
        echo "ERROR: gpu_tuned_verify_arch: cuobjdump not found on PATH (expected under \$CUDA_HOME/bin)." >&2
        return 1
    }
    local found found_count
    found="$(cuobjdump --list-elf "${so_file}" 2>/dev/null | grep -oE 'sm_[0-9]+[a-z]?' | sort -u)"
    if [[ -z "${found}" ]]; then
        echo "ERROR: gpu_tuned_verify_arch: cuobjdump found no embedded cubins in ${so_file} at all." >&2
        return 1
    fi
    found_count="$(echo "${found}" | wc -l)"
    if [[ "${found_count}" -ne 1 ]]; then
        echo "ERROR: ${so_file} embeds MULTIPLE arch targets ($(echo "${found}" | tr '\n' ' ')) -- this is supposed to be a single-arch tuned build, not a fat multi-arch one." >&2
        return 1
    fi
    if [[ "${found}" != "sm_${GPU_TUNED_CUDA_ARCH}" ]]; then
        echo "ERROR: ${so_file} is not built for sm_${GPU_TUNED_CUDA_ARCH} (found: ${found})." >&2
        return 1
    fi
    echo "OK: ${so_file} confirmed single-arch ${found} (matches requested sm_${GPU_TUNED_CUDA_ARCH})"
}

# gpu_tuned_verify_cuda_compat <path-to-.so> <expected-cuda-ver> — confirms
# a compiled library's NEEDED libcudart.so.<major> matches the CUDA major
# version this build expects. CUDA's runtime ABI is only guaranteed
# forward-compatible WITHIN a major series (e.g. built against 13.2 but
# running against 13.3 is fine; 12.x vs 13.x is not) -- so this checks
# major only, by design. Complements gpu_tuned_verify_arch (SM arch) with
# the orthogonal CUDA-runtime-version axis. Same name/signature as
# zbrad/faiss's tuned/env.sh equivalent, which also calls this on a
# downloaded cuvs release .so before linking against it.
gpu_tuned_verify_cuda_compat() {
    local so_file="$1" expected_cuda_ver="$2"
    if [[ ! -f "${so_file}" ]]; then
        echo "ERROR: gpu_tuned_verify_cuda_compat: no such file: ${so_file}" >&2
        return 1
    fi
    command -v objdump >/dev/null 2>&1 || {
        echo "ERROR: gpu_tuned_verify_cuda_compat: objdump not found on PATH." >&2
        return 1
    }
    local needed found_major expected_major
    needed="$(objdump -p "${so_file}" 2>/dev/null | grep -oE 'libcudart\.so\.[0-9]+' | head -1)"
    if [[ -z "${needed}" ]]; then
        echo "WARNING: ${so_file} has no direct libcudart.so.N NEEDED entry -- skipping CUDA runtime compat check." >&2
        return 0
    fi
    found_major="${needed##*.}"
    expected_major="${expected_cuda_ver%%.*}"
    if [[ "${found_major}" != "${expected_major}" ]]; then
        echo "ERROR: ${so_file} was linked against CUDA runtime major ${found_major}" \
             "(${needed}), but this build expects CUDA ${expected_cuda_ver}" \
             "(major ${expected_major}). CUDA's runtime ABI is only forward-compatible" \
             "within the same major version." >&2
        return 1
    fi
    echo "OK: ${so_file} CUDA runtime compat confirmed (${needed}, matches expected major ${expected_major})"
}

# embed_build_info <so_path> <variant> <package> <version> [hw_label] —
# embeds a greppable build-info string into a custom ELF section
# (.cuvs_build_info) on the given .so, readable later via
# `readelf -p .cuvs_build_info <so>` or plain `strings`. Safe at runtime:
# a custom section with no program-header entry is simply ignored by the
# dynamic loader. Same technique/name as zbrad/raft's
# tuned/raft_wheel_common.sh equivalent (.raft_build_info).
#
# hw_label (optional, defaults to the bare variant if omitted) makes the
# binary self-describing about WHICH hardware it targets, not just its
# internal codename -- e.g. "RTX 50-series (Blackwell consumer,
# desktop/laptop, SM 120a)" rather than just "rtx50". Without this, the
# only human-readable description of scope lived in the GitHub release's
# own title text, which goes stale independently of the binary (confirmed:
# this repo's already-published v26.08.00-rtx50-cu133 release still says
# "RTX 5080, RTX 5090" after tuned/devices/rtx50.conf's label was broadened).
embed_build_info() {
    local so_path="$1" variant="$2" package="$3" version="$4" hw_label="${5:-${2}}"
    local tmp
    tmp="$(mktemp)"
    echo "cuvs-${variant} build: ${package} v${version} (${hw_label}), https://github.com/zbrad/cuvs, built $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${tmp}"
    # Idempotent: objcopy --add-section on a section name that already
    # exists (e.g. re-packaging the same install tree a second time)
    # empirically corrupts its own in-place rewrite ("file format not
    # recognized" on its own temp output) -- strip any prior stamp first.
    objcopy --remove-section .cuvs_build_info "${so_path}" 2>/dev/null || true
    objcopy --add-section .cuvs_build_info="${tmp}" "${so_path}"
    rm -f "${tmp}"
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
