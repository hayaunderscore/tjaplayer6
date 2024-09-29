extends Node

static func _find_value(line: String, key: String, value := "", overwrite := false) -> String:
	if line.contains("//"):
		line = line.erase(line.find("//"), 9999)
	return line.trim_prefix(key).strip_edges() if line.begins_with(key) and not (overwrite and value) else value

# https://github.com/Yonokid/PyTaiko/blob/8164a71b451311e7a6790e68055062745fc9dc38/global_funcs.py#L134C1-L138C45
func get_pixels_per_frame(bpm, fps, time_signature, distance):
	var beat_duration = fps / bpm
	var total_time = time_signature * beat_duration
	var total_frames = fps * total_time
	return (distance / total_frames) * (fps/60)

var screen_distance: float = (640 * 1) - 148
var screen_distance_y: float = 640 - 148

func calculate_beat_from_ms(ms: float, bpmevents: Array[Dictionary]):
	var current_beat: float = 0.0
	var used_change: int = 0
	for i in range(0, bpmevents.size()):
		var bpmchange = bpmevents[i]
		if ms >= bpmchange["time"]:
			current_beat += bpmchange["beat_duration"]
			continue
		# Hackity hack, on my back
		if i < bpmevents.size()-2:
			current_beat += (ms - bpmchange["time"]) * bpmevents[max(0,i-1)]["beat_breakdown"]
		else:
			current_beat += (ms - bpmchange["time"]) * bpmevents[min(bpmevents.size()-1,i+1)]["beat_breakdown"]
		break
	return current_beat

func calculate_positive_delay(ms: float, events: Array[Dictionary]):
	var current_time: float = 0.0
	var used_change: int = 0
	for i in range(0, events.size()):
		var change = events[i]
		if ms >= change["time"]:
			continue
		current_time += (ms - change["time"])
		break
	return current_time

# https://github.com/splitlane/SplitlaneTaiko/blob/main/Versions/Taikov34.lua
func parse_complex_number_simple(s: String):
	var t = s.split("+")
	var newt = []
	
	for item in t:
		var t2 = item.split("-")
		for i in range(len(t2)):
			if i == 0:
				newt.append(t2[i])
			else:
				newt.append("-" + t2[i])
	
	t = newt
	var out: Vector2 = Vector2.ZERO # [real, imaginary]
	
	for item in t:
		if item != "":
			var imaginary = false
			if item.find("i") != -1:
				imaginary = true
				item = item.replace("i", "")
				
			# Leniency for 1+i, etc.
			if imaginary and (item == "" or item == "-"):
				item += "1"
			
			item = float(item)
			
			if imaginary:
				out.y += item
			else:
				out.x += item
	
	return out
	
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
	
	var current_negative_delay: float = 0
	
	while file.get_position() < file.get_length():
		# Current line
		var line: String = file.get_line().strip_edges()
		# Empty or comment
		if line.is_empty() or line.begins_with("//"):
			continue
		
		# Shortcut....
		var add_bpm_change: Callable = func(added_time: float, added_bpm: float, current_chart: ChartData):
			if current_chart.bpm_log.size() > 0:
				var last_bpm_change: Dictionary = current_chart.bpm_log[current_chart.bpm_log.size()-1]
				last_bpm_change["duration"] = (added_time) - last_bpm_change["time"]
				last_bpm_change["beat_duration"] = (last_bpm_change["bpm"] / 60) * last_bpm_change["duration"]
			# print("uhhh beat duration ", last_bpm_change["duration"], " and in beats ", last_bpm_change["beat_duration"])
			current_chart.command_log.append({
				"time": added_time, 
				"com": ChartData.CommandType.BPMCHANGE, 
				"val1": added_bpm
			})
			current_chart.bpm_log.append({
				"time": added_time,
				"bpm": added_bpm,
				"duration": 0,
				"beat_duration": 0,
				"beat_breakdown": (added_bpm / 60)
			})
		
		var add_positive_delay: Callable = func(added_time: float, added_delay: float, current_chart: ChartData):
			if current_chart.positive_delay_log.size() > 0:
				var last_bpm_change: Dictionary = current_chart.positive_delay_log[current_chart.positive_delay_log.size()-1]
				last_bpm_change["duration"] = (added_time) - last_bpm_change["time"]
			# print("uhhh beat duration ", last_bpm_change["duration"], " and in beats ", last_bpm_change["beat_duration"])
			current_chart.command_log.append({
				"time": added_time, 
				"com": ChartData.CommandType.DELAY, 
				"val1": added_delay
			})
			current_chart.positive_delay_log.append({
				"time": added_time,
				"delay": added_delay,
				"duration": 0,
			})
		
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
				# Shhh
				add_bpm_change.call(time, cur_bpm, cur_chart)
				add_positive_delay.call(time, 0, cur_chart)
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
			# Grab the latest command and attach the time there...
			add_bpm_change.call(time, cur_bpm, cur_chart)
			add_bpm_change.call(tjaf.wave.get_length(), cur_bpm, cur_chart)
			add_positive_delay.call(time, 0, cur_chart)
			add_positive_delay.call(tjaf.wave.get_length(), 0, cur_chart)
			for note in cur_chart.notes:
				note["beat_position"] = calculate_beat_from_ms(note["time"] - note["negative_delay"], cur_chart.bpm_log)
			for note in cur_chart.barline_data:
				note["beat_position"] = calculate_beat_from_ms(note["time"] - note["negative_delay"], cur_chart.bpm_log)
			var sorted: Array[Dictionary] = cur_chart.notes.duplicate(true)
			sorted = sorted.filter(func(a): return a["note"] < 999)
			# sorted.sort_custom(func(a, b): a["time"] < b["time"])
			cur_chart.note_draw_data = sorted.duplicate(true)
			cur_chart.bemani_scroll = bemani_scroll
			cur_chart.disable_scroll = disable_scroll
			bemani_scroll = false
			disable_scroll = false
			tjaf.chartinfo.append(cur_chart)
			should_read_metadata = true
			continue
		
		if line.begins_with("#BMSCROLL"):
			bemani_scroll = true
			disable_scroll = true
		elif line.begins_with("#HBSCROLL"):
			bemani_scroll = true
			disable_scroll = false
		
		# SORRY NOTHING
		if line.is_empty():
			continue
		
		# Add a barline.
		# This is early to account for scroll specific issues ffs
		if barlines and not line.begins_with("#") and not cont_measure:
			var bpm: float = cur_bpm
			if bemani_scroll: bpm = tjaf.start_bpm
			var ppf_vec: Vector2 = Vector2(
				get_pixels_per_frame(cur_bpm * (cur_meter / 4) * cur_scroll, 60, cur_meter, screen_distance),
				get_pixels_per_frame(cur_bpm * (cur_meter / 4) * cur_scrolly, 60, cur_meter, screen_distance_y)
			)
			cur_chart.barline_data.append({"time": time, "scroll": Vector2(cur_scroll, cur_scrolly), "bpm": cur_bpm, "meter": cur_meter, "note": ChartData.NoteType.BARLINE, "load_ms": Vector2(
				time - (screen_distance / ppf_vec.x / 60),
				time - (screen_distance / ppf_vec.y / 60)
				), "ppf": ppf_vec, "negative_delay": current_negative_delay})
		
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
					cur_chart.notes.append({"time": time, "scroll": Vector2(cur_scroll, cur_scrolly), "note": ChartData.NoteType.GOGOSTART, "load_ms": Vector2.ZERO, "ppf": Vector2.ZERO, "negative_delay": 0})
				"#GOGOEND":
					cur_chart.notes.append({"time": time, "scroll": Vector2(cur_scroll, cur_scrolly), "note": ChartData.NoteType.GOGOEND, "load_ms": Vector2.ZERO, "ppf": Vector2.ZERO, "negative_delay": 0})
				_:
					if l.begins_with("#"):
						## Comment
						if l.begins_with("#BARLINEOFF"):
							barlines = false
						elif l.begins_with("#BARLINEON"):
							barlines = true
						var command_value := _find_value(line, "#BPMCHANGE")
						if command_value:
							cur_bpm = float(command_value)
							add_bpm_change.call(time, cur_bpm, cur_chart)
						command_value = _find_value(line, "#DELAY")
						if command_value:
							time += float(command_value)
							# current_negative_delay += abs(float(command_value))
							if float(command_value) > 0:
								add_positive_delay.call(time, float(command_value), cur_chart)
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
								var vec = parse_complex_number_simple(command_value)
								cur_scroll = vec.x
								cur_scrolly = vec.y
								cur_chart.command_log.append({"time": time, "com": ChartData.CommandType.SCROLL, "val1": float(cur_scroll), "val2": float(cur_scrolly)})
					if l.begins_with("#"): continue
					for idx in line.trim_suffix(","):
						var n = int(idx)
						if n > 0:
							# Note dictionary....
							var ppf_vec: Vector2 = Vector2(
								get_pixels_per_frame(cur_bpm * (cur_meter / 4) * cur_scroll, 60, cur_meter, screen_distance),
								get_pixels_per_frame(cur_bpm * (cur_meter / 4) * cur_scrolly, 60, cur_meter, screen_distance_y)
							)
							var no: Dictionary = {
								"note": n,
								"time": time,
								"bpm": cur_bpm,
								"meter": cur_meter,
								"scroll": Vector2(cur_scroll, cur_scrolly),
								"ppf": ppf_vec,
								"load_ms": Vector2(
									time - (screen_distance / ppf_vec.x / 60),
									time - (screen_distance / ppf_vec.y / 60)
								),
								"roll_note": null,
								"roll_time": 0.0,
								"roll_loadms": Vector2(-INF, -INF),
								"balloon_value": 0,
								"negative_delay": current_negative_delay,
							}
							var last_note: Dictionary = {}
							if n == 8: # Handle
								var rnoteidx: int = cur_chart.notes.find(cur_note)
								cur_chart.notes[rnoteidx].get_or_add("roll_time", time)
								cur_chart.notes[rnoteidx].get_or_add("roll_load_ms", Vector2(
									time - (screen_distance / ppf_vec.x / 60),
									time - (screen_distance / ppf_vec.y / 60)
								))
								last_note = cur_chart.notes[rnoteidx]
							cur_note = no
							if n == 8:
								cur_note["roll_note"] = last_note
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
