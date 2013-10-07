# Spawner Package

Provides replacement functionality for character spawning, which is normally
overridden by Cure. Not available to clients.


## API

- `spawner.Add ( player )`

	Adds a player to the spawner. Usually used with Player.PlayerAdded.

- `spawner.Remove ( player )`

	Removes a player from the spawner. Usually used with
	Player.PlayerRemoving.

- `spawner.Settings`

	A table of settings. Contains the following values:

	- CharacterAutoLoads

		A bool indicating whether the character of a player will load
		automatically. Use this setting in place of
		`Players.CharacterAutoLoads`. Defaults to `true`.

	- RespawnCooldown

		A number indicating the amount of time to wait after a character dies
		before respawning, in seconds. Defaults to 5.
