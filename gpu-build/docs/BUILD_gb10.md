# Building cuVS for GB10 / NVIDIA DGX Spark

This guide builds the cuVS shared library for the NVIDIA DGX Spark — GB10
Grace Blackwell Superchip, compute capability **SM 121** (confirmed via
`torch` `device_capability` on real hardware).

The GB10 build is a single-arch (aarch64, SM 121) build named by GPU codename
per [WHEEL_NAMING.md](WHEEL_NAMING.md): `libcuvs-gb10-cu132.so`.

See [BUILD_rtx.md](BUILD_rtx.md) for the RTX 40 / RTX 50 (x86_64) builds.

---

## Prerequisites

- CUDA 13.2 toolkit for **aarch64 / sbsa-linux** (`/usr/local/cuda-13.2`, or
  set `CUDA_HOME`)
- Python 3 with development headers (for optional Python bindings)
- Build tools: CMake (>=3.30), Ninja, a C++20 compiler
- 8 GB+ free disk space

## Quick start

```bash
bash build_gb10.sh
# produces: cpp/build/libcuvs-gb10-cu132.so
```

To target a different CUDA version:

```bash
CUDA_VER=13.3 bash build_gb10.sh
# produces: cpp/build/libcuvs-gb10-cu133.so
```

## CUDA version selection

The CUDA version is a single input shared via `scripts/cuda_env.sh`.
Specify either variable; the other is derived:

| Variable | Example | Derived |
|----------|---------|--------|
| `CUDA_VER` | `13.3` | `CUDA_TAG=cu133` |
| `CUDA_TAG` | `cu133` | `CUDA_VER=13.3` |

On a host with multiple toolkits, `CUDA_HOME` auto-resolves to
`/usr/local/cuda-<CUDA_VER>`. Override `CUDA_HOME` to force a path. See
[WHEEL_NAMING.md](WHEEL_NAMING.md) for the full version/naming scheme.

## Build output

| Artifact | Location | Notes |
|----------|----------|-------|
| `libcuvs-gb10-cu132.so` | `cpp/build/` | Single-arch, SM 121 (GB10 Grace Blackwell) |

The `cu132` portion tracks `CUDA_TAG`; `CUDA_ARCHS` is fixed at `121-real`
since GB10 is the only chip this build targets.

## Troubleshooting

**"CUDA not found" / version mismatch**
- Ensure the aarch64 CUDA toolkit is installed: `ls $CUDA_HOME/bin/nvcc`
- If `nvcc` reports a different version than `CUDA_VER`, set `CUDA_HOME` to the
  matching toolkit.

**Build runs out of memory**
- Reduce parallelism: `PARALLEL_LEVEL=4 bash build_gb10.sh`

## Note for faiss consumers

`zbrad/faiss gpu-cu/scripts/build_lib_gb10.sh` expects
`libcuvs-gb10-${FAISS_CUDA_TAG}.so` from `${CUVS_DIR}` and suggests
`./build_gb10.sh` in its error messages.
