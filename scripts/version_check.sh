#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# Surfaces which raft this build actually linked against.
#
# An earlier draft of this check asserted raft's fetched VERSION must equal
# this cuVS checkout's own VERSION major.minor, on the assumption that
# get_raft.cmake's tag-pinning guarantees that by construction. Verified
# empirically FALSE: this repo's RAPIDS_BRANCH file is "main" (not a pinned
# "branch-26.08"), so get_raft.cmake's rapids-cmake-checkout-tag resolves to
# upstream rapidsai/raft's current main-branch development version -- which
# routinely runs ahead of this checkout's own declared VERSION during a
# normal RAPIDS release cycle. Confirmed live: a real CMake configure on this
# branch fetched raft main at VERSION 26.10.00 while this repo's own VERSION
# is 26.08.00. A hard equality gate would have failed every normal build on
# this branch, not just genuine drift -- so this deliberately WARNS, it does
# not fail (same precedent as scripts/cuda_env.sh's own nvcc-version
# mismatch check).
#
# What this DOES catch, meaningfully: this cuVS native-builds system has no
# pin to your own raft fork (zbrad/raft) at all -- confirmed, no RAFT_FORK/
# RAFT_PINNED_TAG/CMAKE_PREFIX_PATH override anywhere in build_rtx50.sh/
# build_rtx40.sh/build_gb10.sh. It always CPM-clones upstream rapidsai/raft's
# main branch fresh, independent of whatever's published/tuned on your own
# raft fork. This function's real job is making that visible -- printing
# exactly which raft version got fetched -- so a future upstream raft API/ABI
# break doesn't show up as a mystery compile failure with no record of what
# version was actually in play.

# cuvs_check_raft_version <libcuvs_build_dir> <cuvs_repodir>
cuvs_check_raft_version() {
    local build_dir="$1" repodir="$2"
    local raft_version_file="${build_dir}/_deps/raft-src/VERSION"

    if [ ! -f "$raft_version_file" ]; then
        echo "[version_check] WARNING: ${raft_version_file} not found -- raft was not CPM-fetched where expected (or rapids-cmake's CPM staging layout changed since this was written). Skipping version visibility check." >&2
        return 0
    fi

    local raft_version cuvs_version raft_mm cuvs_mm
    raft_version="$(cat "$raft_version_file")"
    cuvs_version="$(cat "${repodir}/VERSION")"
    raft_mm="$(echo "$raft_version" | grep -oE '^[0-9]+\.[0-9]+')"
    cuvs_mm="$(echo "$cuvs_version" | grep -oE '^[0-9]+\.[0-9]+')"

    echo "[version_check] This build links against upstream rapidsai/raft VERSION ${raft_version} (this cuVS checkout's own VERSION is ${cuvs_version})."
    if [ "$raft_mm" != "$cuvs_mm" ]; then
        echo "[version_check] NOTE: major.minor differs (raft ${raft_mm:-unparseable} vs cuvs ${cuvs_mm:-unparseable}) -- expected during a normal RAPIDS dev cycle since this repo tracks raft's main branch rather than a pinned release, not necessarily a problem. Recorded here so it's visible if something else breaks." >&2
    fi
}
