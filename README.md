# RT-DotReticle

A small PAYDAY 3 UE4SS Lua mod that replaces the standard four-bar crosshair
and its directional spread indicators with the game's built-in center dot.

## Installation

Place the `RT-DotReticle` folder in `UE4SS/Mods`. The included `enabled.txt`
enables the mod automatically.

## Dot size

Open `scripts/main.lua` and change `DOT_SIZE` near the top of the file. The
default is `4.0`.

The mod preserves the reticle visibility and colors selected in PAYDAY 3. It
does not change hit markers or other HUD elements.
