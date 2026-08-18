# Why `Play Crimson Desert (RX 580).cmd` exists

## The problem

Crimson Desert on an RX 580 pushes an enormous number of shaders through the
AMD driver, and the driver caches every compiled result in
`%LOCALAPPDATA%\AMD\DxcCache`. That folder has no size limit. It just grows.

On this machine it reached **4.0 GB**. At that size the game process committed
**30,916 MB** against a Windows commit limit of **32,318 MB** — only 805 MB of
headroom left. The game's shader-compile worker then died without an error
message, and the game sat on the "Compiling Shaders" screen forever, drawing a
black frame at 82 fps. It never timed out and never crashed; it just waited.

Emptying `DxcCache` took peak commit from **30,916 MB down to 8,768 MB**, and
the game reached actual gameplay. That is the whole fix.

## What the launcher deletes

Before starting the game it measures two folders and empties them only if they
are over budget:

| Folder | Default limit |
| --- | --- |
| `%LOCALAPPDATA%\AMD\DxcCache` | 1500 MB |
| `%LOCALAPPDATA%\AMD\VkCache` | 512 MB |

It deletes the *contents* and keeps the folders, so the driver does not have to
recreate them. Nothing else is ever touched — before deleting anything it
checks that the path really sits under `...\AMD\` and that the final folder name
is exactly `DxcCache` or `VkCache`. In particular it never touches
`%LOCALAPPDATA%\AMD\DxCache` (no second "c"), a different folder the Radeon
service keeps open. If a file is locked, the delete is skipped and the game
still starts.

## Why deleting is safe

Both folders are pure caches owned by the graphics driver. The driver rebuilds
them by itself. Your game files, saves and settings are untouched. The only
cost is that the first launch after a clean is slower, because shaders have to
compile again.

## Changing the thresholds

Set either variable before running the launcher; no need to edit the file:

    set RX580_DXC_LIMIT_MB=800
    set RX580_VK_LIMIT_MB=256

Use a huge number to effectively disable cleaning.

## Skipping the launcher

You do not need it. Deleting the contents of `%LOCALAPPDATA%\AMD\DxcCache` by
hand in Explorer, whenever it gets large, does exactly the same job. The
launcher only saves you from remembering.

Each run appends one line to `%LOCALAPPDATA%\AMD\rx580-cache-guard.log`
recording the sizes it found and whether it cleaned.
