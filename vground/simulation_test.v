module vground

import os

fn test_simulation_state_applies_events_and_exposes_snapshot() {
	mut state := new_simulation_state()
	state.apply_event(SimEvent{
		kind:     .spawned
		mob_id:   'mob:a'
		mob_name: 'Mob A'
		glyph:    'a'
		to:       Vec2{
			x: 1
			y: 2
		}
	})
	state.apply_event(SimEvent{
		kind:     .moved
		mob_id:   'mob:a'
		mob_name: 'Mob A'
		glyph:    'a'
		tick:     3
		to:       Vec2{
			x: 4
			y: 5
		}
	})
	state.apply_event(SimEvent{
		kind:   .done
		mob_id: 'mob:a'
		to:     Vec2{
			x: 4
			y: 5
		}
	})
	snapshot := state.snapshot()
	assert snapshot.done == 1
	assert snapshot.ticks['mob:a']! == 3
	assert snapshot.mobs.len == 1
	assert snapshot.mobs[0].pos == Vec2{
		x: 4
		y: 5
	}
}

fn test_deterministic_scheduler_orders_steps_by_virtual_tick_ms() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	actors := demo_mobs(registry)
	world.place_mobs(actors)!
	events := run_deterministic_simulation(world, registry, actors, AppConfig{
		frontend:     'terminal'
		scheduler:    'deterministic'
		mod_paths:    ['mods/core.vgmod']
		ticks:        2
		tick_ms:      100
		render_every: 1
	})
	mut tick_two_mobs := []string{}
	for event in events {
		if (event.kind == .moved || event.kind == .blocked) && event.tick == 2 {
			tick_two_mobs << event.mob_id
		}
	}
	assert tick_two_mobs == ['core:slime/1', 'core:forager/2', 'core:farmer/3']
}
