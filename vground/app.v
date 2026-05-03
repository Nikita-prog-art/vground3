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
	behaviors := new_behavior_registry_for_mods(mods)!
	validate_behavior_registry(registry, behaviors)!
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
		replay := load_replay(config.replay_in)!
		validate_replay_compatibility(replay, app.mods, app.world)!
		replay_config := config_for_replay(config, replay)
		consumer.begin(app.world, app.registry, replay_config)!
		frames := replay_events_to_frames(replay.events, replay_config.render_every)
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
	initial_world_hash := world_hash(app.world)
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
		meta := replay_meta_from_run(app.mods, config, initial_world_hash, snapshot, replay_events.len)
		save_replay(config.replay_out, meta, replay_events)!
	}
	consumer.finish(snapshot, app.world)!
}

pub fn run(config AppConfig) ! {
	mut app := new_app(config)!
	if config.replay_verify != '' {
		result := verify_replay_file(config.replay_verify, app.mods, app.world, config.render_every)!
		println('replay verify ok: ${result.path} events=${result.event_count} snapshot=${result.actual_hash}')
		return
	}
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

fn config_for_replay(config AppConfig, replay ReplayFile) AppConfig {
	if !replay.has_header {
		return config
	}
	scheduler := parse_scheduler(replay.meta.scheduler) or { config.scheduler }
	ticks := if replay.meta.ticks > 0 { replay.meta.ticks } else { config.ticks }
	return AppConfig{
		...config
		scheduler:    scheduler
		ticks:        ticks
		tick_ms:      replay.meta.tick_ms
		render_every: replay_render_every(replay, config.render_every)
	}
}

pub fn frontend_descriptors() []string {
	return [
		'terminal: text renderer, event log, deterministic debugging',
		'gui: reserved frontend slot; currently uses the shared frame contract',
	]
}
