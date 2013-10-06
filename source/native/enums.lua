local Enums = cure:WaitForChild('enums')
local enums = {}

function enums:Register(name,definition)
	if name == "Register" then
		error("'" .. key .. "' cannot be used as an enum",2)
	elseif Enums:FindFirstChild(name) then
		return false
	else
		local object = Instance.new('Configuration')
		object.Name = name
		object.Parent = Enums
	
		for itemName,number in pairs(definition) do
			local itemObject = Instance.new('IntValue')
			itemObject.name = itemName
			itemObject.Value = number
			itemObject.Parent = object
		end
	
		return true
	end
end

setmetatable(enums,{
	__index = function(self,enumName)
		local enum = Enums:FindFirstChild(enumName)
		if enum then
			return setmetatable({},{
				__index = function(self,itemName)
					local item = enum:FindFirstChild(itemName)
					if item then
						return item.Value
					else
						error("enum item `" .. tostring(itemName) .. "` does not exist",2)
					end
				end
			})
		else
			error("enum `" .. tostring(enumName) .. "` does not exist",2)
		end
	end
})

return enums
