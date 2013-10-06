local Settings = cure:WaitForChild('settings')
local settings = {}

local eventChanged do
	local connections = {}
	local waitEvent = Instance.new('BoolValue')
	local waitArguments = {}

	local Event = {}
	local Invoker = {Event = Event}

	function Event:connect(func)
		local connection = {connected = true}
		function connection:disconnect()
			for i = 1,#connections do
				if connections[i][2] == self then
					table.remove(connections,i)
					break
				end
			end
			self.connected = false
		end
		connections[#connections+1] = {func,connection}
		return connection
	end

	function Event:wait()
		waitEvent.Changed:wait()
		return unpack(waitArguments)
	end

	function Invoker:Fire(...)
		waitArguments = {...}
		waitEvent.Value = not waitEvent.Value
		for i,conn in pairs(connections) do
			conn[1](...)
		end
	end

	settings.Changed = Event
	eventChanged = Invoker
end

local function connectEvents(object)
	local conChanged,conParent
	conChanged = object.Changed:connect(function(value)
		eventChanged:Fire(object.Name,value)
	end)
	conParent = object.AncestryChanged:connect(function()
		if object.Parent ~= Settings then
			conChanged:disconnect()
			conParent:disconnect()
		end
	end)
end

for i,object in pairs(Settings:GetChildren()) do
	connectEvents(object)
end
Settings.ChildAdded:connect(connectEvents)

do
	local convertCase = {
		['bool']       = 'Bool';
		['boolean']    = 'Bool';
		['brickcolor'] = 'BrickColor';
		['cframe']     = 'CFrame';
		['color3']     = 'Color3';
		['int']        = 'Int';
		['number']     = 'Number';
		['object']     = 'Object';
		['ray']        = 'Ray';
		['string']     = 'String';
		['vector3']    = 'Vector3';
	}
	function settings:Add(key,type,value)
		if key == "Add" or key == "Remove" or key == "Changed" then
			error("'" .. key .. "' cannot be used as a setting",2)
		end

		if Settings:FindFirstChild(key) then
			return false
		else
			local dtype = convertCase[tostring(type):lower()]
			if not dtype then
				error("`" .. tostring(type) .. "` is not a valid type",2)
			end

			local object = Instance.new(dtype .. 'Value')
			object.Name = key
			object.Value = value
			object.Parent = Settings

			return true
		end
	end
end

function settings:Remove(key)
	local value = Settings:FindFirstChild(key)
	if value then
		value:Destroy()
		return true
	else
		return false
	end
end

local function setvalue(value,v) value.Value = v end
setmetatable(settings,{
	__index = function(self,k)
		local value = Settings:FindFirstChild(k)
		if value then
			return value.Value
		else
			error("setting `" .. tostring(k) .. "` does not exist",2)
		end
	end;
	__newindex = function(self,k,v)
		local value = Settings:FindFirstChild(k)
		if value then
			local s,e = pcall(setvalue,value,v)
			if not s then error(e,2) end
		else
			error("setting `" .. tostring(k) .. "` does not exist",2)
		end
	end;
})

return settings
