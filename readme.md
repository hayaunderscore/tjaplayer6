# TJAPlayer6

<img src="icon.png" alt="uh hello" width="64" height="64" style="display: block; float:left; margin-left: 10px;"/>

A Taiko simulator built with Godot 4.3, named after numerous TJAPlayer offshoots, meant to replicate the look of TaikoJiro 1. Work in progress!

Does not use DTXMania as a base.

# What works

- Basic TJA behavior (full note type support, except kusadamas)
- Scroll and BPM/Measure changes
- Complex y-scroll, with roll support
- `#HBSCROLL`

# What doesn't

- Branches
- Note types used in the OpenTaiko-Outfox standard
- Commands TJAP2fPC/TJAP3 specific (`#SUDDEN`, `#JPOSSCROLL`)
  - TJAP2fPC's y-scroll flipping behavior is currently present, however.
- Song select
- Results screen
- Soul gauge
- Judgements
- Playability (currently autoplay only)

# References

- IID's TJA documentation (https://iepiweidieng.github.io/TJAPlayer3/tja/)
- PyTaiko (https://github.com/Yonokid/PyTaiko)
- TaiClone's (incomplete) TJA loader (https://github.com/rokuhime/TaiClone/blob/dev/scripts/chart_loader.gd)

# License

This simulator is under the MIT License.

