# cuVS 26.12.00 — NVIDIA GB10 (DGX Spark, Blackwell, SM 12.1) (CUDA 13.4) — v0.20261028.0-gb10-cu134

**Package**: `libcuvs-0.20261028.0-gb10-cu134.tar.gz` · aarch64 · SM_121a · built at `a981e422d` (tests ran at `a40b43792`; only `tuned/` scripts changed between them) · paired with RAFT release `v0.20261028.0-gb10-cu134`

## This release

A rebuild of the same cuVS 26.12 library against the new zbrad/raft release `v0.20261028.0-gb10-cu134`, with the shared-object
names unchanged from `v0.20261019.0-gb10-cu134`. It is built with the toolkit's build venv (CMake 4, Ninja, setuptools 84.2)
and the tuned-common gates for it. The packaging and smoke scripts take CMake 4 from that venv because the host's CMake is
3.30 and the package's rmm and raft CMake config files need 4.0; consumers of this package need **CMake 4.0 or newer** too.

**Supersedes** `v0.20261019.0-gb10-cu134`, which stays published for consumers that pin its URL.

## Tested

- Full suite (`tuned/full_test.sh`, 2026-10-28): **37/37 gtest binaries passed** (log attached). The known-flaky
  `KmeansFitBatchedTests/KmeansFitBatchedTestF.Result/4` (NVIDIA/cuvs#2657) is excluded from the gate and passed this run.
- Smoke-tested as packaged: the tarball was extracted and a subset of binaries run against it; `libcuvs`, `libkvikio`,
  `librmm` and `librapids_logger` resolve to files inside the package (log attached). Not the full suite.

**Not in this release:** Python wheels (cuVS has none here).
