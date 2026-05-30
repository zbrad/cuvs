# cuVS GPU Build — Naming Convention

_Last updated: 2026-05-30_

This document records the naming/versioning conventions for cuVS GPU libraries
and build scripts. It mirrors the conventions established in
[zbrad/faiss `gpu-cu/docs/WHEEL_NAMING.md`](https://github.com/zbrad/faiss/blob/faiss-gpu-cu132/gpu-cu/docs/WHEEL_NAMING.md),
adapted for the cuVS C++ shared library (which is not distributed as a Python
wheel from this repo).

---

## Guiding principles

1. **Single CUDA-version knob** — one sourced env file (`scripts/cuda_env.sh`)
   defines `CUDA_VER` (e.g. `13.2`) and `CUDA_TAG` (e.g. `cu132`). Specify
   either at build time; the other is derived. Changing the CUDA version needs no
   script or path renames.

2. **Version-agnostic build dir** — the build directory (`cpp/build/`) does not
   embed the CUDA version. Libraries with different CUDA versions should be
   stored and deployed separately by the consumer.

3. **CPU arch in filename, not in package name** — `x86_64` or `aarch64`
   appears in the `.so` filename to allow both variants to coexist in the same
   directory. For Python wheels (future), the CPU arch is carried by the
   `manylinux` platform tag, not the package name.

4. **Arch/SM-based library naming** — a single-GPU-arch build appends
   `-sm<arch>` to the filename; a multi-arch build omits it:

   | Build scenario | Filename |
   |----------------|----------|
   | x86_64, multi-arch | `libcuvs-x86_64-cu132.so` |
   | aarch64, single-arch (SM 103, DGX Spark) | `libcuvs-aarch64-cu132-sm103.so` |

5. **Build scripts named by CPU arch** — `build_aarch64.sh` /
   `build_x86_64.sh`, mirroring the faiss pattern
   (`build_lib_aarch64.sh` / `build_lib_x86_64.sh`).

---

## Library naming table

| Build | Script | CUDA_ARCHS | Output library | Notes |
|-------|--------|------------|----------------|-------|
| x86_64, multi-arch (default) | `build_x86_64.sh` | `89-real;90a-real;…;121-real` | `libcuvs-x86_64-cu132.so` | No -sm suffix (multi-arch) |
| aarch64 / DGX Spark (SM 103) | `build_aarch64.sh` | `103-real` | `libcuvs-aarch64-cu132-sm103.so` | -sm103 suffix (single-arch) |

The `cu132` portion tracks `CUDA_TAG`; bump `CUDA_VER` in `scripts/cuda_env.sh`
(or pass it at the command line) and all names update automatically.

---

## Selecting / bumping the CUDA version

Specify it **per build** — no file edits needed:

```bash
# aarch64 / DGX Spark, CUDA 13.3 → libcuvs-aarch64-cu133-sm103.so
CUDA_VER=13.3 bash build_aarch64.sh

# x86_64 multi-arch, CUDA 13.3 → libcuvs-x86_64-cu133.so
CUDA_VER=13.3 bash build_x86_64.sh

# Tag form (equivalent)
CUDA_TAG=cu133 bash build_aarch64.sh
```

To change the **default**, edit `CUDA_VER` in `scripts/cuda_env.sh`.

**Multi-toolkit hosts.** When `CUDA_HOME` is not set, `cuda_env.sh` resolves it
to `/usr/local/cuda-<CUDA_VER>` if that directory exists (falling back to
`/usr/local/cuda`). If the `nvcc` on `PATH` reports a different version a
warning is printed.

---

## Downstream: faiss `gpu-cu/` build

The faiss aarch64 build (`zbrad/faiss gpu-cu/scripts/build_lib_aarch64.sh`)
currently expects `libcuvs-spark.so` from this repo's `cpp/build/`. After this
PR merges the library name changes to `libcuvs-aarch64-cu132-sm103.so`.

Required update in faiss:

| File | Old reference | New reference |
|------|--------------|---------------|
| `gpu-cu/scripts/build_lib_aarch64.sh` | `libcuvs-spark.so` | `libcuvs-aarch64-cu${FAISS_CUDA_TAG}-sm103.so` |
| `gpu-cu/scripts/build_pkg_aarch64.sh` | `libcuvs-spark.so` | `libcuvs-aarch64-cu${FAISS_CUDA_TAG}-sm103.so` |
| `gpu-cu/docs/BUILD_arch_aarch64.md` | `libcuvs-spark.so`, `./build_dgx_spark.sh` | updated names |
