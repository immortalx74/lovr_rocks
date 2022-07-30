local Json = require "json"
local Const = require "const"
local UI = require "ui"

App = {
	vshader_source = [[
		vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
		  return projection * transform * vertex;
		}
	  ]],
	fshader_source = [[
		const float gridSize = 25.;
		const float cellSize = 1;
	
		vec4 color(vec4 gcolor, sampler2D image, vec2 uv) {
	
		  // Distance-based alpha (1. at the middle, 0. at edges)
		  float alpha = 1. - smoothstep(.15, .50, distance(uv, vec2(.5)));
	
		  // Grid coordinate
		  uv *= gridSize;
		  uv /= cellSize;
		  vec2 c = abs(fract(uv - .5) - .5) / fwidth(uv);
		  float line = clamp(1. - min(c.x, c.y), 0., 1.);
		  vec3 value = mix(vec3(.01, .01, .011), (vec3(.04)), line);
	
		  return vec4(vec3(value), alpha);
		}
	  ]],

	defaultVertex = [[
        out vec3 FragmentPos;
        out vec3 Normal;

        vec4 position(mat4 projection, mat4 transform, vec4 vertex) { 
            Normal = lovrNormal;
            FragmentPos = (lovrModel * vertex).xyz;
        
            return projection * transform * vertex;
        }
    ]],
	defaultFragment = [[
        uniform vec4 liteColor;

        uniform vec4 ambience;
    
        in vec3 Normal;
        in vec3 FragmentPos;
        uniform vec3 lightPos;

        uniform vec3 viewPos;
        uniform float specularStrength;
        uniform float metallic;
        
        vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) 
        {    
            //diffuse
            vec3 norm = normalize(Normal);
            vec3 lightDir = normalize(lightPos - FragmentPos);
            float diff = max(dot(norm, lightDir), 0.0);
            vec4 diffuse = diff * liteColor;
            
            //specular
            vec3 viewDir = normalize(viewPos - FragmentPos);
            vec3 reflectDir = reflect(-lightDir, norm);
            float spec = pow(max(dot(viewDir, reflectDir), 0.0), metallic);
            vec4 specular = specularStrength * spec * liteColor;
            
            vec4 baseColor = graphicsColor * texture(image, uv);            
            //vec4 objectColor = baseColor * vertexColor;

            return baseColor * (ambience + diffuse + specular);
        }
    ]],

	shader,
	backshader,
	mdl_hammer,
	mdl_pad1, mdl_pad2, mdl_pad3, mdl_pad4,
	mdl_drum_bottom, mdl_drum_top,
	cur_row_idx = 1,
	cur_song_idx = 1,
	cur_difficulty_idx = 1,
	hands = {},
	hammer_collision_point = {},
	driver = {},
	visible_rows = {},
	game_state = Const.game_state_e.load_song_list,
	can_hammer_collide = { true, true },
	song_list = {},
	drum_anim_state = {},
	metrics = { hammer_tip_local_y = -0.15, hammer_tip_local_z = -0.37, drums_offset_y = 0, lower_drum_height = 0.32,
		upper_drum_height = 0.57, drum_collision_radius = 0.235, spawn_distance = 7 },
	snd_metronome = { source_primary, source_secondary, filename_primary, filename_secondary },
	snd_bass_drum = { source, filename },
}

function App.Init()
	App.backshader = lovr.graphics.newShader(App.vshader_source, App.fshader_source, { flags = { highp = true } })
	App.shader = lovr.graphics.newShader(App.defaultVertex, App.defaultFragment, {})
	App.shader:send('liteColor', { 1.0, 1.0, 1.0, 1.0 })
	App.shader:send('ambience', { 0.1, 0.1, 0.1, 1.0 })
	App.shader:send('specularStrength', 0.4)
	App.shader:send('metallic', 128.0)
	lovr.graphics.setBackgroundColor(0.3, 0.3, 0.3)

	App.hammer_collision_point[1] = lovr.math.newVec3(0, 0, 0)
	App.hammer_collision_point[2] = lovr.math.newVec3(0, 0, 0)

	for i = 1, 4 do
		App.drum_anim_state[#App.drum_anim_state + 1] = { is_animating = false, elapsed = 0, bounce_dist = 0,
			y = 0 }
	end

	-- Load models
	App.mdl_hammer = lovr.graphics.newModel("res/models/hammer.obj")
	App.mdl_pad1 = lovr.graphics.newModel("res/models/pad1.obj")
	App.mdl_pad2 = lovr.graphics.newModel("res/models/pad2.obj")
	App.mdl_pad3 = lovr.graphics.newModel("res/models/pad3.obj")
	App.mdl_pad4 = lovr.graphics.newModel("res/models/pad4.obj")
	App.mdl_drum_top = lovr.graphics.newModel("res/models/drum_top.obj")
	App.mdl_drum_bottom = lovr.graphics.newModel("res/models/drum_bottom.obj")

	-- Load sounds
	App.snd_metronome.filename_primary = "res/sounds/metronome1.wav"
	App.snd_metronome.filename_secondary = "res/sounds/metronome2.wav"
	App.snd_metronome.source_primary = lovr.audio.newSource(App.snd_metronome.filename_primary)
	App.snd_metronome.source_secondary = lovr.audio.newSource(App.snd_metronome.filename_secondary)
	App.snd_bass_drum.filename = "res/sounds/bassdrum.wav"
	App.snd_bass_drum.source = lovr.audio.newSource(App.snd_bass_drum.filename)
	App.snd_bass_drum.source:setVolume(1, 'linear')

	-- Setup UI
	UI.font = lovr.graphics.newFont("res/DejaVuSansMono.ttf")
	lovr.graphics.setFont(UI.font)
	UI.font_w = select(1, UI.font:getWidth("W", 0) * UI.font_scale)
	UI.font_h = UI.font:getHeight() * UI.font_scale

	Util.LoadSongList()
end

function App.UpdateNotePositions(cur_audio_frame)
	for i, row in ipairs(App.visible_rows) do
		for j, note in ipairs(row) do
			note.pos_z = ((cur_audio_frame - note.spawn_frame) / 22050) - App.metrics.spawn_distance
		end
	end
end

function App.PopRowPastPlayer()
	-- visible_rows is FIFO, so just check pos_z of first row. If > 0 then pop from stack
	if #App.visible_rows > 0 then
		local pos_z = App.visible_rows[1][1].pos_z
		if pos_z > 0 then
			table.remove(App.visible_rows, 1)
		end
	end
end

function App.SpawnNextRow(cur_audio_frame)
	local cur_row = App.song_list[App.cur_song_idx].difficulties[App.cur_difficulty_idx].rows[App.cur_row_idx]

	-- Die here for now...
	if App.cur_row_idx > #App.song_list[App.cur_song_idx].difficulties[App.cur_difficulty_idx].rows then
		return
	end
	local num_notes = #App.song_list[App.cur_song_idx].difficulties[App.cur_difficulty_idx].rows[App.cur_row_idx]

	local note = cur_row[1]

	if cur_audio_frame >= note.spawn_frame then
		local notes = {}
		local leftmost_center = -((2 * (2 * App.metrics.drum_collision_radius)) - App.metrics.drum_collision_radius)

		for i = 1, num_notes do
			local n = { pos_z = -App.metrics.spawn_distance,
				pos_x = leftmost_center + ((cur_row[i].lane - 1) * (2 * App.metrics.drum_collision_radius)),
				spawn_frame = cur_row[i].spawn_frame,
				lane = cur_row[i].lane }
			notes[#notes + 1] = n
		end

		App.visible_rows[#App.visible_rows + 1] = notes
		App.cur_row_idx = App.cur_row_idx + 1
	end
end

function App.DrawNotes()
	for i, row in ipairs(App.visible_rows) do
		for j, note in ipairs(row) do
			local pad_pos = vec3(note.pos_x,
				App.metrics.drums_offset_y + App.metrics.lower_drum_height + App.metrics.upper_drum_height, note.pos_z)
			local mdl = App.mdl_pad4

			if note.lane == 1 then
				mdl = App.mdl_pad1
			elseif note.lane == 2 then
				mdl = App.mdl_pad2
			elseif note.lane == 3 then
				mdl = App.mdl_pad3
			end

			mdl:draw(pad_pos, 1, 0, 0, 0)
		end
	end
end

function App.DrawHammers()
	-- Update hammer collision points
	local hand_pos_l = lovr.math.newVec3(lovr.headset.getPosition(App.hands[1]))
	local hand_or_l = lovr.math.newQuat(lovr.headset.getOrientation(App.hands[1]))
	local hand_dir_l = lovr.math.newVec3(hand_or_l:direction())
	local tip_pos_local_l = lovr.math.newVec3(0, App.metrics.hammer_tip_local_y, App.metrics.hammer_tip_local_z)
	local m_l = lovr.math.newMat4(hand_pos_l, hand_or_l)
	m_l:translate(tip_pos_local_l)
	App.hammer_collision_point[1] = lovr.math.newVec3(m_l)
	-- lovr.graphics.sphere(lovr.math.newVec3(m_l), 0.03)

	local hand_pos_r = lovr.math.newVec3(lovr.headset.getPosition(App.hands[2]))
	local hand_or_r = lovr.math.newQuat(lovr.headset.getOrientation(App.hands[2]))
	local hand_dir_r = lovr.math.newVec3(hand_or_r:direction())
	local tip_pos_local_r = lovr.math.newVec3(0, App.metrics.hammer_tip_local_y, App.metrics.hammer_tip_local_z)
	local m_r = lovr.math.newMat4(hand_pos_r, hand_or_r)
	m_r:translate(tip_pos_local_r)
	App.hammer_collision_point[2] = lovr.math.newVec3(m_r)
	-- lovr.graphics.sphere(lovr.math.newVec3(m_r), 0.03)

	-- Draw the hammers
	lovr.graphics.setColor(1, 1, 1)
	local model_pos_l = lovr.math.newVec3(hand_pos_l)
	App.mdl_hammer:draw(model_pos_l, 1, hand_or_l)

	local model_pos_r = lovr.math.newVec3(hand_pos_r)
	App.mdl_hammer:draw(model_pos_r, 1, hand_or_r)
end

function App.DrawDrums()
	lovr.graphics.setColor(1, 1, 1)
	local leftmost_center = -((2 * (2 * App.metrics.drum_collision_radius)) - App.metrics.drum_collision_radius)
	local bottom_drum_pos = vec3(leftmost_center, App.metrics.drums_offset_y, -1)
	local top_drum_pos = vec3(leftmost_center, App.metrics.drums_offset_y + App.metrics.lower_drum_height, -1)
	for i = 1, 4 do
		local anim_offset = App.drum_anim_state[i].y
		App.mdl_drum_bottom:draw(bottom_drum_pos, 1, 0, 0, 0)
		App.mdl_drum_top:draw(top_drum_pos.x, top_drum_pos.y + anim_offset, top_drum_pos.z, 1, 0, 0, 0)
		lovr.graphics.setColor(1, 0, 0)
		-- lovr.graphics.circle('fill', top_drum_pos.x,
		-- 	App.metrics.drums_offset_y + App.metrics.lower_drum_height + App.metrics.upper_drum_height, top_drum_pos.z,
		-- 	App.metrics.drum_collision_radius,
		-- 	1.5708, 1, 0, 0)
		lovr.graphics.setColor(1, 1, 1)
		bottom_drum_pos.x = bottom_drum_pos.x + (2 * App.metrics.drum_collision_radius)
		top_drum_pos.x = top_drum_pos.x + (2 * App.metrics.drum_collision_radius)
	end
end

function App.AnimateDrums(dt)
	for i, drum in ipairs(App.drum_anim_state) do
		if drum.is_animating then
			if drum.elapsed < 0.15 then
				drum.y = drum.y - drum.bounce_dist
			elseif drum.elapsed < 0.3 then
				drum.y = drum.y + drum.bounce_dist
			else
				drum.is_animating = false
				drum.elapsed = 0
				drum.y = 0
			end

			drum.elapsed = drum.elapsed + dt
		end
	end
end

function App.HammerDrumCollision(hammer_idx, drum_idx)
	local leftmost_center = -((2 * (2 * App.metrics.drum_collision_radius)) - App.metrics.drum_collision_radius)
	local drum_x = leftmost_center + ((drum_idx - 1) * (2 * App.metrics.drum_collision_radius))
	local drum_z = -1
	local drum_y = App.metrics.drums_offset_y + App.metrics.lower_drum_height + App.metrics.upper_drum_height

	local hammer_x = App.hammer_collision_point[hammer_idx].x
	local hammer_z = App.hammer_collision_point[hammer_idx].z
	local hammer_y = App.hammer_collision_point[hammer_idx].y

	-- reset hammer ability to collide
	local vel = math.abs(select(1, lovr.headset.getAngularVelocity(App.hands[hammer_idx])))

	if hammer_y > drum_y and vel > 2.6 then
		App.can_hammer_collide[hammer_idx] = true
	end

	local is_colliding = false

	if Util.PointInCircle(hammer_x, hammer_z, drum_x, drum_z, App.metrics.drum_collision_radius) then
		is_colliding = true
	end

	if App.can_hammer_collide[hammer_idx] and is_colliding and hammer_y <= drum_y then
		App.can_hammer_collide[hammer_idx] = false
		local vib_strength = Util.Clamp(Util.MapRange(0, 20, 0, 1, vel), 0, 1)
		lovr.headset.vibrate(App.hands[hammer_idx], vib_strength, vib_strength * 0.16, 0)

		-- Begin drum bounce animation
		App.drum_anim_state[drum_idx].is_animating = true
		App.drum_anim_state[drum_idx].elapsed = 0
		App.drum_anim_state[drum_idx].y = 0
		App.drum_anim_state[drum_idx].bounce_dist = vib_strength * 0.007

		return true
	end
	return false
end

function App.CollisionHandler()
	if App.HammerDrumCollision(1, 1) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(1, 2) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(1, 3) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(1, 4) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(2, 1) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(2, 2) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(2, 3) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
	if App.HammerDrumCollision(2, 4) then
		App.snd_bass_drum.source:stop()
		App.snd_bass_drum.source:play()
	end
end

return App
