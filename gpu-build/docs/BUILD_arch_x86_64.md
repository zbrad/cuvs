# Building cuVS for x86_64 — Ada through Blackwell

This guide builds the cuVS shared library for **x86_64**, covering Ada Lovelace
through Blackwell GPU families (RTX 4080 → RTX 5090, H100, B100/B200, GB200).

The x86_64 build is a multi-arch build; the output filename has no SM suffix
per the naming convention in [WHEEL_NAMING.md](WHEEL_NAMING.md):
`libcuvs-x86_64-cu132.so`.

See [BUILD_arch_aarch64.md](BUILD_arch_aarch64.md) for the aarch64 / DGX Spark
build.

---

## Prerequisites

- CUDA 13.2 toolkit for **x86_64** (`/usr/local/cuda-13.2`, or set `CUDA_HOME`)
- Build tools: CMake (>=3.30), Ninja, a C++20 compiler
- 8 GB+ free disk space (multi-arch fat binary is large)

## Quick start

```bash
bash build_x86_64.sh
# produces: cpp/build/libcuvs-x86_64-cu132.so
```

To target a different CUDA version:

```bash
CUDA_VER=13.3 bash build_x86_64.sh
# produces: cpp/build/libcuvs-x86_64-cu133.so
```

## CUDA version selection

The CUDA version is a single input shared via `scripts/cuda_env.sh`.
Specify either variable; the other is derived:

| Variable | Example | Derived |
|----------|---------|--------|
| `CUDA_VER` | `13.3` | `CUDA_TAG=cu133` |
| `CUDA_TAG` | `cu133` | `CUDA_VER=13.3` |

On a host with multiple toolkits, `CUDA_HOME` auto-resolves to
`/usr/local/cuda-<CUDA_VER>`. See [WHEEL_NAMING.md](WHEEL_NAMING.md) for the
full version/naming scheme.

## Supported GPU architectures

| Architecture | SM | Target GPUs |
|---|---|---|
| Ada Lovelace | 89-real | RTX 4080, RTX 4090, RTX 6000 Ada, L40, L40S |
| Hopper | 90a-real | H100 PCIe/SXM, H200 |
| Blackwell DC | 100f-real | B100, B200 |
| Blackwell DC | 101-real | B10x mid-tier |
| DGX Spark | 103-real | GB10 Grace Blackwell |
| Blackwell NVL | 120a-real | GB200 NVL72 tensor-optimized |
| Blackwell | 120 | RTX 5080, RTX 5090, GB200 NVL |
| Blackwell NVL | 121-real | GB201/GB202 follow-on |

## Build output

| Artifact | Location | Notes |
|----------|----------|-------|
| `libcuvs-x86_64-cu132.so` | `cpp/build/` | Multi-arch, no -sm suffix |

## Troubleshooting

**"CUDA not found" / version mismatch**
- Ensure the x86_64 CUDA toolkit is installed: `ls $CUDA_HOME/bin/nvcc`
- If `nvcc` reports a different version than `CUDA_VER`, set `CUDA_HOME`.

**Build runs out of memory**
- Multi-arch builds are large. Reduce parallelism: `PARALLEL_LEVEL=4 bash build_x86_64.sh`
- Ensure at least 8 GB free disk space.
