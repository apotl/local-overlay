# llama.cpp gfx1100 MoE `sum_rows` crash — local fix

Canonical, git-tracked home (pushed to `apotl/local-overlay`) for the local fix that
keeps every MoE GGUF from crashing on `sci-misc/llama-cpp-9999` (guru overlay, live
`git-r3` HEAD), `USE=rocm`, on host **alight** (RX 7900 XT / gfx1100, ROCm 7.2).

**The fix is a build flag, not a source patch** — see `ndebug.conf`. The guru ebuild
is left untouched (it keeps auto-updating on `--sync`).

## Symptom

Every MoE GGUF (`*-A3B`/`*-A4B`: Qwen3.6-35B-A3B, gemma-4-26B-A4B, …) crashed
deterministically (SIGABRT) on a large real request (~20k-token prefill + 27 tools):

```
ggml-cuda.cu:104: ROCm error: the operation cannot be performed in the present state
  in function ggml_cuda_kernel_launch at common.cuh:1639
  <- ggml_cuda_op_sum_rows
```

(HTTP 502 / "empty stream with no finish_reason" at the gateway.) The documented
`-ot ffn_gate_inp=CPU` workaround did **not** avoid it.

## Root cause (diagnosed 2026-06-26 under `dev-debug/gdb[rocm]` + `AMD_LOG_LEVEL=3`)

HIP runtime trace at the fault, on llama.cpp HEAD `3fc4e105`:

```
ShaderName : void reduce_rows_f32<false>(float const*, float*, int)
hipLaunchKernel ( 0x..., {168,1,1}, {32,1,1}, ... )       # grid=168, block=32 (tiny)
rocvirtual.cpp:3650: Pcie atomics not enabled, hostcall not supported
rocvirtual.cpp:3990: AQL dispatch failed!
hipLaunchKernel: Returned hipErrorIllegalState
```

The failing kernel is `reduce_rows_f32` — the `GGML_OP_SUM_ROWS` kernel used for the
MoE-router top-k weight normalization (`RESHAPE→SUM_ROWS→CLAMP→DIV→RESHAPE`; standalone
on the GPU whenever the router isn't GPU-fused, e.g. with `-ot ffn_gate_inp=CPU`).

It is **not** a launch-dimension overflow (grid is only 168). The real chain:

1. `reduce_rows_f32` calls `block_reduce()` (ggml-cuda `common.cuh`), which contains a
   device-side `assert((block_size <= 1024) && (block_size % WARP_SIZE) == 0)`.
2. The **Gentoo cmake build type does not define `NDEBUG`** (asserts stay on), unlike a
   normal upstream Release build — so that device `assert` is compiled into the kernel.
3. A live device assert makes the kernel's code object require **hostcall** services.
4. Hostcall needs **PCIe atomics**, which are **not enabled** on this root complex, so
   the HSA runtime rejects the AQL dispatch → `hipErrorIllegalState`.

(Most kernels don't use `block_reduce`/asserts, which is why only `sum_rows` was hit.)

## The fix: `ndebug.conf` (define `NDEBUG`)

Build `sci-misc/llama-cpp` as a real release by appending `-DNDEBUG` to C/CXXFLAGS for
this package only. That removes the device asserts (kernels no longer require hostcall →
dispatch normally) **and** the host-side debug assert at `ggml-cuda.cu:4406`. This is
the configuration upstream ships, sidesteps the whole device-assert/hostcall class of
bug (not just `sum_rows`), keeps everything on the GPU, and is slightly faster.

### Why not a source patch (`*.patch.superseded`)

The first attempt made `ggml_backend_cuda_device_supports_op` return `false` for
`GGML_OP_SUM_ROWS` (run it on CPU). It removed the `sum_rows` crash but the CPU-resident
node then tripped a *different* live debug assert at `ggml-cuda.cu:4406` during HIP graph
capture (`node->buffer->buft == cuda_buffer_type`), aborting at model load. Kept as
`0001-hip-offload-moe-sum_rows.patch.superseded` for the record. `NDEBUG` is strictly
better and also removes that 4406 assert.

## Wiring (single source of truth = this dir)

```
/etc/portage/env/ndebug.conf            -> symlink to ./ndebug.conf   (canonical)
/etc/portage/package.env/llama-cpp      :  sci-misc/llama-cpp ndebug.conf   (see package.env.sample)
/etc/portage/patches/sci-misc/llama-cpp-9999 -> symlink to this dir   (eapply_user hook,
        kept ready for future *.patch files; currently no active patch)
```

`rocgdb` for diagnosis = `dev-debug/gdb[rocm]` + `dev-libs/rocdbgapi` (Gentoo ships the
amd-dbgapi target in mainline gdb; enabled via `/etc/portage/{package.use,package.accept_keywords}`
and a `profile/package.use.stable.mask` override).

## Validation

`VALIDATION.txt`: n=5 fresh-server battery, production baseline config, repro payload →
**5/5 OK at ~1150 tok/s prefill** (was 5/5 CRASH). No crash/abort/assert signatures.

## Maintenance / staleness

- `NDEBUG` is a flag, not a patch, so it cannot fail to apply when upstream HEAD moves
  (no `eapply` fuzz to worry about). It will keep working across `--sync` of the guru
  ebuild and live llama.cpp HEAD.
- **Hardware alternative:** the true cause is "PCIe atomics not enabled → no hostcall".
  Enabling PCIe atomics (BIOS: Above-4G decoding / Re-Size BAR / slot config, if this
  board+CPU support it) would let assert-bearing kernels dispatch and remove the need for
  this flag entirely.
- Optional source pin: `EGIT_OVERRIDE_COMMIT_ggml-org_llama.cpp=<sha>` in
  `/etc/portage/env/sci-misc/llama-cpp` for reproducible builds.
- Retire by removing the `package.env` line once upstream defaults to NDEBUG for this
  Gentoo build, or once the hardware does hostcall.
