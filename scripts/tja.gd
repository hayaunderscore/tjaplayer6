extends Resource
class_name TJAFile

## COSMETIC
var title: String
var alttitle: String
var subtitle: String
var maker: String
var demo_start: float = 0.0
var head_scroll: float = 1.0
var bgchanges: String

## TIMING
var start_bpm: float = 120.0
var offset: float = 0.0
var wave: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file("res://snd/silence.ogg")

## CHARTS
var chartinfo: Array[ChartData]
