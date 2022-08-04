-- LOVR ROCKS


local App = require "app"
local Util = require "util"
local Const = require "const"
local UI = require "ui"
local Input = require "input"

-- LOAD
function lovr.load()
	App.Init()
end

-- UPDATE
function lovr.update(dt)
	App.shader:send('lightPos', { -5, -2.0, 2.0 })
	App.hands[1] = lovr.headset.getHands()[1]
	App.hands[2] = lovr.headset.getHands()[2]
	Input.ResetThumbsticks()
	Input.ReadThumbsticks()

	if App.game_state == Const.game_state_e.select_song then
		local num_songs = #App.song_list

		if Input.IsThumbstickPressed(1, "down") then
			if UI.selected_idx < num_songs then
				UI.selected_idx = UI.selected_idx + 1
				if UI.selected_idx > UI.offset_idx + UI.num_visible_entries - 1 then UI.offset_idx = UI.offset_idx + 1; end
			end
		end
		if Input.IsThumbstickPressed(1, "up") then
			if UI.selected_idx > 1 then
				UI.selected_idx = UI.selected_idx - 1
				if UI.selected_idx < UI.offset_idx then UI.offset_idx = UI.offset_idx - 1; end
			end
		end

		if Input.IsThumbstickPressed(2, "down") then
			App.metrics.drums_offset_y = App.metrics.drums_offset_y - 0.01
		end

		if Input.IsThumbstickPressed(2, "up") then
			App.metrics.drums_offset_y = App.metrics.drums_offset_y + 0.01
		end

		if lovr.headset.wasPressed(App.hands[2], "trigger") then
			App.game_state = Const.game_state_e.select_difficulty
			App.cur_song_idx = UI.selected_idx
		end
	elseif App.game_state == Const.game_state_e.select_difficulty then

		local num_difs = #App.song_list[App.cur_song_idx].difficulties

		if Input.IsThumbstickPressed(1, "down") then
			if UI.selected_dif_idx < num_difs then UI.selected_dif_idx = UI.selected_dif_idx + 1; end
		end
		if Input.IsThumbstickPressed(1, "up") then
			if UI.selected_dif_idx > 1 then UI.selected_dif_idx = UI.selected_dif_idx - 1; end
		end
		if lovr.headset.wasPressed(App.hands[2], "trigger") then
			App.game_state = Const.game_state_e.play_song
			App.cur_difficulty_idx = UI.selected_dif_idx
			App.song_list[App.cur_song_idx].source:setVolume(0.6, 'linear')
			App.song_list[App.cur_song_idx].source:play()
		end

	elseif App.game_state == Const.game_state_e.play_song then
		local cur_audio_frame = App.song_list[App.cur_song_idx].source:tell("frames")
		App.SpawnNextRow(cur_audio_frame)
		App.UpdateNotePositions(cur_audio_frame)
		App.PopRowPastPlayer()

		if lovr.headset.wasPressed(App.hands[1], "thumbstick") then
			App.song_list[App.cur_song_idx].source:stop()
			App.game_state = Const.game_state_e.select_song
			Util.ClearTable(App.visible_rows)
			App.cur_row_idx = 1
		end
	end


	App.CollisionHandler()
	App.AnimateDrums(dt)
end

-- DRAW
function lovr.draw()
	lovr.graphics.setShader(App.backshader)
	lovr.graphics.plane('fill', 0, 0, 0, 25, 25, -math.pi / 2, 1, 0, 0)

	lovr.graphics.setColor(1, 1, 1)

	if App.game_state == Const.game_state_e.select_song then
		lovr.graphics.setShader()
		UI.DrawSongList()

		lovr.graphics.setShader(App.shader)
		App.DrawHammers()
		App.DrawDrums()
	elseif App.game_state == Const.game_state_e.select_difficulty then
		lovr.graphics.setShader()
		UI.DrawDifficulties()
		lovr.graphics.setShader(App.shader)
		App.DrawHammers()
		App.DrawDrums()
	elseif App.game_state == Const.game_state_e.play_song then
		lovr.graphics.setShader(App.shader)
		App.DrawHammers()
		App.DrawDrums()
		App.DrawNotes()
	end

	lovr.graphics.setShader()
end
