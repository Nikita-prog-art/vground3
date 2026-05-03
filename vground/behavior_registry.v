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
mut:
	handlers  map[string]MobBehaviorFn
	fallbacks map[string]MobBehaviorFn
}

pub struct ResolvedMobBehavior {
pub:
	key                 string
	handler             MobBehaviorFn = missing_mob_behavior_step
	deprecated_fallback bool
}

pub fn new_behavior_registry() BehaviorRegistry {
	return BehaviorRegistry{
		handlers:  map[string]MobBehaviorFn{}
		fallbacks: map[string]MobBehaviorFn{}
	}
}

pub fn new_behavior_registry_for_mods(mods []VgMod) !BehaviorRegistry {
	mut behaviors := new_behavior_registry()
	for mod in mods {
		behaviors.register_mod(mod)!
	}
	return behaviors
}

pub fn new_behavior_registry_for_registry(registry Registry) BehaviorRegistry {
	mut behaviors := new_behavior_registry()
	for mod_id in registry.mod_ids {
		runtime := registry.mod_runtimes[mod_id] or { '' }
		behaviors.register_mod_runtime(mod_id, runtime) or {}
	}
	return behaviors
}

pub fn (mut behaviors BehaviorRegistry) register_mod(mod VgMod) ! {
	behaviors.register_mod_runtime(mod.id, mod.runtime)!
}

pub fn (mut behaviors BehaviorRegistry) register_mod_runtime(mod_id string, runtime string) ! {
	if runtime != 'v' {
		return
	}
	match mod_id {
		'core' {
			behaviors.register_core()
		}
		else {}
	}
}

pub fn (mut behaviors BehaviorRegistry) register_mob_ai(mod_id string, entry string, handler MobBehaviorFn) {
	behaviors.handlers[behavior_key(mod_id, entry)] = handler
}

pub fn (mut behaviors BehaviorRegistry) register_behavior_fallback(mod_id string, name string, handler MobBehaviorFn) {
	behaviors.fallbacks[behavior_key(mod_id, name)] = handler
}

pub fn validate_behavior_registry(registry Registry, behaviors BehaviorRegistry) ! {
	for _, mob in registry.mobs {
		if mob_ai_hooks(mob).len > 0 {
			for hook in mob_ai_hooks(mob) {
				key := behavior_key(mod_id_for_content(mob.id), hook.entry)
				if key !in behaviors.handlers {
					return error('${mob.id}: no registered mob AI hook `${hook.entry}`')
				}
			}
			continue
		}
		resolved := behaviors.resolve_mob(mob)
		if !resolved.found() {
			return error('${mob.id}: no registered mob AI behavior for hooks/behavior')
		}
	}
}

pub fn (behaviors &BehaviorRegistry) resolve_mob(def MobDef) ResolvedMobBehavior {
	mod_id := mod_id_for_content(def.id)
	for hook in mob_ai_hooks(def) {
		key := behavior_key(mod_id, hook.entry)
		handler := behaviors.handlers[key] or { continue }
		return ResolvedMobBehavior{
			key:     key
			handler: handler
		}
	}
	if def.behavior != '' {
		key := behavior_key(mod_id, def.behavior)
		handler := behaviors.fallbacks[key] or { return missing_mob_behavior() }
		return ResolvedMobBehavior{
			key:                 key
			handler:             handler
			deprecated_fallback: true
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

fn (mut behaviors BehaviorRegistry) register_core() {
	behaviors.register_mob_ai('core', 'scripts/behaviors.v:slime_bounce', core_slime_bounce)
	behaviors.register_mob_ai('core', 'scripts/behaviors.v:forage_loop', core_forage_loop)
	behaviors.register_mob_ai('core', 'scripts/behaviors.v:farm_patrol', core_farm_patrol)
	behaviors.register_behavior_fallback('core', 'slime_bounce', core_slime_bounce)
	behaviors.register_behavior_fallback('core', 'forage_loop', core_forage_loop)
	behaviors.register_behavior_fallback('core', 'farm_patrol', core_farm_patrol)
}

fn mob_ai_hooks(def MobDef) []ScriptHook {
	return def.hooks.filter(it.abi == mob_ai_abi)
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
