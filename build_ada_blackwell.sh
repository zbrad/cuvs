#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

# Backward-compatibility shim for build_ada_blackwell.sh.
#
# The single x86_64 multi-arch build this script used to redirect to
# (build_x86_64.sh) has been split into two single-arch, GPU-codename-named
# builds -- build_rtx40.sh (Ada Lovelace, RTX 4080/4090) and build_rtx50.sh
# (Blackwell, RTX 5080/5090) -- and no longer bundles datacenter archs
# (Hopper/Blackwell-DC/GB200); see gpu-build/docs/WHEEL_NAMING.md. There is
# no single correct target to redirect to, so this errors instead of
# silently picking one generation.
echo "ERROR: build_ada_blackwell.sh is removed." >&2
echo "  The Ada+Blackwell fat binary was split by generation:" >&2
echo "    Ada Lovelace (RTX 4080/4090) -> ./build_rtx40.sh" >&2
echo "    Blackwell    (RTX 5080/5090) -> ./build_rtx50.sh" >&2
echo "  Run the script matching your GPU directly." >&2
exit 1
