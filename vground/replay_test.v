module vground

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
	loaded := load_replay_events(path)!
	os.rm(path)!
	assert loaded.len == events.len
	assert loaded[0].kind == .spawned
	assert loaded[1].kind == .moved
	assert loaded[1].to == Vec2{2, 2}
	assert loaded[2].kind == .done
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
