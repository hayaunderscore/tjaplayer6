# TJAPlayer6

<img src="icon.png" alt="uh hello" width="64" height="64" style="display: block; float:left; margin-left: 10px;"/>

A Taiko simulator built with Godot 4.3, named after numerous TJAPlayer offshoots. Meant to replicate the look of <ruby>太<rt>Tai</rt> 鼓<rt>ko</rt> さ<rt>sa</rt> ん<rt>n</rt> 次<rt>Ji</rt> 郎<rt>rou</rt></ruby> (TaikoJiro).

Aims to be fully compatible with <ruby>太<rt>Tai</rt> 鼓<rt>ko</rt> さ<rt>sa</rt> ん<rt>n</rt> 次<rt>Ji</rt> 郎<rt>rou</rt></ruby> (TaikoJiro) notecharts.

Does not use DTXMania as a base.

# What works

- Basic TJA behavior (full note type support, kusadamas are replaced with balloons)
- Note types used in the OpenTaiko-Outfox standard
- Scroll and BPM/Measure changes
- Complex y-scroll, with roll support
- BMS scroll via `#BMSCROLL` and `#HBSCROLL`
- Playability (with scoring)

# What doesn't

- Branches
- Commands TJAP2fPC/TJAP3 specific (`#SUDDEN`, `#JPOSSCROLL`)
  - All quirks from those are also not replicated (such as `#DELAY` not having a stop effect on BMS scroll)
  - TJAP2fPC's y-scroll flipping behavior is currently present, however.
- Song select
- Results screen
- Soul gauge

# References

- IID's TJA documentation (https://iepiweidieng.github.io/TJAPlayer3/tja/)
- Yonokid's PyTaiko (https://github.com/Yonokid/PyTaiko)
- mc08's SplitlaneTaiko (https://github.com/splitlane/SplitlaneTaiko)
- TaiClone's (incomplete) TJA loader (https://github.com/rokuhime/TaiClone/blob/dev/scripts/chart_loader.gd)

# License

This simulator is under the MIT License.

