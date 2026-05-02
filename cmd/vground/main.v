module main

import os
import vground

fn main() {
	config := vground.config_from_args(os.args[1..]) or {
		eprintln(err.msg())
		exit(1)
	}
	vground.run(config) or {
		eprintln('vground: ${err.msg()}')
		exit(1)
	}
}
