extends RefCounted
## Presentation-only schedule. No random generator, simulation state or world entities.

static func event_turn(seed: int, kind: String) -> int:
	if seed <= 0:
		return -1
	match kind:
		"reflection":
			return 18 + posmod(hash(Vector2i(seed, 41)), 33) if posmod(seed, 5) == 2 else -1
		"sound":
			return 25 + posmod(hash(Vector2i(seed, 97)), 46) if posmod(seed, 4) == 1 else -1
	return -1


static func eligible(turn: int, scheduled: int, already_seen: bool, quiet: bool) -> bool:
	return scheduled >= 0 and turn >= scheduled and turn <= scheduled + 8 and not already_seen and quiet
