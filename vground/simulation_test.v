module vground

import os

fn collect_simulation_events(mut run SimulationRun) []SimEvent {
	mut events := []SimEvent{}
	for {
		event := run.next_event() or { break }
		events << event
	}
	run.wait()
	return events
}

fn collect_simulation_frames(mut run SimulationRun, render_every int) []SimulationFrame {
	mut state := new_simulation_state()
	mut cadence := new_render_cadence(render_every)
	mut frames := []SimulationFrame{}
	for {
		frame := run.next_frame(mut state, mut cadence) or { break }
		frames << frame
	}
	run.wait()
	return frames
}

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

fn test_start_simulation_collects_events_for_go_scheduler() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	actors := demo_mobs(registry)
	world.place_mobs(actors)!
	mut run := start_simulation(world, registry, actors, AppConfig{
		frontend:     'terminal'
		scheduler:    .go
		mod_paths:    ['mods/core.vgmod']
		ticks:        1
		tick_ms:      0
		render_every: 1
	})
	assert run.active_mobs() == actors.len
	events := collect_simulation_events(mut run)
	assert events.filter(it.kind == .spawned).len == actors.len
	assert events.filter(it.kind == .done).len == actors.len
}

fn test_start_simulation_collects_events_for_deterministic_scheduler() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	actors := demo_mobs(registry)
	world.place_mobs(actors)!
	mut run := start_simulation(world, registry, actors, AppConfig{
		frontend:     'terminal'
		scheduler:    .deterministic
		mod_paths:    ['mods/core.vgmod']
		ticks:        1
		tick_ms:      0
		render_every: 1
	})
	assert run.active_mobs() == actors.len
	events := collect_simulation_events(mut run)
	assert events.filter(it.kind == .spawned).len == actors.len
	assert events.filter(it.kind == .done).len == actors.len
}

fn test_deterministic_scheduler_orders_steps_by_virtual_tick_ms() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	actors := demo_mobs(registry)
	world.place_mobs(actors)!
	events := run_deterministic_simulation(world, registry, actors, AppConfig{
		frontend:     'terminal'
		scheduler:    .deterministic
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

fn test_simulation_frames_mark_render_due_once_per_global_tick() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	actors := demo_mobs(registry)
	world.place_mobs(actors)!
	mut run := start_simulation(world, registry, actors, AppConfig{
		frontend:     'terminal'
		scheduler:    .deterministic
		mod_paths:    ['mods/core.vgmod']
		ticks:        2
		tick_ms:      0
		render_every: 1
	})
	frames := collect_simulation_frames(mut run, 1)
	due_frames := frames.filter(it.render_due)
	assert due_frames.len == 2
	assert due_frames[0].event.tick == 1
	assert due_frames[0].event.kind in [.moved, .blocked]
	assert due_frames[1].event.tick == 2
	assert due_frames[1].event.kind in [.moved, .blocked]
}

fn test_deterministic_replay_frames_expose_final_snapshot() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	actors := demo_mobs(registry)
	world.place_mobs(actors)!
	mut run := start_simulation(world, registry, actors, AppConfig{
		frontend:     'terminal'
		scheduler:    .deterministic
		mod_paths:    ['mods/core.vgmod']
		ticks:        2
		tick_ms:      0
		render_every: 1
	})
	frames := collect_simulation_frames(mut run, 1)
	assert frames.len > 0
	mut replay := new_simulation_state()
	for frame in frames {
		replay.apply_event(frame.event)
	}
	final_snapshot := frames[frames.len - 1].snapshot
	replay_snapshot := replay.snapshot()
	assert final_snapshot.done == actors.len
	assert final_snapshot.done == replay_snapshot.done
	assert final_snapshot.mobs.len == replay_snapshot.mobs.len
	assert final_snapshot.ticks.len == replay_snapshot.ticks.len
	for id, tick in replay_snapshot.ticks {
		assert final_snapshot.ticks[id]! == tick
	}
	mut final_positions := map[string]Vec2{}
	for mob in final_snapshot.mobs {
		final_positions[mob.id] = mob.pos
	}
	for mob in replay_snapshot.mobs {
		assert final_positions[mob.id]! == mob.pos
	}
}
