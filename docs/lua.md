# Lua

TJAPlayer6 has the ability to set a lua script for background elements, ala ITG. 
This is done via the `BGCHANGES` header in a TJA file.

```
// Points to a lua script relative to the tja path
BGCHANGES:fuuuuuck_i_hate_it.lua
```

Currently, you have full access to every singleton and utility function Godot has, including the OS singleton.
This may change to prevent malicious code from running.

Specific functions exist to add elements to the "stage", accessible via the `tp6` library.

## `tp6.add_to_stage`

Adds a `Node` object to the stage. Removed on song change.

```lua
tp6.add_to_stage(node)
```

## `tp6.create_sprite`

Creates and returns a `Sprite2D` object with a texture specified by a path. <br>
The path specified is relative to the lua script's path.

```lua
local sprite = tp6.create_sprite("fuck.png")
-- If the path to the image doesn't exist it simply doesn't make the image.
tp6.add_to_stage(sprite)
```