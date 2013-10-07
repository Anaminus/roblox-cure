-- maxmimum length of strings that can be passed through a remote. Exceeding
-- this values disconnects the client.
MAX_STRING_LENGTH = 200000

-- The globals `IsServer` and `IsClient` indicate whether the script is
-- running on the server or a client. Since these values are global, they may
-- also be used by packages.
IsServer = true
IsClient = false
shared.IsServer = IsServer
shared.IsClient = IsClient

-- packages borrow this script's env to access globals
-- any global definitions will be available to these packages
local script = script
getfenv().script = nil

cure = script.Parent
shared.cure = cure

local Global = cure:WaitForChild("global")
local ServerPeer = cure:WaitForChild("server")
local Packages = ServerPeer:WaitForChild("packages")
local Scripts = ServerPeer:WaitForChild("scripts")
local ClientPeer = cure:WaitForChild("client")
local ClientPackages = ClientPeer:WaitForChild("packages")
local ClientScripts = ClientPeer:WaitForChild("scripts")

-- contains data that will be streamed to client
local clientData = {}


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
		return run()
	end
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
		local function r(object,preName)
			local children = object:GetChildren()
			for i = 1,#children do
				local longName = preName .. decodeTruncEsc(children[i].Name)
				local source = getSourceFromInstance(children[i],false)
				if source then
					packageSource[longName] = source
				else
					-- only recurse non-source objects
					r(children[i],longName .. ".")
				end
			end
		end

		r(Packages,"")
	end

	function require(name,fetch)
		name = tostring(name)

		if packageData[name] then
			return packageData[name]
		end

		local source = packageSource[name]
		if not source then
			if fetch then
				return
			else
				error("`" .. name .. "` is not an existing package",2)
			end
		end

		local result = runSource(name,source,true,2)
		result = result == nil and true or result
		packageData[name] = result
		return result
	end

	shared.require = require

---- Global packages

	local globalPackages = {}

	-- retrieve global sources
	local clientGlobal = {}
	clientData.global = clientGlobal

	local n = 0
	local function r(object,preName)
		local children = object:GetChildren()
		for i = 1,#children do
			local shortName = decodeTruncEsc(children[i].Name)
			local longName = preName .. shortName
			local source = getSourceFromInstance(children[i],false)
			if source then
				n = n + 1
				packageSource[longName] = source
				globalPackages[n] = {longName,shortName}
				clientGlobal[n] = {longName,shortName,source}
			else
				-- only recurse non-source objects
				r(children[i],longName .. ".")
			end
		end
	end

	r(Global,"")

	-- require global packages
	local env = getfenv()
	for i = 1,#globalPackages do
		local long = globalPackages[i][1]
		local short = globalPackages[i][2]
		-- FIX: top-level `require` in lower-level area
		local result = require(long)
		env[short] = result
		shared[short] = result
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Run scripts

do
	local function r(object,preName)
		local children = object:GetChildren()
		for i = 1,#children do
			local longName = preName .. decodeTruncEsc(children[i].Name)
			local source = getSourceFromInstance(children[i],false)
			if source then
				coroutine.wrap(runSource)(longName,source,false)
			else
				-- only recurse non-source objects
				r(children[i],longName .. ".")
			end
		end
	end

	r(Scripts,"")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Enable setup of client scripts and packages

local CureClient = cure:FindFirstChild("cure.client")
if CureClient then
	-- setup client data
	do
		local n
		local function r(t,object,fullName)
			local children = object:GetChildren()
			for i = 1,#children do
				local short = decodeTruncEsc(children[i].Name)
				local name = fullName .. short
				local source = getSourceFromInstance(children[i],false)
				if source then
					n = n + 1
					t[n] = {name,short,source}
				else
					-- only recurse non-source objects
					r(t,children[i],name .. ".")
				end
			end
		end

		clientData.package = {}
		clientData.script = {}

		n = 0
		r(clientData.package,ClientPackages,"")
		n = 0
		r(clientData.script,ClientScripts,"")
	end

	local Players = Game:GetService('Players')
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:connect(function(player)
		local CallStream = Instance.new('RemoteFunction')
		CallStream.Name = "CallStream"
		local clientLoaded
		function CallStream.OnServerInvoke(peer,func,arg1,arg2)
			if peer ~= player then
				return false,"invalid peer"
			end

			if func == 'initialized' then
			-- client has initialized; return client source info
				return {
					{'package',#clientData.package};
					{'global',#clientData.global};
					{'script',#clientData.script};
				}
			elseif func == 'source' then
			-- serve a client source
				local long = clientData[arg1][arg2][1]
				local short = clientData[arg1][arg2][2]
				local source = clientData[arg1][arg2][3]

				-- divide source into chunks to avoid exceeding max length
				local div = {}
				local max = MAX_STRING_LENGTH
				for i = 0,math.floor(#source/max) do
					local n = i*max
					div[i+1] = source:sub(n+1, n+max)
				end
				return long,short,unpack(div)
			elseif func == 'loaded' then
			-- client has finished loading
				Spawn(clientLoaded)
			else
				return false,"invalid call"
			end
		end

		function clientLoaded()
			-- end the call stream
			CallStream:Destroy()
			if spawner then
				spawner.Add(player)
			end
		end

		CallStream.Parent = player

		local Container = Instance.new('Backpack',player)
		CureClient:Clone().Parent = Container
	end)

	if spawner then
		Players.PlayerRemoving:connect(function(player)
			spawner.Remove(player)
		end)
	end
end
