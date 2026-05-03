module vground

fn test_default_scheduler_is_go() {
	config := config_from_args([])!
	assert config.scheduler == .go
}

fn test_scheduler_accepts_go_and_deterministic() {
	go_config := config_from_args(['--scheduler', 'go'])!
	deterministic_config := config_from_args(['-s', 'deterministic'])!
	assert go_config.scheduler == .go
	assert deterministic_config.scheduler == .deterministic
}

fn test_removed_scheduler_names_are_rejected() {
	for scheduler in ['green', 'spawn', 'native'] {
		if _ := config_from_args(['--scheduler', scheduler]) {
			assert false, '${scheduler} should not be accepted'
		} else {
			assert err.msg().contains('expected go or deterministic')
		}
	}
}

fn test_scheduler_requires_value() {
	if _ := config_from_args(['--scheduler']) {
		assert false
	} else {
		assert err.msg() == '--scheduler expects go or deterministic'
	}
}

fn test_replay_paths_parse() {
	out_config := config_from_args(['--replay-out', '/tmp/out.ndjson'])!
	in_config := config_from_args(['--replay-in', '/tmp/in.ndjson'])!
	verify_config := config_from_args(['--replay-verify', '/tmp/in.ndjson'])!
	assert out_config.replay_out == '/tmp/out.ndjson'
	assert out_config.replay_in == ''
	assert in_config.replay_in == '/tmp/in.ndjson'
	assert in_config.replay_out == ''
	assert verify_config.replay_verify == '/tmp/in.ndjson'
	assert verify_config.replay_in == ''
}

fn test_replay_in_and_out_are_mutually_exclusive() {
	if _ := config_from_args(['--replay-out', '/tmp/out.ndjson', '--replay-in', '/tmp/in.ndjson']) {
		assert false
	} else {
		assert err.msg().contains('cannot be used together')
	}
}

fn test_replay_verify_is_mutually_exclusive_with_other_replay_modes() {
	if _ := config_from_args(['--replay-verify', '/tmp/in.ndjson', '--replay-out', '/tmp/out.ndjson']) {
		assert false
	} else {
		assert err.msg().contains('cannot be used together')
	}
}
