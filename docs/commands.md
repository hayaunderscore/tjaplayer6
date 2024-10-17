# Exclusive TJA Commands

This does not include the base commands a standarized TJA already has.

## `#SPEED`

Suddenly changes the scrolling **speed** of the notes and barlines.

Uses the proposal found [here.](https://iepiweidieng.github.io/TJAPlayer3/tja/#proposal-iid-speed)

## `#GRADSPEED`

Changes the scrolling **speed** of the notes and barlines **grad**ually.

- `#GRADSPEED <float-base-speed-x>,<approach-duration-specifier>,<ease-type>`
   - Valid ease types are:
       `LINEAR` (default)
       `SINE`
       `EXPO`
       `CUBIC`
       `ELASTIC`
       `QUAD`

- `#GRADSPEED <complex-ri-float-base-speed-xy>,<approach-duration-specifier>,<ease-type>`
   - The imaginary component of `<complex-ri-float-base-speed-xy>` specifies the vertical normal scrolling speed from the top to the bottom of the screen (↓). The unit is the same as `<float-base-speed-x>`.

## `#REVERSE`

**Reverse**s the position of the judgement line from the left to the right, from 0-100.
This also moves the position of the notes from moving to the left to the right. Similar to the ITG modifier of the same name.

- `#REVERSE <value-percent>,<approach-duration-specifier>,<ease-type>`
   - Refer to the ease types on `#GRADSPEED`.
   - A percentage value of 50 will move the notes and judgement line to the center.

## `#DUMMYNOTEADD`

**Add**s a **dummy note** at a time position in seconds.

- `#DUMMYNOTEADD <enum-int-note-type>,<time>`
   - Roll note types do not add the roll itself.

## `#DUMMYOFFSET`

**Offset**s the next **dummy** notes by the amount of pixels specified.

- `#DUMMYOFFSET <value-pixels>`
   - Does not move the time position of the dummy note. Why would it?