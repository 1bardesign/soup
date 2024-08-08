local path = (...)
local function require_relative(module)
	return require(path .. "." .. module)
end

return {
	--ecs
	kernel = require_relative("kernel"),
	entity = require_relative("entity"),
	
	--input
	keyboard = require_relative("keyboard"),
	mouse = require_relative("mouse"),
	gamepad = require_relative("gamepad"),
	input = require_relative("input"),

	--important bits
	main_loop = require_relative("main_loop"),
}
