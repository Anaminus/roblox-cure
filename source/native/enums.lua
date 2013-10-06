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
	
		for number,itemName in pairs(definition) do
			local itemObject = Instance.new('IntValue')
			itemObject.name = itemName
			itemObject.Value = number
			itemObject.Parent = object
		end
	
		return true
	end
end

return enums
