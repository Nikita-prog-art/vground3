module vground

pub fn run_gui(mut app GameApp, config AppConfig) ! {
	println('gui frontend is reserved; using terminal renderer through the shared frame contract')
	mut consumer := TerminalFrameConsumer{}
	run_frame_frontend(mut app, config, mut consumer)!
}
