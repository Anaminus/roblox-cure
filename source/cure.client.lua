-- The globals `IsServer` and `IsClient` indicate whether the script is
-- running on the server or a client. Since these values are global, they may
-- also be used by packages.
IsServer = false
IsClient = true
shared.IsServer = IsServer
shared.IsClient = IsClient


-- safely remove self
repeat script.Parent = nil wait() until script.Parent == nil

-- wait until game loads
if not Game:IsLoaded() then
	Game.Loaded:wait()
end

-- packages borrow this script's env to access globals
-- any global definitions will be available to these packages
local script = script
getfenv().script = nil

-- wait for call stream
local CallStream = Game:GetService('Players').LocalPlayer:WaitForChild("CallStream")

-- load client data
local clientData do
	clientData = {}
	local calls,err = CallStream:InvokeServer('initialized')
	if not calls then
		error(err,0)
	end
	for i = 1,#calls do
		local data = {}
		local type = calls[i][1]
		clientData[type] = data
		for i = 1,calls[i][2] do
			local v = {CallStream:InvokeServer('source',type,i)}
			if not v[1] then
				error(v[2],0)
			end

			local long = v[1]
			local short = v[2]
			local source = table.concat(v,'',3)
			data[i] = {long,short,source}
		end
	end
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

	local packages = clientData.package
	for i = 1,#packages do
		packageSource[packages[i][1]] = packages[i][3]
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
	do
		local global = clientData.global
		for i = 1,#global do
			packageSource[global[i][1]] = global[i][3]
			globalPackages[#globalPackages+1] = {global[i][1],global[i][2]}
		end
	end

	-- global packages run ordered by long name
	table.sort(globalPackages,function(a,b)
		return a[1] < b[1]
	end)

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
	local Player = Game:GetService('Players').LocalPlayer
	local scripts = clientData.script
	table.sort(scripts,function(a,b)
		return a[1] < b[2]
	end)
	for i = 1,#scripts do
		local name = scripts[i][1]
		local source = scripts[i][3]
		coroutine.wrap(runSource)(name,source,false)
	end
end

-- indicate that client has finished loading
CallStream:InvokeServer('loaded')
