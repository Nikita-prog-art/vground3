module vground

fn test_behavior_registry_resolves_mob_ai_hook_before_behavior_name() {
	mut behaviors := new_behavior_registry()
	behaviors.register_mod_runtime('core', 'v')!
	def := MobDef{
		id:       'core:test'
		name:     'Test'
		glyph:    't'
		max_hp:   1
		behavior: 'forage_loop'
		hooks:    [
			ScriptHook{
				entry: 'scripts/behaviors.v:slime_bounce'
				abi:   mob_ai_abi
			},
		]
	}
	resolved := behaviors.resolve_mob(def)
	assert resolved.found()
	assert resolved.key == 'core:scripts/behaviors.v:slime_bounce'
	dir := resolved.direction(MobActor{
		id:     'core:test/1'
		def_id: 'core:test'
		name:   'Test'
		glyph:  't'
		hp:     1
		pos:    Vec2{
			x: 4
			y: 5
		}
	}, 1)
	assert dir == Vec2{
		x: 0
		y: 1
	}
	assert !resolved.deprecated_fallback
}

fn test_behavior_registry_keeps_behavior_name_as_deprecated_fallback() {
	mut behaviors := new_behavior_registry()
	behaviors.register_mod_runtime('core', 'v')!
	resolved := behaviors.resolve_mob(MobDef{
		id:       'core:legacy'
		name:     'Legacy'
		glyph:    'l'
		max_hp:   1
		behavior: 'slime_bounce'
	})
	assert resolved.found()
	assert resolved.key == 'core:slime_bounce'
	assert resolved.deprecated_fallback
}

fn test_behavior_registry_validates_hook_entries_not_behavior_fallback_when_hook_exists() {
	mut behaviors := new_behavior_registry()
	behaviors.register_behavior_fallback('core', 'slime_bounce', core_slime_bounce)
	registry := Registry{
		mod_ids:      ['core']
		mod_runtimes: {
			'core': 'v'
		}
		blocks:       {
			'core:grass': BlockDef{
				id:    'core:grass'
				name:  'Grass'
				glyph: '.'
			}
		}
		mobs:         {
			'core:test': MobDef{
				id:       'core:test'
				name:     'Test'
				glyph:    't'
				max_hp:   1
				behavior: 'slime_bounce'
				hooks:    [
					ScriptHook{
						entry: 'scripts/behaviors.v:missing'
						abi:   mob_ai_abi
					},
				]
			}
		}
	}
	if _ := validate_behavior_registry(registry, behaviors) {
		assert false
	} else {
		assert err.msg().contains('no registered mob AI hook')
	}
}

fn test_behavior_registry_reports_missing_mob_ai() {
	mut behaviors := new_behavior_registry()
	behaviors.register_mod_runtime('core', 'v')!
	resolved := behaviors.resolve_mob(MobDef{
		id:       'core:missing'
		name:     'Missing'
		glyph:    'm'
		max_hp:   1
		behavior: 'missing'
	})
	assert !resolved.found()
}
