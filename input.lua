Input = {
	thumbsticks = { LeftX = { cur = 0, prev = 0, pressed = false }, LeftY = { cur = 0, prev = 0, pressed = false },
		RightX = { cur = 0, prev = 0, pressed = false },
		RightY = { cur = 0, prev = 0, pressed = false } }
}

function Input.ReadThumbsticks()
	local rx, ry = lovr.headset.getAxis(App.hands[2], 'thumbstick')
	Input.thumbsticks.RightX.cur = rx
	Input.thumbsticks.RightY.cur = ry
	local lx, ly = lovr.headset.getAxis(App.hands[1], 'thumbstick')
	Input.thumbsticks.LeftX.cur = lx
	Input.thumbsticks.LeftY.cur = ly
end

function Input.ResetThumbsticks()
	Input.thumbsticks.RightX.prev = Input.thumbsticks.RightX.cur
	Input.thumbsticks.RightY.prev = Input.thumbsticks.RightY.cur
	Input.thumbsticks.LeftX.prev = Input.thumbsticks.LeftX.cur
	Input.thumbsticks.LeftY.prev = Input.thumbsticks.LeftY.cur
end

function Input.IsThumbstickPressed(hand_idx, dir)
	if hand_idx == 1 and dir == "right" then
		if Input.thumbsticks.RightX.cur > Input.thumbsticks.RightX.prev and Input.thumbsticks.RightX.prev == 0 then return true; end
	end
	if hand_idx == 1 and dir == "left" then
		if Input.thumbsticks.RightX.cur < Input.thumbsticks.RightX.prev and Input.thumbsticks.RightX.prev == 0 then return true; end
	end
	if hand_idx == 1 and dir == "up" then
		if Input.thumbsticks.RightY.cur > Input.thumbsticks.RightY.prev and Input.thumbsticks.RightY.prev == 0 then return true; end
	end
	if hand_idx == 1 and dir == "down" then
		if Input.thumbsticks.RightY.cur < Input.thumbsticks.RightY.prev and Input.thumbsticks.RightY.prev == 0 then return true; end
	end

	if hand_idx == 2 and dir == "right" then
		if Input.thumbsticks.LeftX.cur > Input.thumbsticks.LeftX.prev and Input.thumbsticks.LeftX.prev == 0 then return true; end
	end
	if hand_idx == 2 and dir == "left" then
		if Input.thumbsticks.LeftX.cur < Input.thumbsticks.LeftX.prev and Input.thumbsticks.LeftX.prev == 0 then return true; end
	end
	if hand_idx == 2 and dir == "up" then
		if Input.thumbsticks.LeftY.cur > Input.thumbsticks.LeftY.prev and Input.thumbsticks.LeftY.prev == 0 then return true; end
	end
	if hand_idx == 2 and dir == "down" then
		if Input.thumbsticks.LeftY.cur < Input.thumbsticks.LeftY.prev and Input.thumbsticks.LeftY.prev == 0 then return true; end
	end
end
return Input
