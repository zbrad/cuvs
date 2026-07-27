#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# Backward-compatibility shim for build_gb10.sh.
# The canonical script is now tuned/build.sh, consolidated with
# build_rtx40.sh/build_rtx50.sh into one parameterized script -- see
# tuned/devices/gb10.conf and gpu-build/docs/BUILD_gb10.md.
#
# This script will be removed in a future release.
# Please update any automation or documentation to call
# `tuned/build.sh gb10` directly.
echo "NOTICE: build_gb10.sh is deprecated. Use 'tuned/build.sh gb10' instead." >&2
exec "$(cd "$(dirname "$0")"; pwd)/tuned/build.sh" gb10 "$@"
