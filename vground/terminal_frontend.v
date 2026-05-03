module vground

pub fn run_terminal(mut app GameApp, config AppConfig) ! {
	mut consumer := TerminalFrameConsumer{}
	run_frame_frontend(mut app, config, mut consumer)!
}

struct TerminalFrameConsumer {}

fn (mut consumer TerminalFrameConsumer) begin(world &World, registry Registry, config AppConfig) ! {
	println('vground3 terminal frontend')
	println('mods: ${registry.mod_ids.join(', ')}')
	println('scheduler: ${scheduler_summary(config.scheduler)}')
	if config.replay_in != '' {
		println('replay: ${config.replay_in}')
	}
	if config.replay_out != '' {
		println('replay out: ${config.replay_out}')
	}
	println('world access: each chunk owns a mutex; actor steps lock occupied chunks')
	println('runtime: ${runtime_summary(registry)}')
	print_world(world, []MobView{})
}

fn (mut consumer TerminalFrameConsumer) consume(frame SimulationFrame, world &World) ! {
	handle_terminal_frame(frame, world)
}

fn (mut consumer TerminalFrameConsumer) finish(snapshot SimulationSnapshot, world &World) ! {
	println('simulation complete')
	print_snapshot(world, snapshot)
}

fn handle_terminal_frame(frame SimulationFrame, world &World) {
	event := frame.event
	match event.kind {
		.spawned {
			println('enter ${event.mob_name} ${event.mob_id} at ${event.to}')
			print_snapshot(world, frame.snapshot)
		}
		.moved {
			println('tick ${event.tick:02d} move ${event.mob_id} ${event.from} -> ${event.to} chunk=${event.chunk} visits=${event.visits}')
			if frame.render_due {
				print_snapshot(world, frame.snapshot)
			}
		}
		.blocked {
			println('tick ${event.tick:02d} block ${event.mob_id} ${event.from} -> ${event.to}: ${event.reason}')
			if frame.render_due {
				print_snapshot(world, frame.snapshot)
			}
		}
		.done {
			println('done ${event.mob_id} at ${event.to}')
		}
	}
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
