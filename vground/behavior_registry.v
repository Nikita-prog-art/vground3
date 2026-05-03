module vground

const mob_ai_abi = 'vground.mob_ai.v1'

pub type MobBehaviorFn = fn (MobBrainInput) MobBrainOutput

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

pub struct BehaviorRegistry {
	handlers map[string]MobBehaviorFn
}

pub struct ResolvedMobBehavior {
pub:
	key     string
	handler MobBehaviorFn = missing_mob_behavior_step
}

pub fn new_behavior_registry() BehaviorRegistry {
	mut handlers := map[string]MobBehaviorFn{}
	handlers['core:scripts/behaviors.v:slime_bounce'] = core_slime_bounce
	handlers['core:scripts/behaviors.v:forage_loop'] = core_forage_loop
	handlers['core:scripts/behaviors.v:farm_patrol'] = core_farm_patrol
	handlers['core:slime_bounce'] = core_slime_bounce
	handlers['core:forage_loop'] = core_forage_loop
	handlers['core:farm_patrol'] = core_farm_patrol
	return BehaviorRegistry{
		handlers: handlers
	}
}

pub fn validate_behavior_registry(registry Registry, behaviors BehaviorRegistry) ! {
	for _, mob in registry.mobs {
		resolved := behaviors.resolve_mob(mob)
		if !resolved.found() {
			return error('${mob.id}: no registered mob AI behavior for hooks/behavior')
		}
	}
}

pub fn (behaviors &BehaviorRegistry) resolve_mob(def MobDef) ResolvedMobBehavior {
	mod_id := mod_id_for_content(def.id)
	for hook in def.hooks {
		if hook.abi != mob_ai_abi {
			continue
		}
		key := behavior_key(mod_id, hook.entry)
		handler := behaviors.handlers[key] or { continue }
		return ResolvedMobBehavior{
			key:     key
			handler: handler
		}
	}
	if def.behavior != '' {
		key := behavior_key(mod_id, def.behavior)
		handler := behaviors.handlers[key] or { return missing_mob_behavior() }
		return ResolvedMobBehavior{
			key:     key
			handler: handler
		}
	}
	return missing_mob_behavior()
}

pub fn (behavior ResolvedMobBehavior) found() bool {
	return behavior.key != ''
}

pub fn (behavior ResolvedMobBehavior) direction(actor MobActor, tick int) Vec2 {
	output := behavior.handler(MobBrainInput{
		mob_id: actor.id
		tick:   tick
		x:      actor.pos.x
		y:      actor.pos.y
	})
	return Vec2{
		x: output.dx
		y: output.dy
	}
}

fn missing_mob_behavior() ResolvedMobBehavior {
	return ResolvedMobBehavior{
		handler: missing_mob_behavior_step
	}
}

fn behavior_key(mod_id string, entry string) string {
	if mod_id == '' {
		return entry
	}
	return '${mod_id}:${entry}'
}

fn mod_id_for_content(id string) string {
	parts := id.split(':')
	if parts.len < 2 {
		return ''
	}
	return parts[0]
}

fn missing_mob_behavior_step(input MobBrainInput) MobBrainOutput {
	return MobBrainOutput{}
}

fn core_slime_bounce(input MobBrainInput) MobBrainOutput {
	pattern := [
		MobBrainOutput{1, 0},
		MobBrainOutput{0, 1},
		MobBrainOutput{-1, 0},
		MobBrainOutput{0, -1},
	]
	return pattern[input.tick % pattern.len]
}

fn core_forage_loop(input MobBrainInput) MobBrainOutput {
	pattern := [
		MobBrainOutput{0, -1},
		MobBrainOutput{1, 0},
		MobBrainOutput{0, 1},
		MobBrainOutput{-1, 0},
	]
	return pattern[input.tick % pattern.len]
}

fn core_farm_patrol(input MobBrainInput) MobBrainOutput {
	return core_forage_loop(input)
}
