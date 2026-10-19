# cuVS 26.12 — GB10 / DGX Spark (CUDA 13.4) — v0.20261019.0-gb10-cu134

**Package**: `libcuvs-0.20261019.0-gb10-cu134.tar.gz` · aarch64 · SM_121a · tested and built at `e47e60dd`, packaged at `91f0f934` (only `tuned/` changed in between, which `tuned/package.sh` checks)

## Install

The toolkit is part of the release name: `-cu133` is built with CUDA 13.3, `-cu134` with CUDA 13.4. Set `CUDA_TAG` once and
every command below follows it. This note is for **cu134**; to use the cu133 release set `CUDA_TAG=cu133` (it has its own note and tarball).

```
CUDA_TAG=cu134
TAG=v0.20261019.0-gb10-${CUDA_TAG}
PREFIX=~/opt/cuvs-0.20261019.0-gb10-${CUDA_TAG}
mkdir -p "${PREFIX}" && cd "${PREFIX}"
gh release download "${TAG}" -R zbrad/cuvs -p "libcuvs-*-gb10-${CUDA_TAG}.tar.gz*"
sha256sum -c libcuvs-*-gb10-${CUDA_TAG}.tar.gz.sha256
tar xzf libcuvs-*-gb10-${CUDA_TAG}.tar.gz                 # extracts into the current directory
```

- **Path:** `~/opt/cuvs-0.20261019.0-gb10-cu134/` (`lib/`, `include/`, `share/`, `lib/cmake/`). The tarball has no top-level directory, so extract into a directory of its own.
- **Build against it:** `cmake -Dcuvs_DIR=${PREFIX}/lib/cmake/cuvs ...`. raft, rmm, rapids_logger, kvikio and nvtx3 are bundled; no separate raft install is needed.
- **Run:** put `${PREFIX}/lib` first on `LD_LIBRARY_PATH` and add the matching toolkit lib dir (`/usr/local/cuda-13.4/lib64` for cu134). The shared objects use `RUNPATH $ORIGIN`.
- **Needs:** aarch64, GB10 (SM 12.1), driver R580 or newer.

## Components

| Component | Shipped file | Device code | Tests | Result |
|---|---|---|---|---|
| cuVS 26.12 | `libcuvs-gb10-cu134.so`, `libcuvs_c-gb10-cu134.so` | yes (sm_121a) | full suite, 37 gtest binaries | 37/37 passed; 15,176 ran, 12,476 passed, rest skipped |
| RAFT 26.12 (bundled) | `libraft-gb10-cu134.so` | yes (sm_121a) | exercised by the cuVS suite | passed |
| kvikio, rmm, rapids_logger (bundled) | `libkvikio-cu134.so`, `librmm-cu134.so`, `librapids_logger-cu134.so` | no | exercised by the cuVS suite | passed |
| Package as extracted | `libcuvs-0.20261019.0-gb10-cu134.tar.gz` | | smoke: 3 binaries (`UTIL_TEST` 23, `NEIGHBORS_ANN_BRUTE_FORCE_TEST` 78, `PREPROCESSING_TEST` 226) | passed |

## This release

Rebuilt in the flat per-toolkit tree (`tuned/build/cu134/`) against the raft build at `3756ce9e` with axis-named shared objects. That raft build is published as `v0.20261019.0-gb10-cu134`; the build-info stamp inside `libcuvs-gb10-cu134.so` names it `v0.20261018.0-gb10-cu134`, the label the raft package carried before it was relabelled and published. The 20261018 name was never published; it is the same raft build.
Shipped libraries: `libcuvs-gb10-cu134.so`, `libcuvs_c-gb10-cu134.so`, `libraft-gb10-cu134.so` (device code: variant and toolkit);
`libkvikio-cu134.so`, `librmm-cu134.so`, `librapids_logger-cu134.so` (toolkit only). **Breaking rename:** the earlier `libcuvs_c-tuned.so`,
`libkvikio-tuned.so`, `librmm-tuned.so` and `librapids_logger-tuned.so` no longer exist; rebuild consumers (zbrad/faiss does).
**Requires the matching raft release** `v0.20261019.0-gb10-cu134` (publish raft first).

**Supersedes** `v0.20261015.0-gb10-cu134`, which carries the earlier `-tuned` shared-object names and stays published for consumers that pin its URL.

## Tested

- Full suite (2026-10-18 23:26Z – 2026-10-19 00:03Z): **37/37 gtest binaries passed**; 15,176 tests ran, 12,476 passed, the rest skipped (log attached).
  One known-flaky case is excluded from the gate, `KmeansFitBatchedTestF.Result/4` ([NVIDIA/cuvs#2657](https://github.com/NVIDIA/cuvs/issues/2657)); it is run once, recorded, and passed.
- Smoke-tested as packaged: extracted and checked on its own, `libcuvs`, `libkvikio`, `librmm`, `librapids_logger` resolving inside the package
  (e.g. `NEIGHBORS_ANN_BRUTE_FORCE_TEST` 78 tests, `PREPROCESSING_TEST` 226 tests; log attached). A subset, not the suite.
