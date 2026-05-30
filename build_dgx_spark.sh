#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# Backward-compatibility shim for build_dgx_spark.sh.
# The canonical script is now build_aarch64.sh, following the CPU-arch
# naming convention from zbrad/faiss gpu-cu/docs/WHEEL_NAMING.md.
#
# This script will be removed in a future release.
# Please update any automation or documentation to call build_aarch64.sh directly.
echo "NOTICE: build_dgx_spark.sh is deprecated. Use ./build_aarch64.sh instead." >&2
exec "$(cd "$(dirname "$0")"; pwd)/build_aarch64.sh" "$@"
