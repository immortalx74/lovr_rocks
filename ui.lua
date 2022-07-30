local Input = require "input"

UI = {
	font, font_w, font_h, font_scale = 0.04, margin = 0.05, num_visible_entries = 5, panel_x = 0, panel_y = 1.7,
	panel_z = -1.5, panel_w = 1, panel_h = 1, selected_idx = 1, offset_idx = 1, selected_dif_idx = 1
}

function UI.DrawSongList()
	lovr.graphics.setColor(0.2, 0.2, 0.2)
	UI.panel_h = 5 * (4 * UI.font_h) + (5 * (UI.margin / 2))
	lovr.graphics.plane('fill', UI.panel_x, UI.panel_y, UI.panel_z, UI.panel_w + UI.margin, UI.panel_h + UI.margin)
	lovr.graphics.setColor(1, 1, 1)
	lovr.graphics.print("SELECT SONG", 0, UI.panel_y + 0.6, UI.panel_z,
		UI.font_scale)
	lovr.graphics.print("(LStick: Move drums, RStick: Select, RTrigger: OK)", 0, UI.panel_y + 0.6 - UI.font_h,
		UI.panel_z,
		UI.font_scale)

	local num_songs = #App.song_list
	local list_start, list_end

	if num_songs <= UI.num_visible_entries then
		list_start = 1
		list_end = num_songs
	else
		list_start = UI.offset_idx
		list_end = list_start + UI.num_visible_entries - 1
	end

	for i = list_start, list_end do
		local difs = {}
		for j, dif in ipairs(App.song_list[i].difficulties) do
			difs[j] = dif.rank
		end
		local info = { name = App.song_list[i].name, artist = App.song_list[i].artist, author = App.song_list[i].author,
			difs = difs, cover = App.song_list[i].cover }
		UI.DrawSongInfo(info, i, list_start)
	end
end

function UI.DrawSongInfo(info, idx, list_start)
	local xx = (UI.panel_x - (UI.panel_w / 2))
	local yy = (UI.panel_y + (UI.panel_h / 2)) - ((idx - list_start) * 4 * UI.font_h) -
		(((idx - list_start) * UI.margin) / 2)

	local plane_type
	if idx == UI.selected_idx then
		lovr.graphics.setColor(0.3, 0.3, 0.35)
		plane_type = 'fill'
	else
		lovr.graphics.setColor(0.3, 0.3, 0.3)
		plane_type = 'line'
	end
	lovr.graphics.plane(plane_type, UI.panel_x, yy - 2 * UI.font_h, UI.panel_z + 0.001, UI.panel_w, 4 * UI.font_h)

	lovr.graphics.setColor(1, 1, 1)
	lovr.graphics.plane(info.cover, UI.panel_x + (UI.panel_w / 2) - (2 * UI.font_h), yy - 2 * UI.font_h, UI.panel_z + 0.002
		, 4 * UI.font_h, 4 * UI.font_h)

	lovr.graphics.setColor(1, 1, 1)
	lovr.graphics.print(info.name, xx, yy, UI.panel_z + 0.002, UI.font_scale, 0, 0, 1, 0, 0, 'left', 'top')
	yy = yy - UI.font_h
	lovr.graphics.print(info.artist, xx, yy, UI.panel_z + 0.002, UI.font_scale, 0, 0, 1, 0, 0, 'left', 'top')
	yy = yy - UI.font_h
	lovr.graphics.print("By: " .. info.author, xx, yy, UI.panel_z + 0.002, UI.font_scale, 0, 0, 1, 0, 0, 'left', 'top')

	yy = yy - UI.font_h
	for i, dif in ipairs(info.difs) do
		lovr.graphics.print(dif, xx, yy, UI.panel_z + 0.002, UI.font_scale, 0, 0, 1, 0, 0, 'left', 'top')
		xx = xx + 0.05
	end
end

function UI.DrawDifficulties()

	lovr.graphics.setColor(0.2, 0.2, 0.2)
	UI.panel_h = 5 * (1 * UI.font_h) + (5 * (UI.margin / 2))
	lovr.graphics.plane('fill', UI.panel_x, UI.panel_y, UI.panel_z, UI.panel_w + UI.margin, UI.panel_h + UI.margin)
	lovr.graphics.setColor(1, 1, 1)
	lovr.graphics.print("SELECT DIFFICULTY", 0, UI.panel_y + 0.3, UI.panel_z,
		UI.font_scale)
	lovr.graphics.print("(RStick: Select, RTrigger: Play)", 0, UI.panel_y + 0.3 - UI.font_h,
		UI.panel_z,
		UI.font_scale)

	local num_difs = #App.song_list[App.cur_song_idx].difficulties
	local xx = (UI.panel_x - (UI.panel_w / 2))
	local yy = (UI.panel_y + (UI.panel_h / 2))

	for i = 1, num_difs do
		local rank = App.song_list[App.cur_song_idx].difficulties[i].rank
		local str = tostring(rank)
		local len = str:len()
		local space
		if len == 2 then
			space = ""
		else
			space = " "
		end

		local plane_type
		if i == UI.selected_dif_idx then
			lovr.graphics.setColor(0.3, 0.3, 0.35)
			plane_type = 'fill'
		else
			lovr.graphics.setColor(0.3, 0.3, 0.3)
			plane_type = 'line'
		end

		lovr.graphics.plane(plane_type, UI.panel_x, yy - (UI.font_h / 2), UI.panel_z + 0.001,
			UI.panel_w, UI.font_h)

		local txt = "[" .. rank .. "]" .. space .. ": " .. App.song_list[App.cur_song_idx].difficulties[i].name
		lovr.graphics.setColor(1, 1, 1)
		lovr.graphics.print(txt, xx, yy, UI.panel_z + 0.002, UI.font_scale, 0, 0, 1, 0, 0, 'left', 'top')
		yy = yy - UI.font_h
	end
end

return UI
