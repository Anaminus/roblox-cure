# Settings Package

Provides global settings across all peers. Settings are stored as Value
objects in the "settings" Configuration object. Value objects may be added
here as initial settings.


## API

- `settings:Add ( key, type, value )`

	Adds a new setting. Returns whether the setting was successfully added.

	- `key` is the name of the setting.
	- `type` is the setting's value type. May be any type for which a Value
      object exists (i.e. "int" for IntValue). Case-insensitive.
	- `value` is the initial value of the setting.

	"Add", "Remove", and "Changed" cannot be used as keys.

- `settings:Remove ( key )`

	Removes a setting. Returns whether the setting was successfully removed.

- `settings[key]`

	Gets a setting.

- `settings[key] = value`

	Sets a setting.

- `settings.Changed:connect ( key, value )`

	Fired after a setting's value changes.
