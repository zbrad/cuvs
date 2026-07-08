# cuVS Binary Build Information
# CUDA 13.2 - DGX Spark (GB10)

## Build Summary

**Binary Release Name:** cuVS CUDA 13.2 - GB10
**Build Date:** 2026-03-31
**CUDA Version:** 13.2.51
**Supported GPU Range:** DGX Spark (GB10)

Builds are single-arch and named by GPU codename (not CPU arch or SM number),
mirroring zbrad/vllm's `gb10` branch convention. Datacenter/professional
architectures (Hopper, Blackwell DC, GB200, and Ada professional parts like
L40/L40S/RTX 6000 Ada) are intentionally **not** built here — this repo only
targets owned/verified hardware. See `gpu-build/docs/WHEEL_NAMING.md` for the
full rationale and naming rules. A separate `rtx` branch adds RTX 40/RTX 50
(x86_64 consumer GPU) builds on top of this one.

### Library Binaries

| Library | Platform | Target | SM | Build script |
|---------|----------|--------|----|--------------|
| `libcuvs-gb10-cu132.so` | aarch64 | DGX Spark — GB10 Grace Blackwell | 121 | `build_gb10.sh` |

**Naming rules:**
- GPU codename (`gb10`) is in the library filename; CPU arch and SM number
  are not, since the codename implies exactly one of each.
- CUDA version (`cu132`) is derived from the single knob in `scripts/cuda_env.sh`.
- The build is single-arch, compiled `-real` (native SASS, no PTX/JIT
  fallback).
- The build directory (`cpp/build/`) is version-agnostic; no CUDA version in the path.

## Build Environment

- **CUDA Toolkit**: 13.2.51
- **Host Compiler**: GCC 13.3.0
- **Build Tool**: Ninja
- **C++ Standard**: C++17

## Supported Features by Architecture

| Feature | GB10 / Blackwell Grace (121) |
|---------|---|
| Tensor Float 32 (TF32) | ✓ |
| Bfloat16 | ✓ |
| Float8 (E4M3/E5M2) | ✓ |
| Async Execution | ✓ |
| Dynamic Parallelism | ✓ |
| Blackwell Matrix Engines | ✓ |
| Grace CPU NVLink-C2C | ✓ |

## Machine Card Support Matrix

**GB10 / Grace Blackwell (SM 121)**
- NVIDIA DGX Spark (GB10 Grace Blackwell Superchip)
  - 128GB unified LPDDR5X memory (CPU+GPU shared)
  - GB10 Blackwell GPU + Grace CPU, aarch64 build target
  - NVLink-C2C interconnect between CPU and GPU

## Validation & Testing

Compiled with `-real` (native SASS, no PTX/JIT fallback).

**Tested GPU Architectures:**
- SM 121: DGX Spark (GB10 Grace Blackwell) ✓ — verified end-to-end on real
  hardware at both CUDA 13.2 and CUDA 13.3.

## Release Compatibility

- ✓ Compatible with CUDA 13.2 runtime and above
- ✓ DGX Spark GB10 (SM 121)
- ⚠ Datacenter/professional GPUs (H100/H200, B100/B200, GB200, L40/L40S,
  RTX 6000 Ada) are not built by this repo
- See the `rtx` branch for RTX 40/RTX 50 (x86_64 consumer GPU) support

## GB10 Build Notes

The DGX Spark uses the **GB10 Grace Blackwell Superchip** (SM 121, confirmed
via `torch` `device_capability` on real hardware), distributed as a
**separate aarch64 library: `libcuvs-gb10-cu132.so`**.

Built with:
```
bash build_gb10.sh
  # CUDA_VER=13.2, CUDA_ARCHS="121-real" (single-arch)
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
| `build_dgx_spark.sh` | `build_gb10.sh` | Shim retained for backward compat |
| `build_aarch64.sh` (never released) | `build_gb10.sh` | Superseded before shipping |
