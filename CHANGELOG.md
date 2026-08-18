# Changelog

## v1.0.0 — 2026-08-18

First public release. Crimson Desert reaches gameplay on AMD Polaris and renders correctly in
daylight and at night, with no missing or substituted textures.

Twelve distinct faults had to be fixed to get there. Each one is documented in the
[full report](https://vidith007.github.io/RX-580-CRIMSON-DESERT-FIX/) with the measurement that
decided it.

### Capability forging

- Report Direct3D 12 feature level **12_1** and `shaderFloat16` to a card that advertises
  neither, then repair every consequence of that lie.
- Forge `minSubgroupSize` to **16** so `[WaveSize(32)]` shaders validate. Validation only
  requires `min <= 32 <= max`.
  Deliberately *not* 32: vkd3d-proton branches on the `CrimsonDesert.exe` executable name into
  an RDNA1 compatibility profile gated on `minSubgroupSize == 32`, which makes 32 a uniquely
  dangerous value to forge.
- Implement the DXGI swapchain paths that returned `E_NOTIMPL`.

### Polaris shader-compiler workarounds

- **`gl_HelperInvocation` load storm.** Reading the builtin more than roughly a hundred times in
  one shader faults the Polaris compiler while it walks its own use-list. Collapsing the reads
  to a single load fixed **11 of 11** crashing shaders with **0 regressions across 402 modules**.
- **`OpIsHelperInvocationEXT`** (opcode 5381) is a second form of the same problem, needing
  module slack, a written-back length, and an anchor that resets on demotes and
  demote-reachable calls.
- **Dead `FragmentShadingRateKHR` declaration.** Shaders declared a capability the card doesn't
  have and never used it. Stripping the unused declaration took pipeline refusals **9 → 0**,
  `VkResult=-3` **51 → 0**, and `E_OUTOFMEMORY` **16 → 0**.
- **Invalid SPIR-V from the fp16 graphics demote.** The pass rewrote `%v2half` to `%v2float`
  *inside* an `OpBitcast` without rewriting the bitcast, making **337 fragment modules** invalid.
  Compute kept fp16 and had zero failures. The pass is now disabled in the shipped build.
- **Disable `VK_EXT`/`VK_VALVE_mutable_descriptor_type`.** Polaris cannot compile graphics
  pipelines that use it; this was the original `VK_ERROR_UNKNOWN`.

### Missing hardware features, emulated

- **Device-generated commands.** Polaris has no DGC support, and **5,281 of 5,284** command
  signatures carry root arguments — so vkd3d returned without drawing and most indirect draws
  silently never happened. Falling through instead took indirect draws from **14 to 255 per
  frame**.
- **Per-command root constants without DGC**, via forced push-UBO mode plus a compute unroll
  pass. 450,000 calls handled, 0 rejected, 0 pipeline refusals.

### Memory and caching

- **The endless "Compiling Shaders" screen was a commit-limit wall.** A 4.0 GB
  `%LOCALAPPDATA%\AMD\DxcCache` pushed peak commit to **30,916 MB against a 32,318 MB limit**,
  leaving 805 MB. The compile worker died silently; the game waited forever at 82 fps drawing a
  black frame, never crashing and never timing out. Emptying the cache dropped peak commit to
  **8,768 MB**.
  `Play Crimson Desert (RX 580).cmd` now measures and empties that cache before launch.
- **`VKD3D_SHADER_CACHE_PSO_BLOB`** ends recompile-every-launch. A 147 MB cache with 2,161
  driver-cache entries is reused across runs, and serving pipelines from it took refusals
  **5 → 0**.

### Known defects at 1.0.0

- The title-screen background is black. Diagnosed, not fixed — the background scene is never
  submitted to the GPU at all.
- `StripPSFromDepthOnly` cannot be set to `0`. Doing so produces 36 pipeline refusals and the
  game dies. The shaders that setting removes are exactly the ones Polaris refuses.
- Commit headroom is tight on 8 GB. Mid-gameplay peak commit is 11,773 MB.

Foliage smearing during motion was investigated and is a frame-rate artifact, not a rendering
defect.

### Provenance

- vkd3d-proton **3.0.1**, modified: **+869 / −13** across 9 files. Corresponding source ships as
  `source/vkd3d-proton-3.0.1-rx580-polaris.patch`.
- dxil-spirv pinned at `62dbb07f771534c8ce924479efdc6c8fa510361d`, **+227 / −8** across 4 files,
  all inert at runtime.
- Tested on one machine: RX 580 2048SP, 8 GB RAM, Windows 11, game version 1.14.00.
