local Json = require "json"

Util = {}

function Util.ReadFileToSTring(filename)
	local f = assert(io.open(filename, "rb"))
	local str = f:read("*all")
	f:close()
	return str
end

function Util.PointInCircle(px, py, cx, cy, cr)
	local dist_x = px - cx
	local dist_y = py - cy

	local dist = math.sqrt((dist_x * dist_x) + (dist_y * dist_y))
	if dist <= cr then
		return true
	end
	return false
end

function Util.MapRange(from_min, from_max, to_min, to_max, v)
	return (v - from_min) * (to_max - to_min) / (from_max - from_min) + to_min
end

function Util.Clamp(n, n_min, n_max)
	if n < n_min then n = n_min
	elseif n > n_max then n = n_max
	end

	return n
end

function Util.EaseOutCubic(x)
	return 1 - math.pow(1 - x, 3)
end

function Util.Norm01(x, min, max)
	return (x - min) / (max - min)
end

function Util.LoadSongList()
	local list = lovr.filesystem.getDirectoryItems("res/songs")
	local len = #list

	for i = 1, len do
		local song_path = "res/songs/" .. list[i]
		local song_info_text = Util.ReadFileToSTring(song_path .. "/info.dat")
		local song_info_decoded = Json.decode(song_info_text)
		local filename = song_path .. "/" .. song_info_decoded["_songFilename"]
		local name = song_info_decoded["_songName"]
		local artist = song_info_decoded["_songAuthorName"]
		local author = song_info_decoded["_levelAuthorName"]

		local tex, cover
		if song_info_decoded["_coverImageFilename"]:len() == 0 then
			tex = lovr.graphics.newTexture("res/no_image.png")
		else
			local tex_filename = song_path .. "/" .. song_info_decoded["_coverImageFilename"]
			tex = lovr.graphics.newTexture(tex_filename)
		end

		cover = lovr.graphics.newMaterial(tex, 1, 1, 1, 1)

		local source = lovr.audio.newSource(filename, { decode = false })
		local sound = source:getSound()
		local sample_rate = sound:getSampleRate()
		local duration_secs = source:getDuration("seconds")
		local num_frames = sound:getFrameCount()
		local BPM = song_info_decoded["_beatsPerMinute"]
		local major_beat_interv = (sample_rate * 60) / BPM
		local minor_beat_interv = major_beat_interv / 4 -- NOTE: temp, should depend on time signature

		local difs = song_info_decoded["_difficultyBeatmapSets"][1]["_difficultyBeatmaps"]

		local dif_table = {}
		for j, dif in pairs(difs) do
			local dif_filename = song_path .. "/" .. dif["_beatmapFilename"]
			local dif_name = dif["_difficulty"]
			local dif_rank = dif["_difficultyRank"]
			local t = Util.LoadNotes(dif_filename, major_beat_interv)
			dif_table[j] = { name = dif_name, rank = dif_rank, rows = t }
		end

		App.song_list[i] = { source = source, sound = sound, filename = filename, name = name, artist = artist,
			author = author, cover = cover, sample_rate = sample_rate, duration_secs = duration_secs, num_frames = num_frames,
			BPM = BPM,
			major_beat_interv = major_beat_interv, minor_beat_interv = minor_beat_interv,
			difficulties = dif_table }
	end

	App.game_state = Const.game_state_e.select_song
end

function Util.LoadNotes(dif_filename, major_beat_interv)
	local song_notes_text = Util.ReadFileToSTring(dif_filename)
	local song_notes_decoded = Json.decode(song_notes_text)
	local prev_time = -1
	local note_idx = 1
	local t = {}

	for i, v in ipairs(song_notes_decoded["_notes"]) do
		local hf = major_beat_interv * v["_time"]
		-- local note = { beat_time = v["_time"], hit_frame = hf, spawn_frame = hf - 132300, lane = v["_lineIndex"] + 1 }
		local note = { beat_time = v["_time"], hit_frame = hf, spawn_frame = hf - 99225, lane = v["_lineIndex"] + 1 }
		local row = {}
		-- (meters x 11025) - 11025

		if prev_time == v["_time"] then
			note_idx = note_idx + 1
			t[#t][note_idx] = note
		else
			note_idx = 1
			row[note_idx] = note
			t[#t + 1] = row
		end

		prev_time = v["_time"]
	end
	return t
end

return Util
