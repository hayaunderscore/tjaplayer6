extends Resource
class_name ChartData

enum CourseType {
	EASY,
	NORMAL,
	HARD,
	ONI,
	EDIT # Or Ura-Oni
}

enum NoteType {
	NONE,
	DON,
	KAT,
	BIG_DON,
	BIG_KAT,
	ROLL,
	BIG_ROLL,
	BALLOON,
	END_ROLL,
	KUSADAMA,
	# OpenTaiko-Outfox standard
	SWAP,	# G
	BOMB,	# C
	FUSE,	# D
	ADLIB,	# F
	# Special "notes" (starts at 999)
	BARLINE = 999, # Yes. A barline is a notetype.
	GOGOSTART,
	GOGOEND,
}

enum CommandType {
	BPMCHANGE,
	MEASURE,
	DELAY,
	SCROLL,
	SPEED,
	REVERSE
}

var course: int = CourseType.ONI
var level: int
# Default values according to TJAPlayer3
var scoreinit: PackedInt32Array = [300, 1000] 
var scorediff: int = 120
var scoremode: int = ScoreManager.ScoreType.AC14
var style: int = 0 # TODO
var balloons: PackedFloat64Array
var bemani_scroll: bool = false
var disable_scroll: bool = false

# Format for these goes like this
# {time_in_ms, scroll, type_of_note, big_note}
var notes: Array[Dictionary]
var specil: Array[Dictionary]
# {command_type, value1, value2}
var command_log: Array[Dictionary]
var bpm_log: Array[Dictionary]
var positive_delay_log: Array[Dictionary]
# Draw data
var note_draw_data: Array[Dictionary] # Phased out in favor of below
var draw_data: Dictionary
var barline_data: Array[Dictionary]
