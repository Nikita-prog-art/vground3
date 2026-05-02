module vground

pub struct Registry {
pub mut:
	mod_ids      []string
	mod_runtimes map[string]string
	blocks       map[string]BlockDef
	items        map[string]ItemDef
	mobs         map[string]MobDef
}

pub fn build_registry(mods []VgMod) !Registry {
	mut registry := Registry{
		mod_ids:      []string{}
		mod_runtimes: map[string]string{}
		blocks:       map[string]BlockDef{}
		items:        map[string]ItemDef{}
		mobs:         map[string]MobDef{}
	}
	for mod in mods {
		if mod.id in registry.mod_ids {
			return error('duplicate mod id `${mod.id}`')
		}
		registry.mod_ids << mod.id
		registry.mod_runtimes[mod.id] = mod.runtime
		for block in mod.blocks {
			validate_content_id(block.id, mod.id, 'block')!
			validate_tags(block.tags, block.id)!
			validate_hooks(block.hooks, mod.id, block.id)!
			if block.id in registry.blocks {
				return error('duplicate block id `${block.id}`')
			}
			registry.blocks[block.id] = block
		}
		for item in mod.items {
			validate_content_id(item.id, mod.id, 'item')!
			validate_hooks(item.hooks, mod.id, item.id)!
			if item.id in registry.items {
				return error('duplicate item id `${item.id}`')
			}
			registry.items[item.id] = item
		}
		for mob in mod.mobs {
			validate_content_id(mob.id, mod.id, 'mob')!
			validate_hooks(mob.hooks, mod.id, mob.id)!
			if mob.id in registry.mobs {
				return error('duplicate mob id `${mob.id}`')
			}
			registry.mobs[mob.id] = mob
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

fn validate_tags(tags []string, id string) ! {
	if 'solid' in tags {
		return error('${id}: solid is a block field, not a tag')
	}
}

fn validate_hooks(hooks []ScriptHook, mod_id string, owner_id string) ! {
	for hook in hooks {
		if hook.entry == '' {
			return error('${owner_id}: hook entry is required')
		}
		if hook.entry.starts_with('/') || hook.entry.starts_with('mods/${mod_id}/') {
			return error('${owner_id}: hook entry `${hook.entry}` must be relative to mods/${mod_id}')
		}
	}
}
