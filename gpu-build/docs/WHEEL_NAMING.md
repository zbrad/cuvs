# cuVS GPU Build — Naming Convention

_Last updated: 2026-07-06_

This document records the naming/versioning conventions for cuVS GPU libraries
and build scripts. Builds are named by **GPU codename** rather than CPU arch
or SM number, mirroring the convention used in zbrad/vllm's `native-builds`
branch (`requirements/gb10.txt`, `tools/build_gb10.sh`, `tools/run_gb10.sh`;
originally established on that repo's `gb10` branch, renamed to
`native-builds` on 2026-07-08 for naming consistency with this repo and
zbrad/faiss, though that branch itself only carries GB10 support today).
This supersedes an earlier CPU-arch/SM-number scheme (`libcuvs-aarch64-cu132-sm103.so`
etc.) that mirrored `zbrad/faiss gpu-cu/docs/WHEEL_NAMING.md` instead —
switched to the vLLM-style codename convention on 2026-07-06.

---

## Guiding principles

1. **Single CUDA-version knob** — one sourced env file (`tuned/env.sh`)
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

5. **One consolidated build script, parameterized by GPU codename** —
   `tuned/build.sh gb10` / `tuned/build.sh rtx40` / `tuned/build.sh rtx50`,
   driven by `tuned/devices/<codename>.conf`. (The three previously-separate
   scripts were ~90% identical; root-level `build_gb10.sh`/`build_rtx40.sh`/
   `build_rtx50.sh` remain as deprecation shims for existing automation.)

---

## Library naming table

| Build | Script | CPU arch | CUDA_ARCHS | Output library |
|-------|--------|----------|------------|-----------------|
| RTX 40 / Ada Lovelace | `tuned/build.sh rtx40` | x86_64 | `89-real` | `libcuvs-rtx40-cu132.so` |
| RTX 50 / Blackwell | `tuned/build.sh rtx50` | x86_64 | `120a-real` | `libcuvs-rtx50-cu132.so` |
| GB10 / DGX Spark | `tuned/build.sh gb10` | aarch64 | `121a-real` | `libcuvs-gb10-cu132.so` |

The `cu132` portion tracks `CUDA_TAG`; bump `CUDA_VER` in `tuned/env.sh`
(or pass it at the command line) and all names update automatically.

---

## Selecting / bumping the CUDA version

Specify it **per build** — no file edits needed:

```bash
# GB10 / DGX Spark, CUDA 13.3 → libcuvs-gb10-cu133.so
CUDA_VER=13.3 bash tuned/build.sh gb10

# RTX 40, CUDA 13.3 → libcuvs-rtx40-cu133.so
CUDA_VER=13.3 bash tuned/build.sh rtx40

# RTX 50, CUDA 13.3 → libcuvs-rtx50-cu133.so
CUDA_VER=13.3 bash tuned/build.sh rtx50

# Tag form (equivalent)
CUDA_TAG=cu133 bash tuned/build.sh gb10
```

To change the **default**, edit `CUDA_VER` in `tuned/env.sh`.

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

`zbrad/faiss`'s `gpu-cu/scripts/build_lib_gb10.sh`, `build_lib_rtx40.sh`, and
`build_lib_rtx50.sh` each consume the matching `libcuvs-{codename}-${FAISS_CUDA_TAG}.so`
from this repo's `cpp/build/` — e.g. `build_lib_gb10.sh` looks for
`libcuvs-gb10-${FAISS_CUDA_TAG}.so`. The old `build_lib_aarch64.sh` /
`libcuvs-spark.so` naming has already been renamed on the faiss side to match
this scheme. See faiss's own `gpu-cu/docs/WHEEL_NAMING.md` for the full
naming scheme there.
