# Building cuVS for RTX 40 / RTX 50 (x86_64)

This guide builds the cuVS shared library for consumer x86_64 GPUs, as two
separate single-arch builds by generation:

- **RTX 40** (Ada Lovelace, SM 89) — RTX 4080, RTX 4090 — `tuned/build.sh rtx40`
- **RTX 50** (Blackwell, SM 120) — RTX 5080, RTX 5090 — `tuned/build.sh rtx50`

Each is single-arch, named by GPU codename per
[WHEEL_NAMING.md](WHEEL_NAMING.md): `libcuvs-rtx40-cu132.so` /
`libcuvs-rtx50-cu132.so`. Datacenter/professional architectures (Hopper,
Blackwell DC, GB200, Ada professional parts) are intentionally not built —
see WHEEL_NAMING.md's guiding principles for why.

See [BUILD_gb10.md](BUILD_gb10.md) for the aarch64 / DGX Spark build.

---

## Prerequisites

- CUDA 13.2 toolkit for **x86_64** (`/usr/local/cuda-13.2`, or set `CUDA_HOME`)
- Build tools: CMake (>=3.30), Ninja, a C++20 compiler
- 2 GB+ free disk space (single-arch builds, no fat binary)

## Quick start

```bash
bash tuned/build.sh rtx40
# produces: cpp/build/libcuvs-rtx40-cu132.so

bash tuned/build.sh rtx50
# produces: cpp/build/libcuvs-rtx50-cu132.so
```

To target a different CUDA version:

```bash
CUDA_VER=13.3 bash tuned/build.sh rtx40
# produces: cpp/build/libcuvs-rtx40-cu133.so
```

## CUDA version selection

The CUDA version is a single input shared via `tuned/env.sh`.
Specify either variable; the other is derived:

| Variable | Example | Derived |
|----------|---------|--------|
| `CUDA_VER` | `13.3` | `CUDA_TAG=cu133` |
| `CUDA_TAG` | `cu133` | `CUDA_VER=13.3` |

On a host with multiple toolkits, `CUDA_HOME` auto-resolves to
`/usr/local/cuda-<CUDA_VER>`. See [WHEEL_NAMING.md](WHEEL_NAMING.md) for the
full version/naming scheme.

## Supported GPU architectures

| Codename | SM | Target GPUs | Script |
|----------|----|-------------|--------|
| rtx40 | 89-real | RTX 4080, RTX 4090 | `tuned/build.sh rtx40` |
| rtx50 | 120a-real | RTX 5080, RTX 5090 | `tuned/build.sh rtx50` |

## Build output

| Artifact | Location | Notes |
|----------|----------|-------|
| `libcuvs-rtx40-cu132.so` | `cpp/build/` | Single-arch, SM 89 |
| `libcuvs-rtx50-cu132.so` | `cpp/build/` | Single-arch, SM 120a (Blackwell family-specific) |

## Troubleshooting

**"CUDA not found" / version mismatch**
- Ensure the x86_64 CUDA toolkit is installed: `ls $CUDA_HOME/bin/nvcc`
- If `nvcc` reports a different version than `CUDA_VER`, set `CUDA_HOME`.

**Wrong GPU / script mismatch**
- Each variant targets exactly one architecture; there's no combined build.
  Run `tuned/build.sh rtx40` on Ada hardware, `tuned/build.sh rtx50` on
  Blackwell hardware, or build both if you need to distribute for both
  generations.
