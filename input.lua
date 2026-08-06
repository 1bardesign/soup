--centralised input

local path = (...):gsub(".input", "")
local function relative_require(module)
	return require(path .. "." .. module)
end

local input = {
	keyboard = relative_require("keyboard")(),
	mouse = relative_require("mouse")(),
	gamepad = relative_require("gamepad")(1),
}

input.mode = "desktop"

--init the cursor stuff
input._cursor = vec2()
input._first_cursor = true
input._cursor_pressed = {false, false, false}
input._cursor_old_pressed = {false, false, false}

function input:update(dt)
	self.keyboard:update(dt)
	self.mouse:update(dt)
	self.gamepad:update(dt)
	local old_mode = self.mode
	if
		self.keyboard:any_just_pressed()
		or self.mouse:any_just_pressed()
		or self.mouse.delta:length_squared() > 10
	then
		self.mode = "desktop"
		if self._first_cursor then
			self._first_cursor = false
		end
	elseif self.gamepad:any_just_pressed_even_axes() then
		self.mode = "gamepad"
		if self._first_cursor then
			--init cursor to the middle of the screen
			input._cursor:sset(display:dimensions()):smuli(0.5):vaddi(display.offset)
			self._first_cursor = false
		end
	end

	--clear on first press
	if old_mode ~= self.mode then
		self:clear()
	end

	--update cursor
	if self.mode == "gamepad" then
		--gamepad mouse has to manage writing it in somehow
	else
		self._cursor:vset(self.mouse.pos)
	end
	for i, v in ipairs(self._cursor_pressed) do
		self._cursor_old_pressed[i] = v
	end
	if input.mode == "gamepad" then
		for i, v in ipairs({"a", "b", "leftstick"}) do
			self._cursor_pressed[i] = self.gamepad:pressed(v)
		end
	else
		for i = 1, 3 do
			self._cursor_pressed[i] = self.mouse:pressed(i)
		end
	end
end

function input:clear()
	self.keyboard:clear()
	self.mouse:clear()
	self.gamepad:clear()
end

function input:cursor()
	return self._cursor
end

function input:cursor_pressed(button)
	return self._cursor_pressed[button]
end

function input:cursor_released(button)
	return not self._cursor_pressed[button]
end

function input:cursor_old_pressed(button)
	return self._cursor_old_pressed[button]
end

function input:cursor_just_pressed(button)
	return not self:cursor_old_pressed(button) and self:cursor_pressed(button)
end

function input:cursor_just_released(button)
	return self:cursor_old_pressed(button) and not self:cursor_pressed(button)
end


return input
