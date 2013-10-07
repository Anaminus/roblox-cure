# Spawner Package

Provides replacement functionality for character spawning, which is normally overridden by Cure.


## API

- `spawner.add ( player )`

	Adds a player to the spawner. Usually used with Player.PlayerAdded.

- `spawner.remove ( player )`

	Removes a player from the spawner. Usually used with Player.PlayerRemoving.


## Settings

If the **settings** package is available, then this package will utilize it by adding the following settings:

- CharacterAutoLoads

	A bool indicating whether the character of a player will load automatically. Use this setting in place of `Players.CharacterAutoLoads`. Defaults to `true`.

- RespawnCooldown

	A number indicating the amount of time to wait after a character dies before respawning, in seconds. Defaults to 5.
