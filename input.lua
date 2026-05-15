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
	elseif self.gamepad:any_just_pressed_even_axes() then
		self.mode = "gamepad"
	end

	--clear on first press
	if old_mode ~= self.mode then
		self:clear()
	end
end

function input:clear()
	self.keyboard:clear()
	self.mouse:clear()
	self.gamepad:clear()
end


return input
