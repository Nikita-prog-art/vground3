module vground

import os
import toml

fn test_core_mod_loads_and_registers_content() {
	path := os.join_path(@VMODROOT, 'mods', 'core.vgmod')
	core := load_mod(path)!
	assert core.id == 'core'
	assert core.runtime == 'v'
	registry := build_registry([core])!
	assert 'core:grass' in registry.blocks
	assert 'core:slime' in registry.mobs
	core_runtime := registry.mod_runtimes['core'] or { '' }
	assert core_runtime == 'v'
	assert registry.blocks['core:tree']!.tags == ['wood', 'harvestable']
	assert registry.mobs['core:farmer']!.hooks[0].entry == 'scripts/behaviors.v:farm_patrol'
}

fn test_solid_is_a_field_not_a_tag() {
	bad := VgMod{
		schema:  1
		id:      'core'
		name:    'Bad Core'
		version: '0.0.1'
		runtime: 'v'
		blocks:  [
			BlockDef{
				id:    'core:grass'
				name:  'Grass'
				glyph: '.'
				tags:  ['solid']
			},
		]
		mobs:    [
			MobDef{
				id:       'core:slime'
				name:     'Slime'
				glyph:    's'
				max_hp:   1
				behavior: 'slime_bounce'
			},
		]
	}
	if _ := build_registry([bad]) {
		assert false
	} else {
		assert err.msg().contains('solid is a block field')
	}
}

fn test_hook_entries_are_relative_to_mod_dir() {
	bad := VgMod{
		schema:  1
		id:      'core'
		name:    'Bad Core'
		version: '0.0.1'
		runtime: 'v'
		blocks:  [
			BlockDef{
				id:    'core:grass'
				name:  'Grass'
				glyph: '.'
				hooks: [
					ScriptHook{
						entry: 'mods/core/scripts/behaviors.v:grass_tick'
						abi:   'vground.block_tick.v1'
					},
				]
			},
		]
		mobs:    [
			MobDef{
				id:       'core:slime'
				name:     'Slime'
				glyph:    's'
				max_hp:   1
				behavior: 'slime_bounce'
			},
		]
	}
	if _ := build_registry([bad]) {
		assert false
	} else {
		assert err.msg().contains('must be relative to mods/core')
	}
}

fn test_mod_sections_are_optional() {
	doc := toml.parse_text('schema = 1\n' + 'id = "items_only"\n' + 'name = "Items Only"\n' +
		'version = "0.0.1"\n' + 'runtime = "v"\n' + '\n' + '[[items]]\n' +
		'id = "items_only:seed"\n' + 'name = "Seed"\n' + 'glyph = "*"\n')!
	mod := parse_mod_doc(doc)!
	assert mod.blocks.len == 0
	assert mod.items.len == 1
	assert mod.mobs.len == 0
}

fn test_hook_entries_must_be_tables() {
	doc := toml.parse_text('schema = 1\n' + 'id = "bad_hooks"\n' + 'name = "Bad Hooks"\n' +
		'version = "0.0.1"\n' + 'runtime = "v"\n' + '\n' + '[[mobs]]\n' +
		'id = "bad_hooks:slime"\n' + 'name = "Slime"\n' + 'glyph = "s"\n' +
		'hooks = ["not a table"]\n')!
	if _ := parse_mod_doc(doc) {
		assert false
	} else {
		assert err.msg().contains('hooks: expected table entry')
	}
}
