#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# Single source of truth for the CUDA version targeted by cuVS build scripts.
# All build scripts source this file.
#
# Specify the version at build time with EITHER variable (the other is derived):
#
#   CUDA_VER=13.3  bash build_gb10.sh    # human-readable form
#   CUDA_TAG=cu133 bash build_gb10.sh    # short tag form
#
# Defaults to CUDA 13.2 (cu132) when neither is set.
#
# The CUDA version drives all library and script names, which are keyed by
# GPU codename rather than CPU arch or SM number (mirrors zbrad/vllm's gb10
# branch convention, e.g. requirements/gb10.txt / tools/build_gb10.sh):
#   C++ library  : libcuvs-{codename}-${CUDA_TAG}.so
#     e.g. libcuvs-gb10-cu132.so  (DGX Spark, aarch64, SM 121)
#
# This branch covers GB10 only. The `rtx` branch adds rtx40/rtx50 codenames
# (Ada Lovelace / Blackwell, x86_64) on top of this same convention.
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

# List installed toolkits under /usr/local/cuda-<ver> (glob, sorted). Used to
# give actionable guidance instead of a bare "wrong version" warning.
cuvs_installed_cuda_toolkits() {
    local d
    for d in /usr/local/cuda-[0-9]*; do
        [ -d "$d" ] && basename "$d" | sed 's/^cuda-//'
    done | sort -V
}

# --- Resolve CUDA_HOME to the matching toolkit when not explicitly set ---
if [ -z "${CUDA_HOME:-}" ]; then
    if [ -d "/usr/local/cuda-${CUDA_VER}" ]; then
        export CUDA_HOME="/usr/local/cuda-${CUDA_VER}"
    else
        echo "[cuda_env] WARNING: /usr/local/cuda-${CUDA_VER} not found; falling back to /usr/local/cuda (whatever version that symlinks to)." >&2
        _cuvs_installed="$(cuvs_installed_cuda_toolkits | tr '\n' ' ')"
        if [ -n "$_cuvs_installed" ]; then
            echo "[cuda_env]          Installed toolkits: ${_cuvs_installed}. Set CUDA_VER to one of these, or CUDA_HOME to an explicit path." >&2
        else
            echo "[cuda_env]          No /usr/local/cuda-<ver> toolkits found at all." >&2
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
        echo "[cuda_env] WARNING: nvcc reports CUDA $_nvcc_ver but CUDA_VER=$CUDA_VER" >&2
        echo "[cuda_env]          (CUDA_HOME=$CUDA_HOME). Set CUDA_HOME or CUDA_VER to match." >&2
        _cuvs_installed="$(cuvs_installed_cuda_toolkits | tr '\n' ' ')"
        [ -n "$_cuvs_installed" ] && echo "[cuda_env]          Installed toolkits: ${_cuvs_installed}" >&2
        unset _cuvs_installed
    fi
    unset _nvcc_ver
fi
