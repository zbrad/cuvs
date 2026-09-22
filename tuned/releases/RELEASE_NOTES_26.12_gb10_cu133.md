# cuVS 26.12 — GB10 / DGX Spark Release Notes (CUDA 13.3)

**Release Date**: 2026-09-22
**Package**: `libcuvs-26.12-gb10-cu133-g1c38fcf18.tar.gz`
**Platform**: aarch64
**GPU Architecture**: SM_121a (GB10 / DGX Spark, Grace Blackwell)
**CUDA Toolkit**: 13.3.73 (CCCL 3.5.0)
**Commit**: `1c38fcf18`

## Overview

The 26.12 source line of cuVS built against CUDA 13.3, single-arch for
`sm_121a`, as `libcuvs-gb10-cu133.so`. It links the published RAFT release
`v26.12-gb10-cu133-g9fcf3a1f` (see "Depends on RAFT" below) and bundles
`kvikio`, which cuVS's own install does not ship.

**Upstream base.** This is a development build: `tuned-builds` is merged with
upstream `NVIDIA/cuvs` `main` as of `411d4129d` (2026-09-21), version 26.12.00, which
upstream has not tagged. Upstream's latest tagged release is `v26.08.01`; its
`release/26.10` branch exists but is not yet tagged. Every fork-only change is
listed in `tuned/docs/FORK_PATCHES.md`.

**Changes relative to upstream** (everything else is upstream's code):
- **sm_121 cuTile smoke-test fragment.** GB10 rejects the `sm_120` cubin as
  forward-compatible, so we add a `cutile_arch_12_1` tag, an `sm_121` entry in
  the cuTile *smoke-test* matrix, and a `CutileSmoke` canary that turns the
  driver's missing JIT compiler into a skip. Submitted upstream as
  [`NVIDIA/cuvs#2568`](https://github.com/NVIDIA/cuvs/pull/2568), still open.
  This does **not** add `sm_121` to the production cuTile top-1 nearest-neighbor
  kernels: their matrix (`fused_1nn_cutile_matrix.json`) is identical to
  upstream's and has no `sm_121` entry.
- **`NNTest` skip guard** in `cpp/tests/neighbors/distance_nn.cu`: an
  `IsSkipped()` check so upstream's `GTEST_SKIP()` in a helper actually skips
  the test. Reported upstream as
  [`NVIDIA/cuvs#2660`](https://github.com/NVIDIA/cuvs/issues/2660), open.
- **`CUVS_OUTPUT_NAME`** CMake option so the library is named
  `libcuvs-gb10-cu133.so`.
- **Regression test** `REGRESSION_TEST` for the `warpReduce`/`add_op`
  ambiguity, with a write-up in `docs/fixes/`. The fix itself is already
  upstream; the test guards against it regressing.
- **Build-config fixes in the C tests:** `MG_C_TEST` is only configured when
  `BUILD_MG_ALGOS` is on, and the C header check uses the right source root.
- **Repository files:** `.gitattributes` (LF line endings) and `.gitignore`.
- **`tuned/` build, test, package and release tooling.**

The **Driver Context** section records which NVIDIA drivers exist for GB10 and
what is and is not known about their memory behavior; the cuTile tests in this
release are skipped because of the driver (see "Test Skips").

## Depends on RAFT

**Paired RAFT release.** This cuVS was built and tested against the published
RAFT release
[`v26.12-gb10-cu133-g9fcf3a1f`](https://github.com/zbrad/raft/releases/tag/v26.12-gb10-cu133-g9fcf3a1f)
(RAFT 26.12, CUDA 13.3.73, CCCL 3.5.0, `sm_121a`; 16/16 RAFT gtest binaries
passed). `tuned/build.sh` downloads and extracts that release, so the build
does not compile RAFT from source.

**How upstream cuVS pins RAFT.** cuVS does not pin a RAFT commit or release.
Its `get_raft.cmake` requires RAFT at cuVS's own RAPIDS major.minor
(`find_package(raft <major.minor>)`), so any installed RAFT with the same
major.minor satisfies it. If none is found, CMake clones `rapidsai/raft` at the
branch named in cuVS's `RAPIDS_BRANCH` file:

| cuVS source | RAFT it expects |
|---|---|
| upstream `v26.08.01` (latest upstream release) | 26.08, branch `release/26.08` |
| upstream `release/26.10` | 26.10, branch `release/26.10` |
| upstream `main` and `zbrad/cuvs` `tuned-builds` | 26.12, branch `main` |

The version check only compares major.minor, so compatibility comes from our
paired, tested releases, recorded for every release in
`tuned/docs/RELEASE_PINS.md`. Use this cuVS with the RAFT release above. A
RAFT built from a different RAPIDS version or against a different CUDA toolkit
is not covered by these tests.

**Shared build pins.** Both builds resolve the same `rapids-cmake` commit
[`8fc2d05e`](https://github.com/rapidsai/rapids-cmake/commit/8fc2d05e4b29a2fb7a355192ce19190fcf24c37f)
(`-Drapids-cmake-sha`), which also fixes CCCL at 3.5.0. Pinning it in both
repositories is what stopped a `rapids_logger` version mismatch that broke
cuVS's configure on 2026-09-08.

**Bundled with this release:** kvikio 26.12.0, raft 26.12.0, rmm 26.12.0, rapids_logger 0.3.0 (as recorded in the library's build-info stamp).

## Full Test Suite Result

**35/35** gtest binaries passed (`tuned/full_test.sh`, 2026-09-21, on the merged tree).
Full output attached as `TEST_RESULTS_gb10.log` on this release. One
known-flaky case is excluded from the gate (below).

## Test Skips and Known Issues

The suite reports thousands of skipped tests (8,278 in the final run). Almost all are upstream's own guards, not caused by this build:

| Skips | Where they come from | Ours? |
|---|---|---|
| CAGRA and NN-Descent parameter combinations (the large majority) | `ann_cagra.cuh` and `ann_nn_descent.cuh` have no diff from upstream. They skip combinations the algorithms cannot build or verify: IVF_PQ with BitwiseHamming, Hamming cases with too little data for a reliable top-k ground truth, L1 with non-iterative builds, cosine with iterative build or `dim == 1`, and datasets too small for NN-Descent. | Upstream, by design |
| `NNTest` cases where the dimension is too large for exact checking (`bitshift <= 1`) | `distance_nn.cu`, unmodified in that line | Upstream, by design |
| `NNTest` cuTile-backend cases ("cuTile is not available for this device/input") | The `GTEST_SKIP()` is upstream's. We added the `IsSkipped()` guard so it skips instead of failing ([`#2660`](https://github.com/NVIDIA/cuvs/issues/2660)). | Skip upstream, guard ours |
| `CutileSmoke.LaunchesCompatibleCubin` | Our version of `cutile_smoke.cu` turns `cudaErrorJitCompilerNotFound` into a skip. | Ours |

**Why the cuTile tests skip.** The pinned driver (580.173.02) cannot launch
cuTile-compiled kernels: `libnvidia-gpucomp.so` is not installed (details in
Driver Context below). Separately, the production cuTile top-1 nearest-neighbor kernels have no
`sm_121` entry (see above), so that backend may be unavailable on GB10 even
with a working driver; we have not determined which condition makes the
availability check fail. Either way, that backend has no test coverage on GB10.

**Known flaky test.** `KmeansFitBatchedTestF.Result/4` fails about half the
time on GB10 (`kmeans::fit` is not run-to-run reproducible), reported upstream
as [`NVIDIA/cuvs#2657`](https://github.com/NVIDIA/cuvs/issues/2657), open.
`full_test.sh` still runs it once and records the result, but it does not
fail the gate.

## Driver Context

Which NVIDIA driver a GB10 node runs affects what this build can do, so this
section records what was installed, what was available, and what NVIDIA
documents, as of 2026-09-21.

### What this release was built and tested on

- Driver **580.173.02** (open kernel module), kernel `6.17.0-1031-nvidia`,
  Ubuntu 24.04 aarch64, on GB10 nodes.
- The driver version is deliberately pinned (apt pin on the 580.173.02 source
  packages).

### Installing and checking the tested driver (580.173.02)

This is the package set on the nodes this release was tested on. It comes from
Canonical's HWE channel (`ports.ubuntu.com`, `noble-updates/restricted`), with
one small pinning package from NVIDIA's CUDA `sbsa` repository. Do not mix in
NVIDIA-repo driver packages such as `nvidia-open` or `cuda-drivers`: the kernel
module for `6.17.0-1031-nvidia` requires `nvidia-kernel-common-580` at exactly
580.173.02, so a driver from the other channel can leave a mismatched
driver/module pair. Secure Boot works because Canonical ships the module
prebuilt and signed.

The command below is what we ran to move nodes from 610.43.02. We have not
tried it from a clean install or from other driver branches.

1. **Check first (read-only).** Confirm the running kernel and that a matching
   module exists:
   ```
   uname -r                                   # 6.17.0-1031-nvidia
   apt-cache policy linux-modules-nvidia-580-open-$(uname -r) \
       nvidia-firmware-580-580.173.02 nvidia-driver-pinning-580.173.02
   dpkg -l | grep -i nvidia                   # record this: it is your rollback list
   ```
2. **Install.** Run as root, in one apt transaction. If the node currently has
   another branch installed (for us `-610`), add its installed packages with a
   trailing `-` so they are removed in the same transaction:
   ```
   TARGET=580.173.02-0ubuntu0.24.04.1
   KERNEL=$(uname -r)
   apt install -y \
     "libnvidia-compute-580=${TARGET}" \
     "nvidia-compute-utils-580=${TARGET}" \
     "nvidia-firmware-580-580.173.02=${TARGET}" \
     "nvidia-kernel-common-580=${TARGET}" \
     "nvidia-utils-580=${TARGET}" \
     "linux-modules-nvidia-580-open-${KERNEL}" \
     "linux-modules-nvidia-580-open-nvidia-hwe-24.04" \
     "nvidia-driver-pinning-580.173.02"
   ```
   `nvidia-driver-pinning-580.173.02` has no dependencies and installs an apt
   preferences file that holds the driver source packages at 580.173.02.
3. **Reboot.** The new kernel module only loads after a reboot. This stops
   everything using the GPU and drops network connections to services on the
   node.
4. **Verify:**
   ```
   nvidia-smi --query-gpu=driver_version,name --format=csv,noheader   # 580.173.02, NVIDIA GB10
   head -1 /proc/driver/nvidia/version        # "NVRM version: NVIDIA UNIX Open Kernel Module for aarch64  580.173.02 ..."
   dpkg -l | grep -E 'nvidia.*580'            # all at 580.173.02
   ```
   To check unified-memory release the way we did: load a large model in a CUDA
   process, stop it, and compare `free -h` and `/proc/meminfo` (`MemAvailable`,
   `AnonPages`, `Cached`). Used memory should fall back to a few GiB with no
   unexplained gap.
5. **Run the build.** The driver only needs to be 580 or newer for CUDA 13.x
   toolkits. This release was built with the CUDA 13.3 toolkit at
   `/usr/local/cuda-13.3` (see "Reproducing This Build").
6. **Roll back.** Install the previous package set from the list you recorded
   in step 1, at its recorded versions, in one transaction, then reboot. We do
   not have a tested rollback script for the 580.173.02 install itself.

Keep the driver and kernel versions matched when upgrading: install kernel and
module packages together (see the 580.173.02 forum thread below).

### Drivers available for GB10 (arm64, Ubuntu 24.04)

Versions of the `nvidia-open` package in NVIDIA's CUDA `sbsa` apt index, as
seen on our nodes on 2026-09-21. Other apt sources on our nodes also list
580.142 (a Canonical PPA snapshot) and 595.84; availability changes as
archives are updated:

| Branch | Versions available |
|---|---|
| 580 | 580.65.06, 580.82.07, 580.95.05, 580.105.08, 580.126.09, 580.126.16, 580.126.20, 580.159.03, 580.159.04, 580.167.08, **580.173.02** (used), 580.178.04 |
| 590 | 590.44.01, 590.48.01 |
| 595 | 595.45.04, 595.58.03, 595.71.05, 595.91.07 |
| 610 | 610.43.02, 610.57.04 |
| 615 | 615.71.09 |

In February 2026 an NVIDIA moderator said 580.126.09 was the newest driver
supported (see the 590.48.01 report below); NVIDIA's DGX Spark release notes
have since listed 580.159.03 as current. Only 580.173.02 was tested with this
build; the other versions have not been exercised with RAFT or cuVS on GB10.

### What NVIDIA documents

In the four NVIDIA pages we read (listed below), none states whether a
unified-memory leak is present or fixed in any release:

- The DGX Spark release notes list driver 580.159.03 (DGX OS 7.5.0). Their
  July 2026 section says the driver "enhances Out-of-Memory (OOM) handling with
  GB10's unified memory architecture". They do not mention a leak fix.
- The DGX Spark known-issues page covers `cudaMemGetInfo` not counting
  swap-reclaimable memory. It does not mention leaks or driver versions.
- The data-center R580 release notes for 580.173.02 (2026-06-29) include
  "Enabled WAR against GDMA HW deadlock under high load situations for GB10y";
  those for 580.178.04 (2026-08-03) list no GB10 or unified-memory item.
  Neither lists a GPU memory-leak fix, and neither page lists GB10/DGX Spark as
  a supported platform, so these notes are weak evidence for GB10.

### Community reports (NVIDIA Developer Forums)

Forum posts are user reports, not NVIDIA statements, except where noted.

- **580.159.03 and earlier**: a user reports `NV_ERR_NO_MEMORY` after 20–30
  minutes of light serving on 580.159.03. NVIDIA staff replied in that thread
  but attributed the OOM reports to vLLM changes, said they could not reproduce
  a leak, and worked on a separate power-off/lockup issue. No post tests a
  driver newer than 580.159.03. Another user characterizes it as a memdesc
  leak under allocation churn that a reboot clears (thread 376882, 2026-07-19).
- **580.173.02**: one thread reports the GPU not detected after an `apt
  upgrade` from 580.159.03 on a DGX OS 2607 system. The cause was disputed: the
  reporter blamed driver/GSP-firmware pairing, NVIDIA staff blamed a kernel
  that had not been updated to `6.17.0-1029-nvidia` and advised `apt
  dist-upgrade`. It was resolved by rerunning the DGX Dashboard update. Another
  user runs 580.173.02 on four Sparks without issue. The thread suggests
  keeping the driver and kernel versions matched when upgrading.
- **580.178.04**: one out-of-memory report (2026-09-21) was traced by another
  forum user, and confirmed by the reporter, to inference-server memory
  settings (`--max-running-requests`, `--max-mamba-cache-size`), not the
  driver.
- **590.48.01**: one user reports memory not released after a CUDA process
  exits (580.126.09 unaffected). NVIDIA staff replied: "we do not support new
  drivers past version 580.126.09". No fix version was named.

**Our observation (2026-08-31, one node)**: on driver **610.43.02**, after a
CUDA process (a llama.cpp server holding a ~38 GiB model) exited, `free` kept
showing tens of GiB "used" (up to about 84 GiB) that no process, container or
`/proc/meminfo` category (`AnonPages`, `Cached`, `Slab`) accounted for.
Dropping caches and reloading `nvidia_uvm` did not release it; community
reports say a reboot does. That matches the signature in the 590.48.01 report
above.
After moving that node to 580.173.02 (a package swap plus reboot), a similar
test (load the model, stop it) released memory cleanly: used memory went from 42 GiB to 3.1 GiB with no
residual gap, and a later check the same day still showed no gap.

Limits of this evidence: it is one node and one load/stop test, not a soak
test. The second GB10 node was moved to the same 580.173.02 package set but
not leak-tested. We chose 580.173.02 because it is the 580 version in the
Ubuntu HWE channel that matches the installed kernel, not because we compared
it against other 580 versions. We never ran 580.159.03, 580.159.04, 580.167.08,
580.178.04, 590 or 595 ourselves, and we did not test 610.57.04. The 580.159.03
serving-time reports above describe a different symptom (failure under
sustained serving) that this test does not cover.

### cuTile and `libnvidia-gpucomp`

cuTile-compiled kernels need `libnvidia-gpucomp.so` at launch. It is not part
of the installed `libnvidia-compute-580` package. NVIDIA's CUDA repository
ships it as a separate package, `libnvidia-gpucomp-580` (580.173.02-1ubuntu1
exists). Apt gives it priority -1 on our nodes (we have not confirmed which
rule causes that), so it is not installed on the nodes this release was tested
on. We expect cuTile kernel launches to fail with
`cudaErrorJitCompilerNotFound` without it (the `CutileSmoke` test skips with
that error on our nodes). Whether installing that package makes cuTile kernels
launch has not been tested.

### Sources

- [DGX Spark release notes](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html)
- [DGX Spark known issues](https://docs.nvidia.com/dgx/dgx-spark/known-issues.html)
- [Data-center driver 580.173.02 notes](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-173-02/index.html)
- [Data-center driver 580.178.04 notes](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-580-178-04/index.html)
- [Improved Unified Memory Handling with Driver 580.159.03](https://forums.developer.nvidia.com/t/improved-unified-memory-handling-with-driver-580-159-03/373018)
- [Memory leak report on 580.159.03](https://forums.developer.nvidia.com/t/multi-node-inference-crash-on-blackwell-gb10-memory-allocation-0x51-nccl-timeouts-tested-on-qwen-122b-nemotron-120b/363989/6)
- [Memdesc leak report, 580.159.03 and earlier (thread 376882)](https://forums.developer.nvidia.com/t/376882)
- [580.173.02 apt upgrade breaks GPU on OTA2607](https://forums.developer.nvidia.com/t/dgx-spark-apt-upgrade-to-driver-580-173-02-breaks-gpu-on-ota2607-nvidia-smi-no-devices-found/378200)
- [Driver issue with 580.178.04](https://forums.developer.nvidia.com/t/driver-issue-with-580-178-04/383859)
- [590.48.01 UMA memory not released](https://forums.developer.nvidia.com/t/driver-590-48-01-regression-uma-memory-not-released-after-cuda-process-exit-works-on-580-126-09/359969)

## Reproducing This Build

```
git clone git@github.com:zbrad/cuvs.git && cd cuvs
git checkout <commit>
CUDA_VER=13.3 GPU_TUNED_BUILD_TESTS=1 bash tuned/build.sh gb10   # fetches the RAFT release above
CUDA_VER=13.3 bash tuned/full_test.sh gb10                       # must pass before packaging
CUDA_VER=13.3 bash tuned/package.sh gb10
```

Outputs go to CUDA-version-specific directories so a cu133 and a cu134 build
never share files: `cpp/build/cu133/gb10/`, `dist/cu133/gb10/` and
`tuned/releases/cu133/`.

See `tuned/docs/RELEASE_PINS.md` for the pairing and `rapids-cmake` pin of
every release.
