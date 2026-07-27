#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# Backward-compatibility shim for build_dgx_spark.sh.
# The canonical script is now tuned/build.sh, following the GPU-codename
# naming convention in gpu-build/docs/WHEEL_NAMING.md.
#
# This script will be removed in a future release.
# Please update any automation or documentation to call
# `tuned/build.sh gb10` directly.
echo "NOTICE: build_dgx_spark.sh is deprecated. Use 'tuned/build.sh gb10' instead." >&2
exec "$(cd "$(dirname "$0")"; pwd)/tuned/build.sh" gb10 "$@"
