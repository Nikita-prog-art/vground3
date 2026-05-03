module vground

import strconv

pub enum Scheduler {
	go
	deterministic
}

pub struct AppConfig {
pub:
	frontend     string
	scheduler    Scheduler
	mod_paths    []string
	ticks        int
	tick_ms      int
	render_every int
	replay_out   string
	replay_in    string
}

pub fn config_from_args(args []string) !AppConfig {
	mut frontend := 'terminal'
	mut scheduler_name := 'go'
	mut mod_paths := ['mods/core.vgmod']
	mut ticks := 16
	mut tick_ms := 120
	mut render_every := 2
	mut replay_out := ''
	mut replay_in := ''
	mut i := 0
	for i < args.len {
		arg := args[i]
		match arg {
			'--' {}
			'--help', '-h' {
				println(help_text())
				exit(0)
			}
			'--frontend', '-f' {
				i++
				if i >= args.len {
					return error('--frontend expects terminal or gui')
				}
				frontend = args[i]
			}
			'--scheduler', '-s' {
				i++
				if i >= args.len {
					return error('--scheduler expects go or deterministic')
				}
				scheduler_name = args[i]
			}
			'--mod', '-m' {
				i++
				if i >= args.len {
					return error('--mod expects a path to a .vgmod file')
				}
				mod_paths << args[i]
			}
			'--only-mod' {
				i++
				if i >= args.len {
					return error('--only-mod expects a path to a .vgmod file')
				}
				mod_paths = [args[i]]
			}
			'--ticks' {
				i++
				if i >= args.len {
					return error('--ticks expects an integer')
				}
				ticks = strconv.atoi(args[i]) or {
					return error('invalid --ticks value: ${args[i]}')
				}
			}
			'--tick-ms' {
				i++
				if i >= args.len {
					return error('--tick-ms expects an integer')
				}
				tick_ms = strconv.atoi(args[i]) or {
					return error('invalid --tick-ms value: ${args[i]}')
				}
			}
			'--render-every' {
				i++
				if i >= args.len {
					return error('--render-every expects an integer')
				}
				render_every = strconv.atoi(args[i]) or {
					return error('invalid --render-every value: ${args[i]}')
				}
			}
			'--replay-out' {
				i++
				if i >= args.len {
					return error('--replay-out expects a path')
				}
				replay_out = args[i]
			}
			'--replay-in' {
				i++
				if i >= args.len {
					return error('--replay-in expects a path')
				}
				replay_in = args[i]
			}
			else {
				return error('unknown argument `${arg}`\n${help_text()}')
			}
		}
		i++
	}
	if frontend !in ['terminal', 'gui'] {
		return error('unknown frontend `${frontend}`; expected terminal or gui')
	}
	scheduler := parse_scheduler(scheduler_name)!
	if ticks < 1 {
		return error('--ticks must be >= 1')
	}
	if tick_ms < 0 {
		return error('--tick-ms must be >= 0')
	}
	if render_every < 1 {
		return error('--render-every must be >= 1')
	}
	if replay_out != '' && replay_in != '' {
		return error('--replay-out and --replay-in cannot be used together')
	}
	return AppConfig{
		frontend:     frontend
		scheduler:    scheduler
		mod_paths:    mod_paths
		ticks:        ticks
		tick_ms:      tick_ms
		render_every: render_every
		replay_out:   replay_out
		replay_in:    replay_in
	}
}

pub fn help_text() string {
	return
		'usage: ./v/v run cmd/vground -- [--frontend terminal|gui] [--scheduler go|deterministic] [--ticks N] [--tick-ms N] [--mod path] [--replay-out path|--replay-in path]\n' +
		'\n' + 'frontends:\n' + '  terminal  deterministic text renderer and event log\n' +
		'  gui       placeholder frontend using the shared frame contract\n' + '\n' +
		'schedulers:\n' + '  go        one V runtime lightweight task per mob\n' +
		'  deterministic  cooperative mob tasks on the frontend thread\n' + '\n' + 'replay:\n' +
		'  --replay-out path  write SimEvent stream as NDJSON\n' +
		'  --replay-in path   render a previously written NDJSON SimEvent stream\n'
}

fn parse_scheduler(value string) !Scheduler {
	match value {
		'go' {
			return .go
		}
		'deterministic' {
			return .deterministic
		}
		else {
			return error('unknown scheduler `${value}`; expected go or deterministic')
		}
	}
}
