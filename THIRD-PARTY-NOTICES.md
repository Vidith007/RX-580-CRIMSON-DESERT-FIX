# Third-party notices

This repository distributes compiled binaries that are **not** the repository author's work
and are **not** covered by the repository's Apache-2.0 licence. This file records who owns
what, under which terms, and where to get the corresponding source.

If you only want to know one thing: **`fix/vkd3d/d3d12core.dll` and `fix/vkd3d/d3d12.dll`
are modified LGPL-2.1-or-later binaries, and their modified source is in
`source/vkd3d-proton-3.0.1-rx580-polaris.patch`.**

---

## Summary

| Component | In this repo | Licence | Modified? |
|---|---|---|---|
| The D3D12 shim | `fix/d3d12.dll`, `fix/dxgi.dll`, `fix/dx12bridge.ini` | Apache-2.0 | Original work |
| The cache-guard launcher | `fix/Play Crimson Desert (RX 580).cmd` | Apache-2.0 | Original work |
| The engineering report and docs | `docs/`, `README.md`, `INSTALL.md` | Apache-2.0 | Original work |
| **vkd3d-proton 3.0.1** | `fix/vkd3d/d3d12core.dll`, `fix/vkd3d/d3d12.dll` | **LGPL-2.1-or-later** | **Yes** — see below |
| **dxil-spirv** | vendored inside `d3d12core.dll` | MIT | Yes, but inert at runtime |
| bc-decoder | vendored inside `d3d12core.dll` | MIT | No |
| glslang | vendored inside `d3d12core.dll` | MIT / BSD-3-Clause | No |
| SPIRV-Cross, SPIRV-Tools, SPIRV-Headers | vendored inside `d3d12core.dll` | Apache-2.0 / MIT | No — byte-clean |
| AMD Vulkan driver (`amdvlk64.dll`) | **not distributed** | AMD's own terms | No — stock, untouched |
| Crimson Desert | **not distributed** | Pearl Abyss | No file modified |

Apache-2.0 does not and cannot cover the vkd3d-proton binaries. You cannot relicense
someone else's LGPL work by putting an Apache licence in the repository root.

---

## vkd3d-proton — LGPL-2.1-or-later, modified

**Upstream:** https://github.com/HansKristian-Work/vkd3d-proton
**Version:** v3.0.1
**Licence text:** [`fix/licenses/vkd3d-proton-LICENSE.txt`](fix/licenses/vkd3d-proton-LICENSE.txt)
and [`fix/licenses/vkd3d-proton-COPYING.txt`](fix/licenses/vkd3d-proton-COPYING.txt), unedited.
**Authors:** [`fix/licenses/vkd3d-proton-AUTHORS.txt`](fix/licenses/vkd3d-proton-AUTHORS.txt), unedited.

`fix/vkd3d/d3d12core.dll` is a **modified** build. LGPL-2.1 sections 4 and 6 require the
corresponding modified source to accompany the binary. It does:

> [`source/vkd3d-proton-3.0.1-rx580-polaris.patch`](source/vkd3d-proton-3.0.1-rx580-polaris.patch)

That patch is **+869 / −13 lines across 9 files** against upstream v3.0.1. To reproduce the
build, clone upstream at tag `v3.0.1`, then:

```bash
patch -p1 < vkd3d-proton-3.0.1-rx580-polaris.patch
```

The patch was verified two ways before shipping: `patch -p1 --dry-run` exits clean against a
fresh upstream tree, and after applying, all nine modified files reproduce byte-for-byte.

**What was changed, in one line each:**

| File | Change |
|---|---|
| `libs/vkd3d/command.c` | Emulate device-generated commands, which Polaris has no support for, so indirect draws carrying root arguments are executed instead of silently dropped |
| `libs/vkd3d/state.c` | Force push-UBO mode for root constants; correct an `E_OUTOFMEMORY` that was mislabelling a driver pipeline refusal |
| `libs/vkd3d/device.c` | Report the forged feature level and subgroup sizes consistently |
| `libs/vkd3d/vkd3d_private.h` | Declarations for the above |
| remaining 5 files | Plumbing for the levers above, read via `vkd3d_get_env_var` |

Nothing in the patch is Crimson Desert-specific game code; it is all capability and
command-translation work.

---

## dxil-spirv — MIT

**Upstream:** https://github.com/HansKristian-Work/dxil-spirv
**Pinned commit:** `62dbb07f771534c8ce924479efdc6c8fa510361d`
**Copyright:** "Copyright (c) 2019-2022 Hans-Kristian Arntzen for Valve Corporation"
**Licence text:** [`fix/licenses/dxil-spirv-LICENSE.txt`](fix/licenses/dxil-spirv-LICENSE.txt)

Four files carry local fp16 changes, **+227 / −8**. All of them are **inert at runtime**,
because `dx12bridge.ini` line 371 sets `DXIL_SPIRV_GRAPHICS_DISABLE_NATIVE_FP16=0` — the
shipped build therefore behaves as pristine upstream. They are left in the build only so the
tree matches what was tested.

The reason they are off is recorded in the report: that demotion pass rewrote a type inside an
`OpBitcast` without rewriting the bitcast, producing invalid SPIR-V in 337 fragment shaders.

Vendored inside dxil-spirv and unmodified: **bc-decoder** (Baldur Karlsson, MIT) and
**glslang** (The Khronos Group, MIT / BSD-3-Clause). Their notices ship inside the upstream
tree. **SPIRV-Cross**, **SPIRV-Tools** and **SPIRV-Headers** are byte-clean against upstream.

---

## What is not distributed here

**AMD's Vulkan driver is stock and unmodified.** `amdvlk64.dll` comes from your own Radeon
Software install. Nothing in this repository replaces, patches or redistributes any AMD file.

**No Crimson Desert file is modified or redistributed.** Pearl Abyss made the game. This
package contains none of it — not a texture, not a shader, not an executable. The fix works by
sitting in front of the game's D3D12 calls, which is why uninstalling is just deleting five
files.

---

## If you think something here is wrong

Licence compliance is not a formality and getting it wrong is not harmless. If you believe a
component is misattributed, missing a required notice, or that the corresponding source is
incomplete, please [open an issue](https://github.com/Vidith007/RX-580-CRIMSON-DESERT-FIX/issues)
and it will be corrected.
