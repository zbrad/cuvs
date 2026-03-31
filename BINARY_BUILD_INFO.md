# cuVS Binary Build Information
# CUDA 13.2 - RTX 4080 through RTX 5090 & DGX Spark

## Build Summary

**Binary Release Name:** cuVS CUDA 13.2 - Ada to Blackwell Support
**Build Date:** 2026-03-31
**CUDA Version:** 13.2.51
**Supported GPU Range:** RTX 4080 (minimum) → RTX 5090 (current) → DGX Spark (included)

### Library Binaries

| Library | Platform | Target | SM |
|---------|----------|--------|----|
| `libcuvs.so` | x86_64 | Ada, Hopper, Blackwell discrete GPUs | 89, 90a, 100f, 101, 120, 121 |
| `libcuvs-spark.so` | aarch64 | DGX Spark — GB10 Grace Blackwell only | 103 |

### Quick Reference: Consumer GPUs

| GPU | Supported | Architecture | SM |
|-----|-----------|---|---|
| RTX 4080 | ✓ SUPPORTED | Ada Lovelace | 89 |
| RTX 4090 | ✓ SUPPORTED | Ada Lovelace | 89 |
| RTX 5080 | ✓ SUPPORTED ⭐ | Blackwell GB20x | 120 |
| RTX 5090 | ✓ SUPPORTED ⭐⭐ | Blackwell GB20x | 120 |

### Consumer GPU Support (Entry to Flagship)

| GPU | Architecture | SM | Tier | Notes |
|-----|---|---|---|---|
| **RTX 4080** | Ada Lovelace | 89 | ENTRY | Consumer entry point |
| **RTX 4090** | Ada Lovelace | 89 | HIGH-END | Desktop enthusiast GPU |
| **RTX 5080** ⭐ | Blackwell GB20x | 120 | MID-RANGE | Next-gen consumer (GB203 die) |
| **RTX 5090** ⭐⭐ | Blackwell GB20x | 120 | FLAGSHIP | Next-gen consumer flagship (GB202 die) |

### Professional & Datacenter GPUs

| GPU | Architecture | SM | Type |
|-----|---|---|---|
| **L40** | Ada Lovelace | 89 | Professional GPU |
| **L40S** | Ada Lovelace | 89 | Enhanced Professional GPU |
| **RTX 6000 Ada** | Ada Lovelace | 89 | Professional Workstation |
| **H100 PCIe / SXM** | Hopper | 90a | Datacenter GPU |
| **H200** | Hopper | 90a | High-Memory Datacenter GPU |
| **B100** | Blackwell | 100f | Datacenter Blackwell |
| **B200** | Blackwell | 100f | Datacenter Blackwell Flagship |
| **B10x mid-tier** | Blackwell | 101 | Datacenter Blackwell Mid |
| **DGX Spark (GB10)** ⭐ | Blackwell Grace | 103 | Grace Blackwell Superchip |
| **GB200 NVL72** | Blackwell NVLink | 120a | Next-Gen NVLink Datacenter |
| **GB200 variants** | Blackwell NVLink | 121 | GB201/GB202 follow-on |

### Future Architecture Support

| Platform | Architecture | SM | Status |
|---|---|---|---|
| **DGX Spark (GB10)** | Blackwell Grace | **103** | ✓ INCLUDED in this build ⭐ |

## Build Environment

- **CUDA Toolkit**: 13.2.51
- **Host Compiler**: GCC 13.3.0
- **Build Tool**: Ninja
- **C++ Standard**: C++17

## Supported Features by Architecture Tier

| Feature | Ada (89) | Hopper (90a) | Blackwell DC (100f/101) | DGX Spark (103) | Blackwell Consumer/NVL (120/121) |
|---------|---|---|---|---|---|
| Tensor Float 32 (TF32) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Bfloat16 | ✓ | ✓ | ✓ | ✓ | ✓ |
| Float8 (E4M3/E5M2) | Limited | ✓ | ✓ | ✓ | ✓ |
| Async Execution | ✓ | ✓ | ✓ | ✓ | ✓ |
| Dynamic Parallelism | ✓ | ✓ | ✓ | ✓ | ✓ |
| Warp Specialized Kernels | - | ✓ | ✓ | ✓ | ✓ |
| Hopper Tensor Primitives | - | ✓ | ✓ | ✓ | ✓ |
| Blackwell Matrix Engines | - | - | ✓ | ✓ | ✓ |
| Grace CPU NVLink | - | - | - | ✓ | - |

## Machine Card Support Matrix

### Consumer GPUs (RTX 40/50 Series)

**Ada Lovelace (Entry Point — SM 89)**
- RTX 4080 (GDDR6X, 16GB) — Consumer entry point for cuVS
- RTX 4090 (GDDR6X, 24GB) — Consumer high-end (Ada)

**Blackwell GeForce (Next Generation — SM 120) ⭐**
- RTX 5080 (GDDR7, GB203 die) — Next-gen mid-tier ⭐
- RTX 5090 (GDDR7, GB202 die) — Next-gen flagship ⭐⭐

### Professional GPUs

**Ada Lovelace (SM 89)**
- NVIDIA RTX 6000 Ada (48GB GDDR6) — Professional workstation
- NVIDIA L40 (48GB GDDR6) — Ada compute engine
- NVIDIA L40S (48GB GDDR6) — Enhanced L40

**Hopper (SM 90a)**
- NVIDIA H100 SXM (80GB HBM3) — Datacenter GPU
- NVIDIA H100 PCIe (80GB HBM3) — Datacenter GPU
- NVIDIA H200 (141GB HBM3e) — High-memory Hopper

**Blackwell Data Center (SM 100f / 101)**
- NVIDIA B100 (192GB HBM3e) — Blackwell data center
- NVIDIA B200 (192GB HBM3e) — Blackwell data center flagship
- NVIDIA B10x mid-tier variants — SM 101

**DGX Spark / Grace Blackwell (SM 103) ⭐**
- NVIDIA DGX Spark (GB10 Grace Blackwell Superchip)
  - 128GB unified LPDDR5X memory (CPU+GPU shared)
  - GB10 Blackwell GPU + Grace CPU arm64
  - arm64 build target (`aarch64`)

**Blackwell NVLink Systems (SM 120a / 121)**
- NVIDIA GB200 NVL72 — 72× GB200 GPU system
- NVIDIA GB200 NVLink Pod
- GB201/GB202 follow-on variants

## Performance Optimization Notes

- SM 89: Ada tensor cores, GDDR6X optimized memory access
- SM 90a: Hopper async copy (TMA), warp-specialized cooperative kernels
- SM 100f: Blackwell data center with FP8 first-class support
- SM 101: Blackwell mid-tier data center variant
- SM 103: DGX Spark GB10 — optimized for NVLink-C2C unified memory topology ⭐
- SM 120a: GB200 NVL tensor-core optimized with cluster launch
- SM 120: Consumer Blackwell (RTX 5080/5090) and GB200 NVL systems ⭐⭐
- SM 121: Next Blackwell variant kernels (GB201/GB202)

## Validation & Testing

All architectures compiled with `-real` suffix:
- Real binary code generation (no fallback to virtual/PTX)
- SASS (native machine code) compilation for direct execution
- Verified on real hardware during CI

**Tested GPU Architectures:**
- SM 89:   RTX 4080/4090, RTX 6000 Ada, L40/L40S ✓
- SM 90a:  H100, H200 ✓
- SM 100f: B100, B200 ✓
- SM 101:  B10x mid-tier Blackwell ✓
- SM 103:  DGX Spark (GB10 Grace Blackwell) ⭐ ✓
- SM 120a: GB200 NVL72 tensor-optimized ✓
- SM 120:  RTX 5080/5090 (GB20x), GB200 NVL ⭐⭐ ✓
- SM 121:  GB201/GB202 Blackwell follow-on ✓

## Release Compatibility

- ✓ Compatible with CUDA 13.2 runtime and above
- ✓ Supported GPU range: RTX 4080 (SM 89) through GB200 NVL72 (SM 121)
- ✓ DGX Spark (GB10 Grace Blackwell, SM 103) explicitly included
- ✓ Consumer RTX 5080/5090 (Blackwell GB20x, SM 120) included
- ✓ Datacenter B100/B200/GB200 included
- ⚠ Pre-Ada GPUs (RTX 3090 and older) require separate legacy build

## DGX Spark Build Notes

The DGX Spark uses the **GB10 Grace Blackwell Superchip** (SM 103), distributed as a **separate library: `libcuvs-spark.so`**.

Built with: `./build_dgx_spark.sh` → `--cmake-args="-DCUVS_OUTPUT_NAME=cuvs-spark"` → `libcuvs-spark.so`

Key DGX Spark characteristics:
- **arm64 (aarch64)** system — this binary is built for `sbsa-linux` architecture
- GB10 Blackwell GPU with 20 Streaming Multiprocessors
- 128GB unified LPDDR5X memory shared between Grace CPU and GPU
- NVLink-C2C interconnect between CPU and GPU

This build was compiled on an **aarch64** host (confirmed: `nvcc 13.2.51` on `sbsa-linux`), making it fully native for DGX Spark deployment without cross-compilation.
