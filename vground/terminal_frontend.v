module vground

struct TerminalState {
mut:
	simulation       SimulationState
	next_render_tick int
}

pub fn run_terminal(mut app GameApp, config AppConfig) ! {
	actors := demo_mobs(app.registry)
	if actors.len == 0 {
		return error('no demo mobs are available in loaded mods')
	}
	app.world.place_mobs(actors)!
	println('vground3 terminal frontend')
	println('mods: ${app.registry.mod_ids.join(', ')}')
	println('scheduler: ${scheduler_summary(config.scheduler)}')
	println('world access: each chunk owns a mutex; actor steps lock occupied chunks')
	println('runtime: ${runtime_summary(app.registry)}')
	print_world(app.world, []MobView{})
	mut run := start_simulation(app.world, app.registry, actors, config)
	mut state := new_terminal_state(config)
	for {
		event := run.next_event() or { break }
		handle_terminal_event(event, mut state, app.world, config, run.active_mobs())
	}
	run.wait()
	println('simulation complete')
	print_snapshot(app.world, state.simulation.snapshot())
}

fn new_terminal_state(config AppConfig) TerminalState {
	return TerminalState{
		simulation:       new_simulation_state()
		next_render_tick: config.render_every
	}
}

fn handle_terminal_event(event SimEvent, mut state TerminalState, world &World, config AppConfig, active_mobs int) {
	state.simulation.apply_event(event)
	match event.kind {
		.spawned {
			println('enter ${event.mob_name} ${event.mob_id} at ${event.to}')
			print_snapshot(world, state.simulation.snapshot())
		}
		.moved {
			println('tick ${event.tick:02d} move ${event.mob_id} ${event.from} -> ${event.to} chunk=${event.chunk} visits=${event.visits}')
			render_if_ready(mut state, world, config, active_mobs)
		}
		.blocked {
			println('tick ${event.tick:02d} block ${event.mob_id} ${event.from} -> ${event.to}: ${event.reason}')
			render_if_ready(mut state, world, config, active_mobs)
		}
		.done {
			println('done ${event.mob_id} at ${event.to}')
		}
	}
}

fn render_if_ready(mut state TerminalState, world &World, config AppConfig, active_mobs int) {
	snapshot := state.simulation.snapshot()
	if active_mobs == 0 || snapshot.ticks.len < active_mobs {
		return
	}
	for _, tick in snapshot.ticks {
		if tick < state.next_render_tick {
			return
		}
	}
	print_snapshot(world, snapshot)
	state.next_render_tick += config.render_every
}

fn print_snapshot(world &World, snapshot SimulationSnapshot) {
	print_world(world, snapshot.mobs)
}

fn print_world(world &World, mobs []MobView) {
	for line in world.render(mobs) {
		println(line)
	}
	println('')
}

fn runtime_summary(registry Registry) string {
	if registry.mod_runtimes.len == 0 {
		return 'none'
	}
	mut parts := []string{}
	for mod_id, runtime in registry.mod_runtimes {
		parts << '${mod_id}:${runtime}'
	}
	return parts.join(', ')
}

fn scheduler_summary(scheduler Scheduler) string {
	match scheduler {
		.go {
			return 'one V runtime lightweight task per mob'
		}
		.deterministic {
			return 'deterministic mob tasks on the frontend thread'
		}
	}
}
