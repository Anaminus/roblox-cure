# Enums Package

Provides global enums across all peers.

Enums are stored as Configuration folders in the "enums" Configuration object. IntValues are used here to represent the enum items.


## API

- `enums:Register ( name, definition )`

	Registers a new enum. Returns whether the enum was successfully registered.

	- `name` is the name of the enum.
	- `definition` a table that contains item names as keys and enum item values (numbers) as values.
	
	Example:
	```lua
	enums:Register("FruitType", {
		Apple = 2;
		Lemon = 4;
		Pear = 5
	})
	```

	"Register" cannot be used as the name.

- `enums[enumName][itemName]`

	Gets an enum item (its value). In the example above, `enums.FruitType.Lemon` would evaluate to `4`.
