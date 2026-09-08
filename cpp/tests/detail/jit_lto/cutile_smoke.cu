/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <cuvs/detail/jit_lto/TileAlgorithmPlanner.hpp>
#include <cuvs/detail/jit_lto/cutile_arch_tags.hpp>
#include <cuvs/detail/jit_lto/cutile_module.hpp>
#include <cuvs/detail/jit_lto/cutile_smoke_fragments.hpp>

#include <gtest/gtest.h>

#include <cuda_runtime.h>

#include <array>
#include <exception>
#include <memory>
#include <string>
#include <vector>

namespace cuvs::detail::jit_lto {

#if !CUVS_CUTILE_ENABLED

TEST(CutileSmoke, DisabledBuild)
{
  GTEST_SKIP() << "cuTile embedded kernels are disabled in this build";
}

#else

namespace {

template <typename ArchTag>
using smoke_fragment = StaticCubinFragmentEntry<fragment_tag_cutile_smoke_add_cubin<ArchTag>>;

std::vector<std::unique_ptr<CubinFragmentEntry>> make_smoke_fragments()
{
  std::vector<std::unique_ptr<CubinFragmentEntry>> fragments;
  fragments.emplace_back(std::make_unique<smoke_fragment<cutile_arch_8_0>>());
  fragments.emplace_back(std::make_unique<smoke_fragment<cutile_arch_8_6>>());
  fragments.emplace_back(std::make_unique<smoke_fragment<cutile_arch_9_0>>());
  fragments.emplace_back(std::make_unique<smoke_fragment<cutile_arch_10_0>>());
  fragments.emplace_back(std::make_unique<smoke_fragment<cutile_arch_12_0>>());
  fragments.emplace_back(std::make_unique<smoke_fragment<cutile_arch_12_1>>());
  return fragments;
}

void add_smoke_fragments(TileAlgorithmPlanner& planner)
{
  planner.add_static_fragment<fragment_tag_cutile_smoke_add_cubin<cutile_arch_8_0>>();
  planner.add_static_fragment<fragment_tag_cutile_smoke_add_cubin<cutile_arch_8_6>>();
  planner.add_static_fragment<fragment_tag_cutile_smoke_add_cubin<cutile_arch_9_0>>();
  planner.add_static_fragment<fragment_tag_cutile_smoke_add_cubin<cutile_arch_10_0>>();
  planner.add_static_fragment<fragment_tag_cutile_smoke_add_cubin<cutile_arch_12_0>>();
  planner.add_static_fragment<fragment_tag_cutile_smoke_add_cubin<cutile_arch_12_1>>();
}

// Runs the add-two-tiles kernel and checks the result. Throws (via RTCX_CUDA_TRY,
// see rtcx/macros.hpp) on any CUDA failure -- callers decide whether to tolerate
// a specific expected failure or let it propagate as a test failure.
void run_smoke_add_and_verify(const std::shared_ptr<rtcx::algorithm_launcher>& launcher)
{
  cudaStream_t stream = nullptr;
  constexpr int count = 256;
  std::array<float, count> host_lhs{};
  std::array<float, count> host_rhs{};
  std::array<float, count> host_output{};
  for (int i = 0; i < count; ++i) {
    host_lhs[i] = static_cast<float>(i);
    host_rhs[i] = static_cast<float>(count - i);
  }

  float* lhs    = nullptr;
  float* rhs    = nullptr;
  float* output = nullptr;
  ASSERT_EQ(cudaMalloc(&lhs, sizeof(host_lhs)), cudaSuccess);
  ASSERT_EQ(cudaMalloc(&rhs, sizeof(host_rhs)), cudaSuccess);
  ASSERT_EQ(cudaMalloc(&output, sizeof(host_output)), cudaSuccess);
  ASSERT_EQ(cudaMemcpy(lhs, host_lhs.data(), sizeof(host_lhs), cudaMemcpyHostToDevice),
            cudaSuccess);
  ASSERT_EQ(cudaMemcpy(rhs, host_rhs.data(), sizeof(host_rhs), cudaMemcpyHostToDevice),
            cudaSuccess);

  using smoke_kernel_t = void(void*, int, int, void*, int, int, void*, int, int);
  try {
    launcher->template dispatch<smoke_kernel_t>(stream,
                                                dim3{1, 1, 1},
                                                dim3{1, 1, 1},
                                                0,
                                                static_cast<void*>(lhs),
                                                count,
                                                1,
                                                static_cast<void*>(rhs),
                                                count,
                                                1,
                                                static_cast<void*>(output),
                                                count,
                                                1);
  } catch (...) {
    (void)cudaFree(lhs);
    (void)cudaFree(rhs);
    (void)cudaFree(output);
    throw;
  }
  ASSERT_EQ(cudaGetLastError(), cudaSuccess);
  ASSERT_EQ(cudaMemcpy(host_output.data(), output, sizeof(host_output), cudaMemcpyDeviceToHost),
            cudaSuccess);
  ASSERT_EQ(cudaFree(lhs), cudaSuccess);
  ASSERT_EQ(cudaFree(rhs), cudaSuccess);
  ASSERT_EQ(cudaFree(output), cudaSuccess);

  for (const auto value : host_output) {
    EXPECT_FLOAT_EQ(value, static_cast<float>(count));
  }
}

}  // namespace

TEST(CutileSmoke, ResolvesEveryEmbeddedArchitecture)
{
  auto fragments = make_smoke_fragments();

  EXPECT_EQ(find_compatible_cubin_fragment(8, 0, fragments), fragments[0].get());
  EXPECT_EQ(find_compatible_cubin_fragment(8, 9, fragments), fragments[1].get());
  EXPECT_EQ(find_compatible_cubin_fragment(9, 0, fragments), fragments[2].get());
  EXPECT_EQ(find_compatible_cubin_fragment(10, 0, fragments), fragments[3].get());
  EXPECT_EQ(find_compatible_cubin_fragment(12, 0, fragments), fragments[4].get());
  // GB10 (12.1) must resolve to the exact 12.1 fragment, not fall back to the
  // 12.0 base -- 12.0 SASS is not actually forward-compatible on this device
  // (cudaErrorNoKernelImageForDevice), even though it's the same major and a
  // lower minor. See cutile_arch_12_1's doc comment in cutile_arch_tags.hpp.
  EXPECT_EQ(find_compatible_cubin_fragment(12, 1, fragments), fragments[5].get());
  EXPECT_EQ(find_compatible_cubin_fragment(7, 5, fragments), nullptr);
}

TEST(CutileSmoke, LaunchesCompatibleCubin)
{
  CutileRuntimeCapabilities capabilities{};
  if (!query_current_cutile_runtime_capabilities(capabilities)) {
    GTEST_SKIP() << "No CUDA device is available";
  }

  auto fragments = make_smoke_fragments();
  if (find_compatible_cubin_fragment(capabilities.cc_major, capabilities.cc_minor, fragments) ==
      nullptr) {
    GTEST_SKIP() << "No embedded smoke cubin is compatible with this device";
  }

  TileLauncherCache cache;
  TileAlgorithmPlanner planner{"cutile_smoke_add", cache};
  add_smoke_fragments(planner);
  auto launcher = planner.try_get_launcher();
  ASSERT_NE(launcher, nullptr);

  try {
    run_smoke_add_and_verify(launcher);
  } catch (const std::exception& e) {
    // rtcx::algorithm_launcher::call() throws via RTCX_CUDA_TRY on any CUDA
    // failure, so a legitimately-missing driver component surfaces here as a
    // generic runtime_error rather than a typed cudaError_t we could re-check
    // against is_expected_cutile_unavailable() (which already treats
    // cudaErrorJitCompilerNotFound as expected-unavailable, but only for the
    // *load* step). Match on the same error name for the launch step: some
    // driver branches don't ship the component cuTile's cubins need to
    // complete their runtime relocation at launch time -- see
    // RequiresJitLinkCapableDriver below, which tracks this explicitly.
    if (std::string(e.what()).find("cudaErrorJitCompilerNotFound") != std::string::npos) {
      GTEST_SKIP() << "cuTile kernel launch unavailable on this driver: " << e.what();
    }
    throw;
  }
}

// Deliberately NOT tolerant of cudaErrorJitCompilerNotFound, unlike
// LaunchesCompatibleCubin above -- this is expected to FAIL on any driver
// branch missing libnvidia-gpucomp.so (confirmed absent from the pinned
// 580.173.02 branch via strace; only present in an untested 595.45.04
// package cached locally, not installed). Excluded from tuned/full_test.sh's
// release gate (see that script) precisely so it stays red and visible
// instead of silently passing or silently being skipped -- once a driver
// upgrade ships the missing component, this test starts passing on its own,
// which is the signal to fold its guarantee back into LaunchesCompatibleCubin
// and delete this test and the skip branch above.
TEST(CutileSmoke, RequiresJitLinkCapableDriver)
{
  CutileRuntimeCapabilities capabilities{};
  if (!query_current_cutile_runtime_capabilities(capabilities)) {
    GTEST_SKIP() << "No CUDA device is available";
  }

  auto fragments = make_smoke_fragments();
  if (find_compatible_cubin_fragment(capabilities.cc_major, capabilities.cc_minor, fragments) ==
      nullptr) {
    GTEST_SKIP() << "No embedded smoke cubin is compatible with this device";
  }

  TileLauncherCache cache;
  TileAlgorithmPlanner planner{"cutile_smoke_add", cache};
  add_smoke_fragments(planner);
  auto launcher = planner.try_get_launcher();
  ASSERT_NE(launcher, nullptr);

  run_smoke_add_and_verify(launcher);
}

#endif

}  // namespace cuvs::detail::jit_lto
