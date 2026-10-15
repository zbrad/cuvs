# cuVS 26.12 — GB10 / DGX Spark Release Notes (CUDA 13.4)

**Release**: `v0.20261015.0-gb10-cu134` (2026-10-15)
**Package**: `libcuvs-0.20261015.0-gb10-cu134.tar.gz`
**Platform**: aarch64
**GPU Architecture**: SM_121a (GB10 / DGX Spark, Grace Blackwell)
**Re-release of**: `v26.12-gb10-cu134-g424288ff`

## This release

The same library as `v26.12-gb10-cu134-g424288ff`, published under the fleet's date-label tag
(`v0.<UTC date>.<seq>-<variant>-<cuda>`, tuned-common `docs/ARCHITECTURE.md` E2) instead of
`v<upstream version>-<variant>-<cuda>-g<sha>`. Nothing in the library changed: it was repackaged from the
existing build tree (tested at `075bc636`; no source outside `tuned/` has changed since, which
`tuned/package.sh` now checks), not rebuilt. The upstream version, cuVS 26.12, is in the title. The old tag
is superseded by this one.

**Tested:** the full suite passed on this build (37/37 gtest binaries, log attached; the known-flaky
`KmeansFitBatchedTestF.Result/4`, NVIDIA/cuvs#2657, is excluded from the gate as before). **Smoke-tested as
packaged:** the tarball was extracted and checked on its own: its sha256 against `package-info.txt`, a consumer
`find_package(rmm raft cuvs)` configure that resolves nvtx3, rmm and rapids_logger inside the package, and three
gtest binaries (`UTIL_TEST` 23 tests, `NEIGHBORS_ANN_BRUTE_FORCE_TEST` 78 tests, `PREPROCESSING_TEST` 226 tests)
run with the package's `lib/` first on `LD_LIBRARY_PATH` and `libcuvs-gb10-cu134.so`, `libkvikio-tuned.so`,
`librmm-tuned.so` and `librapids_logger-tuned.so` resolving to files inside the package (log attached). These
smoke runs are three of the 37 binaries, not the suite.

Everything below is the content of the previous release's notes, unchanged except the RAFT section's first paragraph.

## Overview

The 26.12 source line of cuVS built against CUDA 13.4, single-arch for `sm_121a`, as
`libcuvs-gb10-cu134.so`. It links the published RAFT release `v26.12-gb10-cu134-g0fa8a51f` and
bundles `kvikio`, which cuVS's own install does not ship.

**Upstream base.** `tuned-builds` is merged with upstream `NVIDIA/cuvs` `main` at `24b0b1706`
("Make TestCagraToHnswSerializationAndSearch less flaky", #2775), version 26.12.00, which upstream
has not tagged. That includes the roaring-bitmap CAGRA filter (#2446). Fork-only changes are listed
in `tuned/docs/FORK_PATCHES.md`; the changes carried over from the CUDA 13.3 release are described
in `RELEASE_NOTES_26.12_gb10_cu133.md`.

## What Changed

- **Unique shared-object identities.** The stock RAPIDS names `librmm.so`, `librapids_logger.so`,
  `libkvikio.so` and `libcuvs_c.so` could be swapped with a stock install in either direction.
  This package ships **`librmm-tuned.so`, `librapids_logger-tuned.so`, `libkvikio-tuned.so` and
  `libcuvs_c-tuned.so`**: file name, SONAME and every `DT_NEEDED` that names them, with the CMake
  and pkg-config files repointed so `find_package(cuvs)` consumers link them unchanged.
  `libcuvs-gb10-cu134.so` and `libraft-gb10-cu134.so` already carry variant and CUDA tag and keep
  their names. The rename is a patchelf pass on a copy of the install tree at packaging time
  (`tuned/package.sh`), and packaging fails closed unless every shared object is renamed or kept
  and every dependency resolves inside the tree. **Breaking** for anything that loaded the old
  names from an earlier cuVS release; rebuild such consumers (zbrad/faiss) against this one.
  The libraries under test were built against the renamed RAFT, so they link the `-tuned` names
  directly.
- **nvtx3 is now shipped.** The previous packages did not contain nvtx3 although their installed
  `rmm-dependencies.cmake` calls `find_dependency(nvtx3)`: the builds had resolved nvtx3 from a stock pip
  `librmm` wheel in the build host's user site-packages, so it was never fetched or installed, and a
  consumer configured against the package alone (zbrad/faiss) failed. The build now ignores user-site pip
  CMake packages and the RAFT release it links ships nvtx3 (`lib/cmake/nvtx3/`, `include/nvtx3/`, 3.2.0,
  header-only). The build fails if any `*_DIR` in its CMake cache points into a pip wheel, and packaging
  fails unless nvtx3 is in the package and a minimal consumer project configures against it with `nvtx3`,
  `rmm`, `rapids_logger` and `raft` resolving inside it. A stock wheel's nvtx3 is not the tuned, tested copy.
- **Shared rapids-cmake pin moved `8fc2d05e` -> `61a96c8f`**, the same pin as RAFT. The merged
  roaring-bitmap filter calls `cuco::roaring_bitmap::from_indices`, which the older pinned cuco
  lacks, so cuVS did not compile against the old pin.
- **Fork-local regression test fixed.** `REGRESSION_TEST`'s `warp_reduce_add_op.cu` still used
  `rmm::cuda_stream_view`, which upstream removed, so the target failed to compile. The first
  test run on this tree reported 29/29 with that binary silently missing and was discarded.
  Fixed to `cuda::stream_ref` in `368852e8`.
- **Package and publish are separate steps.** `tuned/package.sh` builds the tarball and no longer
  publishes; `tuned/release.sh` holds the fresh-passing-tests and non-draft-notes gates and the
  publish. `tuned/build.sh` accepts `RAFT_RELEASE_TARBALL=<path>` to build against a RAFT package
  that is not published yet.
- **Build outputs live in one tree per toolkit, `tuned/build/<cuda_tag>/`** (`cmake/`, `dist/`,
  `releases/`, `raft/`, `ccache/`, `timing.tsv`), with a fixed compile path so ccache can hit.

## Depends on RAFT

RAFT has been re-released under the date-label tag `v0.20261015.0-gb10-cu134`: the same package as
`v26.12-gb10-cu134-g0fa8a51f`, repackaged. The RAFT for this cuVS is that release; this cuVS bundles its libraries
(`libraft-gb10-cu134.so`, `librmm-tuned.so`, `librapids_logger-tuned.so`) and was built before the rename,
against the bits that release contains. The text below names the tag it was built against at the time.

This cuVS was built and tested against the RAFT package
[`v26.12-gb10-cu134-g0fa8a51f`](https://github.com/zbrad/raft/releases/tag/v26.12-gb10-cu134-g0fa8a51f)
(RAFT 26.12, CUDA 13.4, CCCL 3.5.0, `sm_121a`; 16/16 RAFT gtest binaries), the published release itself.
`tuned/build.sh` extracts a RAFT package instead of compiling RAFT from source. cuVS does not pin a RAFT
commit; it requires RAFT at its own RAPIDS major.minor, so compatibility comes from these paired, tested
releases (recorded in `tuned/docs/RELEASE_PINS.md`). A RAFT built from a different RAPIDS version, a
different CUDA toolkit, or without the same library names and nvtx3 is not covered.

Both builds resolve `rapids-cmake`
[`61a96c8f`](https://github.com/rapidsai/rapids-cmake/commit/61a96c8f29731affd7fd913a586673dd057dc3b0)
(`-Drapids-cmake-sha`).

**Bundled with this release:** kvikio 26.10.0, raft 26.12.0, rmm 26.10.0, rapids_logger 0.3.0
(read from each bundled package's version file, recorded in the library's build-info stamp).

## Full Test Suite Result

**37/37 gtest binaries passed, 0 failed; 12,476 tests passed, 2,702 skipped** (`tuned/full_test.sh`,
started 21:37Z, finished 22:14Z on 2026-10-13, 37 minutes, one binary at a time, on commit `075bc636`), against the
`-tuned`-named libraries. Full output attached as `TEST_RESULTS_gb10.log` on this release. One
known-flaky case is excluded from the gate: `KmeansFitBatchedTestF.Result/4`
([`NVIDIA/cuvs#2657`](https://github.com/NVIDIA/cuvs/issues/2657), open); it is run once and
recorded, and passed this run.

The skipped tests were not re-audited for this build. The categories explained in the CUDA 13.3
notes ("Test Skips and Known Issues"), upstream's own parameter-combination guards and the cuTile
skips on the pinned driver, apply; the driver is the same (580.173.02, see the Driver Context in
those notes).

## Build Timing

Cold-ish build with tests on: wall 1,085 s with `-j20`, 7,052 timed units (summed unit time
19,894 s), ccache 179 of 2,234 hits (8%). The hit rate is low because the pin move invalidated the
cache and the JIT-LTO `generated_kernels` objects cannot be cached. Per-unit timings are in
`tuned/build/cu134/timing.tsv` on the build host.

## Reproducing This Build

```
git clone git@github.com:zbrad/cuvs.git && cd cuvs
git checkout <the release tag>
GPU_TUNED_BUILD_TESTS=ON bash tuned/build.sh gb10   # resolves the newest zbrad/raft gb10-cu134 release
bash tuned/full_test.sh gb10                        # must pass before packaging
bash tuned/package.sh gb10                          # builds the tarball
bash tuned/release.sh gb10                          # publishes, after the gates
```

## Package Contents

`lib/`: `libcuvs-gb10-cu134.so`, `libcuvs_c-tuned.so`, `libraft-gb10-cu134.so`,
`librmm-tuned.so`, `librapids_logger-tuned.so`, `libkvikio-tuned.so`, static archives; `include/`;
`lib/cmake/` (cuvs, raft, rmm, rapids_logger, kvikio). Use with
`-Dcuvs_DIR=<extracted>/lib/cmake/cuvs`.

---

**cuVS Version**: 26.12.00
**Release Date**: 2026-10-12
**Platform**: aarch64 / SM_121a / CUDA 13.4
