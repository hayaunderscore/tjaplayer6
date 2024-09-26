extends Node

static func _find_value(line: String, key: String, value := "", overwrite := false) -> String:
	return line.trim_prefix(key).strip_edges() if line.begins_with(key) and not (overwrite and value) else value

# https://github.com/Yonokid/PyTaiko/blob/8164a71b451311e7a6790e68055062745fc9dc38/global_funcs.py#L134C1-L138C45
func get_pixels_per_frame(bpm, fps, time_signature, distance):
	var beat_duration = fps / bpm
	var total_time = time_signature * beat_duration
	var total_frames = fps * total_time
	return (distance / total_frames) * (fps/60)

var screen_distance: float = (640 * 1) - 148
var screen_distance_y: float = 640 - 148
	
func parse_tja(path: String):
	print("Parsing tja on %s....." % path)
	if not FileAccess.file_exists(path):
		print("%s doesn't exist....." % path)
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	
	# {time_in_ms, scroll, type_of_note, big_note}
	var cur_note: Dictionary
	var barlines: bool = true
	var should_read_metadata: bool = true
	var notes_in_measure: int = 0
	var cur_bpm: float = 0.0
	var cur_meter: float = 4 * 4 / 4
	var time: float = 0.0
	var last_scrollers: Vector2 = Vector2.ZERO
	var cur_scroll: float = 1.0
	var cur_scrolly: float = 0.0
	
	var tjaf: TJAFile = TJAFile.new()
	var cur_chart: ChartData
	
	# Track these
	var course: int = ChartData.CourseType.ONI
	var level: int
	# Default values according to TJAPlayer3
	var scoreinit: Array[int] = [300, 1000] 
	var scorediff: int = 120
	var style: int = 0 # TODO
	var balloons: PackedFloat64Array
	
	var measures: Array[String]
	var cont_measure: bool = false
	var bemani_scroll: bool = false
	var disable_scroll: bool = false
	
	while file.get_position() < file.get_length():
		# Current line
		var line: String = file.get_line().strip_edges()
		# Empty or comment
		if line.is_empty() or line.begins_with("//"):
			continue
		
		if should_read_metadata:
			if line.begins_with("#START"):
				should_read_metadata = false
				cur_bpm = tjaf.start_bpm
				time = -tjaf.offset
				cur_scroll = tjaf.head_scroll
				cur_chart = ChartData.new()
				cur_chart.course = course
				cur_chart.level = level
				cur_chart.balloons = balloons
				if tjaf.alttitle.is_empty():
					tjaf.alttitle = tjaf.title
			else:
				tjaf.title = _find_value(line, "TITLE:", tjaf.title)
				if tjaf.alttitle.is_empty():
					tjaf.alttitle = _find_value(line, "TITLEJA:", "")
				tjaf.subtitle = _find_value(line, "SUBTITLE:", tjaf.subtitle)
				tjaf.maker = _find_value(line, "MAKER:", tjaf.maker)
				tjaf.demo_start = float(_find_value(line, "DEMOSTART:", str(tjaf.demo_start)))
				tjaf.head_scroll = float(_find_value(line, "HEADSCROLL:", str(tjaf.head_scroll)))
				tjaf.start_bpm = float(_find_value(line, "BPM:", str(tjaf.start_bpm)))
				tjaf.offset = float(_find_value(line, "OFFSET:", str(tjaf.offset)))
				var wpath: String = path.get_base_dir() + "/" + _find_value(line, "WAVE:", "audio.ogg")
				if FileAccess.file_exists(wpath):
					tjaf.wave = AudioStreamOggVorbis.load_from_file(wpath)
					tjaf.wave.take_over_path(wpath)
				
				if line.begins_with("#BMSCROLL"):
					bemani_scroll = true
					disable_scroll = true
				elif line.begins_with("#HBSCROLL"):
					bemani_scroll = true
					print("bemani scroll!")
					disable_scroll = false
				
				# Handle chart specific metadata
				if line.begins_with("COURSE:"):
					var cname = _find_value(line, "COURSE:", str(course))
					if cname.is_valid_int():
						course = int(cname)
					else:
						match cname.to_lower():
							"easy":
								course = 0
							"normal":
								course = 1
							"hard":
								course = 2
							"oni":
								course = 3
							"edit":
								course = 4
				if line.begins_with("LEVEL:"):
					level = int(_find_value(line, "LEVEL:", str(level)))
				# No score diff and init for now... deal with that laterer
				if line.begins_with("BALLOON:"):
					balloons = _find_value(line, "BALLOON:").split_floats(",")
			continue
		
		# Chart has ended, read metadata again
		if line.begins_with("#END"):
			var sorted: Array[Dictionary] = cur_chart.notes.duplicate(true)
			sorted = sorted.filter(func(a): return a["note"] < 999)
			# sorted.sort_custom(func(a, b): a["time"] < b["time"])
			cur_chart.note_draw_data = sorted.duplicate(true)
			cur_chart.bemani_scroll = bemani_scroll
			cur_chart.disable_scroll = disable_scroll
			tjaf.chartinfo.append(cur_chart)
			should_read_metadata = true
			continue
		
		# SORRY NOTHING
		if line.is_empty():
			continue
		
		# Add a barline.
		# This is early to account for scroll specific issues ffs
		if barlines and not line.begins_with("#") and not cont_measure:
			var bpm: float = cur_bpm
			if bemani_scroll: bpm = tjaf.start_bpm
			var px_perframe: float = get_pixels_per_frame(bpm * (cur_meter / 4) * cur_scroll, 60, cur_meter, screen_distance)
			var load_ms: float = time - (screen_distance / px_perframe / 60)
			cur_chart.barline_data.append({"time": time, "scroll": cur_scroll, "meter": cur_meter, "note": ChartData.NoteType.BARLINE, "load_ms": load_ms, "ppf": px_perframe})
		
		# Handle current line stuff
		measures.append(line)
		var nline: String = ""
		var lpos: int = file.get_position()
		# Continue in next line until we hit a measure terminator
		if not line.ends_with(",") and not line.begins_with("#") and not cont_measure:
			notes_in_measure += line.trim_suffix(",").length()
			# print("continue to next line...")
			cont_measure = true
			while not nline.ends_with(","):
				nline = file.get_line().strip_edges()
				if not nline.begins_with("#"):
					notes_in_measure += nline.trim_suffix(",").length()
			# print("done! seek back to... ", lpos, " from ", file.get_position())
			file.seek(lpos)
		elif line.ends_with(",") and not cont_measure:
			# print("at: " + str(file.get_position()) + ", seek measure....")
			notes_in_measure += line.trim_suffix(",").length()
		# -1 means nothing lol
		if line.begins_with("#") and not cont_measure:
			# print("reset measure length")
			notes_in_measure = -1
		if line.ends_with(","):
			cont_measure = false
		
		# Handle commands and note addition.
		for l in measures:
			match l:
				"#GOGOSTART":
					cur_chart.notes.append({"time": time, "scroll": cur_scroll, "note": ChartData.NoteType.GOGOSTART, "load_ms": 0, "ppf": 0})
				"#GOGOEND":
					cur_chart.notes.append({"time": time, "scroll": cur_scroll, "note": ChartData.NoteType.GOGOEND, "load_ms": 0, "ppf": 0})
				_:
					if l.begins_with("#"):
						## Comment
						if l.begins_with("#BARLINEOFF"):
							barlines = false
						elif l.begins_with("#BARLINEON"):
							barlines = true
							print("turned on")
						var command_value := _find_value(line, "#BPMCHANGE")
						if command_value:
							cur_bpm = float(command_value)
							cur_chart.command_log.append({"time": time, "com": ChartData.CommandType.BPMCHANGE, "val1": cur_bpm})
						command_value = _find_value(line, "#DELAY")
						if command_value:
							time += float(command_value)
							cur_chart.command_log.append({"time": time, "com": ChartData.CommandType.DELAY, "val1": command_value})
						command_value = _find_value(line, "#MEASURE")
						if command_value:
							## Comment
							var line_data := command_value.split("/")
							cur_meter = (4 * float(line_data[0])) / float(line_data[1])
							# print("measure found")
							cur_chart.command_log.append({"time": time, "com": ChartData.CommandType.MEASURE, "val1": cur_meter})
						command_value = _find_value(line, "#SCROLL")
						if command_value and not disable_scroll:
							# Normal scroll
							if not command_value.contains("i"):
								last_scrollers = Vector2(cur_scroll, cur_scrolly)
								cur_scroll = float(tjaf.head_scroll) * float(command_value)
								cur_scrolly = 0.0
								cur_chart.command_log.append({"time": time, "com": ChartData.CommandType.SCROLL, "val1": float(cur_scroll)})
							else:
								last_scrollers = Vector2(cur_scroll, cur_scrolly)
								command_value = command_value.erase(command_value.find("i"))
								var scrollers: PackedStringArray = command_value.split("+")
								if scrollers.is_empty():
									scrollers = command_value.split("-")
								if scrollers.is_empty():
									scrollers = [0, 1]
								cur_scroll = float(tjaf.head_scroll) * float(scrollers[0])
								if cur_scroll == 0:
									cur_scroll = 0.0001
								cur_scrolly = float(tjaf.head_scroll) * float(scrollers[1])
								cur_chart.command_log.append({"time": time, "com": ChartData.CommandType.SCROLL, "val1": float(cur_scroll), "val2": float(cur_scrolly)})
					if l.begins_with("#"): continue
					for idx in line.trim_suffix(","):
						var n = int(idx)
						if n > 0:
							var bpm: float = cur_bpm
							if bemani_scroll: bpm = tjaf.start_bpm
							var px_perframe: float = get_pixels_per_frame(bpm * (cur_meter / 4) * cur_scroll, 60, cur_meter, screen_distance)
							var load_ms: float = time - (screen_distance / px_perframe / 60)
							var px_perframe_y: float = get_pixels_per_frame(bpm * (cur_meter / 4) * cur_scrolly, 60, cur_meter, screen_distance_y)
							var load_ms_y: float = time - (screen_distance / px_perframe_y / 60)
							var last_note_type: int = 0
							var last_note_ppf: float = 0
							var last_note_loadms: float = 0
							var last_note_ppf_y: float = 0
							var last_note_loadms_y: float = 0
							if n == 8: # Handle
								var rnoteidx: int = cur_chart.notes.find(cur_note)
								cur_chart.notes[rnoteidx].get_or_add("roll_time", time)
								cur_chart.notes[rnoteidx].get_or_add("roll_load_ms", time - (screen_distance / px_perframe / 60))
								# lot to take in mate
								last_note_type = cur_chart.notes[rnoteidx]["note"]
								last_note_ppf = cur_chart.notes[rnoteidx]["ppf"]
								last_note_loadms = cur_chart.notes[rnoteidx]["load_ms"]
								last_note_ppf_y = cur_chart.notes[rnoteidx]["ppf_y"]
								last_note_loadms_y = cur_chart.notes[rnoteidx]["load_ms_y"]
							cur_note = {"time": time, "scroll": cur_scroll, "scroll_y": cur_scrolly, "meter": cur_meter, "note": n, "load_ms": load_ms, "ppf": px_perframe, "load_ms_y": load_ms_y, "ppf_y": px_perframe_y, "measure_length": notes_in_measure}
							if n == 8:
								cur_note.get_or_add("roll_type", last_note_type)
								cur_note.get_or_add("roll_ppf", last_note_ppf)
								cur_note.get_or_add("roll_loadms", last_note_loadms)
								cur_note.get_or_add("roll_ppf_y", last_note_ppf_y)
								cur_note.get_or_add("roll_loadms_y", last_note_loadms_y)
							cur_chart.notes.append(cur_note)
						time += 60 * (cur_meter / notes_in_measure) / cur_bpm
		
		# No notes? No problem!
		if notes_in_measure == 0:
			time += 60 * cur_meter / cur_bpm
		
		measures.clear()
		if line.ends_with(",") or (line.begins_with("#") and not cont_measure):
			notes_in_measure = 0
	
	file.close()
	return tjaf
