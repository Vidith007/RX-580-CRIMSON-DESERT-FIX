# Crimson Desert on a Radeon RX 580

**Crimson Desert refuses to start on AMD Polaris cards.** This makes it run.

[![Download](https://img.shields.io/badge/download-v2.0.0%20%C2%B7%203.7%20MB-2B5A87?style=flat-square)](https://github.com/Vidith007/RX-580-CRIMSON-DESERT-FIX/releases/latest/download/Crimson-Desert-RX580-Fix.zip)
[![Report](https://img.shields.io/badge/read-the%20full%20report-4E6B33?style=flat-square)](https://vidith007.github.io/RX-580-CRIMSON-DESERT-FIX/)
![GPU](https://img.shields.io/badge/GPU-Polaris%20%2F%20GCN4-informational?style=flat-square)
![Game](https://img.shields.io/badge/game-1.14.00-informational?style=flat-square)
![Licence](https://img.shields.io/badge/licence-Apache--2.0%20%2B%20LGPL--2.1-lightgrey?style=flat-square)

<table>
<tr>
<td width="50%" align="center"><img src="docs/paper/figures/before-black.jpg" alt="Before: a black frame. The game never reaches a rendered scene."><br><sub><b>Before</b> — the game never gets past a black frame</sub></td>
<td width="50%" align="center"><img src="docs/paper/figures/after-gameplay-day.jpg" alt="After: gameplay in daylight, terrain, foliage and characters rendering."><br><sub><b>After</b> — gameplay, daylight, full terrain and foliage</sub></td>
</tr>
</table>

The game asks for Direct3D 12 **feature level 12_1** and **native 16-bit float** shaders. An
RX 580 has neither. It's not that the game runs badly on Polaris — it checks, doesn't like the
answer, and stops.

This is a D3D12 translation shim that sits in front of the game, answers those capability
questions differently, and then repairs every place where that answer turns out to be a lie.
There were twelve such places. The game now reaches gameplay and renders correctly in daylight
and at night.

**v2.0.0 is about frame rate.** v1.0.0 made the game run at 15 fps. This release takes it to
**22–24 fps** at 1600×900 on minimum settings, and the card's power draw from 65 W to ~110 W of
its ~150 W budget — because the bottleneck was never the hardware. Emulating a GPU feature
Polaris doesn't have was draining the render pipeline several hundred times a frame, so the card
reported near-100% busy while drawing a third of its rated watts.
[What changed, and what the ceiling now is →](CHANGELOG.md)

---

## Read this before you install

> [!WARNING]
> **If you have an RX 5000 series or newer, do not install this.** RDNA and later report
> feature level 12_1 natively. This fix exists only to paper over gaps that Polaris has and
> newer cards don't — on those cards it can only make things worse.

> [!CAUTION]
> This has been tested on **exactly one machine**: an RX 580 2048SP with 8 GB of system RAM,
> over seven days. It is unofficial, unaffiliated with AMD, Valve or Pearl Abyss, and
> warranted for nothing. **Keep a backup of anything you overwrite.**

---

## Requirements

| | |
|---|---|
| **GPU** | AMD Polaris / GCN4 — RX 470, 480, 570, 580, 580 2048SP, 590 |
| **Driver** | AMD Radeon Software, stock and unmodified. Needs `amdvlk64.dll` present |
| **OS** | Windows 10 or 11, 64-bit |
| **RAM** | 8 GB works but is tight. 16 GB is more comfortable |
| **Game** | Crimson Desert, PC, GameVersion **1.14.00** |

No installer, no registry writes, no game file is modified. Five loose files go into your
`bin64` folder; deleting them puts you exactly back where you started.

---

## Install

### 1. Download and unzip

**[Download Crimson-Desert-RX580-Fix.zip](https://github.com/Vidith007/RX-580-CRIMSON-DESERT-FIX/releases/latest/download/Crimson-Desert-RX580-Fix.zip)** — v2.0.0, 3.7 MB.
Verify it before you use it: [checksums](#verify-your-download). Older versions and full release
notes are on the [releases page](https://github.com/Vidith007/RX-580-CRIMSON-DESERT-FIX/releases).

### 2. Back up first

Open the folder containing `CrimsonDesert.exe` — usually:

```
...\Crimson Desert\bin64\
```

If any file you're about to copy is already there, **move the original into a
`backup-original\` folder.** That's your revert path and it's the only one you get.

### 3. Copy the files in

Copy everything inside `fix\` into `bin64`, so you end up with:

```
...\Crimson Desert\bin64\
    CrimsonDesert.exe                 (already there, untouched)
    d3d12.dll                         <- from fix\
    dxgi.dll                          <- from fix\
    dx12bridge.ini                    <- from fix\
    Play Crimson Desert (RX 580).cmd  <- from fix\
    vkd3d\
        d3d12.dll                     <- from fix\vkd3d\
        d3d12core.dll                 <- from fix\vkd3d\
```

> [!IMPORTANT]
> **Keep the `vkd3d\` subfolder nested.** Line 35 of `dx12bridge.ini` reads
> `RealD3D12=vkd3d\d3d12.dll`. Flatten it and nothing loads.

### 4. Empty the AMD shader cache

Delete the **contents** of this folder — keep the folder itself:

```
%LOCALAPPDATA%\AMD\DxcCache
```

> [!IMPORTANT]
> **This step matters more than any other on this page.** That cache has no size limit. On the
> test machine it reached **4.0 GB**, and the game then committed **30,916 MB against a
> 32,318 MB Windows commit limit** — 805 MB of headroom. The shader-compile worker died
> silently and the game sat on *"Compiling Shaders"* forever, at 82 fps, drawing a black frame.
> It never crashed and never timed out. Emptying the cache dropped peak commit to **8,768 MB**
> and the game started working.

> [!WARNING]
> **Never delete `%LOCALAPPDATA%\AMD\DxCache`** — note the spelling, no second `c`. Different
> folder, held open by the Radeon service.

### 5. Launch

Run **`Play Crimson Desert (RX 580).cmd`** from `bin64`.

It measures both AMD cache folders, empties them only if they're over budget, prints your free
RAM and commit headroom, then starts the game. It refuses to delete anything whose path isn't
literally `...\AMD\DxcCache` or `...\AMD\VkCache`.

It's a plain text file that deletes things. **Open it in Notepad and read it first** — you
shouldn't run a script from a stranger that deletes things, and this one deletes things.
[`fix/cache-guard-notes.md`](fix/cache-guard-notes.md) explains every decision in it.

You can also just start the game normally. The launcher is convenience, not a requirement.

### 6. Expect a slow first launch

Every shader compiles from scratch. Later launches are much faster. Twenty minutes on the
compile screen is not necessarily a hang; forty is.

### Upgrading from v1.0.0?

Overwrite all of it — `d3d12.dll`, `dxgi.dll`, `dx12bridge.ini` and both files in `vkd3d\`.
Don't mix versions: v2.0.0 changes how per-draw shader constants are laid out, and a v1 `d3d12.dll`
against a v2 `d3d12core.dll` is a mismatched interface, not a partial upgrade.

Then **empty `%LOCALAPPDATA%\AMD\DxcCache` and delete `bin64\vkd3d-proton.cache`** before the first
launch. The generated shaders changed, and a cache that still holds the v1 versions will serve
them; that failure mode is wrong-looking geometry rather than an error message. You get one slow
compile launch out of it, once. After that, **leave `vkd3d-proton.cache` alone** — it's what stops
every later launch recompiling from scratch.

---

## Frame rate, and how to get more of it

On the test machine, at **1600×900 on minimum settings**, gameplay sits at **22–24 fps**. v1.0.0
managed 15. That is what it is: this is a 2016 mid-range card running a 2026 title, and after the
v2.0.0 work the card is genuinely at its own ceiling rather than waiting on the translation
layer. Measured during gameplay:

```
GPU core   1300 MHz — full stock boost, no throttling
GPU power  ~110 W of a ~150 W budget
Activity   100%
CPU        8 of 12 logical cores idle
```

Full boost clock, pinned occupancy, three-quarters of the power budget, CPU nowhere near the
limit — **the frame is GPU-bound.** There is no remaining stall to remove; the last two
driver-side optimisations each came in under 3% for that reason, and one of them is written up in
the [changelog](CHANGELOG.md) as a negative result.

So the two levers left are yours, not the driver's:

- **Drop the render resolution.** 1280×720 is 0.64× the pixels of 1600×900 — worth roughly
  **+35–50%** on a frame that is pixel-bound. This is the single biggest thing you can do.
- **Check your memory clock.** The card on the test machine runs its memory at 1500 MHz under
  load, where the driver's own table allows up to 2250 MHz. Some RX 580 2048SP boards genuinely
  ship slower memory, so this may well be stock for yours. A GPU-bound Polaris frame runs out of
  memory bandwidth before it runs out of anything else, so this is where headroom would be if you
  have any.

> [!CAUTION]
> Changing clocks or voltages is overclocking. It can crash, corrupt, or damage hardware, and
> nothing in this repo does it for you or checks whether your board can take it. If you don't
> already know your way around Radeon's tuning tab, use the resolution lever and leave this one
> alone.

Turning settings down inside the game works normally too — none of the usual advice stops
applying just because there's a translation layer underneath.

---

## What doesn't work

Four known defects, stated plainly rather than buried.

**1. The title-screen background is black.** Menu text and UI render; the scene behind them
doesn't. This is diagnosed, not fixed — the background scene is never handed to the GPU at all.
It isn't a broken video: there are zero movie assets of any format in the install and the game
never requests a D3D12 Video interface. Gameplay is unaffected. Chasing it further means
touching the indirect-draw path that took a week to get right.

**2. `StripPSFromDepthOnly` in the ini can't be turned off.** Setting it to `0` produces 36
pipeline refusals and the game dies. Leave it alone.

**3. Some rock and ground textures don't load in certain scenes.** Where it happens the surface
renders untextured rather than invisible, and it is scene-dependent rather than everywhere. Not
yet diagnosed.

**4. Commit headroom is tight on 8 GB.** Mid-gameplay peak commit is 11,773 MB. It works, but
close your browser before playing. More RAM buys load speed, not correctness — that was
measured, not assumed.

Foliage smearing during motion was investigated and is a frame-rate artifact, not a rendering
defect.

---

## If it goes wrong

| Symptom | Fix |
|---|---|
| **Stuck on "Compiling Shaders" forever** | Empty `%LOCALAPPDATA%\AMD\DxcCache` again and close everything else. Under 4,000 MB of available commit is the danger zone. This is the most likely failure and the easiest fix. |
| **Game exits immediately, or errors about D3D12** | Confirm `vkd3d\` survived the copy with *both* DLLs inside, and that `dx12bridge.ini` sits next to `d3d12.dll`, not inside `vkd3d\`. |
| **Worked, then stopped after you edited the ini** | Restore `dx12bridge.ini` from this package. Several levers in it are load-bearing and their failure mode is death at the compile screen, not a warning. |
| **Black or corrupted geometry that used to be fine** | Move `%LOCALAPPDATA%\AMD\DxcCache` and any vkd3d pipeline cache aside. Some changes here alter shader behaviour without changing anything a pipeline cache hashes, so a stale cache serves pipelines built for an older interface. It fails silently and wrongly rather than loudly. |
| **Nothing above helped** | Delete the files you copied, restore your backup. You're exactly where you started — that's the whole point of shipping five loose files. |

Still stuck? [Open an issue](https://github.com/Vidith007/RX-580-CRIMSON-DESERT-FIX/issues) and
include your exact GPU, driver version, RAM, and the line the launcher printed for
*commit available*.

---

## How it works

<table>
<tr>
<td width="50%" align="center"><img src="docs/paper/figures/before-compile-wedge.jpg" alt="The Compiling Shaders screen, wedged."><br><sub>The commit-limit wall — 82 fps, black frame, forever</sub></td>
<td width="50%" align="center"><img src="docs/paper/figures/after-gameplay-night.jpg" alt="After: night-time gameplay rendering correctly."><br><sub>Night-time gameplay after the twelve fixes</sub></td>
</tr>
</table>

The game talks to `d3d12.dll`. This package replaces that file with a shim that forges the
capability answers, then forwards everything to [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton),
which translates D3D12 into Vulkan for AMD's driver. Both the shim and vkd3d-proton are patched
to work around things the Polaris shader compiler gets wrong and to emulate hardware features the
card doesn't have — 12 files of vkd3d-proton, about 2,000 lines, all of it shipping as a patch in
[`source/`](source/).

A few of the twelve faults, to give a flavour of what "make it run" actually meant:

- Reading `gl_HelperInvocation` more than about a hundred times in one shader makes the Polaris
  compiler fault while walking its own use-list. Collapsing those reads to one fixed 11 of 11
  crashing shaders with zero regressions across 402 modules.
- 337 fragment shaders were being emitted as **invalid SPIR-V** — an fp16 demotion pass rewrote
  a type inside a bitcast without rewriting the bitcast.
- Shaders declared `FragmentShadingRateKHR`, a capability the card doesn't have, and never used
  it. Stripping the dead declaration took pipeline refusals from 9 to 0.
- 5,281 of 5,284 GPU command signatures were being silently dropped because Polaris has no
  device-generated-commands support, so most indirect draws never happened. Emulating them took
  indirect draws from 14 to 255 per frame.

And the frame-rate work in v2.0.0, which is the same story one layer down — the emulation that
made those draws happen at all was doing it extremely expensively:

- Emulating per-draw GPU commands means a compute pass that writes draw arguments, then the draws
  that read them. That ordering **ended and restarted the render pass on every single call** —
  **685,335 full GPU pipeline drains in one session.** Batching the calls so a group of N costs
  one drain instead of N cut drains per call **4.5×**, and that is the change that moved the frame
  rate.
- The unrolling loop ran to the *declared* maximum command count instead of the count the GPU
  actually produced: **1.43 billion unrolled draws in one session, 612 per call.** Collapsing them
  into multi-draws turned **~2.18 billion Vulkan calls into ~8.5 million** with nothing dropped.
- That collapse made every vertex shader read the `DrawIndex` builtin, which is the *same* Polaris
  use-list fault as `gl_HelperInvocation` reached through a different builtin, and it broke 787
  shaders. Hoisting on storage class rather than on a list of known builtins took them to **0**.

**[Read the full report →](https://vidith007.github.io/RX-580-CRIMSON-DESERT-FIX/)** — all twelve
root causes with the measurement that decided each one, a layer-by-layer architecture diagram,
the 48 hypotheses that turned out to be wrong, and the complete code footprint. It's also in
this repo at [`docs/index.html`](docs/index.html) if you'd rather open it locally. The report
covers the v1.0.0 work that made the game run; the v2.0.0 frame-rate work is written up in the
[changelog](CHANGELOG.md), including the two changes that were measured and *rejected*.

---

## Verify your download

Especially if you got this from anywhere other than this repo. These are the seven files that
actually go on your disk, for **v2.0.0**:

```
af05b86592ce5a039e338e3572d7fd130641d93be61e1f5b72a817ab4bee048d  fix/d3d12.dll
c06ce3c4d327780915d857beeebe9c196cb4a59d306504b42a5f76df06307cfb  fix/dxgi.dll
d528a268a04135018337961d3d47f06569c420ff59695ea10c08c1318c1a8de5  fix/dx12bridge.ini
d029c5e774ece6220392c123ed5f9d8baddc7ee2977c9bdc59f53c050d64b6fe  fix/Play Crimson Desert (RX 580).cmd
66366c7a3aa99a9883371e57f2a44dc3ae2c66fdd6391fabd4b65992dee27184  fix/vkd3d/d3d12.dll
dc5eb5ba26908382535e91f7e724f0e489d581378815e5b312ec8cebf59b7e65  fix/vkd3d/d3d12core.dll
ddc4df087de610919f90dd6f0f4c463cf65da2fa8b7658c496745cc3af38b278  source/vkd3d-proton-3.0.1-rx580-polaris.patch
```

In PowerShell, from the folder you unzipped into:

```powershell
Get-FileHash -Algorithm SHA256 .\fix\d3d12.dll, .\fix\vkd3d\d3d12core.dll
```

**The archive's own SHA-256** is published in
[`SHA256SUMS.txt`](SHA256SUMS.txt) here in the repo and in the release notes on the
[releases page](https://github.com/Vidith007/RX-580-CRIMSON-DESERT-FIX/releases) — deliberately
not in this file, because this file ships *inside* the archive and could not state the archive's
hash without being one build out of date every time. Check it there, against a copy you did not
get from the same download.

---

## What's in this repo

```
fix/                      the five files that go in bin64, plus the launcher
fix/licenses/             upstream licence texts, unedited
source/                   the modified vkd3d-proton source, as a patch
docs/index.html           the full engineering report
docs/paper/figures/       before/after captures
CHANGELOG.md              what changed in each release, with the measurements
INSTALL.md                the long-form install guide
THIRD-PARTY-NOTICES.md    who owns what in here
Crimson-Desert-RX580-Fix.zip   everything above, packaged
```

---

## Credit

Almost none of the hard parts of this stack were written for this fix. It is a small correction
applied to an enormous amount of other people's work.

- **[Józef Kucia](https://www.winehq.org/news/2020082401)** (1985–2020), who wrote vkd3d and
  led it until his death. Nothing here exists without his work.
- **Hans-Kristian Arntzen**, for [vkd3d-proton](https://github.com/HansKristian-Work/vkd3d-proton)
  and [dxil-spirv](https://github.com/HansKristian-Work/dxil-spirv).
- **Philip Rebohle** and **Joshua Ashton**, core vkd3d-proton maintainers.
- **All vkd3d-proton contributors** — the unedited `AUTHORS` file ships in
  [`fix/licenses/`](fix/licenses/).
- **Valve Corporation**, which funds the work that makes D3D12 games run on Vulkan at all.
- **Pearl Abyss** made Crimson Desert. No file of theirs is modified or redistributed here.

AMD's Vulkan driver is stock and unmodified.

## Licences

This repo carries three different licences and it matters which is which — see
**[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)** for the full breakdown.

- **Original work here** (the shim, the launcher, the report, the docs) — Apache-2.0, see [`LICENSE`](LICENSE).
- **`fix/vkd3d/d3d12core.dll` and `fix/vkd3d/d3d12.dll`** — vkd3d-proton, **LGPL-2.1-or-later**,
  and these are *modified* builds. The corresponding source ships alongside them as
  [`source/vkd3d-proton-3.0.1-rx580-polaris.patch`](source/vkd3d-proton-3.0.1-rx580-polaris.patch),
  against upstream v3.0.1, which is what LGPL sections 4 and 6 require.
- **dxil-spirv**, vendored inside that build — MIT.

Apache-2.0 does **not** and cannot cover the vkd3d-proton binaries. They stay LGPL.
