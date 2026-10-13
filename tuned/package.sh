#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# tuned/package.sh <variant> — package an already-built (tuned/build.sh
# <variant>) cmake-install tree into a tarball (with unique shared-object
# identities; see below). Publishing is a separate step, tuned/release.sh,
# so the tarball can be used locally first. Downstream C++ consumers (zbrad/faiss) can pull a
# published cuVS build instead of reaching into a local sibling checkout.
#
# Not a Python wheel (unlike raft/flashinfer/pytorch's tuned/wheel.sh) --
# faiss links cuvs::cuvs as a C++ CMake target at configure time, not a
# Python runtime import, so the released artifact needs to be a tarball of
# the cmake --install output (lib/, include/, lib/cmake/cuvs/*.cmake), not
# a .whl. Naming follows tuned/docs/WHEEL_NAMING.md's GPU-codename
# convention (already used for the .so itself); the one pre-existing
# release (v26.06.00-spark) predates that convention and is not reused
# as a pattern here.
#
# Usage:
#   bash tuned/build.sh rtx50      # first, produces the install tree
#   bash tuned/package.sh rtx50    # then, packages it; tuned/release.sh publishes
set -euo pipefail

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="$1"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1

CUVS_LIB_NAME="cuvs-${GPU_TUNED_VARIANT}-${CUDA_TAG}"
# tr -d '\r': defends against CRLF drift in VERSION (bash's $() only
# strips a trailing \n, not \r) -- a real, empirically-hit failure mode:
# an embedded \r here silently corrupted both the release tag_name (gh
# rejected it as "not well-formed") and the tarball filename (a hidden \r
# byte made ls/find LOOK like a normal name on screen while stat/gh/cp all
# correctly reported "no such file" for the literal name being typed).
CUVS_VERSION="$(tr -d '\r' < "${REPODIR}/VERSION")"
# Derive short version (e.g. 26.08.00 -> 26.8), matching zbrad/raft's own
# tuned/package.sh convention -- used for the tarball name/release tag/
# title below; CUVS_VERSION (full, unshortened) stays in the build-info
# stamp and the informational "Version:" line above, where precision
# matters more than brevity.
SHORT_VER="$(gpu_tuned_short_ver "${CUVS_VERSION}")" || exit 1
# -g<short-sha> suffix: SHORT_VER alone collides across genuinely
# different rebuilds (VERSION only bumps on a real upstream release cut)
# -- matches zbrad/raft's tuned/package.sh, which hit exactly this
# collision 2026-09-08 (had to delete-and-recreate a tag to republish).
SHORT_SHA="$(git -C "${REPODIR}" rev-parse --short HEAD)"

# Must match tuned/build.sh's own default resolution exactly -- this script
# does not rebuild, it packages whatever tuned/build.sh already installed.
LIBCUVS_BUILD_DIR="${LIBCUVS_BUILD_DIR:-"$(gpu_tuned_out_dir build "${REPODIR}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}")"}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${PREFIX:-${CONDA_PREFIX:-${LIBCUVS_BUILD_DIR}/install}}}"

echo "===================================================="
echo "cuVS ${GPU_TUNED_DEVICE_LABEL} Package"
echo "===================================================="
echo ""
echo "  Install tree : ${INSTALL_PREFIX}"
echo "  Library      : lib${CUVS_LIB_NAME}.so"
echo "  Version      : ${CUVS_VERSION} (${CUDA_TAG})"
echo ""

INSTALLED_LIB="${INSTALL_PREFIX}/lib/lib${CUVS_LIB_NAME}.so"
if [[ ! -f "${INSTALLED_LIB}" ]]; then
    echo "ERROR: ${INSTALLED_LIB} not found." >&2
    echo "  Run 'bash tuned/build.sh ${GPU_TUNED_VARIANT}' first (with the same" >&2
    echo "  INSTALL_PREFIX/PREFIX/CONDA_PREFIX this script resolved above)." >&2
    exit 1
fi
gpu_tuned_verify_arch "${INSTALLED_LIB}" "${GPU_TUNED_CUDA_ARCH}" || exit 1
gpu_tuned_verify_cuda_compat "${INSTALLED_LIB}" "${CUDA_VER}" || exit 1

# libcuvs (and libcuvs_c) link kvikio, a CPM subproject that cuvs's own
# install does not install. Without libkvikio.so in the tarball the release
# loads only on a machine that still has this build tree (v26.10-gb10-cu133
# and v26.12-gb10-cu134 shipped that way). Install it from its own generated
# install script, the same technique tuned/build.sh uses for raft/rmm. Done
# before stamping so the stamp can record it.
if readelf -d "${INSTALLED_LIB}" | grep -q 'NEEDED.*libkvikio'; then
    KVIKIO_INSTALL_SCRIPT="${LIBCUVS_BUILD_DIR}/_deps/kvikio-build/cmake_install.cmake"
    if [[ ! -f "${KVIKIO_INSTALL_SCRIPT}" ]]; then
        echo "ERROR: ${INSTALLED_LIB} needs libkvikio.so but ${KVIKIO_INSTALL_SCRIPT} is missing." >&2
        echo "  Re-run tuned/build.sh ${GPU_TUNED_VARIANT}." >&2
        exit 1
    fi
    echo "Bundling kvikio into ${INSTALL_PREFIX}..."
    cmake -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -P "${KVIKIO_INSTALL_SCRIPT}"
fi

# Record what the package bundles in the stamp, read from each bundled cmake
# package's own version file, so it is visible with `readelf -p` and tells a
# release that carries kvikio from one that does not.
BUNDLED_DEPS=""
for _pkg in kvikio raft rmm rapids_logger; do
    _ver_file="${INSTALL_PREFIX}/lib/cmake/${_pkg}/${_pkg}-config-version.cmake"
    if [[ -f "${_ver_file}" ]]; then
        _ver="$(grep -oE 'PACKAGE_VERSION "[^"]+"' "${_ver_file}" | head -1 | cut -d'"' -f2 || true)"
        [[ -z "${_ver}" ]] || BUNDLED_DEPS+="${BUNDLED_DEPS:+, }${_pkg} ${_ver}"
    fi
done
unset _pkg _ver_file _ver
export GPU_TUNED_BUILD_INFO_DEPS="${BUNDLED_DEPS}"
echo "  bundled deps : ${BUNDLED_DEPS:-none}"

embed_build_info "${INSTALLED_LIB}" "${GPU_TUNED_VARIANT}" "cuvs" "${CUVS_VERSION}+${CUDA_TAG}" "${GPU_TUNED_HW_LABEL}"
# Confirm the stamp actually landed before archiving -- the tarball is a
# straight `tar -czf` of INSTALL_PREFIX below with no further build/install
# pass, so this should always pass, but every other repo in this fleet
# validates its stamp right after writing it rather than assuming.
gpu_tuned_verify_build_info "${INSTALLED_LIB}" "cuvs" "${CUVS_VERSION}+${CUDA_TAG}" || exit 1

CUVS_CMAKE_CONFIG="$(find "${INSTALL_PREFIX}" -maxdepth 4 -iname 'cuvs-config.cmake' 2>/dev/null | head -1)"
if [[ -z "${CUVS_CMAKE_CONFIG}" ]]; then
    echo "ERROR: no cuvs-config.cmake found under ${INSTALL_PREFIX} -- the" >&2
    echo "  install tree looks incomplete (expected rapids_export's cmake" >&2
    echo "  package config alongside the .so). Re-run tuned/build.sh." >&2
    exit 1
fi
echo "  cmake config : ${CUVS_CMAKE_CONFIG}"

# Unique shared-object identities, applied to a copy so the build tree's install prefix keeps the
# names the rest of the build expects. Every shared object this package ships -- cuvs's, and the
# raft chain and kvikio it vendors -- carries a stock RAPIDS file name and SONAME (librmm.so,
# librapids_logger.so, libkvikio.so, libcuvs_c.so) and so could be swapped with a stock install in
# either direction. They become <name>-tuned.so (file name, SONAME, every DT_NEEDED naming them) and
# the installed CMake import files are repointed. lib${CUVS_LIB_NAME}.so and libraft-${GPU_TUNED_VARIANT}-${CUDA_TAG}.so
# already carry variant and CUDA tag and are kept; .a archives have no SONAME. Idempotent, so it
# does not matter whether the vendored raft release was already renamed. See "unique shared-object
# identities" in tuned-common's tuned-common.sh.
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
cp -a "${INSTALL_PREFIX}/." "${STAGE}/"
echo ""
echo "Giving the shared objects unique identities:"
OURS_MANIFEST="$(mktemp)"
for so in librmm.so librapids_logger.so libkvikio.so libcuvs_c.so; do
    if [[ -f "${STAGE}/lib/${so}" ]]; then
        echo "${so}" >> "${OURS_MANIFEST}"
    elif [[ ! -f "${STAGE}/lib/$(gpu_tuned_tuned_so_name "${so}")" ]]; then
        echo "ERROR: ${so} is missing from ${STAGE}/lib; the rename list is stale." >&2
        exit 1
    fi
done
KEEP_RE="^lib(${CUVS_LIB_NAME}|raft-${GPU_TUNED_VARIANT}-${CUDA_TAG})\\.so\$"
# Renames, repoints the installed CMake and pkg-config files, then fails closed: every shared object
# is renamed or kept, every DT_NEEDED resolves in the tree or is a toolkit/system library.
gpu_tuned_rename_package "${STAGE}/lib" "${OURS_MANIFEST}" - "${KEEP_RE}" \
    '^(linux-vdso\.so|ld-linux|libc\.so|libm\.so|libdl\.so|libpthread\.so|librt\.so|libgcc_s\.so|libstdc\+\+\.so|libgomp\.so|libcuda\.so|libcudart\.so|libcublas\.so|libcublasLt\.so|libcusolver\.so|libcusparse\.so|libcurand\.so|libcufft\.so|libnvrtc\.so|libnvJitLink\.so|libnvtx|libcufile\.so)' \
    "${STAGE}/lib/cmake" "${STAGE}/lib/pkgconfig" || exit 1
rm -f "${OURS_MANIFEST}"
# patchelf rewrote the files; the build-info stamp on the cuvs lib must have survived
gpu_tuned_verify_build_info "${STAGE}/lib/lib${CUVS_LIB_NAME}.so" "cuvs" "${CUVS_VERSION}+${CUDA_TAG}" || exit 1

# Refuse to publish a package whose libraries need something it does not ship.
bash "${REPODIR}/tuned/verify_bundled_deps.sh" "${STAGE}" || exit 1

# Self-containment gates. A package whose installed CMake files ask for nvtx3 must ship it (config and
# headers): found in a pip wheel instead of fetched, it is silently left out and consumers (faiss) fail
# to configure. Then prove it the way a consumer would: configure a minimal project against this
# package alone and require nvtx3, rmm and rapids_logger to resolve inside it.
if grep -rqE 'find_dependency\(nvtx3' "${STAGE}/lib/cmake" 2>/dev/null; then
    if ! compgen -G "${STAGE}/lib*/cmake/nvtx3/nvtx3-config.cmake" >/dev/null || [[ ! -f "${STAGE}/include/nvtx3/nvtx3.hpp" ]]; then
        echo "ERROR: the CMake files in this package require nvtx3 but it does not ship its config and headers; it was found outside the build (a pip wheel?) instead of fetched. That copy is not the tuned, tested one." >&2
        exit 1
    fi
fi
gpu_tuned_verify_consumer_configure "${STAGE}" rmm raft cuvs || exit 1
DIST_DIR="$(gpu_tuned_out_dir dist "${REPODIR}" "${CUDA_TAG}" "${GPU_TUNED_VARIANT}")"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
TARBALL="${DIST_DIR}/libcuvs-${SHORT_VER}-${GPU_TUNED_VARIANT}-${CUDA_TAG}-g${SHORT_SHA}.tar.gz"

echo ""
echo "Packaging ${STAGE} (renamed copy of ${INSTALL_PREFIX}) -> ${TARBALL}..."
tar -C "${STAGE}" -czf "${TARBALL}" .
echo "Tarball: $(basename "${TARBALL}") ($(du -sh "${TARBALL}" | awk '{print $1}'))"

echo ""
echo "Packaged (not published): ${TARBALL}"
echo "Publish with: bash tuned/release.sh ${GPU_TUNED_VARIANT}"
