extends Node
## Autoload bus for level-wide gameplay signals.

signal player_died
signal level_completed
signal ball_hit(speed: float)
signal ball_ricochet(speed: float)
signal flipper_fired
signal hazard_hit
