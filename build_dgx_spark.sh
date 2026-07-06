#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# Backward-compatibility shim for build_dgx_spark.sh.
# The canonical script is now build_gb10.sh, following the GPU-codename
# naming convention in gpu-build/docs/WHEEL_NAMING.md.
#
# This script will be removed in a future release.
# Please update any automation or documentation to call build_gb10.sh directly.
echo "NOTICE: build_dgx_spark.sh is deprecated. Use ./build_gb10.sh instead." >&2
exec "$(cd "$(dirname "$0")"; pwd)/build_gb10.sh" "$@"
