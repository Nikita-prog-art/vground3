module vground

fn test_default_scheduler_is_go() {
	config := config_from_args([])!
	assert config.scheduler == 'go'
}

fn test_scheduler_accepts_go_and_deterministic() {
	go_config := config_from_args(['--scheduler', 'go'])!
	deterministic_config := config_from_args(['-s', 'deterministic'])!
	assert go_config.scheduler == 'go'
	assert deterministic_config.scheduler == 'deterministic'
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
