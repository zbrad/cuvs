# Fork patches

Every change `tuned-builds` carries relative to upstream `NVIDIA/cuvs`, why we
carry it, its upstream status, and when we can drop it. Keep this current: add
a row in the same commit that adds a fork-only change, cite the upstream
issue or PR number in that commit's message, and re-check the list after each
upstream merge.

Tracking issue: [zbrad/cuvs#6](https://github.com/zbrad/cuvs/issues/6).
Status below is as of 2026-09-21.

To see what differs from upstream in source (outside `tuned/`):

```
git diff --stat upstream/main...tuned-builds -- . ':!tuned'
```

## Source patches

| # | Change | Files | Commits | Upstream | Drop when |
|---|---|---|---|---|---|
| 1 | **cuTile smoke-test `sm_121` fragment** and the `CutileSmoke` canary. GB10 rejects the `sm_120` cubin as forward-compatible, so the smoke test needs an exact `sm_121` fragment; the canary turns the driver's missing JIT compiler into a skip. Test-only: it does **not** add `sm_121` to the production cuTile top-1 NN kernels (`fused_1nn_cutile_matrix.json` is identical to upstream). | `cpp/include/cuvs/detail/jit_lto/cutile_arch_tags.hpp`, `cpp/src/detail/jit_lto/cutile_smoke/cutile_smoke_matrix.json`, `cpp/tests/detail/jit_lto/cutile_smoke.cu` | `418242c30`, `119c2a4ff` | [PR #2568](https://github.com/NVIDIA/cuvs/pull/2568) (base `release/26.10`): open and mergeable since 2026-09-21 (`release/26.10` merged into the PR branch, head `843bc4407`); two maintainer reviews still request changes | the PR merges upstream (take upstream's version on the next merge) |
| 2 | **`NNTest` skip guard.** `IsSkipped()` check in `compare()` so upstream's `GTEST_SKIP()` inside a helper actually skips the test instead of failing the cuTile-backend cases when cuTile is unavailable. | `cpp/tests/neighbors/distance_nn.cu` (2 lines) | `4c925940e` | [issue #2660](https://github.com/NVIDIA/cuvs/issues/2660): open, no PR yet | upstream fixes the skip, or we submit the 2-line fix and it merges |
| 3 | **`CUVS_OUTPUT_NAME` option** so the library builds as `libcuvs-<variant>-<cuda_tag>.so`. | `cpp/CMakeLists.txt` | `7497adac4` | not submitted | permanent (fork naming); revisit if we upstream it |
| 4 | **`warpReduce`/`add_op` regression test** and write-up. The underlying fix is already upstream; this test guards against it regressing. | `cpp/tests/regression/`, `cpp/tests/CMakeLists.txt`, `docs/fixes/cccl-3.4.0-warpreduce-adl-fix.md` | `9cd424d0a`, `bd61c44cd`, `7497adac4` | fix is upstream; the test is fork-only | upstream carries an equivalent test, or we decide we no longer need it |
| 5 | **C test build-config fixes:** `MG_C_TEST` only when `BUILD_MG_ALGOS` is on; header check uses `project_root` instead of `CMAKE_SOURCE_DIR`. | `c/tests/CMakeLists.txt`, `c/tests/cmake/header_check.cmake` | `016017a71`, `8562560d2` | not submitted | upstream fixes the same, or we submit and it merges |
| 6 | **LF line endings.** `.gitattributes` forces `eol=lf` to stop `core.autocrlf` churn. | `.gitattributes` | `1083bc1b1` | not applicable | permanent |

## Workarounds that are not source patches

| Item | Where | Upstream | Drop when |
|---|---|---|---|
| **`KmeansFitBatchedTestF.Result/4` excluded from the test gate.** It fails about half the time on GB10 (`kmeans::fit` is not run-to-run reproducible). `tuned/full_test.sh` still runs it once and records the result. | `tuned/full_test.sh` (`8abfa07c9`) | [issue #2657](https://github.com/NVIDIA/cuvs/issues/2657): open | upstream makes `kmeans::fit` reproducible or fixes the test tolerance |
| **cuTile launch gap on driver 580.173.02.** `libnvidia-gpucomp.so` is not installed, so cuTile-compiled kernels cannot launch and the cuTile tests skip. | environment, not code | [cutile-python#105](https://github.com/NVIDIA/cutile-python/issues/105) covers a related `sm_XXXa` parsing bug | we install `libnvidia-gpucomp-580` (untested) or change driver; see the release notes' Driver Context |

## Fork-only tooling

`tuned/` (build, test, package and release scripts, device configs, release
notes and docs) exists only in this fork and is permanent. It is not listed
patch by patch; its history is `git log upstream/main..tuned-builds -- tuned`.
`tuned/common.sh` is a vendored copy of
[`zbrad/tuned-common`](https://github.com/zbrad/tuned-common); change it there
and sync, never here.
