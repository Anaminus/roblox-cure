-- Container for network remotes
local Network = Game:GetService('ReplicatedStorage'):FindFirstChild("network")
if not Network then
	Network = Instance.new('Configuration')
	Network.Name = "network"
	Network.Parent = Game:GetService('ReplicatedStorage')
end

-- MessageStream is used by peers to send and receive socket metadata.
local MessageStream = Network:FindFirstChild("MessageStream")
if not MessageStream then
	MessageStream = Instance.new('RemoteEvent')
	MessageStream.Name = "MessageStream"
	MessageStream.Parent = Network
end

-- In case a malicious client removes the remote, add it back in. Hope any
-- communications are not interrupted. If the malicious client happens to
-- destroy the remote, the destroyed state does not replicate, so the object
-- will reappear just fine on other peers, while remaining destroyed on the
-- malicious client.
Network.ChildRemoved:connect(function(c)
	if c == MessageStream then
		c.Parent = Network
	end
end)

local function isPortValue(port)
	if type(port) == 'number' then
	-- if value is a number, convert it to a string
		port = tostring(port)
	elseif type(port) ~= 'string' then
	-- otherwise, value must be a string
		return false
	end
	if #port < 1 or #port > 32 then
	-- string must contain between 1 and 32 characters
		return false
	end
	if port:match('[^\32-\126]') then
	-- string may only contain basic printable characters
		return false
	end
	return true
end

---- Socket remote data type
-- Used when sending data through a socket.

SocketClose = 0
-- Indicates that the socket is being closed. No arguments.
SocketSend  = 1
-- Indicates that data is being sent through the socket. Arguments are 1) a
-- table containing the sent data.


---- Message remote data type
-- Used when sending data through the MessageStream.

MessageClientInit  = 0
-- Used by clients to tell the server that the network library has
-- initialized.
MessageNewRemote   = 1
-- Indicates that another peer has an incoming remote for the current peer.
-- Arguments are 1) the remote, and 2) the port number.
MessageRemoteReady = 2
-- Indicates that the recipient peer has processed the remote and is ready to
-- send or receive data.

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
---- Network implementation (per peer)

if IsServer then
	-- Used to create generic MessageStream listeners filtered by type.
	MessageTypes = {}
	MessageStream.OnServerEvent:connect(function(peer,msgType,...)
		if MessageTypes[msgType] then
			MessageTypes[msgType](peer,...)
		end
	end)

	-- Sends a single message across the MessageStream
	function SendMessage(peer,msgType,...)
		MessageStream:FireClient(peer,msgType,...)
	end

	-- Receives a single message from the MessageStream
	function ReceiveMessage(msgType)
		local v = {MessageStream.OnServerEvent:wait()}
		if v[2] == msgType then
			return v[1],unpack(v,3)
		end
	end

	-- Implements a socket's Send action.
	function socketSend(peer,remote,method,data)
		remote:InvokeClient(peer,method,data)
	end

	-- Implements a socket's Receive action.
	function socketReceive(remote,callback)
		remote.OnServerInvoke = function(peer,method,data)
			if method == SocketClose then
				remote.OnServerInvoke = nil
			end
			callback(peer,method,data)
		end
	end

	-- Implements a socket's Close action.
	function socketClose(peer,remote)
		remote:InvokeClient(peer,SocketClose)
	end

	-- Waits until a given peer's network package has initialized.
	do -- waitForPeer
		local peers = {}
		local waiting = {}
		MessageTypes[MessageClientInit] = function(peer)
			peers[peer] = true
			if waiting[peer] then
				local t = waiting[peer]
				waiting[peer] = nil
				for i = 1,#t do
					t[i].Value = not t[i].Value
				end
			end
		end
		function waitForPeer(peer)
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

	-- Indicates that the peer's network package has initialized.
	function networkInitialized()
		-- server is already initialized by the time anything else cares
	end
else
	MessageTypes = {}
	MessageStream.OnClientEvent:connect(function(msgType,...)
		if MessageTypes[msgType] then
			MessageTypes[msgType](nil,...)
		end
	end)

	function SendMessage(peer,msgType,...)
		MessageStream:FireServer(msgType,...)
	end

	function ReceiveMessage(msgType)
		local v = {MessageStream.OnClientEvent:wait()}
		if v[1] == msgType then
			return nil,unpack(v,2)
		end
	end

	function socketSend(peer,remote,method,data)
		remote:InvokeServer(method,data)
	end

	function socketReceive(remote,callback)
		remote.OnClientInvoke = function(method,data)
			if method == SocketClose then
				remote.OnClientInvoke = nil
			end
			callback(nil,method,data)
		end
	end

	function socketClose(peer,remote)
		remote:InvokeServer(SocketClose)
	end

	function waitForPeer(peer)
		-- server is already initialized by the time the client exists
	end

	function networkInitialized()
		SendMessage(nil,MessageClientInit)
	end
end

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
---- Network implementation (global)

local network = {}

-- creates a generic socket for a given recipient peer and remote
local function createSocket(peer,remote)
	local socket = {
		Recipient = peer;
		Closed = false;
	}
	local closed = false

	-- ensure remote persists
	local remoteConn = Network.ChildRemoved:connect(function(c)
		if c == remote then
			c.Parent = Network
		end
	end)

	-- used to block the thread when receiving
	local halt = Instance.new('BoolValue')

	function socket:Send(...)
		if closed then
			error("socket is closed",2)
		end
		socketSend(peer,remote,SocketSend,{...})
	end

	local receiveBuffer = {}
	socketReceive(remote,function(p,method,data)
		if p ~= peer then
			return
		end
		if method == SocketSend then
			table.insert(receiveBuffer,data)
			halt.Value = not halt.Value
		elseif method == SocketClose then
			closed = true
			socket.Closed = true
			remoteConn:disconnect()
			halt.Value = not halt.Value
			Spawn(function()
				remote:Destroy()
			end)
		end
		return
	end)
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

	-- close the socket if the peer disconnects
	local peerConn = Game:GetService('Players').PlayerRemoving:connect(function(player)
		if player == peer then
			socket:Close()
		end
	end)

	function socket:Close()
		if not closed then
			closed = true
			socket.Closed = true
			socket.Recipient = nil
			remoteConn:disconnect()
			peerConn:disconnect()
			socketClose(peer,remote)
			Spawn(function()
				remote:Destroy()
			end)
		end
	end

	return socket
end

function network.Socket(peer,port)
	if not isPortValue(port) then
		error("invalid port number",2)
	end

	-- Blocks the thread if it so happens that the recipient peer's network
	-- library has not yet finished initializing (otherwise it wouldn't detect
	-- our new-remote message).
	waitForPeer(peer)

	local remote = Instance.new('RemoteFunction')
	remote.Name = "Socket"
	remote.Parent = Network

	local socket = createSocket(peer,remote)
	-- Remote should replicate properly since it has been added to to the game
	-- hierarchy. However, this assumes that the object will always replicate
	-- before the message.
	SendMessage(peer,MessageNewRemote,remote,port)
	while true do
		-- FIX: It may be possible for the receive message to have been sent
		-- before this point.
		local p,rem = ReceiveMessage(MessageRemoteReady)
		if p == peer and rem == remote then
			break
		end
	end
	return socket
end

-- sets up a socket from a successful detection
local function linkListener(listener,peer,remote)
	local socket = createSocket(peer,remote)
	SendMessage(peer,MessageRemoteReady,remote)

	if listener.Callback then
		listener.Callback(socket)
	end
end

-- contains unhandled remote data
local remoteData = {}
-- contains active listeners
local listeners = {}

-- FIX?: Can malicious clients send unlimited new-remote messages? Roblox may
--       already throttle data sent by remotes.
-- FIX: Handle sockets being closed before being detected by a listener.
-- Fix: Listener will fail to detect existing remotes if port changes. Allow
--      modifiable ports?
MessageTypes[MessageNewRemote] = function(peer,remote,port)
	if not isPortValue(port) or not remote then
		return
	end

	-- check to see if any listeners match this new remote
	for i = 1,#listeners do
		if listeners[i].Port == port then
			linkListener(listeners[i],peer,remote)
			return
		end
	end

	-- no listeners matched, so queue up remote data for later
	table.insert(remoteData,{port,peer,remote})
end

function network.Listener(port,callback)
	if not isPortValue(port) then
		error("invalid port number",2)
	end

	local listener = {
		Port = port or 0;
		Callback = callback;
	}

	function listener:Close()
		for i = 1,#listeners do
			if listener[i] == self then
				table.remove(listeners,i)
				break
			end
		end
	end

	table.insert(listeners,listener)
	-- detect any remotes made before this listener was created
	local i,n = 1,#remoteData
	while i <= n do
		local data = remoteData[i]
		if data[1] == listener.Port then
			table.remove(remoteData,i)
			linkListener(listener,data[2],data[3])
			n = n - 1
		else
			i = i + 1
		end
	end

	return listener
end

networkInitialized()

return network
