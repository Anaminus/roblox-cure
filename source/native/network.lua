local Network do
	Network = Game:GetService('ReplicatedStorage'):FindFirstChild("network")
	if not Network then
		Network = Instance.new('Configuration')
		Network.Name = "network"
		Network.Parent = Game:GetService('ReplicatedStorage')
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- Helper functions

-- packs a single value into a Value object
local packValue do
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
	function packValue(type,value,e)
		local dtype = convertCase[tostring(type):lower()]
		if not dtype then
			error("`" .. tostring(type) .. "` is not a valid type",e or 3)
		end
		local object = Instance.new(dtype .. 'Value')
		object.Value = value
		return object
	end
end

-- packs an array of values into Value objects
-- returns the object created from the array,
-- and a string that indicates the structure of the array
local function packArray(dtype,data,e)
	local object = Instance.new('Configuration')
	local struct = ''

	local n = #dtype
	for i = 1,n do
		if data[i] == nil then
			error("data array does not match type array",e or 3)
		end

		if type(dtype[i]) == 'table' then
			if type(data[i]) ~= 'table' then
				error("data array does not match type array",e or 3)
			end

			local str,child = packArray(dtype[i],data[i],(e or 3)+1)
			child.Name = i
			child.Parent = object
			struct = struct .. i .. '{' .. str .. '}'
		else
			local child = packValue(dtype[i],data[i],(e or 3)+1)
			child.Name = i
			child.Parent = object
			if i == n then
				struct = struct .. i
			end
		end
	end
	return struct,object
end

-- decodes an array structure string
-- "3{4}5" -> {a, b, {a, b, c, d}, c, d}
local decodeStruct do
	local cache = {}
	function decodeStruct(str)
		if cache[str] then
			return cache[str]
		else
			local digit = {}
			for i = 0,9 do digit[tostring(i)] = true end

			local struct = {}

			local stack = {struct}
			local num = 1

			local i = 1
			local n = #str
			while i <= n do
				local c = str:sub(i,i)
				if digit[c] then
					local d = i
					repeat d = d + 1 until not digit[str:sub(d,d)]
					d = d - 1
					num = tonumber(str:sub(i,d))
					i = d
					for n = #struct+1,num do
						struct[n] = true
					end
				elseif c == '{' then
					struct[num] = {}
					struct = struct[num]
					stack[#stack+1] = struct
				elseif c == '}' then
					stack[#stack] = nil
					struct = stack[#stack]
				end
				i = i + 1
			end
			cache[str] = struct
			return struct
		end
	end
end

local function unpackValue(object)
	-- TODO: verify that object is a Value object
	return object.Value
end

local function unpackArray(struct,object)
	local data = {}
	for i = 1,#struct do
		local child = object:WaitForChild(tostring(i))
		local value
		if type(struct[i]) == 'table' then
			if not child:IsA'Configuration' then
				return nil
			end
			value = unpackArray(struct[i],child)
			if value == nil then return nil end
		else
			value = unpackValue(child)
		end
		data[i] = value
	end
	return data
end

local function handlePacket(packet)
	if packet:IsA'Configuration' then
		-- packet is a multi-value array object
		local array = packet:WaitForChild("array")
		local struct = packet:WaitForChild("struct")
		return packet.Name,unpackArray(decodeStruct(struct.Value),array)
	else
		-- packet is a single-value object
		return packet.Name,unpackValue(packet)
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- network

local network = {}

function network.send(ref,dtype,data)
	local packet
	if type(dtype) == 'table' then
		packet = Instance.new('Configuration')
		local structstr,array = packArray(dtype,data)
		array.Name = "array"
		array.Parent = packet
		local struct = Instance.new('StringValue',packet)
		struct.Name = "struct"
		struct.Value = structstr
	else
		packet = packValue(dtype,data)
	end
	packet.Name = ref
	packet.Parent = Network
	return true
end

do
	local receivers = {}
	Network.ChildAdded:connect(function(packet)
		local ref,data = handlePacket(packet)
		for i = 1,#receivers do
			local receiver = receivers[i]
			if ref:match(receiver.pattern) then
				coroutine.wrap(receiver.callback)(data,ref)
			end
		end
	end)

	function network.receive(pattern,callback)
		local receiver = {
			connected = true;
			pattern = pattern;
			callback = callback;
		}
		function receiver:disconnect()
			for i = 1,#receivers do
				if receivers[i][2] == self then
					table.remove(receivers,i)
					break
				end
			end
			self.connected = false
		end
		receivers[#receivers+1] = receiver
		return receiver
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- server-only

if IsServer then
	Network.ChildAdded:connect(function(packet)
		-- Debris service is not used because it clears children
		-- which would be bad for multi-value packets
		delay(5,function() packet.Parent = nil end)
	end)
end

return network
