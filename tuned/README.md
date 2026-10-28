# tuned/ — single-arch cuVS builds

Builds cuVS's C++ shared library (`libcuvs-<variant>-cu<tag>.so`, named per `docs/WHEEL_NAMING.md`) for one GPU variant
and one CUDA toolkit, and packages it as a tarball. It builds against a RAFT release from zbrad/raft, and zbrad/faiss
consumes the result. The layout and rules are `docs/ARCHITECTURE.md` in
[zbrad/tuned-common](https://github.com/zbrad/tuned-common). Only gb10 is built here today; rtx40 and rtx50 are
described in `docs/BUILD_rtx.md`.

```
CUDA_TAG=cu134 bash tuned/build.sh gb10        # libcuvs                         -> tuned/build/cu134/cmake/
GPU_TUNED_BUILD_TESTS=1 CUDA_TAG=cu134 bash tuned/build.sh gb10   # opt-in: also build the gtest binaries
CUDA_TAG=cu134 bash tuned/full_test.sh gb10    # run those gtest binaries        -> tuned/build/cu134/releases/ log
CUDA_TAG=cu134 bash tuned/package.sh gb10      # tarball, sha256, DRAFT notes    -> .../dist/
CUDA_TAG=cu134 bash tuned/smoke_test.sh gb10
# review and commit tuned/releases/RELEASE_NOTES_<label>_<variant>_<cuda>.md
CUDA_TAG=cu134 bash tuned/release.sh gb10      # gates only; writes the ready-marker, never publishes
CUDA_TAG=cu134 bash tuned/publish.sh gb10      # publishes exactly what release.sh saw
```

`build.sh` normally skips tests (`-DBUILD_TESTS=OFF`); a release needs the opt-in test build and a passing `full_test.sh`.

## Files

| File | Purpose |
|---|---|
| `env.sh` | device, toolkit and tree setup, including `GPU_TUNED_VENV_DIR`; sourced by every script |
| `repo.env` | cuVS-only settings |
| `common.sh`, `sync-common.sh`, `common-data/` | vendored from tuned-common; refresh with `bash tuned/sync-common.sh sync` |
| `build.sh`, `full_test.sh`, `package.sh`, `smoke_test.sh`, `release.sh`, `publish.sh` | the stages above |
| `requirements-build.txt` | the build venv's Python requirements: `cuda-tile[tileiras]`, `nvidia-nccl-cu13`, `ninja`, `cmake>=4.0` (locked in `requirements-build.lock`, installed under it by `gpu_tuned_pip_install_requirements`) |
| `verify_bundled_deps.sh` | fails if a shared library in an install tree or tarball needs a library that is neither shipped nor a system library, or has a `RUNPATH` into a build tree |
| `_raft_release/` | gitignored; extracted RAFT releases per variant and toolkit (`gb10-cu133`, `gb10-cu134`) |
| `docs/` | `BUILD_gb10.md`, `BUILD_rtx.md`, `WHEEL_NAMING.md`, `BINARY_BUILD_INFO.md`, `FORK_PATCHES.md`, `RELEASE_PINS.md` |
| `compliance.conf` | attestations for the checks `tools/tuned_compliance.sh` cannot make mechanically |

## RAFT pairing

`build.sh` downloads the matching zbrad/raft release for the variant and toolkit (or uses the tarball named in
`RAFT_RELEASE_TARBALL=<path>`), extracts it under `tuned/build/<cuda-tag>/raft/<tag>/` unless that tag is already there, and
puts `RAFT_RELEASE_DIR` on `CMAKE_PREFIX_PATH`. Without it, CMake would clone and build RAFT's main branch from source.
`docs/RELEASE_PINS.md` records each published release with its repo commit and RAFT pairing.

## Build venv

The venv (`tuned/build/<cuda-tag>/venv`, `GPU_TUNED_CLEAN_VENV=1` recreates it) is made by `gpu_tuned_setup_build_venv`
with `requirements-build.txt` and the current setuptools (at least 84.2, C8). It supplies the tools the configure needs
(CMake 4, Ninja, `tileiras`, the NCCL headers and library for the multi-GPU algorithms). The build itself is native and
produces no wheel, so the wheel-only dependency audit does not apply. `tuned/build/` is gitignored.
