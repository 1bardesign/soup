local entity = class()

function entity:new(kernel)
	self.kernel = kernel

	self.all_behaviours = {}
	self.named_behaviours = {}
	
	self.subscriptions = {}

	self.destroyed = false
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
	self:error_if_destroyed()
	self.kernel:add(behaviour)
	table.insert(self.all_behaviours, behaviour)
	return behaviour
end

function entity:add_named(name, behaviour)
	self.named_behaviours[name] = behaviour
	return self:add(behaviour)
end

function entity:add_from_system(system_name, ...)
	self:error_if_destroyed()
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
	self:error_if_destroyed()

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
	--clean up components
	for i, v in ripairs(self.all_behaviours) do
		self:remove(v)
	end
	--unsub everything
	for i, v in ripairs(self.subscriptions) do
		self.kernel.event:unsubscribe(v[1], v[2])
		table.remove(self.subscriptions, i)
	end
	self.destroyed = true
	self.enabled = false
end

function entity:error_if_destroyed()
	if self.destroyed then
		error("entity used after destruction")
		return
	end
end

--event handling proxied through the kernel
function entity:publish(event, ...)
	self:error_if_destroyed()
	self.kernel.event:publish(event, ...)
end

function entity:subscribe(event, f)
	self:error_if_destroyed()
	self.kernel.event:subscribe(event, f)
	table.insert(self.subscriptions, {event, f})
end

function entity:subscribe_once(event, f)
	self:error_if_destroyed()
	f = self.kernel.event:subscribe_once(event, f)
	table.insert(self.subscriptions, {event, f})
end

function entity:unsubscribe(event, f)
	self:error_if_destroyed()
	self.kernel.event:unsubscribe(event, f)
	for i, v in ipairs(self.subscriptions) do
		if v[1] == event and v[2] == f then
			table.remove(self.subscriptions, i)
			break
		end
	end
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