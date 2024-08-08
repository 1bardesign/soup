local entity = class()

function entity:new(kernel)
	self.kernel = kernel
	self.all_components = {}
	self.named_components = {}

	self.destroyed = false
end

function entity:c(name)
	return self.named_components[name]
end

function entity:add(component)
	if self.destroyed then
		error("entity:add after destruction")
		return
	end
	self.kernel:add(component)
	table.insert(self.all_components, component)
	return component
end

function entity:add_named(name, component)
	self.named_components[name] = component
	return self:add(component)
end

function entity:add_from_system(system_name, ...) 
	local component = self.kernel:add_from_system(system_name, ...)
	table.insert(self.all_components, component)
	return component
end

function entity:add_named_from_system(system_name, name, ...)
	local component = self:add_from_system(system_name, ...)
	self.named_components[name] = component
	return component
end

function entity:name_for(component)
	for k, v in pairs(self.named_components) do
		if v == component then
			return k
		end
	end
	return nil
end

function entity:remove(component_or_name)
	if self.destroyed then
		error("entity:remove after destruction")
		return
	end

	local component, name
	if type(component_or_name) == "string" then
		name = component_or_name
		component = self.named_components[name]
	else
		component = component_or_name
	end

	if table.remove_value(self.all_components, component) then
		if not name then
			name = self:name_for(component)
		end
		if name then
			self.named_components[name] = nil
		end
		self.kernel:remove(component)
	end
end

--remove everything and mark destroyed
function entity:destroy()
	for i, v in ripairs(self.all_components) do
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