# cuVS Binary Build Information
# CUDA 13.2 - RTX 40, RTX 50 & DGX Spark (GB10)

## Build Summary

**Binary Release Name:** cuVS CUDA 13.2 - RTX40/RTX50/GB10
**Build Date:** 2026-03-31
**CUDA Version:** 13.2.51
**Supported GPU Range:** RTX 4080/4090 (RTX 40), RTX 5080/5090 (RTX 50), DGX Spark (GB10)

Builds are single-arch and named by GPU codename (not CPU arch or SM number),
mirroring zbrad/vllm's `native-builds` branch convention (originally
established on that repo's `gb10` branch, since renamed). Datacenter/professional
architectures (Hopper, Blackwell DC, GB200, and Ada professional parts like
L40/L40S/RTX 6000 Ada) are intentionally **not** built here — this repo only
targets owned/verified consumer + DGX Spark hardware. See
`gpu-build/docs/WHEEL_NAMING.md` for the full rationale and naming rules.

### Library Binaries

| Library | Platform | Target | SM | Build script |
|---------|----------|--------|----|--------------|
| `libcuvs-rtx40-cu132.so` | x86_64 | RTX 4080, RTX 4090 (Ada Lovelace) | 89 | `tuned/build.sh rtx40` |
| `libcuvs-rtx50-cu132.so` | x86_64 | RTX 5080, RTX 5090 (Blackwell) | 120 | `tuned/build.sh rtx50` |
| `libcuvs-gb10-cu132.so` | aarch64 | DGX Spark — GB10 Grace Blackwell | 121 | `tuned/build.sh gb10` |

Root-level `build_gb10.sh`/`build_rtx40.sh`/`build_rtx50.sh` are deprecation
shims that exec the above; see "Deprecated script names" below.

**Naming rules:**
- GPU codename (`gb10` / `rtx40` / `rtx50`) is in the library filename; CPU
  arch and SM number are not, since each codename implies exactly one of each.
- CUDA version (`cu132`) is derived from the single knob in `tuned/env.sh`.
- Every build here is single-arch, compiled `-real` (native SASS, no PTX/JIT
  fallback).
- The build directory (`cpp/build/`) is version-agnostic; no CUDA version in the path.

### Consumer GPU Support

| GPU | Codename | Architecture | SM |
|-----|----------|---------------|----|
| RTX 4080 | rtx40 | Ada Lovelace | 89 |
| RTX 4090 | rtx40 | Ada Lovelace | 89 |
| RTX 5080 | rtx50 | Blackwell GB20x | 120 |
| RTX 5090 | rtx50 | Blackwell GB20x | 120 |
| DGX Spark (GB10) | gb10 | Blackwell Grace | 121 |

## Build Environment

- **CUDA Toolkit**: 13.2.51
- **Host Compiler**: GCC 13.3.0
- **Build Tool**: Ninja
- **C++ Standard**: C++17

## Supported Features by Architecture

| Feature | RTX 40 / Ada (89) | RTX 50 / Blackwell (120) | GB10 / Blackwell Grace (121) |
|---------|---|---|---|
| Tensor Float 32 (TF32) | ✓ | ✓ | ✓ |
| Bfloat16 | ✓ | ✓ | ✓ |
| Float8 (E4M3/E5M2) | Limited | ✓ | ✓ |
| Async Execution | ✓ | ✓ | ✓ |
| Dynamic Parallelism | ✓ | ✓ | ✓ |
| Blackwell Matrix Engines | - | ✓ | ✓ |
| Grace CPU NVLink-C2C | - | - | ✓ |

## Machine Card Support Matrix

**RTX 40 / Ada Lovelace (SM 89)**
- RTX 4080 (GDDR6X, 16GB)
- RTX 4090 (GDDR6X, 24GB)

**RTX 50 / Blackwell (SM 120)**
- RTX 5080 (GDDR7, GB203 die)
- RTX 5090 (GDDR7, GB202 die)

**GB10 / Grace Blackwell (SM 121)**
- NVIDIA DGX Spark (GB10 Grace Blackwell Superchip)
  - 128GB unified LPDDR5X memory (CPU+GPU shared)
  - GB10 Blackwell GPU + Grace CPU, aarch64 build target
  - NVLink-C2C interconnect between CPU and GPU

## Validation & Testing

All architectures compiled with `-real` (native SASS, no PTX/JIT fallback).

**Tested GPU Architectures:**
- SM 89:  RTX 4080/4090 ✓
- SM 120: RTX 5080/5090 ✓
- SM 121: DGX Spark (GB10 Grace Blackwell) ✓

## Release Compatibility

- ✓ Compatible with CUDA 13.2 runtime and above
- ✓ RTX 4080/4090 (SM 89), RTX 5080/5090 (SM 120), DGX Spark GB10 (SM 121)
- ⚠ Pre-Ada GPUs (RTX 3090 and older) require a separate legacy build
- ⚠ Datacenter/professional GPUs (H100/H200, B100/B200, GB200, L40/L40S,
  RTX 6000 Ada) are not built by this repo

## GB10 Build Notes

The DGX Spark uses the **GB10 Grace Blackwell Superchip** (SM 121, confirmed
via `torch` `device_capability` on real hardware), distributed as a
**separate aarch64 library: `libcuvs-gb10-cu132.so`**.

Built with:
```
bash tuned/build.sh gb10
  # CUDA_VER=13.2, CUDA_ARCHS="121a-real" (single-arch, Blackwell family-specific)
  # -DCUVS_OUTPUT_NAME=cuvs-gb10-cu132
  # Output: cpp/build/libcuvs-gb10-cu132.so
```

Key DGX Spark characteristics:
- **arm64 (aarch64)** system — this binary is built for `sbsa-linux` architecture
- GB10 Blackwell GPU
- 128GB unified LPDDR5X memory shared between Grace CPU and GPU
- NVLink-C2C interconnect between CPU and GPU

### Deprecated script names

| Old script | New script | Note |
|------------|------------|------|
| `build_dgx_spark.sh` | `tuned/build.sh gb10` | Shim retained for backward compat |
| `build_gb10.sh` | `tuned/build.sh gb10` | Shim retained for backward compat (consolidated into tuned/build.sh alongside rtx40/rtx50) |
| `build_rtx40.sh` | `tuned/build.sh rtx40` | Shim retained for backward compat |
| `build_rtx50.sh` | `tuned/build.sh rtx50` | Shim retained for backward compat |
| `build_ada_blackwell.sh` | `tuned/build.sh rtx40` / `tuned/build.sh rtx50` | **Removed, not shimmed** — the old fat binary split into two generations; errors with guidance instead of guessing which one you want |
| `build_aarch64.sh` (never released) | `tuned/build.sh gb10` | Superseded before shipping |
| `build_x86_64.sh` (never released) | `tuned/build.sh rtx40` / `tuned/build.sh rtx50` | Superseded before shipping |
