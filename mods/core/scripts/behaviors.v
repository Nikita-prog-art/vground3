module core_behaviors

// Placeholder V-side mod script. The current prototype reads the manifest and
// runs built-in behavior names; this file documents the future native V hook.

pub struct MobBrainInput {
pub:
	mob_id string
	tick   int
	x      int
	y      int
}

pub struct MobBrainOutput {
pub:
	dx int
	dy int
}

pub fn slime_bounce(input MobBrainInput) MobBrainOutput {
	pattern := [
		MobBrainOutput{1, 0},
		MobBrainOutput{0, 1},
		MobBrainOutput{-1, 0},
		MobBrainOutput{0, -1},
	]
	return pattern[input.tick % pattern.len]
}

pub fn forage_loop(input MobBrainInput) MobBrainOutput {
	pattern := [
		MobBrainOutput{0, -1},
		MobBrainOutput{1, 0},
		MobBrainOutput{0, 1},
		MobBrainOutput{-1, 0},
	]
	return pattern[input.tick % pattern.len]
}

pub fn farm_patrol(input MobBrainInput) MobBrainOutput {
	return forage_loop(input)
}
