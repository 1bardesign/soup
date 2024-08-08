local entity = class()

function entity:new(kernel)
	self.kernel = kernel
	self.all_behaviours = {}
	self.named_behaviours = {}

	self.destroyed = false
end

function entity:c(name)
	return self.named_behaviours[name]
end

function entity:b(name)
	return self.named_behaviours[name]
end

function entity.__index(self, name)
	local v = rawget(self, name)
	if v ~= nil then
		return v
	end
	local b = rawget(self, "named_behaviours")
	b = b and b[name]
	if b ~= nil then
		return b
	end
	return entity[name]
end

function entity:add(behaviour)
	if self.destroyed then
		error("entity:add after destruction")
		return
	end
	self.kernel:add(behaviour)
	table.insert(self.all_behaviours, behaviour)
	return behaviour
end

function entity:add_named(name, behaviour)
	self.named_behaviours[name] = behaviour
	return self:add(behaviour)
end

function entity:add_from_system(system_name, ...) 
	local behaviour = self.kernel:add_from_system(system_name, ...)
	table.insert(self.all_behaviours, behaviour)
	return behaviour
end

function entity:add_named_from_system(system_name, name, ...)
	local behaviour = self:add_from_system(system_name, ...)
	self.named_behaviours[name] = behaviour
	return behaviour
end

function entity:name_for(behaviour)
	for k, v in pairs(self.named_behaviours) do
		if v == behaviour then
			return k
		end
	end
	return nil
end

function entity:remove(behaviour_or_name)
	if self.destroyed then
		error("entity:remove after destruction")
		return
	end

	local behaviour, name
	if type(behaviour_or_name) == "string" then
		name = behaviour_or_name
		behaviour = self.named_behaviours[name]
	else
		behaviour = behaviour_or_name
	end

	if table.remove_value(self.all_behaviours, behaviour) then
		if not name then
			name = self:name_for(behaviour)
		end
		if name then
			self.named_behaviours[name] = nil
		end
		self.kernel:remove(behaviour)
	end
end

--remove everything and mark destroyed
function entity:destroy()
	for i, v in ripairs(self.all_behaviours) do
		self:remove(v)
	end
	self.destroyed = true
end

--event handling proxied through the kernel
function entity:subscribe(...)
	self.kernel.event:subscribe(...)
end

function entity:subscribe_once(...)
	self.kernel.event:subscribe_once(...)
end

function entity:unsubscribe(...)
	self.kernel.event:unsubscribe(...)
end

--sorting and ordering functions
function entity.behaviour_has_update(a)
	return a.update and a.enabled ~= false
end

function entity.behaviour_sort_order(a)
	if not entity.behaviour_has_update(a) then
		--sort last, so we can skip them all
		return math.huge
	end
	return a.order or 0
end

function entity.less(a, b)
	return entity.behaviour_sort_order(a) < entity.behaviour_sort_order(b)
end

function entity.draw_less(a, b)
	a = a.draw_order or a.order or 0
	b = b.draw_order or b.order or 0
	return a < b
end

return entity