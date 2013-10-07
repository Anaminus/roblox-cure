MethodClose = 0
MethodInit = 1
MethodSend = 2

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------

-- Container for network remotes
local Network = Game:GetService('ReplicatedStorage'):FindFirstChild("network")
if not Network then
	Network = Instance.new('Configuration')
	Network.Name = "network"
	Network.Parent = Game:GetService('ReplicatedStorage')
end

-- RemoteStream is used to associate an incoming remote with a peer. Before a
-- peer adds a remote, it passes itself and the remote to the recipient, so
-- the recipient knows which peer created the remote.
local RemoteStream = Network:FindFirstChild("RemoteStream")
if not RemoteStream then
	RemoteStream = Instance.new('RemoteFunction')
	RemoteStream.Name = "RemoteStream"
	RemoteStream.Parent = Network
end

-- In case a malicious client removes the remote, add it back in. Hope any
-- communications are not interrupted (doubtful). If the malicious client
-- happens to destroy the remote, it will have only sabotaged itself. The
-- destroyed state does not replicate, so the object will reappear just fine
-- on other peers, while remaining destroyed on the malicious client.
Network.ChildRemoved:connect(function(c)
	if c == RemoteStream then
		c.Parent = Network
	end
end)
-- In theory, this property could be exploited to create objects that
-- replicate only to chosen peers. However, it requires cooperation from each
-- uninvolved peer. It would also throw a lot of ugly errors.

-- Used to tell the server that the network package has finished initializing
-- for a client.
local InitStream = Network:FindFirstChild("InitStream")
if not InitStream then
	InitStream = Instance.new('RemoteFunction')
	InitStream.Name = "InitStream"
	InitStream.Parent = Network
end
Network.ChildRemoved:connect(function(c)
	if c == RemoteStream then
		c.Parent = Network
	end
end)

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------

local function validatePort(port)
	if type(port) ~= 'number' then
		return nil
	end
	if math.floor(port) ~= port then
		return nil
	end
	if port < 0 or port > 2^16-1 then
		return nil
	end
	return port
end

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------

local network = {}

if IsServer then
	local initPeer do
		local peers = {}
		local waiting = {}
		function InitStream.OnServerInvoke(peer)
			peers[peer] = true
			if waiting[peer] then
				local t = waiting[peer]
				waiting[peer] = nil
				for i = 1,#t do
					t[i].Value = not t[i].Value
				end
			end
		end

		function initPeer(peer)
			if not peers[peer] then
				local halt = Instance.new('BoolValue')
				if waiting[peer] then
					local t = waiting[peer]
					t[#t+1] = halt
				else
					waiting[peer] = {halt}
				end
				halt.Changed:wait()
			end
		end
	end

	local function createSocket(peer,remote,conn,halt)
		local socket = {
			Recipient = peer;
			Closed = false;
		}
		local closed = false

		halt = halt or Instance.new('BoolValue')

		function socket:Send(...)
			if closed then
				error("socket is closed",2)
			end
			remote:InvokeClient(peer,MethodSend,{...})
		end

		local receiveBuffer = {}
		function remote.OnServerInvoke(p,method,data)
			if p ~= peer then
				return
			end
			if method == MethodSend then
				table.insert(receiveBuffer,data)
				halt.Value = not halt.Value
			elseif method == MethodClose then
				closed = true
				socket.Closed = true
				remote.OnServerInvoke = nil
				conn:disconnect()
				halt.Value = not halt.Value
				Spawn(function()
					remote:Destroy()
				end)
			end
			return
		end
		function socket:Receive()
			if closed then
				error("socket is closed",2)
			end
			if #receiveBuffer == 0 then
				halt.Changed:wait()
			end
			if closed then
				error("socket was closed",2)
			end
			return unpack(table.remove(receiveBuffer,1))
		end

		function socket:Close()
			if not closed then
				closed = true
				socket.Closed = true
				socket.Recipient = nil
				conn:disconnect()
				remote:InvokeClient(peer,MethodClose)
				remote:Destroy()
			end
		end

		return socket
	end

	function network.Socket(peer,port)
		if not validatePort(port or 0) then
			error("invalid port number",2)
		end
		initPeer(peer)
		local remote = Instance.new('RemoteFunction')
		remote.Name = "Socket"

		local conn = Network.ChildRemoved:connect(function(c)
			if c == remote then
				c.Parent = Network
			end
		end)

		local halt = Instance.new("BoolValue")

		function remote.OnServerInvoke(p,method)
			if p ~= peer then
				return
			end
			if method == MethodInit then
				return port
			elseif method == MethodReady then
				remote.OnServerInvoke = nil
				halt.Value = not halt.Value
			end
			return
		end

		remote.Parent = Network
		RemoteStream:InvokeClient(peer,true,remote)
		halt.Changed:wait()
		return createSocket(peer,remote,conn,halt)
	end

	local incomingRemotes = {}
	local waitingListeners = {}
	function RemoteStream.OnServerInvoke(peer,remote)
		if remote.ClassName ~= 'RemoteFunction' or remote == RemoteStream then
			return
		end
		if incomingRemotes[remote] == nil then
			incomingRemotes[remote] = peer
		end
		if waitingListeners[remote] then
			local peer = incomingRemotes[remote]
			local ls = waitingListeners[remote]
			waitingListeners[remote] = nil
			for i = 1,#ls do
				if ls[i](remote,peer) then
					break
				end
			end
		end
	end

	function network.Listener(port,callback)
		local listener = {
			Port = port or 0;
			Callback = callback;
		}

		local function checkRemote(remote,peer)
			local port = validatePort(remote:InvokeClient(peer,MethodInit))
			if port ~= listener.Port then
				return false
			end

			incomingRemotes[remote] = nil
			Spawn(function()
				local conn = Network.ChildRemoved:connect(function(c)
					if c == remote then
						c.Parent = Network
					end
				end)

				local socket = createSocket(peer,remote,conn)
				remote:InvokeClient(peer,MethodReady)

				if listener.Callback then
					listener.Callback(socket)
				end
			end)
			return true
		end

		local function handleRemote(remote)
			if remote.ClassName ~= 'RemoteFunction' or remote == RemoteStream then
				return
			end
			if incomingRemotes[remote] then
				checkRemote(remote,incomingRemotes[remote])
			elseif waitingListeners[remote] then
				local t = waitingListeners[remote]
				t[#t+1] = checkRemote
			else
				waitingListeners[remote] = {checkRemote}
			end
		end

		local conn = Network.ChildAdded:connect(handleRemote)

		function listener:Close()
			conn:disconnect()
		end

		local remotes = Network:GetChildren()
		for i = 1,#remotes do
			coroutine.wrap(handleRemote)(remotes[i])
		end

		return listener
	end
else
	local function createSocket(peer,remote,conn,halt)
		local socket = {
			Recipient = peer;
			Closed = false;
		}
		local closed = false

		halt = halt or Instance.new('BoolValue')

		function socket:Send(...)
			if closed then
				error("socket is closed",2)
			end
			remote:InvokeServer(MethodSend,{...})
		end

		local receiveBuffer = {}
		function remote.OnClientInvoke(method,data)
			if method == MethodSend then
				table.insert(receiveBuffer,data)
				halt.Value = not halt.Value
			elseif method == MethodClose then
				closed = true
				socket.Closed = true
				remote.OnClientInvoke = nil
				conn:disconnect()
				halt.Value = not halt.Value
				Spawn(function()
					remote:Destroy()
				end)
			end
			return
		end
		function socket:Receive()
			if closed then
				error("socket is closed",2)
			end
			if #receiveBuffer == 0 then
				halt.Changed:wait()
			end
			if closed then
				error("socket was closed",2)
			end
			return unpack(table.remove(receiveBuffer,1))
		end

		function socket:Close()
			if not closed then
				closed = true
				socket.Closed = true
				socket.Recipient = nil
				conn:disconnect()
				remote:InvokeServer(MethodClose)
				remote:Destroy()
			end
		end

		return socket
	end

	function network.Socket(peer,port)
		if not validatePort(port or 0) then
			error("invalid port number",2)
		end
		local remote = Instance.new('RemoteFunction')
		remote.Name = "Socket"

		local conn = Network.ChildRemoved:connect(function(c)
			if c == remote then
				c.Parent = Network
			end
		end)

		local halt = Instance.new("BoolValue")

		function remote.OnClientInvoke(method)
			if method == MethodInit then
				return port
			elseif method == MethodReady then
				remote.OnClientInvoke = nil
				halt.Value = not halt.Value
			end
			return
		end

		remote.Parent = Network
		RemoteStream:InvokeServer(remote)
		halt.Changed:wait()

		return createSocket(peer,remote,conn,halt)
	end

	local incomingRemotes = {}
	local waitingListeners = {}
	function RemoteStream.OnClientInvoke(peer,remote)
		if remote.ClassName ~= 'RemoteFunction' or remote == RemoteStream then
			return
		end
		if incomingRemotes[remote] == nil then
			incomingRemotes[remote] = true
		end
		if waitingListeners[remote] then
			local peer = incomingRemotes[remote]
			local ls = waitingListeners[remote]
			waitingListeners[remote] = nil
			for i = 1,#ls do
				if ls[i](remote,peer) then
					break
				end
			end
		end
	end

	function network.Listener(port,callback)
		local listener = {
			Port = port or 0;
			Callback = callback;
		}

		local function checkRemote(remote,peer)
			local port = validatePort(remote:InvokeServer(MethodInit))
			if port ~= listener.Port then
				return false
			end

			incomingRemotes[remote] = nil
			Spawn(function()
				local conn = Network.ChildRemoved:connect(function(c)
					if c == remote then
						c.Parent = Network
					end
				end)

				local socket = createSocket(peer,remote,conn)
				remote:InvokeServer(MethodReady)

				if listener.Callback then
					listener.Callback(socket)
				end
			end)
			return true
		end

		local function handleRemote(remote)
			if remote.ClassName ~= 'RemoteFunction' or remote == RemoteStream then
				return
			end
			if incomingRemotes[remote] then
				checkRemote(remote,incomingRemotes[remote])
			elseif waitingListeners[remote] then
				local t = waitingListeners[remote]
				t[#t+1] = checkRemote
			else
				waitingListeners[remote] = {checkRemote}
			end
		end

		local conn = Network.ChildAdded:connect(handleRemote)

		function listener:Close()
			conn:disconnect()
		end

		local remotes = Network:GetChildren()
		for i = 1,#remotes do
			coroutine.wrap(handleRemote)(remotes[i])
		end

		return listener
	end

	InitStream:InvokeServer()
end

return network
