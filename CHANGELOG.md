# Changelog

## v2.0.0 — 2026-09-03 — frame rate

v1.0.0 made the game run. This release makes it playable: **15 fps → 22–24 fps** at 1600×900 on
minimum settings, and the GPU went from drawing 65 W of its ~150 W power budget to ~110 W.

The gain is one root cause, found by measuring power rather than utilisation, plus three
supporting fixes. A fourth change is documented here as a *negative* result, because knowing
which lever does nothing is worth as much as knowing which one works.

### The frame-rate root cause: ExecuteIndirect drained the GPU once per call

Polaris has no `VK_EXT_device_generated_commands`, so v1.0.0 emulated D3D12's per-command root
arguments with a compute pass that writes draw arguments, followed by the draws that read them.
That dispatch has to complete before the draws can run, and it almost always shares a command
buffer with them — so **every `ExecuteIndirect` ended the render pass, issued a full
compute-to-graphics barrier, and restarted it**. Measured: **685,335 render-pass breaks in one
session**, one per call, several hundred times a frame.

Each break is a complete GPU pipeline drain. The card reported near-100% busy the whole time
while drawing a third of its rated watts, because "utilisation" counts time with a packet in
flight, not time doing work.

**The fix is to batch them.** Deferred calls accumulate, then replay as *all* the dispatches back
to back with the render pass already closed, one barrier, then *all* the draws — so a batch of N
costs one drain instead of N. Drains per call fell **4.5×**. This is the change that produced the
frame-rate gain.

Two traps in it, both hit for real and both now guarded:

- **The replay must not be able to defer into itself.** The first build replayed single-entry
  batches in a mode that re-deferred them, and the replay loop — bounded by the live batch count
  it was appending to — extended itself forever, growing a 5 KB-per-entry array until the game
  died at four minutes with `vkd3d_realloc: Out of memory` on three threads. The replay now has
  its own mode, and the loop bounds are snapshotted so any future instance costs a late draw
  rather than a hang.
- **Batches cannot cross a barrier that names a graphics source scope**, or a texture barrier
  (layout transitions), or half of a split barrier. Each refusal is counted in the log rather
  than assumed.

### Draws that were being issued 612 times over

The unroll pass looped to the *declared* `MaxCommandCount`, not the count the GPU actually
produced — **1.43 billion unrolled draws in one session, 612 per call.** Cross-checked against
the shim's own draw counter over the same run: two independent instruments, same answer.

The fix is a multi-draw collapse. Instead of one descriptor push and one `drawCount=1` indirect
draw per command, the driver issues one push and one `drawCount=N` draw per chunk of 256
commands, and the shaders read their own command's root constants from an array indexed by
`DrawIndex`. **~2.18 billion Vulkan calls became ~8.5 million**, with nothing dropped and nothing
drawn with a neighbour's transform.

> **Rejected alternative, recorded because it looked right and was wrong.** Simply lowering the
> unroll bound to 2048 removes 90% of the draws and the performance half of the theory held — GPU
> power rose exactly as predicted. But commands above the bound fall back to a count-draw that
> still *draws* every command, using the root constant the command list last bound. For this
> engine that constant is per-object transform data, so **the geometry lands in the wrong place**.
> It shipped for one session and was immediately visible. There is no safe value for that bound;
> the fix had to be the partial unroll, not a better constant. Wrong position is as broken as
> missing.

### A `DrawIndex` load storm broke 787 shaders

The multi-draw collapse makes every vertex shader read `DrawIndex` (`BuiltIn 4426`), and reading
an input builtin hundreds of times faults the Polaris compiler while it walks its own use-list —
the same defect v1.0.0 fixed for `gl_HelperInvocation`, reached by a different builtin. **60 of 64
shaders in the fault band were `DrawIndex`**, and they were gated out of the only pass that could
have fixed them, because that pass matched on a builtin allow-list.

Hoisting on *storage class* (`Input`) rather than on a list of known builtins took shader
failures **787 → 0**.

### Missing indirect draws, and a 4 GB cache that stalled the loader

- **`ExecuteIndirect` silently discarded most indirect draws.** 5,281 of 5,284 command signatures
  carry root arguments, and vkd3d returned without drawing for those. Falling through to the
  emulation took indirect draws from **14 to 255 per frame**.
- **The endless "Compiling Shaders" screen was a commit-limit wall.** A 4.0 GB
  `%LOCALAPPDATA%\AMD\DxcCache` pushed peak commit to **30,916 MB against a 32,318 MB limit**. The
  compile worker died silently and the game waited forever, never crashing and never timing out.
  Emptying it dropped peak commit to **8,768 MB**. `Play Crimson Desert (RX 580).cmd` now measures
  and clears that cache before launch.

### Negative result: eliding redundant descriptor-heap binds

`SetDescriptorHeaps` used to flush the deferred batch unconditionally. It now compares the heap
objects against the ones last applied and returns early when they match — sound because
everything read out of a heap is written once at creation and never mutated.

It worked as designed and **it bought 2%**:

```
heapSame=1488603  heapSet=136125    92% of the engine's heap binds were redundant re-binds
drains per call   0.2025 → 0.1980   phase-matched over six windows per build
```

The flushes *migrated* rather than disappearing — barrier-site flushes per call rose 0.1348 →
0.1814. The heap bind was breaking a batch the game's next barrier would have broken anyway, and
that barrier cannot be crossed: **`bxSync=370506` against `bxOk=5643`**, so 98.5% of crossings are
refused because the engine's own barriers name a graphics source scope.

**The general rule:** removing a flush site only removes drains if no *other* uncrossable boundary
sits in the same gap. A flush-site count is an upper bound the barrier pattern can erase
completely. Kept in the build because it removes real CPU work and cost nothing, with
`VKD3D_DGC_HEAP_ELIDE=0` to disable it.

### Where the frame rate now stands

Measured with `ADL2` Overdrive 5 against the driver directly, because Windows exposes no GPU power
counter:

```
gameplay:  gfx 1300 MHz (full stock boost)   mem 1500 MHz   100% activity   ~110 W of ~150 W
CPU:       8 of 12 logical cores idle
```

**The frame is GPU-bound and the card is at its ceiling.** Full boost clock, pinned occupancy,
three-quarters of its power budget, CPU nowhere near the limit. The emulation sits at 0.198
pipeline drains per `ExecuteIndirect` and is held there by the game's own barrier pattern, not by
anything left to rewrite — the two most recent driver-side changes each came in under 3% for that
reason.

Two levers remain, and both are the user's to pull:

- **Render resolution.** 1280×720 is 0.64× the pixels of 1600×900, worth roughly +35–50% on a
  pixel-bound frame.
- **Memory clock.** The card runs at 1500 MHz under load where the driver's own table allows up to
  2250 MHz. Some RX 580 2048SP boards genuinely ship slower memory, so this may be stock — but a
  GPU-bound Polaris frame runs out of bandwidth before anything else.

### Also in this release

- **`VKD3D_SHADER_CACHE_PSO_BLOB` and `PersistentPipelineCache` are both forced off, and must stay
  off.** `vkGetPipelineCacheData` faults inside `amdvlk64.dll` whenever `pData != NULL` — the size
  query with `pData=NULL` succeeds every time, so this is not a race in the caller. Persistent
  *driver* pipeline caching is unavailable on this driver by any route, because that call is the
  only way to get a blob out of a `VkPipelineCache`. SPIR-V caching still works and
  `bin64\vkd3d-proton.cache` is reused across launches; do not delete it.
- **Diagnostics that had become their own cost are off by default.** `LogDrawCalls` was recording
  6.6 million hooked draws per second, each doing four interlocked adds on two globals shared by
  five recording threads. `MemoryTelemetry` was doing synchronous formatted writes on the
  pipeline-compile critical path. Set either back to `1` only for a deliberate measuring run.

### Known defects at 2.0.0

Unchanged from v1.0.0: the title-screen background is never submitted to the GPU;
`StripPSFromDepthOnly` cannot be set to `0` (the shaders it removes are exactly the ones Polaris
refuses); rock and ground textures in some scenes do not load.

### Provenance

- vkd3d-proton **3.0.1**, modified: **+2,033 / −37** across 12 files, including one new compute
  shader. Corresponding source ships as `source/vkd3d-proton-3.0.1-rx580-polaris.patch` and has
  been verified to reproduce the shipped tree byte-for-byte from a clean upstream v3.0.1 checkout.
- dxil-spirv pinned at `62dbb07f771534c8ce924479efdc6c8fa510361d`.
- Tested on one machine: RX 580 2048SP, Windows 11, game version 1.14.00.

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
