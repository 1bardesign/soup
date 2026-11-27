--kernel

local path = (...):gsub(".kernel", "")
local entity = require(path .. ".entity")

local kernel = class()

kernel.default_phases = {
	{
		name = "update",
		keys = {
			"update",
		},
		sort = entity.less,
		flush = true,
		setup = function(k) end,
		action = function(k, v, dt)
			v:update(dt)
		end,
		cleanup = function(k) end,
	},
	{
		name = "fixed_update",
		keys = {
			"fixed_update",
		},
		sort = entity.less,
		flush = true,
		setup = function(k) end,
		action = function(k, v, dt)
			v:fixed_update(dt)
		end,
		cleanup = function(k) end,
	},
	{
		name = "draw",
		keys = {
			"draw"
		},
		sort = entity.draw_less,
		setup = function(k) end,
		action = function(k, v)
			if 
				v.visible ~= false
			then
				lg.push("all")
				if v.pos then
					lg.translate(v.pos.x, v.pos.y)
				end
				v:draw()
				lg.pop()
			end
		end,
		cleanup = function(k) end,
	},
}

function kernel:new(args)
	args = args or {}

	self.all = {}

	self.phases = args.phases or kernel.default_phases
	self.with = {}
	--generate the phase functions
	for _, phase in ipairs(self.phases) do
		self.with[phase.name] = {}
		self[phase.name] = function(self, ...)
			profiler:push(phase.name)
			if phase.flush then
				self:flush()
			end
			local collection = phase.everything and self.all or self.with[phase.name]
			if phase.sort then
				table.insertion_sort(collection, phase.sort)
			end
			if phase.setup then
				phase.setup(self, ...)
			end
			if phase.ignore_enabled then
				for _, v in ipairs(collection) do
					phase.action(self, v, ...)
				end
			else
				for _, v in ipairs(collection) do
					if v.enabled ~= false then
						phase.action(self, v, ...)
					end
				end
			end
			if phase.cleanup then
				phase.cleanup(self, ...)
			end
			if phase.flush then
				self:flush()
			end
			profiler:pop(phase.name)
		end
	end

	self.to_add = {}
	self.to_remove = {}
	self.deferred = {}

	self.systems = {}
	self.all_systems = {}

	self.event = pubsub()
end

--queue add/remove
function kernel:add(behaviour)
	table.insert(self.to_add, behaviour)
	return behaviour
end

function kernel:remove(behaviour)
	table.insert(self.to_remove, behaviour)
	return behaviour
end

--actual implementations of queued actions - use care when calling directly!
function kernel:add_now(behaviour)
	table.insert(self.all, behaviour)
	for _, phase in ipairs(self.phases) do
		local has_all = true
		for _, key in ipairs(phase.keys) do
			if type(behaviour[key]) ~= "function" then
				has_all = false
				break
			end
		end
		if has_all then
			table.insert(self.with[phase.name], behaviour)
		end
	end
	--also to any systems
	for _, s in ipairs(self.all_systems) do
		if s.added then
			s:added(behaviour)
		end
	end
end

function kernel:remove_now(behaviour)
	table.remove_value(self.all, behaviour)
	--and from phase tables
	for _, v in ipairs(self.phases) do
		table.remove_value(self.with[v.name], behaviour)
	end
	--also from any systems
	for _, s in ipairs(self.all_systems) do
		if s.removed then
			s:removed(behaviour)
		end
	end
	--fire final callback
	local cb = behaviour.remove or behaviour.removed --alias allowed because it was done wrong enough times :)
	if cb then
		cb(behaviour)
	end
end

--add a behaviour directly from a system
function kernel:add_from_system(system_name, ...)
	local sys = self.systems[system_name]
	if not sys then
		error(("missing system for %s"):format(system_name))
	end
	return self:add(sys:create(...))
end

--defer something until outside of update/draw
--todo: consider if we should natively support cancelling somehow
function kernel:defer(f, ...)
	table.insert(self.deferred, {f, ...})
end

function kernel:flush(dt)
	while #self.to_add > 0 or #self.to_remove > 0 or #self.deferred > 0 do
		--swap beforehand, so any newly added things go into the next cycle
		local _to_add = self.to_add
		local _to_remove = self.to_remove
		local _deferred = self.deferred
		self.to_add = {}
		self.to_remove = {}
		self.deferred = {}
		for _, v in ipairs(_to_add) do
			self:add_now(v)
			if dt and v.update and v.enabled then
				v:update(dt)
			end
		end
		for _, v in ipairs(_to_remove) do
			self:remove_now(v)
		end
		for _, v in ipairs(_deferred) do
			local f = table.remove(v, 1)
			f(unpack(v))
		end
	end
end

function kernel:entity()
	return entity(self)
end

function kernel:add_system(name, system)
	self.systems[name] = system
	table.insert(self.all_systems, system)
	--system is also added as a regular behaviour so it's updated, ordered and drawn same as everything else
	self:add(system)
	if system.register then
		system:register(self, name)
	end
	--
	return self --for chaining
end

function kernel:release()
	for _, v in ipairs(self.all) do
		if not table.contains(self.all_systems, v) then
			self:remove(v)
		end
	end
	self:flush()

	--(todo fix removing systems?)
	-- for _, v in ipairs(self.all_systems) do
	-- 	self:remove(v)
	-- end
	-- self:flush()
	self:new()
end

return kernel