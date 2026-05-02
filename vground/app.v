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
	world := new_demo_world(registry)!
	return GameApp{
		mods:     mods
		registry: registry
		world:    world
	}
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
		'gui: reserved frontend slot; currently delegates to terminal',
	]
}
