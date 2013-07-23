-- tag names for handshake between client and server main scripts
local loadedTagName = 'ClientLoaded'
local packageTagName = 'PackageList'
local nativeTagName = 'NativeList'
local scriptTagName = 'ScriptList'

-- For consistency, both the client and the server main scripts have the
-- same source. So, the globals `IsServer` and `IsClient` indicate whether
-- the script is running on the server or a client. Since these values
-- are global, they may also be used by packages.
IsServer = script.ClassName == 'Script'
IsClient = script.ClassName == 'LocalScript'
shared.IsServer = IsServer
shared.IsClient = IsClient

if IsClient then
	-- safely remove self
	repeat script.Parent = nil wait() until script.Parent == nil

	-- wait until game loads
	if not Game:IsLoaded() then
		Game.Loaded:wait()
	end

	-- send tag to indicate to server that we are successfully running
	do
		local tag = Instance.new('BoolValue')
		tag.Name = loadedTagName
		tag.Value = true
		tag.Parent = Game:GetService('Players').LocalPlayer
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- packages borrow this script's env to access globals
-- any global definitions will be available to these packages
local script = script
getfenv().script = nil

cure = Workspace:WaitForChild("cure")
shared.cure = cure

local Native = cure:WaitForChild("native")
local Peer = cure:WaitForChild("peers"):WaitForChild(IsServer and "server" or "client")
local Packages = Peer:WaitForChild("packages")
local Scripts = Peer:WaitForChild("scripts")


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Helper functions

local getSourceFromInstance

-- retrieve a source from an external roblox asset
local function getSourceFromAsset(id,doerr,e)
	local model = Game:GetService('InsertService'):LoadAsset(id)

	if not model then
		(doerr and error or print)("could not load asset from ID `" .. id .. "`",e and e+1 or 2)
		return nil
	end

	return getSourceFromInstance(model:GetChildren()[1],doerr,e and e+1 or 2)
end

-- because of the way XML is parsed, leading spaces get truncated
-- so, simply add a "\" when a space or "\" is detected as the first character
local function encodeTruncEsc(str)
	local first = str:sub(1,1)
	if first:match('%s') or first == [[\]] then
		return [[\]] .. str
	end
	return str
end

local function decodeTruncEsc(str)
	local first = str:sub(1,1)
	if first == [[\]] then
		return str:sub(2)
	end
	return str
end

-- retrieve a source from an instance
function getSourceFromInstance(object,doerr,e)
	local source = nil
	if object:IsA'StringValue' then
		-- take the source from the value
		source = decodeTruncEsc(object.Value)
	elseif object:IsA'BoolValue' then
		-- multi-part object; take source from child StringValues
		local value = ""
		for i,part in pairs(object:GetChildren()) do
			if part:IsA'StringValue' then
				value = value .. decodeTruncEsc(part.Value)
			end
		end
		source = value
	elseif object:IsA'IntValue' then
		-- take source from external asset
		source = getSourceFromAsset(decodeTruncEsc(object.Value),doerr,e and e+1 or 2)
	end
	return source
end

-- run a source as lua
local runSource do
	local env = getfenv()
	function runSource(name,source,doerr,e)
		local run,err = loadstring(source,name)

		if not run then
			(doerr and error or print)(err,e and e+1 or 2)
			return nil
		end

		-- the function's env will piggyback off of this script's env to access globals
		setfenv(run,setmetatable({},{__index=env,__metatable="The metatable is locked"}))
		-- but, because of how lua works, we will inject this env into the script's env
		local ret = {run()}
		for i, v in pairs(getfenv(run)) do
			env[i] = v
		end
		return unpack(ret)
	end
end

-- retrieves a list of children from an object
-- if on the client, then the list is retrieved from the server using the given name
local function receiveChildren(object,name)
	local list
	if IsClient then
		list = {}
		repeat
			-- repeat until we find a StringValue with the given name
			local tag = Game:GetService('Players').LocalPlayer:WaitForChild(name)
			if tag:IsA'StringValue' then
				-- decode the value into a list of strings, seperated by ";", escaped by "\"
				for item in decodeTruncEsc(tag.Value):gmatch([[(.-[^\]);]]) do
					list[#list+1] = object:WaitForChild(item:gsub([[\;]],[[;]]))
				end
				tag:Destroy()
				break
			end
		until false
	else
		list = object:GetChildren()
	end
	return list
end

local function traversePackage(obj,package,namappend)
	namappend = namappend or ""
	obj = type(obj) == "table" and obj or obj:getChildren()
	for i=1,#obj do
		if obj[i]:isA"Configuration" then
			--Folder! Gah!
			traversePackage(obj[i],package,namappend..decodeTruncEsc(obj[i].Name)..".")
		else
			package[namappend..decodeTruncEsc(obj[i].Name)] = getSourceFromInstance(obj[i],false)
		end
	end
end

local function traverseNativePackage(obj,package,natpack,namappend)
	namappend = namappend or ""
	obj = type(obj) == "table" and obj or obj:getChildren()
	for i=1,#obj do
		natpack[i] = namappend..decodeTruncEsc(obj[i].Name)
		if obj[i]:isA"Configuration" then
			--Folder! Gah!
			traversePackage(obj[i],package,natpack,namappend..decodeTruncEsc(obj[i].Name)..".")
		else
			package[namappend..decodeTruncEsc(obj[i].Name)] = getSourceFromInstance(obj[i],false)
		end
	end
end

-- server-only: creates a StringValue with a list of children names, to be sent to a client
local function makeListTag(object,name)
	local value = ""
	for i,child in pairs(object:GetChildren()) do
		value = value .. child.Name:gsub([[;]],[[\;]]) .. ';'
	end
	local tag = Instance.new('StringValue')
	tag.Name = name
	tag.Value = encodeTruncEsc(value)
	return tag
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- require

do
	local packageSource = {}
	local packageData = {}

	-- retrieve package sources
	do
		local packages = receiveChildren(Packages,packageTagName)
		traversePackage(packages,packageSource)
	end

	function require(name)
		name = tostring(name)

		if packageData[name] then
			return packageData[name]
		end
		
		local source = packageSource[name]
		if not source then
			error("`" .. name .. "` is not an existing package",2)
		end

		local result = runSource(name,source,true,2)
		result = result == nil and true or result
		packageData[name] = result
		return result
	end

	shared.require = require

---- Native packages

	local nativePackages = {}
	-- retrieve native sources
	do
		local packages = receiveChildren(Native,nativeTagName)
		traverseNativePackage(packages,packageSource,nativePackages)
		for i=1,#packages do
			local name = decodeTruncEsc(packages[i].Name)
			packageSource[name] = getSourceFromInstance(packages[i],false)
			nativePackages[i] = name
		end
	end

	-- require native packages
	local env = getfenv()
	for i = 1,#nativePackages do
		local name = nativePackages[i]
		-- FIX: top-level `require` in lower-level area
		local result = require(name)
		env[name] = result
		shared[name] = result
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Run scripts

do
	local Player = Game:GetService('Players').LocalPlayer
	local scripts = receiveChildren(Scripts,scriptTagName)
	for i = 1,#scripts do
		local script = scripts[i]
		if script:IsA'Script' then
			if IsServer then
				script.Disabled = false
			else
				local s = script:Clone()
				s.Disabled = false
				s.Parent = Player:FindFirstChild('PlayerGui')
			end
		else
			local source = getSourceFromInstance(script,false)
			if source then
				coroutine.wrap(runSource)(decodeTruncEsc(script.Name),source,false)
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Enable setup of client scripts and packages

if IsServer then
	local ClientMain = script:FindFirstChild("cure")
	if ClientMain then
		local packageList = makeListTag(cure.peers.client.packages,packageTagName)
		local nativeList  = makeListTag(Native,nativeTagName)
		local scriptList  = makeListTag(cure.peers.client.scripts,scriptTagName)

		local Players = Game:GetService('Players')
		Players.CharacterAutoLoads = false
		Players.PlayerAdded:connect(function(player)
			local Container = Instance.new('Backpack',player)
			ClientMain:Clone().Parent = Container
			player:WaitForChild("ClientLoaded"):Destroy()
			packageList:Clone().Parent = player
			nativeList:Clone().Parent = player
			scriptList:Clone().Parent = player

			if spawner then
				spawner.add(player)
			end
		end)

		if spawner then
			Players.PlayerRemoving:connect(function(player)
				spawner.remove(player)
			end)
		end
	end
end
