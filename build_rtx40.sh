#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# Backward-compatibility shim for build_rtx40.sh.
# The canonical script is now tuned/build.sh, consolidated with
# build_gb10.sh/build_rtx50.sh into one parameterized script -- see
# tuned/devices/rtx40.conf and gpu-build/docs/BUILD_rtx.md.
#
# This script will be removed in a future release.
# Please update any automation or documentation to call
# `tuned/build.sh rtx40` directly.
echo "NOTICE: build_rtx40.sh is deprecated. Use 'tuned/build.sh rtx40' instead." >&2
exec "$(cd "$(dirname "$0")"; pwd)/tuned/build.sh" rtx40 "$@"
