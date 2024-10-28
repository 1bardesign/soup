--kernel

local path = (...):gsub(".kernel", "")
local entity = require(path .. ".entity")

local kernel = class()

function kernel:new()
	self.all = {}
	self.with_update = {}
	self.with_draw = {}

	self.to_add = {}
	self.to_remove = {}
	self.deferred = {}

	self.systems = {}
	self.all_systems = {}

	self.event = pubsub()
end

function kernel:update(dt)
	self:flush()
	table.insertion_sort(self.with_update, entity.less)
	for _, v in ipairs(self.with_update) do
		if v.enabled ~= false then
			v:update(dt)
		end
	end
	self:flush(dt)
end

function kernel:draw()
	table.insertion_sort(self.with_draw, entity.draw_less)
	for _, v in ipairs(self.with_draw) do
		if 
			v.visible ~= false
			and v.enabled ~= false
		then
			lg.push("all")
			if v.pos then
				lg.translate(v.pos.x, v.pos.y)
			end
			v:draw()
			lg.pop()
		end
	end
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
	if type(behaviour.update) == "function" then
		table.insert(self.with_update, behaviour)
	end
	if type(behaviour.draw) == "function" then
		table.insert(self.with_draw, behaviour)
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
	if type(behaviour.update) == "function" then
		table.remove_value(self.with_update, behaviour)
	end
	if type(behaviour.draw) == "function" then
		table.remove_value(self.with_draw, behaviour)
	end
	--also from any systems
	for _, s in ipairs(self.all_systems) do
		if s.removed then
			s:removed(behaviour)
		end
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


return kernel