module vground

import os

fn test_chunk_locked_step_updates_visits() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	from := Vec2{
		x: 2
		y: 2
	}
	to := Vec2{
		x: 3
		y: 2
	}
	first := world.try_step(from, to)
	second := world.try_step(from, to)
	assert first.ok
	assert second.ok
	assert first.visits == 1
	assert second.visits == 2
}

fn test_solid_blocks_reject_steps() {
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	result := world.try_step(Vec2{
		x: 2
		y: 5
	}, Vec2{
		x: 3
		y: 5
	})
	assert !result.ok
	assert result.block_id == 'core:water'
}
