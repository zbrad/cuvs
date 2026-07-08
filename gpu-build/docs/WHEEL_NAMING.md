# cuVS GPU Build — Naming Convention

_Last updated: 2026-07-06_

This document records the naming/versioning conventions for cuVS GPU libraries
and build scripts. Builds are named by **GPU codename** rather than CPU arch
or SM number, mirroring the convention used in zbrad/vllm's `gb10` branch
(`requirements/gb10.txt`, `tools/build_gb10.sh`, `tools/run_gb10.sh`). This
supersedes an earlier CPU-arch/SM-number scheme (`libcuvs-aarch64-cu132-sm103.so`
etc.) that mirrored `zbrad/faiss gpu-cu/docs/WHEEL_NAMING.md` instead —
switched to the vLLM-style codename convention on 2026-07-06.

---

## Guiding principles

1. **Single CUDA-version knob** — one sourced env file (`scripts/cuda_env.sh`)
   defines `CUDA_VER` (e.g. `13.2`) and `CUDA_TAG` (e.g. `cu132`). Specify
   either at build time; the other is derived. Changing the CUDA version needs
   no script or path renames.

2. **Version-agnostic build dir** — the build directory (`cpp/build/`) does not
   embed the CUDA version. Libraries with different CUDA versions should be
   stored and deployed separately by the consumer.

3. **GPU codename in filename, not CPU arch or SM number** — each codename
   (`gb10`, `rtx40`, `rtx50`) implies exactly one CPU arch and exactly one SM
   number, so encoding both separately would be redundant. All three builds
   here are single-arch, compiled `-real` (native SASS, no PTX/JIT fallback).

4. **Only owned/verified hardware is built** — datacenter and professional
   architectures (Hopper, Blackwell DC, GB200, and Ada professional parts
   like L40/L40S/RTX 6000 Ada) are **not** built here. An earlier revision of
   this scheme bundled them into a multi-arch x86_64 fat binary alongside a
   `CUDA_ARCHS=103-real` entry for "DGX Spark" that turned out to be a
   fabricated SM number (real GB10 is SM 121, confirmed via `torch`
   `device_capability` on real hardware, and matches what
   `zbrad/faiss gpu-cu/scripts/build_lib_aarch64.sh` already used
   independently). That fat binary was written by an earlier, disconnected
   agent session with no access to real hardware for any of the chips it
   claimed to support. Building only what's actually been run on real
   hardware avoids repeating that mistake.

5. **Build scripts named by GPU codename** — `build_gb10.sh` / `build_rtx40.sh`
   / `build_rtx50.sh`.

---

## Library naming table

| Build | Script | CPU arch | CUDA_ARCHS | Output library |
|-------|--------|----------|------------|-----------------|
| RTX 40 / Ada Lovelace | `build_rtx40.sh` | x86_64 | `89-real` | `libcuvs-rtx40-cu132.so` |
| RTX 50 / Blackwell | `build_rtx50.sh` | x86_64 | `120-real` | `libcuvs-rtx50-cu132.so` |
| GB10 / DGX Spark | `build_gb10.sh` | aarch64 | `121-real` | `libcuvs-gb10-cu132.so` |

The `cu132` portion tracks `CUDA_TAG`; bump `CUDA_VER` in `scripts/cuda_env.sh`
(or pass it at the command line) and all names update automatically.

---

## Selecting / bumping the CUDA version

Specify it **per build** — no file edits needed:

```bash
# GB10 / DGX Spark, CUDA 13.3 → libcuvs-gb10-cu133.so
CUDA_VER=13.3 bash build_gb10.sh

# RTX 40, CUDA 13.3 → libcuvs-rtx40-cu133.so
CUDA_VER=13.3 bash build_rtx40.sh

# RTX 50, CUDA 13.3 → libcuvs-rtx50-cu133.so
CUDA_VER=13.3 bash build_rtx50.sh

# Tag form (equivalent)
CUDA_TAG=cu133 bash build_gb10.sh
```

To change the **default**, edit `CUDA_VER` in `scripts/cuda_env.sh`.

**Multi-toolkit hosts.** When `CUDA_HOME` is not set, `cuda_env.sh` resolves it
to `/usr/local/cuda-<CUDA_VER>` if that directory exists (falling back to
`/usr/local/cuda`). If the `nvcc` on `PATH` reports a different version a
warning is printed.

---

## Considered and deferred: a JIT/virtual-only datacenter build

Datacenter jobs (H100/H200, B100/B200, GB200) run long enough that a one-time
JIT-compile cost at first kernel launch is negligible against total runtime —
unlike GB10 (edge device, users expect a fast single-shot run) or RTX40/50
(interactive desktop use). A `-virtual`-only (PTX, no native SASS) build could
cover that tier with a much smaller binary than the old fat binary's
per-arch-additive `-real` approach, at the cost of a first-launch JIT hit
absorbed once per process. This mirrors flashinfer's own GB10 release, which
ships AOT-compiled kernels only for its two latency-sensitive target model
families and leaves everything else to JIT.

**Deferred, not built**: this repo has no datacenter hardware to verify such a
build against — building it unverified would repeat exactly the mistake
principle 4 above describes. Revisit if/when there's real hardware to test on.
Note also that Hopper (90a) introduced instructions (TMA, etc.) not present in
Ada's PTX baseline, so a single universal PTX blob likely can't cleanly span
Ada-through-Blackwell-datacenter — it would need at least two virtual targets
(one baseline per instruction-set generation), not one.

---

## Downstream: faiss `gpu-cu/` build

The faiss aarch64 build (`zbrad/faiss gpu-cu/scripts/build_lib_aarch64.sh`)
currently expects `libcuvs-spark.so` from this repo's `cpp/build/`, and
already independently uses `CUDA_ARCHS="121-real"` with comments identifying
it as "SM 121 — GB10 Grace Blackwell" — consistent with the SM 121 fix in this
revision, and further confirmation that `103` (this scheme's previous value)
was wrong. After this PR merges, the library name changes to
`libcuvs-gb10-cu132.so`.

Required update in faiss (tracked separately, see faiss's own
`gpu-cu/docs/WHEEL_NAMING.md`):

| File | Old reference | New reference |
|------|--------------|---------------|
| `gpu-cu/scripts/build_lib_aarch64.sh` | `libcuvs-spark.so` | `libcuvs-gb10-cu${FAISS_CUDA_TAG}.so` |
| `gpu-cu/scripts/build_pkg_aarch64.sh` | `libcuvs-spark.so` | `libcuvs-gb10-cu${FAISS_CUDA_TAG}.so` |
| `gpu-cu/scripts/build_wheel_aarch64.sh` | `libcuvs-spark.so`, `./build_dgx_spark.sh` | `libcuvs-gb10-cu${FAISS_CUDA_TAG}.so`, `./build_gb10.sh` |
| `gpu-cu/scripts/package_wheel_aarch64.sh` | `libcuvs-spark.so` | `libcuvs-gb10-cu${FAISS_CUDA_TAG}.so` |
