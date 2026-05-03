module vground

pub struct GameApp {
pub:
	mods     []VgMod
	registry Registry
pub mut:
	world &World = unsafe { nil }
}

pub fn new_app(config AppConfig) !GameApp {
	mods := load_mods(config.mod_paths)!
	registry := build_registry(mods)!
	validate_behavior_registry(registry, new_behavior_registry())!
	world := new_demo_world(registry)!
	return GameApp{
		mods:     mods
		registry: registry
		world:    world
	}
}

pub interface SimulationFrameConsumer {
mut:
	begin(world &World, registry Registry, config AppConfig) !
	consume(frame SimulationFrame, world &World) !
	finish(snapshot SimulationSnapshot, world &World) !
}

pub fn run_frame_frontend(mut app GameApp, config AppConfig, mut consumer SimulationFrameConsumer) ! {
	if config.replay_in != '' {
		events := load_replay_events(config.replay_in)!
		consumer.begin(app.world, app.registry, config)!
		frames := replay_events_to_frames(events, config.render_every)
		mut snapshot := SimulationSnapshot{}
		for frame in frames {
			snapshot = frame.snapshot
			consumer.consume(frame, app.world)!
		}
		consumer.finish(snapshot, app.world)!
		return
	}

	actors := demo_mobs(app.registry)
	if actors.len == 0 {
		return error('no demo mobs are available in loaded mods')
	}
	app.world.place_mobs(actors)!
	consumer.begin(app.world, app.registry, config)!
	mut run := start_simulation(app.world, app.registry, actors, config)
	mut simulation := new_simulation_state()
	mut cadence := new_render_cadence(config.render_every)
	mut replay_events := []SimEvent{}
	for {
		frame := run.next_frame(mut simulation, mut cadence) or { break }
		if config.replay_out != '' {
			replay_events << frame.event
		}
		consumer.consume(frame, app.world)!
	}
	run.wait()
	snapshot := simulation.snapshot()
	if config.replay_out != '' {
		save_replay_events(config.replay_out, replay_events)!
	}
	consumer.finish(snapshot, app.world)!
}

pub fn run(config AppConfig) ! {
	mut app := new_app(config)!
	match config.frontend {
		'terminal' {
			run_terminal(mut app, config)!
		}
		'gui' {
			run_gui(mut app, config)!
		}
		else {
			return error('unknown frontend `${config.frontend}`')
		}
	}
}

pub fn frontend_descriptors() []string {
	return [
		'terminal: text renderer, event log, deterministic debugging',
		'gui: reserved frontend slot; currently uses the shared frame contract',
	]
}
