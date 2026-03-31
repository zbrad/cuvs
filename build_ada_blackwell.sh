#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# cuVS Build Script for RTX 4080 through RTX 5090 & DGX Spark
# CUDA 13.2 Optimized Build
#
# Supported GPU Architectures and Target Cards:
#
# Ada Lovelace Generation (89):
#   - 89: RTX 4080, RTX 4090, RTX 6000 Ada, L40, L40S
#        [CONSUMER ENTRY POINT: RTX 4080 #####]
#
# Hopper Generation (90):
#   - 90: H100 PCIe, H100 SXM, H200
#
# Blackwell Data Center Generation (100, 100f, 101):
#   - 100:  B100, B200 (data center Blackwell flagship)
#   - 100f: B100/B200 with FP8 optimizations (RAPIDS default for CUDA 13.x)
#   - 101:  Blackwell B10x variant (mid-tier data center)
#
# DGX Spark Generation (103):
#   - 103: GB10 Grace Blackwell Superchip — NVIDIA DGX Spark [#####]
#          (compact Blackwell GPU paired with Grace CPU arm64)
#
# Blackwell Consumer / GB200 NVLink Generation (120, 120a, 121):
#   - 120:  RTX 5080, RTX 5090 (consumer GB20x Blackwell) [#####]
#            GB200 NVL72, GB200 NVLink systems (data center)
#   - 120a: GB200 tensor-core optimized variant
#   - 121:  Next blackwell variant (GB201/GB202 follow-on)
#
# Build Information:
#   CUDA Version: 13.2
#   Architectures: 89-real; 90a-real; 100f-real; 103-real; 120a-real; 120

set -e

REPODIR=$(cd "$(dirname "$0")"; pwd)

echo "===================================================="
echo "cuVS Build: RTX 4080 → 5090 & DGX Spark Support"
echo "===================================================="
echo ""
echo "Consumer GPU Support:"
echo "  [ENTRY]   - Ada Lovelace (89-real):  RTX 4080, RTX 4090"
echo "  [NEXT-GEN]- Blackwell    (120):      RTX 5080, RTX 5090 ⭐⭐"
echo ""
echo "Datacenter & Professional:"
echo "  - Hopper        (90a-real):  H100 PCIe, H100 SXM, H200"
echo "  - Blackwell     (100f-real): B100, B200"
echo "  - Blackwell     (101-real):  B10x mid-tier data center"
echo "  - DGX Spark     (103-real):  GB10 Grace Blackwell ⭐"
echo "  - Blackwell NVL (120a-real): GB200 Tensor optimized"
echo "  - Blackwell NVL (120):       GB200 NVL72, RTX 5080/5090"
echo "  - Blackwell NVL (121-real):  GB201/GB202 follow-on variants"
echo ""
echo "CUDA Version: 13.2.51"
echo "Build Type: Release"
echo ""

# Clean previous build
echo "Cleaning previous build artifacts..."
cd "$REPODIR"
./build.sh clean

# Build for Ada through Blackwell architectures
echo "Starting libcuvs build for Ada-Blackwell architectures..."
echo ""

./build.sh libcuvs \
  --gpu-arch="89-real;90a-real;100f-real;101-real;103-real;120a-real;120;121-real" \
  -v

echo ""
echo "===================================================="
echo "Build Complete!"
echo "===================================================="
echo ""
echo "Consumer support:"
echo "  ✓ RTX 4080/4090  (Ada,       SM  89)"
echo "  ✓ RTX 5080/5090  (Blackwell, SM 120) ⭐⭐"
echo ""
echo "Datacenter support:"
echo "  ✓ H100, H200     (Hopper,    SM  90a)"
echo "  ✓ B100, B200     (Blackwell, SM 100f)"
echo "  ✓ B10x mid-tier  (Blackwell, SM 101)"
echo "  ✓ DGX Spark GB10 (Blackwell, SM 103) ⭐"
echo "  ✓ GB200 NVL72    (Blackwell, SM 120a/121)"
echo ""
