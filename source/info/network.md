# Network Package

Provides communication between peers.

Communication is done by abstracting RemoteFunction objects as "sockets" and
"listeners". All network related objects are contained in the "network"
Configuration object, which is stored in the ReplicatedStorage service.

## API

- `network.Socket ( peer, port )`

	Returns a new Socket object.

	*peer* is a Player object representing the peer to connect to. A nil value
	indicates the server as the peer.

	*port* is an integer between 0 and 65536. It is used as a filter for
	listeners. Defaults to 0.

- `network.Listener ( port, callback )`

	Returns a new Listener object.

	*port* is the port number to listen on. The listener will only listen for
	sockets with the same port number.

	*callback* is a function called when the listener detects a connection.
	The only parameter passed to the callback is a socket object representing
	the detected connection.

## Socket

A Socket represents a connection between two peers.

Sockets have the following members:

- `Socket.Recipient`

	A Player object representing the peer the socket is connected to. Will be
	`true` if the recipient is the server.

- `Socket.Closed`

	A bool indicating whether the socket has been closed.

- `Socket:Send ( ... )`

	Sends data to the recipient.

- `Socket:Receive( )`

	Receives data from the recipient. Received data is buffered, so this
	function will block if the buffer is empty.

	The values returned correspond to the arguments given to a Send call.

- `Socket:Close ( )`

	Closes the connection. Subsequent calls to Send and Receive will throw an
	error. If Receive is blocking, then it will throw an error.

## Listener

A Listener is used to detect incoming connections from other peers.

Listeners have the following members:

- `Listener.Port`

	The port the listener is listening on. Can be modified.

- `Listener.Callback`

	A function called when a connection is detected. The only parameter passed
	to the callback is a socket object representing the detected connection.
	Can be modified.

- `Listener:Close ( )`

	Closes the listener.
