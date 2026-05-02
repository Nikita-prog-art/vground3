module vground

pub fn run_terminal(mut app GameApp, config AppConfig) ! {
	actors := demo_mobs(app.registry)
	if actors.len == 0 {
		return error('no demo mobs are available in loaded mods')
	}
	println('vground3 terminal frontend')
	println('mods: ${app.registry.mod_ids.join(', ')}')
	println('scheduler: ${scheduler_summary(config.scheduler)}')
	println('world access: each chunk owns a mutex; actor steps lock destination chunks')
	println('runtimes: ${runtime_summary(app.registry)}')
	print_world(app.world, []MobView{})
	if config.scheduler == 'green' {
		run_terminal_green(mut app, actors, config)
		return
	}
	events := chan SimEvent{cap: 128}
	mut threads := start_mob_threads(app.world, app.registry, actors, events, config)
	mut mob_views := map[string]MobView{}
	mut done := 0
	for done < threads.len {
		event := <-events
		done += handle_terminal_event(event, mut mob_views, app.world, config)
	}
	for worker in threads {
		worker.wait()
	}
	println('simulation complete')
	print_world(app.world, mob_views.values())
}

fn run_terminal_green(mut app GameApp, actors []MobActor, config AppConfig) {
	mut mob_views := map[string]MobView{}
	for event in run_green_simulation(app.world, app.registry, actors, config) {
		handle_terminal_event(event, mut mob_views, app.world, config)
	}
	println('simulation complete')
	print_world(app.world, mob_views.values())
}

fn handle_terminal_event(event SimEvent, mut mob_views map[string]MobView, world &World, config AppConfig) int {
	match event.kind {
		.spawned {
			mob_views[event.mob_id] = MobView{
				id:    event.mob_id
				name:  event.mob_name
				glyph: event.glyph
				pos:   event.to
			}
			println('enter ${event.mob_name} ${event.mob_id} at ${event.to}')
			print_world(world, mob_views.values())
		}
		.moved {
			mob_views[event.mob_id] = MobView{
				id:    event.mob_id
				name:  event.mob_name
				glyph: event.glyph
				pos:   event.to
			}
			println('tick ${event.tick:02d} move ${event.mob_id} ${event.from} -> ${event.to} chunk=${event.chunk} visits=${event.visits}')
			if event.tick % config.render_every == 0 {
				print_world(world, mob_views.values())
			}
		}
		.blocked {
			println('tick ${event.tick:02d} block ${event.mob_id} ${event.from} -> ${event.to}: ${event.reason}')
			if event.tick % config.render_every == 0 {
				print_world(world, mob_views.values())
			}
		}
		.done {
			println('done ${event.mob_id} at ${event.to}')
			return 1
		}
	}
	return 0
}

fn print_world(world &World, mobs []MobView) {
	for line in world.render(mobs) {
		println(line)
	}
	println('')
}

fn runtime_summary(registry Registry) string {
	if registry.runtimes.len == 0 {
		return 'none'
	}
	mut parts := []string{}
	for _, runtime in registry.runtimes {
		parts << '${runtime.id}/${runtime.language}/${runtime.status}'
	}
	return parts.join(', ')
}

fn scheduler_summary(scheduler string) string {
	match scheduler {
		'native' {
			return 'one OS thread per mob'
		}
		'spawn' {
			return 'one OS thread per mob'
		}
		'go' {
			return 'one V runtime lightweight task per mob'
		}
		'green' {
			return 'cooperative green tasks on the frontend thread'
		}
		else {
			return scheduler
		}
	}
}
