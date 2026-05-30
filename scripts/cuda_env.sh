#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# Single source of truth for the CUDA version targeted by cuVS build scripts.
# All build scripts source this file.
#
# Specify the version at build time with EITHER variable (the other is derived):
#
#   CUDA_VER=13.3  bash build_aarch64.sh    # human-readable form
#   CUDA_TAG=cu133 bash build_aarch64.sh    # short tag form
#
# Defaults to CUDA 13.2 (cu132) when neither is set.
#
# The CUDA version drives all library and script names:
#   C++ library  : libcuvs-{cpu_arch}-${CUDA_TAG}[-sm{sm}].so
#     single GPU arch  ->  include -sm suffix  (e.g. libcuvs-aarch64-cu132-sm103.so)
#     multi  GPU arch  ->  omit   -sm suffix  (e.g. libcuvs-x86_64-cu132.so)
#
# Multi-toolkit hosts: CUDA_HOME is auto-resolved to /usr/local/cuda-<CUDA_VER>
# when that directory exists. Set CUDA_HOME explicitly to force a path.
# If the nvcc on PATH reports a different version a warning is printed.
#
# Mirrors the convention in zbrad/faiss gpu-cu/scripts/cuda_env.sh
# (uses CUDA_VER/CUDA_TAG instead of FAISS_CUDA_VER/FAISS_CUDA_TAG).

# --- Resolve CUDA_VER / CUDA_TAG (specify either, derive the other) ---
if [ -n "${CUDA_VER:-}" ]; then
    : "${CUDA_TAG:=cu${CUDA_VER//./}}"                          # 13.3 -> cu133
elif [ -n "${CUDA_TAG:-}" ]; then
    _cuda_digits="${CUDA_TAG#cu}"                               # cu133 -> 133
    : "${CUDA_VER:=${_cuda_digits%?}.${_cuda_digits: -1}}"     # 133 -> 13.3
    unset _cuda_digits
fi
export CUDA_VER="${CUDA_VER:-13.2}"
export CUDA_TAG="${CUDA_TAG:-cu${CUDA_VER//./}}"

# --- Resolve CUDA_HOME to the matching toolkit when not explicitly set ---
if [ -z "${CUDA_HOME:-}" ]; then
    if [ -d "/usr/local/cuda-${CUDA_VER}" ]; then
        export CUDA_HOME="/usr/local/cuda-${CUDA_VER}"
    else
        export CUDA_HOME="/usr/local/cuda"
    fi
fi
export PATH="$CUDA_HOME/bin:$PATH"

# --- Sanity: warn if the resolved nvcc does not match the requested version ---
if command -v nvcc >/dev/null 2>&1; then
    _nvcc_ver="$(nvcc --version 2>/dev/null | grep -oE 'release [0-9]+\.[0-9]+' | awk '{print $2}')"
    if [ -n "$_nvcc_ver" ] && [ "$_nvcc_ver" != "$CUDA_VER" ]; then
        echo "[cuda_env] WARNING: nvcc reports CUDA $_nvcc_ver but CUDA_VER=$CUDA_VER" >&2
        echo "[cuda_env]          (CUDA_HOME=$CUDA_HOME). Set CUDA_HOME or CUDA_VER to match." >&2
    fi
    unset _nvcc_ver
fi

# Print "-sm<arch>" when the build targets exactly one GPU arch, else nothing.
# Used to tag single-arch libraries (e.g. libcuvs-aarch64-cu132-sm103.so).
# Multi-arch builds (e.g. libcuvs-x86_64-cu132.so) get no suffix.
# Reads CUDA_ARCHS; tolerant of ";"/","/"\;" separators and -real/-virtual suffixes.
cuvs_sm_suffix() {
    local archs="${1:-${CUDA_ARCHS:-}}"
    local uniq
    uniq=$(printf '%s' "$archs" \
        | sed -E 's/[\\,;]+/\n/g; s/-(real|virtual)//g; s/[[:blank:]]//g' \
        | sed '/^$/d' | sort -u)
    if [ -n "$uniq" ] && [ "$(printf '%s\n' "$uniq" | wc -l | tr -d ' ')" -eq 1 ]; then
        printf -- '-sm%s' "$uniq"
    fi
}
