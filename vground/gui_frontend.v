module vground

pub fn run_gui(mut app GameApp, config AppConfig) ! {
	println('gui frontend is reserved; delegating this run to terminal frontend')
	run_terminal(mut app, config)!
}
