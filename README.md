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

	Indicates a divided, multi-part source. Because Roblox tends to crash when
	replicating large strings, large source code is split into multiple parts.
	These parts are contained in StringValues, which are children of the
	BoolValue.

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
Configuration instance:

- `cure.server` (Script)

	The main control script for the server.

- `cure.client` (LocalScript)

	The main control script for clients.

- `peers` (Configuration)

	Contains packages and scripts, for clients and the server. This folder
	contains two folders, `client` and `server`. Each of these folders contain
	two more folders, `packages` and `scripts`. These are where your packages
	and scripts go, respectively.

- `native` (Configuration)

	This folder contains packages that are available on both clients and the
	server. Cure comes with a few of these native packages built-in.

- `info` (Configuration)

	Contains general information and documentation about the project. By
	default, this folder contains documentation for the built-in native
	packages.

- `settings` (Configuration)

	Used by the *settings* native package to contain setting objects. Value
	objects may be added here as initial settings.

Note that the `native` folder, as well as the `packages` and `scripts` folders
of each peer, may contain sub-folders. Cure will automatically recurse every
folder, looking for sources.


### Globals

In order for scripts and packages to have access to the standard global
variables, they piggyback off of the environment of the main control script.
This doesn't mean they all share the same environment, they just have read-
only access to it.

Some extra globals are added to the main environment, and are therefore
accessible to all scripts and packages. For convenience, they are also added
to the `shared` table, for use by scripts outside of Cure.

Native packages are also added to the main environment automatically, under
the name of the package (sub-folders do not make a difference).

Currently, the following extra global variables are defined:

- `require ( package )`

	A function that loads a package. The only argument is the name of the
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

	Native packages may also be required, though it's usually not necessary,
	since they're already available to the environment.

- `IsServer`

	A bool indicating whether the peer is the server.

- `IsClient`

	A bool indicating whether the peer is a client. Should always be opposite
	of `IsServer`.


### Run-time Procedure

At run-time, the Cure server control script does the following things:

1. **Gather source code for server packages.**

	Each source in the `peers.server.packages` folder is converted to source
	code, then stored for later requiring.

2. **Run native packages.**

	Each source in the `native` folder is converted to source code, required,
	and added to the main environment automatically. This means that they
	share the same space as normal packages, which allows native packages to
	require other native packages. It also means that native packages will
	override normal packages that have the same name.

	Each native package is available in the main environment, and in the
	`shared` table, under the name of the package. Sub-folders do not affect
	the name.

3. **Run scripts.**

	Each source in the `peers.server.scripts` folder is converted to source
	code, then executed.

4. **Gather source for client packages and scripts**

	Each source in the `peers.client.packages` and `peers.client.scripts`
	folders are converted to source code, then stored for later requests from
	clients. Native package sources have also been stored similarly.

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

		Requests a source. Requires two arguments: the type of source (native,
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
7. Run native packages.
8. Run scripts.
9. Send call indicating that the client has finished loading.


This procedure requires that the client's Character is not loaded immediately.
As a consequence, Character spawning cannot be handled internally by Roblox.
To remedy this, the **spawner** package is available. This recreates the
original functionality of character spawning, with a few enhancements. If this
package is included as a native package, then Cure will utilize it
automatically.


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
