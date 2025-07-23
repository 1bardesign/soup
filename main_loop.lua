local path = (...):gsub(".main_loop", "")
local frequency_counter = require(path..".frequency_counter")

local main_loop = class({
	name = "main_loop",
})

function main_loop:profiler_push(f)
	if self.profiler then
		self.profiler:push(f)
	end
end

function main_loop:profiler_pop(f)
	if self.profiler then
		self.profiler:pop(f)
	end
end

function main_loop:new(args)
	self.frametime = args.frametime or 1 / 60
	if self.interpolate_render == nil then
		self.interpolate_render = false
	end
	self.ticks_per_second = frequency_counter()
	self.frames_per_second = frequency_counter()
	self.interpolate_render = args.interpolate_render

	self.garbage_time = args.garbage_time or 1e-3

	self.after_frame = args.after_frame

	self.profiler = args.profiler
	self.input = args.input

	--redefine main loop
	function love.run()
		if love.load then
			love.load(love.arg.parseGameArguments(arg), arg)
		end

		--(dont count love.load time)
		love.timer.step()

		--accumulator
		local frametimer = 0

		-- Main loop time.
		return function()
			self:profiler_push("frame")
			self:profiler_push("event")
			-- process and handle events
			if love.event then
				love.event.pump()
				for name, a,b,c,d,e,f in love.event.poll() do
					if name == "quit" then
						if not love.quit or not love.quit() then
							return a or 0
						end
					end
					love.handlers[name](a,b,c,d,e,f)
				end
			end
			self:profiler_pop("event")

			-- get time passed, and accumulate
			self:profiler_push("update")
			local dt = love.timer.step()
			-- fuzzy timing snapping
			for _, v in ipairs {0.5, 1, 2} do
				v = self.frametime * v
				if math.abs(dt - v) < 0.002 then
					dt = v
				end
			end
			-- dt clamping
			dt = math.clamp(dt, 0, 2 * self.frametime)
	 		frametimer = frametimer + dt
	 		-- accumulater clamping
			frametimer = math.clamp(frametimer, 0, 8 * self.frametime)

			local ticked = false

	 		--spin updates if we're ready
	 		while frametimer > self.frametime do
				self:profiler_push("tick")
	 			frametimer = frametimer - self.frametime
	 			love.update(self.frametime) --pass consistent dt
	 			self.ticks_per_second:add()
	 			ticked = true
				self:profiler_pop("tick")
	 		end
			self:profiler_pop("update")

	 		--render if we need to
			self:profiler_push("draw")
			if
				love.graphics
				and love.graphics.isActive()
				and (ticked or self.interpolate_render)
			then
				love.graphics.origin()
				love.graphics.clear(love.graphics.getBackgroundColor())

				love.draw(frametimer / self.frametime) --pass interpolant

				if not (self.profiler and self.input and self.input.keyboard:pressed("`")) then
					love.graphics.present()
				end
	 			self.frames_per_second:add()
			end
			self:profiler_pop("draw")

			if self.after_frame then
				self:after_frame()
			else
				--sweep garbage always
				self:profiler_push("collect")
				manual_gc(self.garbage_time)
				self:profiler_pop("collect")

				--give the cpu a break
				self:profiler_push("sleep")
				love.timer.sleep(0.001)
				self:profiler_pop("sleep")
			end
			self:profiler_pop("frame")

			--profiler stuff if relevant
			if self.profiler and self.input then
				if not love.filesystem.isFused() and self.input.keyboard:pressed(";") then
					love.filesystem.write("profile.txt", self.profiler:format())
				end
				if self.input.keyboard:pressed("`") then
					if self.input.keyboard:just_pressed("lshift") then
						self.profiler:hold_result()
					elseif self.input.keyboard:released("lshift") then
						self.profiler:drop_hold()
					end
					if self.input.keyboard:just_pressed("lctrl") then
						self.profiler:clear_worst()
					end
					if self.input.keyboard:just_pressed("return") then
						self.profiler:print_result()
					end
					love.graphics.push()
					love.graphics.origin()
					love.graphics.translate(10, 10)
					if not self.profiler_font then
						self.profiler_font = love.graphics.newFont(10)
					end
					love.graphics.setFont(self.profiler_font)
					self.profiler:draw_result()
					love.graphics.pop()
					love.graphics.present()
				end
			end
		end
	end
end

return main_loop
