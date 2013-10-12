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
framework. This script comes in two flavors: one for the server, and one for
each client.


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

	Indicates a divided, multi-part source. Because Roblox tends to crash or
	disconnect when replicating large strings, large source code is split into
	multiple parts. These parts are contained in StringValues, which are
	children of the BoolValue.

- IntValue

	Indicates an external Roblox asset. The Value indicates the asset ID to
	load, which should be a model. The model may be of any source in this
	list. Basically, treat IntValues as if they are replaced by the asset they
	represent.

Because of the way Roblox parses XML, whitespace at the start of strings are
truncated. To get around this, if the first character in a string is
whitespace or a "\" character, then the string will be encoded simply by
adding a "\" character to the beginning. To decode, if a string starts with a
"\", then that character is removed.


### Structure

Cure consists of the following Roblox instances, all contained under a single
Configuration instance (the "cure container"). The cure container should be a
child of ServerScriptService.

- `cure.server` (Script)

	The main control script for the server.

- `cure.client` (LocalScript)

	The main control script for clients.

- `server` (Configuration)

	Contains packages and scripts for the server. This folder contains two
	folders, `packages` and `scripts`. These are where your packages and
	scripts go, respectively. Packages and scripts.

- `client` (Configuration)

	Similar to the `server` folder, but contains packages and scripts that are
	to be run on clients.

- `global` (Configuration)

	This folder contains packages that are available on both clients and the
	server. Packages here are automatically available in script environments.

- `info` (Configuration)

	Contains general information and documentation about the project.

Note that the `global` folder, as well as the `packages` and `scripts` folders
of each peer, may contain sub-folders. Cure will automatically recurse every
folder, looking for sources.


### Global Variables

In order for scripts and packages to have access to the standard global
variables, they piggyback off of the environment of the main control script.
This doesn't mean they all share the same environment, they just have read-
only access to it.

Some extra global variables are added to the main environment, and are
therefore accessible to all scripts and packages. For convenience, they are
also added to the `shared` table, for use by scripts outside of Cure.

Global packages are also added to the main environment automatically, under
the name of the package (sub-folders do not make a difference).

Currently, the following extra global variables are defined:

- `require ( package, fetch )`

	A function that loads a package. The first argument is the name of the
	package to load. For example, a package source with the name of "example"
	would be loaded by calling `require('example')`.

	Note that a package contained within a sub-folder must be referenced by
	its entire directory, separated by `.` characters. For example:

		-- require `packages/foo/bar/package.lua`
		require('foo.bar.package')

	The results returned by the package are returned by `require`. If the
	package has already been loaded, then the results are reused instead of
	loading the package again. Note that the results are not added to the
	current environment, so it is not sufficient enough to simply call
	`require('example')`. The results can be acquired by using something like
	`example = require('example')`.

	Global packages may also be required, though it's usually not necessary,
	since they're already available to the environment.

	Normally, if a package does not exist, then require will throw an error.
	However, if the second, optional argument to require is not false, then
	require will return no value instead.

- `IsServer`

	A bool indicating whether the peer is the server.

- `IsClient`

	A bool indicating whether the peer is a client. Should always be opposite
	of `IsServer`.

- `cure`

	A reference to the cure container. This global variable is only available
	on the server.

- `spawner`

	A table that contains settings to modify the behavior of character
	respawning. The following settings are available.

	- `CharacterAutoLoads` (bool)

		Reimplements the behavior of Players.CharacterAutoLoads. If this value
		is false, the player's character will not automatically respawn.
		Initially, this value is true.

	- `RespawnCooldown` (number)

		The amount of time to wait before respawning after a player's
		character dies, in seconds. Initially, this value is 5.

	This global variable is only available on the server.

- `PlayerAdded ( callback )`

	A function that allows scripts to hook into the Players.PlayerAdded event
	*after* Cure has finished setting up a client.

	*callback* is a function called when a new player is added. A Player
	instance is passed as an argument.

	This function returns a table that contains a single function,
	"disconnect". After disconnect is called, the callback function will no
	longer be called by PlayerAdded.

	This global variable is only available on the server.

- `PlayerRemoving ( callback )`

	Similar to PlayerAdded, but fires after a player is being removed. This
	global variable is only available on the server.

### Run-time Procedure

At run-time, the Cure server control script does the following things:

1. **Gather source code for server packages.**

	Each source in the `server.packages` folder is converted to source code,
	then stored for later requiring.

2. **Run global packages.**

	Each source in the `global` folder is converted to source code, required,
	and added to the main environment automatically. This means that they
	share the same space as normal packages, which allows global packages to
	require other global packages. It also means that global packages will
	override normal packages that have the same name.

	Each global package is available in the main environment, and in the
	`shared` table, under the name of the package. Sub-folders do not affect
	the name.

3. **Run scripts.**

	Each source in the `server.scripts` folder is converted to source code,
	then executed.

4. **Gather source for client packages and scripts**

	Each source in the `client.packages` and `client.scripts` folders are
	converted to source code, then stored for later requests from clients.
	Global package sources have also been stored similarly.

4. **Listen for peers.**

	When a new peer is found, the client control script is executed on that
	peer. The server creates a "CallStream" object, which serves the client
	data that it needs in order to successfully load. The CallStream serves
	the following requests:

	- `initialized`

		Indicates that the client is successfully running persistently. The
		server returns a list of sources the client should request, which
		includes the type of source, and the amount of source available for
		that type.

	- `source`

		Requests a source. Requires two arguments: the type of source (global,
		package, script), and a numerical index indicating which source.

		Returns the full name, short name, and source code of the requested
		source. The source code may span multiple values, if it is too large.

	- `loaded`

		Indicates that the client has completely finished loading, and the
		server may end the CallStream and finish setting up the client.


The Cure client control script runs the following procedure:

1. Reliably remove self to ensure code is persistent.
2. Wait until the DataModel has been completely loaded.
3. Find the server's CallStream.
4. Send call indicating that the client has initialized.
5. Request client sources.
6. Organize source code for packages.
7. Run global packages.
8. Run scripts.
9. Send call indicating that the client has finished loading.


This procedure requires that the client's Character is not loaded immediately.
As a consequence, Character spawning cannot be handled internally by Roblox.
To remedy this, Cure recreates the original functionality of character
spawning, with a few enhancements. Spawning behavior can be controlled by
settings in the `spawner` global variable.


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

- `packages`

	Contains premade packages that may be useful.

- `locations.txt`

	Contains a line-separated list of alternative paths to output the contents
	of the .rbxm file to.

- `build.lua`

	Compiles everything in the `source` folder into a .rbxm file. All files
	and folders become Roblox instances. Folders are converted into
	Configuration objects, and files are converted based on their extensions.
	The name of a file or folder is used as the name of the object.

	- `*.lua`: Converts to a StringValue or BoolValue source (depending on
      length of content).
	- `*.script.lua`: Converts to a Script source.
	- `*.localscript.lua`: Converts to a LocalScript source.
	- `*.asset`: Converts to an IntValue source. The content of the file is
      the asset ID.
	- `*.*` (anything else): Converts to a disabled Script whose Source is
      commented out.
	- `.gitignore`: Ignored, so that empty folders may be committed with git.

	For convenience, Lua files are checked for syntax errors. Note that a file
	with an error will still be built regardless.

	The output file name can be specified by giving it as an option to
	build.lua. Defaults to "cure.rbxm".

		lua build.lua [filename]

### Building

In order to run `build.lua`, you'll need two things:

- A Lua interpreter
- The LuaFileSystem module

In Windows, this can be done by installing [LuaForWindows][lfw], then simply
running `lua build.lua`.

*more solutions here*

[lfw]: http://code.google.com/p/luaforwindows/
