# Network Package

Provides basic communication between peers.

Communication is done using Value objects, which are referred to as "packets". This package uses the "network" Configuration object to replicate packets to every peer.

## API

- `network.send ( ref, type, data )`

	Sends a packet of data.

	- `ref` is a string that allows packets to be filtered by receiving peers.
	- `type` is a [dataType](#datatype), which indicates the type of data to send.
	- `data` is a [dataValue](#datavalue), which is the actual data to send.


- `network.receive ( pattern, callback )`

	Returns a *receiver*, an object that receives packets of data.

	- `pattern` is a Lua pattern string used to match the `ref` value of a packet.
	- `callback` is a function called when a matched packet is received. The following parameters are passed:
		- `data`, the [dataValue](#datavalue) received from the packet.
		- `ref`, the reference string of the packet.

	The receiver object is a table with the following fields:

	- `receiver.pattern` : The pattern used to match a packet's reference value. Can be modified.
	- `receiver.callback` : The function called when a packet is received. Can be modified.
	- `receiver.connected` : A bool indicating whether the receiver is connected.
	- `receiver:disconnect()` : Stops the receiver from receiving any more packets.

### Types

For reference, the following types are defined.

#### dataValue

May be any value for which a Value object exists (i.e. IntValue).

It may also be an array containing dataValues, including more arrays.

#### dataType

A string indicating the type of the corresponding dataValue. Case-insensitive.

Should be an array if the dataValue is also an array.

Examples:

	dataType:  'Vector3'
	dataValue: Vector3.new( 10, 10, 10 )

	dataType:  { 'int', 'int', 'int' }
	dataValue: {    10,    10,    10 }

	dataType:  { 'bool', { 'int', 'int', 'int' }, 'string', 'number' }
	dataValue: {   true, {    10,    10,    10 },  "hello",  math.pi }
