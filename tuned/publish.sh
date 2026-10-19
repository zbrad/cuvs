#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# tuned/publish.sh <variant> — publish the GitHub release that tuned/release.sh's gates approved. It publishes
# only what those gates saw: the ready-marker records HEAD, the release notes and each asset with its sha256,
# and gpu_tuned_publish_ready refuses if any of them changed since. With no marker (release.sh never passed,
# or was re-run and failed) or a spent one (already published), it refuses. Nothing else publishes.
#
# Usage:
#   bash tuned/release.sh gb10 && bash tuned/publish.sh gb10
set -uo pipefail

REPODIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPU_TUNED_ARG_VARIANT="${1:?usage: bash tuned/publish.sh <variant>}"

# shellcheck source=env.sh
source "${REPODIR}/tuned/env.sh" "${GPU_TUNED_ARG_VARIANT}" || exit 1
cd "${REPODIR}" || exit 1

MARKER="$(gpu_tuned_out_dir releases "${REPODIR}" "${CUDA_TAG}")/RELEASE_READY_${GPU_TUNED_VARIANT}"
gpu_tuned_publish_ready "${MARKER}" || exit 1
echo "Release: https://github.com/$(sed -n 's/^repo=//p' "${MARKER}.published")/releases/tag/$(sed -n 's/^tag=//p' "${MARKER}.published")"
