# Fix: CCCL 3.4.0 `warpReduce` ADL name collision with `raft::warpReduce`

**Affects:** cuVS built against CCCL 3.4.0 (CUDA 13.x toolchain)  
**Symptom:** Compilation failure in any `.cu` file that uses `raft::add_op` as a CUB scan operator  
**Fix location:** `cub/device/dispatch/kernels/kernel_scan_warpspeed.cuh`

---

## Error

```
cub/device/dispatch/kernels/kernel_scan_warpspeed.cuh(455): error:
  more than one instance of function template "cub::detail::scan::warpReduce"
  matches the argument list:
    function template "T raft::warpReduce(T, ReduceLambda)"
      (declared at raft/util/reduction.cuh:49)
    function template "Tp cub::detail::scan::warpReduce(Tp, ScanOpT &)"
      (declared at kernel_scan_warpspeed.cuh:247)
    argument types are: (unsigned int, raft::add_op)
  regWarpSum = warpReduce(regThreadSum, scan_op);
```

Triggered by files such as:
- `src/neighbors/ivf_pq/detail/ivf_pq_build_extend_*.cu`
- `src/neighbors/knn_merge_parts.cu`

---

## Root Cause

CCCL 3.4.0 introduced a new warpspeed scan path in
`cub/device/dispatch/kernels/kernel_scan_warpspeed.cuh`.
Inside `cub::detail::scan::kernelBody`, two helper functions are called
**without qualification**:

```cpp
// kernel_scan_warpspeed.cuh — before fix
regWarpSum = warpReducePartial(regThreadSum, scan_op, valid_threads_this_warp);  // line 450
regWarpSum = warpReduce(regThreadSum, scan_op);                                  // line 455
```

Because these calls are unqualified, C++ **Argument-Dependent Lookup (ADL)**
searches the namespaces of all argument types. When `scan_op` is `raft::add_op`
(which lives in namespace `raft`), ADL finds:

| Found via | Signature |
|-----------|-----------|
| ADL on `raft::add_op` | `raft::warpReduce(T val, ReduceLambda reduce_op)` |
| Normal lookup in `cub::detail::scan` | `cub::detail::scan::warpReduce(Tp input, ScanOpT& scan_op)` |

Both are two-argument templates with compatible signatures — the compiler
cannot disambiguate, producing the error above.

The same ambiguity applies to `warpReducePartial`.

---

## Fix

Qualify both call sites with the full namespace, disabling ADL:

```cpp
// kernel_scan_warpspeed.cuh — after fix
regWarpSum = ::cub::detail::scan::warpReducePartial(regThreadSum, scan_op, valid_threads_this_warp);
regWarpSum = ::cub::detail::scan::warpReduce(regThreadSum, scan_op);
```

### Diff

```diff
--- a/cub/cub/device/dispatch/kernels/kernel_scan_warpspeed.cuh
+++ b/cub/cub/device/dispatch/kernels/kernel_scan_warpspeed.cuh
@@ -447,9 +447,9 @@ _CCCL_DEVICE_API _CCCL_FORCEINLINE void kernelBody(
         if (is_last_tile)
         {
           regThreadSum = ThreadReducePartial(regInput, scan_op, valid_items_this_thread);
-          regWarpSum   = warpReducePartial(regThreadSum, scan_op, valid_threads_this_warp);
+          regWarpSum   = ::cub::detail::scan::warpReducePartial(regThreadSum, scan_op, valid_threads_this_warp);
         }
         else
         {
           regThreadSum = ThreadReduce(regInput, scan_op);
-          regWarpSum   = warpReduce(regThreadSum, scan_op);
+          regWarpSum   = ::cub::detail::scan::warpReduce(regThreadSum, scan_op);
         }
```

---

## Why This Works

Qualifying the call with `::cub::detail::scan::` makes it a **qualified lookup**,
which C++ performs without ADL. The compiler finds exactly one match
(`cub::detail::scan::warpReduce`) and resolves the call unambiguously.

No behavior changes — the same function is called, just without the ADL search
that found the false `raft` match.

---

## Upstream

This should be reported and fixed upstream in CCCL:
- Repository: https://github.com/NVIDIA/cccl
- File: `cub/cub/device/dispatch/kernels/kernel_scan_warpspeed.cuh`
- Introduced in: CCCL 3.4.0

The correct upstream fix is to qualify these calls in `kernel_scan_warpspeed.cuh`
as shown above, or to enclose the helper definitions in an anonymous/inner
namespace to prevent ADL from finding them.

An alternative fix in consuming code (e.g. raft) would be to place `add_op`
and similar scan functors in a sub-namespace that is not discovered by ADL
when `warpReduce` is called from within `cub::detail::scan`.
