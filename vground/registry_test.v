module vground

import os

fn test_core_mod_loads_and_registers_content() {
	path := os.join_path(@VMODROOT, 'mods', 'core.vgmod')
	core := load_mod(path)!
	assert core.id == 'core'
	registry := build_registry([core])!
	assert 'core:grass' in registry.blocks
	assert 'core:slime' in registry.mobs
	assert 'core:native_v' in registry.runtimes
}
