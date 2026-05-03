module vground

import json
import os
import time

fn replay_test_path() string {
	return os.join_path(os.temp_dir(), 'vground_replay_${time.now().unix_milli()}.ndjson')
}

fn test_replay_events_round_trip_as_ndjson() {
	path := replay_test_path()
	events := [
		SimEvent{
			kind:     .spawned
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			to:       Vec2{1, 2}
		},
		SimEvent{
			kind:     .moved
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			tick:     1
			from:     Vec2{1, 2}
			to:       Vec2{2, 2}
			chunk:    ChunkPos{0, 0}
			visits:   1
		},
		SimEvent{
			kind:     .done
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			tick:     1
			to:       Vec2{2, 2}
		},
	]
	save_replay_events(path, events)!
	replay := load_replay(path)!
	loaded := load_replay_events(path)!
	os.rm(path)!
	assert replay.has_header
	assert replay.schema == replay_schema_version
	assert replay.meta.event_count == events.len
	assert replay.meta.final_snapshot_hash != ''
	assert loaded.len == events.len
	assert loaded[0].kind == .spawned
	assert loaded[1].kind == .moved
	assert loaded[1].to == Vec2{2, 2}
	assert loaded[2].kind == .done
}

fn test_replay_loader_accepts_legacy_event_stream_without_header() {
	path := replay_test_path()
	event := SimEvent{
		kind:     .spawned
		mob_id:   'mob:a'
		mob_name: 'Mob A'
		glyph:    'a'
		to:       Vec2{1, 2}
	}
	os.write_file(path, json.encode(event) + '\n')!
	replay := load_replay(path)!
	os.rm(path)!
	assert !replay.has_header
	assert replay.events.len == 1
	assert replay.events[0].kind == .spawned
}

fn test_replay_events_rebuild_frames_and_render_cadence() {
	events := [
		SimEvent{
			kind:     .spawned
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			to:       Vec2{1, 1}
		},
		SimEvent{
			kind:     .spawned
			mob_id:   'mob:b'
			mob_name: 'Mob B'
			glyph:    'b'
			to:       Vec2{2, 1}
		},
		SimEvent{
			kind:     .moved
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			tick:     1
			from:     Vec2{1, 1}
			to:       Vec2{1, 2}
		},
		SimEvent{
			kind:     .moved
			mob_id:   'mob:b'
			mob_name: 'Mob B'
			glyph:    'b'
			tick:     1
			from:     Vec2{2, 1}
			to:       Vec2{2, 2}
		},
		SimEvent{
			kind:   .done
			mob_id: 'mob:a'
			to:     Vec2{1, 2}
		},
		SimEvent{
			kind:   .done
			mob_id: 'mob:b'
			to:     Vec2{2, 2}
		},
	]
	frames := replay_events_to_frames(events, 1)
	due_frames := frames.filter(it.render_due)
	final := frames[frames.len - 1].snapshot
	assert due_frames.len == 1
	assert due_frames[0].event.mob_id == 'mob:b'
	assert final.done == 2
	assert final.mobs.len == 2
}

fn test_replay_verify_checks_final_snapshot_hash() {
	path := replay_test_path()
	events := [
		SimEvent{
			kind:     .spawned
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			to:       Vec2{1, 1}
		},
		SimEvent{
			kind:     .moved
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			tick:     1
			from:     Vec2{1, 1}
			to:       Vec2{2, 1}
		},
		SimEvent{
			kind:     .done
			mob_id:   'mob:a'
			mob_name: 'Mob A'
			glyph:    'a'
			tick:     1
			to:       Vec2{2, 1}
		},
	]
	save_replay_events(path, events)!
	core := load_mod(os.join_path(@VMODROOT, 'mods', 'core.vgmod'))!
	registry := build_registry([core])!
	world := new_demo_world(registry)!
	result := verify_replay_file(path, []VgMod{}, world, 1)!
	os.rm(path)!
	assert result.event_count == events.len
	assert result.expected_hash == result.actual_hash
}
