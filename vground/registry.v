module vground

pub struct Registry {
pub mut:
	mod_ids  []string
	blocks   map[string]BlockDef
	items    map[string]ItemDef
	mobs     map[string]MobDef
	runtimes map[string]RuntimeDef
}

pub fn build_registry(mods []VgMod) !Registry {
	mut registry := Registry{
		mod_ids:  []string{}
		blocks:   map[string]BlockDef{}
		items:    map[string]ItemDef{}
		mobs:     map[string]MobDef{}
		runtimes: map[string]RuntimeDef{}
	}
	for mod in mods {
		if mod.id in registry.mod_ids {
			return error('duplicate mod id `${mod.id}`')
		}
		registry.mod_ids << mod.id
		for block in mod.blocks {
			validate_content_id(block.id, mod.id, 'block')!
			if block.id in registry.blocks {
				return error('duplicate block id `${block.id}`')
			}
			registry.blocks[block.id] = block
		}
		for item in mod.items {
			validate_content_id(item.id, mod.id, 'item')!
			if item.id in registry.items {
				return error('duplicate item id `${item.id}`')
			}
			registry.items[item.id] = item
		}
		for mob in mod.mobs {
			validate_content_id(mob.id, mod.id, 'mob')!
			if mob.id in registry.mobs {
				return error('duplicate mob id `${mob.id}`')
			}
			registry.mobs[mob.id] = mob
		}
		for runtime in mod.runtimes {
			validate_content_id(runtime.id, mod.id, 'runtime')!
			if runtime.id in registry.runtimes {
				return error('duplicate runtime id `${runtime.id}`')
			}
			registry.runtimes[runtime.id] = runtime
		}
	}
	if 'core:grass' !in registry.blocks {
		return error('core:grass block is required by demo world generation')
	}
	if registry.mobs.len == 0 {
		return error('at least one mob definition is required')
	}
	return registry
}

fn validate_content_id(id string, mod_id string, kind string) ! {
	if id == '' {
		return error('${mod_id}: ${kind} id is required')
	}
	if !id.starts_with('${mod_id}:') {
		return error('${mod_id}: ${kind} `${id}` must be namespaced as `${mod_id}:...`')
	}
}
