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

	--misc bits
	frequency_counter = require_relative("frequency_counter"),
	random_pool = require_relative("random_pool"),
	crossfade = require_relative("crossfade"),

	--management
	profiler = require_relative("profiler"),
	main_loop = require_relative("main_loop"),
}
