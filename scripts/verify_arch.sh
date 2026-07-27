#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# Empirical "did the build actually do what we asked" check for the
# single-arch build_rtx50.sh/build_rtx40.sh/build_gb10.sh scripts.
#
# Those scripts only ever confirmed the output .so file EXISTS -- never that
# its embedded cubin(s) actually match the single CMAKE_CUDA_ARCHITECTURES
# value that was requested. A file-existence check can't tell a correctly
# single-arch build apart from a fat multi-arch one, or from CMake silently
# normalizing a requested arch to a different one (this repo's own git log
# shows exactly this kind of drift already happened once: commit 535a16e1,
# "Use Blackwell 'a' family-specific arch suffix for gb10/rtx50" -- a real fix
# for a real prior mismatch between the requested and actually-useful arch).
# cuobjdump reads back what nvcc really embedded, so this checks reality
# instead of trusting the request.

# cuvs_verify_arch <so_path> <cmake_cuda_archs>
#   <cmake_cuda_archs> is the exact string passed to
#   -DCMAKE_CUDA_ARCHITECTURES, e.g. "120a-real" or "89-real".
cuvs_verify_arch() {
    local so_path="$1" cmake_arch="$2"
    local expected_sm="sm_${cmake_arch%%-*}"

    command -v cuobjdump >/dev/null 2>&1 || {
        echo "[verify_arch] ERROR: cuobjdump not found on PATH (expected under \$CUDA_HOME/bin) -- cannot verify ${so_path}." >&2
        return 1
    }
    [ -f "$so_path" ] || {
        echo "[verify_arch] ERROR: ${so_path} does not exist -- nothing to verify." >&2
        return 1
    }

    local found_sms found_count
    found_sms="$(cuobjdump --list-elf "$so_path" 2>/dev/null | grep -oE 'sm_[0-9]+[a-z]?' | sort -u)"

    if [ -z "$found_sms" ]; then
        echo "[verify_arch] ERROR: cuobjdump found no embedded cubins in ${so_path} at all." >&2
        return 1
    fi

    found_count="$(echo "$found_sms" | wc -l)"
    if [ "$found_count" -ne 1 ]; then
        echo "[verify_arch] ERROR: ${so_path} embeds MULTIPLE arch targets ($(echo "$found_sms" | tr '\n' ' ')) -- this is supposed to be a single-arch tuned build, not a fat multi-arch one." >&2
        return 1
    fi

    if [ "$found_sms" != "$expected_sm" ]; then
        echo "[verify_arch] ERROR: ${so_path} embeds ${found_sms}, but this build requested ${expected_sm} (-DCMAKE_CUDA_ARCHITECTURES=${cmake_arch}). CMake/nvcc silently produced a different arch than requested -- do not ship this artifact under the ${cmake_arch} name." >&2
        return 1
    fi

    echo "[verify_arch] OK: ${so_path} confirmed single-arch ${found_sms} (matches requested ${cmake_arch})"
}
