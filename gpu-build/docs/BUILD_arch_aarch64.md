# Building cuVS for aarch64 / NVIDIA DGX Spark

This guide builds the cuVS shared library for **aarch64** (ARM), targeting the
NVIDIA DGX Spark — GB10 Grace Blackwell Superchip, compute capability **SM 103**.

The aarch64 build is a single-arch build; the output filename carries the SM
suffix per the naming convention in [WHEEL_NAMING.md](WHEEL_NAMING.md):
`libcuvs-aarch64-cu132-sm103.so`.

See [BUILD_arch_x86_64.md](BUILD_arch_x86_64.md) for the x86_64 build.

---

## Prerequisites

- CUDA 13.2 toolkit for **aarch64 / sbsa-linux** (`/usr/local/cuda-13.2`, or
  set `CUDA_HOME`)
- Python 3 with development headers (for optional Python bindings)
- Build tools: CMake (>=3.30), Ninja, a C++20 compiler
- 8 GB+ free disk space

## Quick start

```bash
# aarch64 host only:
bash build_aarch64.sh
# produces: cpp/build/libcuvs-aarch64-cu132-sm103.so
```

To target a different CUDA version:

```bash
CUDA_VER=13.3 bash build_aarch64.sh
# produces: cpp/build/libcuvs-aarch64-cu133-sm103.so
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
| `libcuvs-aarch64-cu132-sm103.so` | `cpp/build/` | Single-arch, SM 103 (GB10 Grace Blackwell) |

The `cu132`/`sm103` portions track `CUDA_TAG` and `CUDA_ARCHS`. Because the DGX
Spark build always targets a single GPU arch, the filename carries the `-sm103`
suffix; see [WHEEL_NAMING.md](WHEEL_NAMING.md).

## Troubleshooting

**"CUDA not found" / version mismatch**
- Ensure the aarch64 CUDA toolkit is installed: `ls $CUDA_HOME/bin/nvcc`
- If `nvcc` reports a different version than `CUDA_VER`, set `CUDA_HOME` to the
  matching toolkit.

**Build runs out of memory**
- Reduce parallelism: `PARALLEL_LEVEL=4 bash build_aarch64.sh`

## Note for faiss consumers

The faiss aarch64 build (`zbrad/faiss gpu-cu/scripts/build_lib_aarch64.sh`)
expects the cuVS library from `${CUVS_DIR}`. Update the filename reference from
`libcuvs-spark.so` to `libcuvs-aarch64-cu${FAISS_CUDA_TAG}-sm103.so`.
