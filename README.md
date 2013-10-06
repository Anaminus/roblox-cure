# Cure Framework

**Cure** is a solution to Roblox's lack of library system.

## The Framework

Cure consists of a few components, primarily **packages** and **scripts**.
Packages are like Lua modules in that they're meant to be loaded and used by
multiple scripts. Scripts pretty much run code, as usual. A combination of
these can used to create whatever is needed.

Cure also consists of **folders**, represented by Configuration objects. Each
folder has a specific meaning and usage, and provides a hierarchical structure
to the framework. See [Structure](#structure) for information on each folder.

Finally, there's the **main control script**. This brings the folders,
packages, and scripts together to form the functionality of the Cure
framework. This script runs once on each peer (the server and all clients).


### Code Representation

Packages and scripts can be made for both the server and for clients. An
important feature provided by Cure is persistent client-side code. That is,
LocalScripts that run independently of the player's character.

In order to allow scripts and packages to work easily with one another, normal
Script instances are not used. Instead, code is put into a "source" object,
which is handled by the main control script. This lets custom environments be
used, which allows for cleaner source code.

**Sources** are Roblox instances that refer to source code in some way. The
type of source depends on the Roblox class used:

- StringValue

	Indicates a single-part source. The Value contains the source code.

- BoolValue

	Indicates a divided, multi-part source. Because Roblox tends to crash when
	replicating large strings, large source code is split into multiple parts.
	These parts are contained in StringValues, which are children of the
	BoolValue.

- IntValue

	Indicates an external Roblox asset. The Value indicates the asset ID to
	load, which should be a model. The model may be of any source in this
	list. Basically, treat IntValues as if they are replaced by the asset they
	represent.

- Script

	A normal script. While these shouldn't actually be used, they are still
	handled. When Cure detects a Script, it will simply enable it by setting
	its Disabled property to false. However, if detected on the client, the
	script will be copied to the player's PlayerGui, then enabled.

- LocalScript

	Follows the same rules as Scripts.

Because of the way Roblox parses XML, whitespace at the start of strings are
truncated. To get around this, if the first character in a string is
whitespace or a "\" character, then the string will be encoded simply by
adding a "\" character to the beginning. To decode, if a string starts with a
"\", then that character is removed.


### Structure

Cure consists of the following Roblox instances, all contained under a single
Configuration instance:

- `cure` (Script)

	The main control script. A LocalScript version is included as a child of
	this Script, which is run on clients.

- `peers` (Configuration)

	Contains packages and scripts, for clients and the server. This folder
	contains two folders, `client` and `server`. Each of these folders contain
	two more folders, `packages` and `scripts`. These are where your packages
	and scripts go, respectively.

- `native` (Configuration)

	This folder contains packages that are included with Cure by default. The
	current default packages are *network*, *settings*, and *spawner*. Any
	package in this folder will be available on both the server and clients.

- `info` (Configuration)

	Contains general information and documentation about the project. By
	default, this folder contains documentation for the *network*, *settings*,
	and *spawner* packages.

- `network` (Configuration)

	Used by the *network* package to replicate network packets.

- `settings` (Configuration)

	Used by the *settings* package to contain setting objects. Value objects
	may be added here as initial settings.


### Globals

In order for scripts and packages to have access to the standard global
variables, they piggyback off of the environment of the main control script.
This doesn't mean they all share the same environment, they just have read-
only access to it.

Some extra globals, as well as all native packages, are added to the main
environment, and are therefore accessible to all scripts and packages. For
convenience, they are also added to the `shared` table, for use by scripts
outside of Cure.

Currently, the following extra global variables are defined:

- `require ( package )`

	A function that loads a package. The only argument is the name of the
	package to load. For example, a package source with the name of "example"
	would be loaded by calling `require('example')`.

	The results returned by the package are returned by `require`. If the
	package has already been loaded, then the results are reused. Note that
	the results are not added to the current environment, so it is not
	sufficient enough to simply call `require('example')`. The results can be
	acquired by using `example = require('example')`.

	Native packages may also be required, though it's usually not necessary,
	since they're already available to the environment.

- `cure`

	The top Configuration object that contains all other objects in the Cure
	structure. This provides an easy reference to these objects for packages
	and scripts.

- `IsServer`

	A bool indicating whether the peer is the server.

- `IsClient`

	A bool indicating whether the peer is a client. Should always be opposite
	of `IsServer`.


### Run-time Procedure

At run-time, Cure does the following things. The same general procedure goes
for clients as well, unless noted otherwise.

1. **Gather source code from packages.**

	Each source in the `peers.server.packages` folder (`peers.client.packages`
	on the client) is converted to source code, then stored for later
	requiring.

2. **Run native packages.**

	Each source in the `native` folder is converted to source code, required,
	and added to the main environment automatically. This means that they
	share the same space as normal packages, which allows native packages to
	require other native packages. It also means that native packages will
	override normal packages that have the same name.

	Each native package is available in the main environment, and in the
	`shared` table, under the name of the package.

3. **Run scripts.**

	Each source in the `peers.server.scripts` folder (`peers.client.scripts`
	on the client) is converted to source code, then executed.

	Any Script instances found by the server are simply enabled. Any Script
	instances found by a client are copied to the player's PlayerGui and
	enabled. Note that this isn't reliable since the PlayerGui may not yet
	exist at this point.

4. **Listen for peers.**

	Only done by the server. When a new peer is found, the client control
	script is executed on that peer. To verify that everything is running
	properly, the following handshake procedure occurs between the server and
	client:

	1. **Server:** Create Backpack object and copy the client script to it.
	2. **Server:** Wait for indication that client script is successfully running.
	3. **Client:** Reliably remove self to ensure code is persistent.
	4. **Client:** Send indication that the client script is successfully running with persistence.
	5. **Client:** Wait for lists of natives, packages, and scripts.
	6. **Server:** Send lists of natives, packages, and scripts.

	This handshake requires that the client's Character is not loaded
	immediately. As a consequence, Character spawning cannot be handled
	internally by Roblox. To remedy this, the **spawner** package is
	available. This recreates the original functionality of character
	spawning, with a few enhancements. If this package is included as a native
	package, then Cure will utilize it automatically.


## External Editing

While it is possible to work with Cure using Roblox Studio, the main point of
this repo is to use Cure in an external editor. A Lua script is used to
compile the project into a single .rbxm file, which can then be inserted into
your place. A Sublime Text project file is provided to get started.

### Structure

- `README.md`

	This file!

- `source`

	Contains the source code for Cure scripts as well as the structure of the
	Cure framework.

- `build`

	Contains the .rbxm file created by `build.lua`.

- `locations.txt`

	Contains a line-separated list of alternative paths to output the contents
	of the .rbxm file to.

- `build.lua`

	Compiles everything in the `source` folder into a .rbxm file. All files
	and folders become Roblox instances. Folders are converted into
	Configuration objects, and files are converted based on their extensions.
	The name of a file or folder is used as the name of the object.

	- `*.lua`: Converts to a StringValue or BoolValue source (depending on length of content).
	- `*.script.lua`: Converts to a Script source.
	- `*.localscript.lua`: Converts to a LocalScript source.
	- `*.asset`: Converts to an IntValue source. The content of the file is the asset ID.
	- `*.*` (anything else): Converts to a disabled Script whose Source is commented out.
	- `.gitignore`: Ignored, so that empty folders may be committed with git.

	For convenience, Lua files are checked for syntax errors. Note that a file
	with an error will still be built regardless.

	Value objects may also be created by using the `.value` extension:

	- `*.bool.value`: Content that is "0", "false", "nil", "no", "null", or empty, becomes false (case-insensitive). Anything else becomes true.
	- `*.brickcolor.value`: Content is the integer representation of a BrickColor.
	- `*.cframe.value`: Content is 12 seperated numbers (whitespace, commas, and semi-colons).
	- `*.color3.value`: Content is 3 separated numbers (r, g, b), or hexadecimal ("#FFFFFF").
	- `*.doubleconstrained.value`: Content is a single number.
	- `*.intconstrained.value`: Content is a single integer.
	- `*.int.value`: Content is a single integer.
	- `*.number.value`: Content is a single number.
	- `*.object.value`: Content is blank (not fully implemented).
	- `*.ray.value`: Content is 6 seperated numbers (origin Vector3, direction Vector3).
	- `*.string.value`: Content is anything (non-binary).
	- `*.vector3.value`: Content is 3 seperated numbers (x, y, z).

### Building

In order to run `build.lua`, you'll need two things:

- A Lua interpreter
- The LuaFileSystem module

In Windows, this can be done by installing [LuaForWindows][lfw], then simply
running `lua build.lua`.

*more solutions here*

[lfw]: http://code.google.com/p/luaforwindows/
