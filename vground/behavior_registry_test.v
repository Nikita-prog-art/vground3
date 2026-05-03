module vground

fn test_behavior_registry_resolves_mob_ai_hook_before_behavior_name() {
	behaviors := new_behavior_registry()
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
}

fn test_behavior_registry_reports_missing_mob_ai() {
	behaviors := new_behavior_registry()
	resolved := behaviors.resolve_mob(MobDef{
		id:       'core:missing'
		name:     'Missing'
		glyph:    'm'
		max_hp:   1
		behavior: 'missing'
	})
	assert !resolved.found()
}
