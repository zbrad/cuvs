#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# tuned/verify_bundled_deps.sh <install-tree-or-extracted-tarball>
#
# Fail if a shared library under <dir>/lib needs a library that is neither
# shipped in the package nor a system library, or if a library's RUNPATH points
# into a build tree. A package that passes runs on a machine that has only the
# CUDA toolkit/driver and the OS libraries.
#
# Why: the published cuvs 26.10 and 26.12 releases shipped libcuvs with
# NEEDED libkvikio.so but without libkvikio.so, so they loaded only on the
# machine that had the build tree. Nothing checked; this does.
#
# CUDA toolkit and driver libraries (libcudart, libcublas, libnvrtc, libcuda,
# ...) are supplied by the consumer's CUDA install and are not bundled, so a
# miss on those is reported as "external" and does not fail.
#
# Resolution runs with LD_LIBRARY_PATH unset, so a stray path on the machine
# doing the check (for example the build tree) cannot hide a missing library.
set -euo pipefail

DIR="${1:?usage: verify_bundled_deps.sh <install-tree-or-extracted-tarball>}"
LIBDIR="${DIR}/lib"
EXTERNAL_RE='^lib(cu[A-Za-z0-9_]*|nv[A-Za-z0-9_-]*)\.so'

if [[ ! -d "${LIBDIR}" ]]; then
    echo "ERROR: ${LIBDIR} not found -- nothing to verify." >&2
    exit 1
fi

failures=0
checked=0
while IFS= read -r -d '' so; do
    # Skip anything that is not an ELF object (linker scripts, cmake files).
    [[ "$(head -c4 "${so}" | od -An -tx1 | tr -d ' \n')" == "7f454c46" ]] || continue
    checked=$((checked + 1))
    rel="${so#"${DIR}"/}"

    # ldd honours the library's own RUNPATH ($ORIGIN) and the system loader
    # config, which is what a consumer's process would do.
    missing="$(env -u LD_LIBRARY_PATH ldd "${so}" 2>&1 | awk '/not found/ {print $1}' | sort -u || true)"
    for lib in ${missing}; do
        if [[ "${lib}" =~ ${EXTERNAL_RE} ]]; then
            echo "  external (CUDA toolkit/driver): ${rel} needs ${lib}"
        else
            echo "ERROR: ${rel} needs ${lib}, which is not bundled in this package and is not a system library." >&2
            failures=$((failures + 1))
        fi
    done

    # A RUNPATH into a build or home directory only works on the build machine.
    runpath="$(readelf -d "${so}" 2>/dev/null | awk '/RPATH|RUNPATH/ {print}' | grep -oE '\[[^]]*\]' | tr -d '[]' || true)"
    IFS=':' read -ra entries <<< "${runpath}"
    for entry in "${entries[@]}"; do
        if [[ "${entry}" == /home/* || "${entry}" == /tmp/* || "${entry}" == *"/build"* ]]; then
            echo "ERROR: ${rel} has RUNPATH entry '${entry}', which points into a build tree." >&2
            failures=$((failures + 1))
        fi
    done
done < <(find "${LIBDIR}" -maxdepth 1 -type f -name '*.so*' -print0)

if (( checked == 0 )); then
    echo "ERROR: no ELF shared libraries found under ${LIBDIR}." >&2
    exit 1
fi
if (( failures > 0 )); then
    echo "ERROR: ${failures} bundled-dependency problem(s) in ${DIR} (${checked} libraries checked)." >&2
    exit 1
fi
echo "Bundled-dependency check passed: ${checked} libraries under ${LIBDIR} resolve without the build machine."
