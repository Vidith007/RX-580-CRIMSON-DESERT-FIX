# Crimson Desert on a Radeon RX 580

A Direct3D 12 translation shim that makes **Crimson Desert** run on **AMD Polaris**
(RX 470/480/570/580/590, including the RX 580 2048SP) — hardware the game refuses
to start on, because it asks for D3D12 feature level 12_1 and native 16-bit float
support that Polaris does not have.

The game reaches gameplay and renders correctly in daylight and at night, with no
missing or substituted textures. Read **[what doesn't work](#what-doesnt-work)**
before you install it.

The full engineering report — twelve root causes, the architecture diagram, the
forty-eight hypotheses that turned out to be wrong, and all credits — is in
**`index.html`**. Open it in any browser; it needs no server.

---

## Requirements

| | |
|---|---|
| **GPU** | AMD Polaris / GCN4 — RX 470, 480, 570, 580, 580 2048SP, 590 |
| **Driver** | AMD Radeon Software with `amdvlk64.dll` present (stock, unmodified) |
| **OS** | Windows 10 or 11, 64-bit |
| **RAM** | 8 GB works. 16 GB is more comfortable — see [headroom](#3-not-enough-commit-headroom) |
| **Game** | Crimson Desert, PC, GameVersion 1.14.00 |

**On RDNA (RX 5000) or newer you do not need this and it will make things worse.**
Those cards report feature level 12_1 natively. This fix exists only to paper over
gaps that Polaris has and they don't.

This has been tested on **one** machine: an RX 580 2048SP with 8 GB of system RAM.
Treat it accordingly.

---

## Install

### 1. Back up first

Open your game's `bin64` folder — the one containing `CrimsonDesert.exe`. If any
file you are about to copy already exists there, **move the original into a
`backup-original\` folder first.** That is your revert path, and it is the only
one you get.

This is not boilerplate caution. The report has an entire section (fault 10) about
an evening lost to a revert that checked three files out of four.

### 2. Copy the files

Copy everything inside `fix\` into your `bin64` folder, so you end up with:

```
...\Crimson Desert\bin64\
    CrimsonDesert.exe               (already there, untouched)
    d3d12.dll                       <- from fix\
    dxgi.dll                        <- from fix\
    dx12bridge.ini                  <- from fix\
    Play Crimson Desert (RX 580).cmd  <- from fix\
    vkd3d\
        d3d12.dll                   <- from fix\vkd3d\
        d3d12core.dll               <- from fix\vkd3d\
```

**Keep the `vkd3d\` subfolder.** Line 35 of `dx12bridge.ini` reads
`RealD3D12=vkd3d\d3d12.dll`. Flatten the folder and the chain breaks.

### 3. Empty the AMD shader cache — do not skip this

Delete the **contents** of:

```
%LOCALAPPDATA%\AMD\DxcCache
```

Keep the folder, delete what's inside it. Paste that path into Explorer's address
bar if you can't find it.

> **Why this matters more than anything else on this page.** That cache has no size
> limit. On the test machine it reached 4.0 GB, and the game then committed
> 30,916 MB against a 32,318 MB Windows commit limit — 805 MB of headroom. The
> shader-compile worker died silently and the game sat on "Compiling Shaders"
> forever, at 82 fps, drawing a black frame. It never crashed and never timed out.
> Emptying the cache dropped peak commit to 8,768 MB and the game started working.

> **Never delete `%LOCALAPPDATA%\AMD\DxCache`** — no second `c`. Different folder,
> held open by the Radeon service.

### 4. Launch

Run **`Play Crimson Desert (RX 580).cmd`** from the `bin64` folder.

It measures both AMD cache folders, empties them only if they're over budget
(1500 MB for `DxcCache`, 512 MB for `VkCache`), prints your free RAM and commit
headroom, and then starts the game. It logs one line per run to
`%LOCALAPPDATA%\AMD\rx580-cache-guard.log`.

It is a plain text file. **Open it in Notepad and read it before you run it** —
you should not run a script from a stranger that deletes things, and this one
deletes things. `cache-guard-notes.md` explains every decision in it.

If the launcher can't find your game, it says so and launches nothing. Either copy
it next to `CrimsonDesert.exe`, or edit the `GAME_EXE=` line near the top.

You can also just start the game normally. The launcher is convenience, not a
requirement.

### 5. The first launch is slow

Every shader compiles from scratch. Later launches are much faster. Twenty minutes
on the compile screen is not necessarily a hang; forty is.

---

## Uninstall

Delete the files you copied and restore anything from `backup-original\`. Nothing
was written to your registry, nothing was installed, and no game file was modified.

---

## Verify the download

Check these before copying anything into a game folder — especially if you got
this package from someone other than the person who built it.

```
57aa85ab362b9080426169bfca52a4dc  fix\d3d12.dll                        3,601,660
451a89e5f0420b96fdad6633d7d79daa  fix\dxgi.dll                           191,287
1e6911ad101b1f61075b6ad730f4d4ab  fix\dx12bridge.ini                      56,376
a9b2709459cf2573f5dc7b81ecaf7763  fix\Play Crimson Desert (RX 580).cmd    12,050
d72e6f233b1b9ccc8bb6ea4d609b822a  fix\vkd3d\d3d12.dll                    267,221
4cf0f1fa948a07366317b405d88436c6  fix\vkd3d\d3d12core.dll              8,847,126
4a146905d103bdfcbc8617a96658bb95  source\vkd3d-proton-3.0.1-rx580-polaris.patch
```

In PowerShell:

```powershell
Get-FileHash -Algorithm MD5 .\fix\d3d12.dll, .\fix\dxgi.dll, .\fix\vkd3d\d3d12core.dll
```

---

## What doesn't work

Three known defects, stated plainly.

### 1. The title-screen background is black

The menu text and UI render; the scene behind them does not. **This is diagnosed,
not fixed.** It is not a broken video — there are zero movie assets of any format
in the install, no Bink or Media Foundation DLLs, and the game never requests a
D3D12 Video interface. The command stream shows the title screen submitting the
same near-empty UI workload as the compile screen (about 3 direct and 30 indexed
draws per frame), and there is no step up anywhere inside the black stretch. The
background scene is never handed to the GPU at all.

Chasing it further means touching the indirect-draw path that took a week to fix.
That trade wasn't worth it. Gameplay is unaffected.

### 2. Depth-only pixel-shader stripping can't be turned off

`StripPSFromDepthOnly` in the ini is load-bearing. Setting it to `0` produces 36
pipeline refusals and the game dies. Leave it alone.

### 3. Not enough commit headroom

Mid-gameplay peak commit is 11,773 MB. On 8 GB of RAM that leaves about 3,100 MB
available — it works, but it's tight, and `DxcCache` regrows every launch. Close
browsers before playing. If your commit-available number is under 4,000 MB, the
launcher warns you.

More RAM buys load speed, not correctness. That was measured, not assumed.

### Not on the list

Foliage smearing during motion was investigated and is a frame-rate artifact, not
a rendering defect.

---

## If it goes wrong

**Stuck on "Compiling Shaders" forever.**
Empty `%LOCALAPPDATA%\AMD\DxcCache` again, close everything else, and check the
commit-available number the launcher prints. Under 4,000 MB is the danger zone.
This is the single most likely failure and the single easiest fix.

**Game exits immediately, or reverts to an error about D3D12.**
Confirm the `vkd3d\` subfolder survived the copy with both DLLs inside it, and that
`dx12bridge.ini` sits next to `d3d12.dll` rather than inside `vkd3d\`.

**It worked, then stopped after you changed a setting in the ini.**
Restore `dx12bridge.ini` from this package. Several levers in it are load-bearing
and their failure mode is death at the compile screen, not a warning.

**Black or corrupted geometry that used to be fine.**
Move `%LOCALAPPDATA%\AMD\DxcCache` and any vkd3d pipeline cache aside. Some changes
in this stack alter shader behaviour without changing anything a pipeline cache
hashes, so a stale cache can serve pipelines built for an older interface. It fails
silently and wrongly rather than loudly.

**Nothing above helped.** Delete the files you copied, restore your backup, and
you're exactly where you started. That's the whole point of shipping it as five
loose files.

---

## What's in this package

```
index.html                          the full engineering report — start here
README.md                           this file
fix\                                the five files that go in bin64
fix\Play Crimson Desert (RX 580).cmd  cache guard + launcher
fix\cache-guard-notes.md            why the launcher deletes what it deletes
fix\licenses\                       LGPL-2.1 and MIT texts for upstream projects
source\...-rx580-polaris.patch      modified vkd3d-proton source (LGPL obligation)
paper\figures\                      before/after captures used by the report
```

---

## Licences and credit

Almost none of the hard parts of this stack were written for this fix. It is a
small correction applied to an enormous amount of other people's work.

**vkd3d-proton** — LGPL-2.1-or-later. The `d3d12core.dll` here is a **modified**
build, so sections 4 and 6 require the corresponding modified source to ship with
it. It does: `source\vkd3d-proton-3.0.1-rx580-polaris.patch`, against upstream
v3.0.1. Verified two ways — `patch -p1 --dry-run` exits clean on a fresh upstream
tree, and after applying, all nine modified files reproduce byte-for-byte.

```bash
patch -p1 < vkd3d-proton-3.0.1-rx580-polaris.patch
```

**dxil-spirv** — MIT, "Copyright (c) 2019-2022 Hans-Kristian Arntzen for Valve
Corporation", pinned at `62dbb07f771534c8ce924479efdc6c8fa510361d`. Four files
carry local fp16 changes (+227 / −8), all inert at runtime because the ini leaves
those levers off, so the shipped build behaves as pristine upstream. Vendored
bc-decoder (Baldur Karlsson) and glslang (The Khronos Group) are MIT and their
notices ship inside it. SPIRV-Cross, SPIRV-Tools and SPIRV-Headers are byte-clean.

**AMD's Vulkan driver is stock and unmodified.**

**No Crimson Desert file is modified or redistributed.** Pearl Abyss made the game;
this package contains none of it.

Credit where it belongs:

- **Józef Kucia** (1985–2020), who wrote vkd3d and led it until his death. Nothing
  here exists without his work.
- **Hans-Kristian Arntzen**, for vkd3d-proton and dxil-spirv.
- **Philip Rebohle** and **Joshua Ashton**, core vkd3d-proton maintainers.
- **All vkd3d-proton contributors** — the unedited `AUTHORS` file ships in
  `fix\licenses\`.
- **Valve Corporation**, which funds the work that makes D3D12 games run on Vulkan.

Full acknowledgements, including the person who ran every one of the dozens of
cold-cache launches this required, are in `index.html`.

---

## Honest disclaimer

This is unofficial, unaffiliated with AMD, Valve or Pearl Abyss, and warranted for
nothing. It was built and tested on exactly one RX 580 in one machine over seven
days. It might not work on yours.

Keep your backup.
