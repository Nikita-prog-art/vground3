module vground

import crypto.sha256
import json
import os
import strings

const replay_header_name = 'vground.replay'
const replay_schema_version = 1
const replay_world_seed = 'demo-world-v1'

pub struct ReplayMod {
pub:
	id      string
	version string
	runtime string
}

pub struct ReplayMeta {
pub:
	mods                []ReplayMod
	scheduler           string
	ticks               int
	tick_ms             int
	render_every        int
	world_seed          string
	world_hash          string
	final_snapshot_hash string
	event_count         int
}

pub struct ReplayHeader {
pub:
	replay string
	schema int
	meta   ReplayMeta
}

pub struct ReplayFile {
pub:
	has_header bool
	schema     int
	meta       ReplayMeta
	events     []SimEvent
}

pub struct ReplayVerifyResult {
pub:
	path          string
	event_count   int
	expected_hash string
	actual_hash   string
}

pub fn save_replay(path string, meta ReplayMeta, events []SimEvent) ! {
	header := ReplayHeader{
		replay: replay_header_name
		schema: replay_schema_version
		meta:   meta
	}
	mut file := os.create(path)!
	defer {
		file.close()
	}
	file.write_string(json.encode(header) + '\n')!
	for event in events {
		file.write_string(json.encode(event) + '\n')!
	}
}

pub fn save_replay_events(path string, events []SimEvent) ! {
	save_replay(path, replay_meta_from_events(events, 1), events)!
}

pub fn load_replay(path string) !ReplayFile {
	body := os.read_file(path)!
	mut events := []SimEvent{}
	mut meta := ReplayMeta{}
	mut schema := 0
	mut has_header := false
	mut first_payload_seen := false
	for line_no, raw_line in body.split_into_lines() {
		line := raw_line.trim_space()
		if line == '' {
			continue
		}
		if !first_payload_seen {
			first_payload_seen = true
			if line.contains('"replay"') {
				header := json.decode(ReplayHeader, line) or {
					return error('${path}:${line_no + 1}: invalid replay header: ${err.msg()}')
				}
				if header.replay != replay_header_name {
					return error('${path}:${line_no + 1}: unsupported replay header `${header.replay}`')
				}
				if header.schema != replay_schema_version {
					return error('${path}:${line_no + 1}: unsupported replay schema ${header.schema}')
				}
				meta = header.meta
				schema = header.schema
				has_header = true
				continue
			}
		}
		event := json.decode(SimEvent, line) or {
			return error('${path}:${line_no + 1}: invalid replay event: ${err.msg()}')
		}
		events << event
	}
	return ReplayFile{
		has_header: has_header
		schema:     schema
		meta:       meta
		events:     events
	}
}

pub fn load_replay_events(path string) ![]SimEvent {
	return load_replay(path)!.events
}

pub fn replay_meta_from_run(mods []VgMod, config AppConfig, world_hash string, snapshot SimulationSnapshot, event_count int) ReplayMeta {
	return ReplayMeta{
		mods:                replay_mods_from_mods(mods)
		scheduler:           config.scheduler.name()
		ticks:               config.ticks
		tick_ms:             config.tick_ms
		render_every:        config.render_every
		world_seed:          replay_world_seed
		world_hash:          world_hash
		final_snapshot_hash: snapshot_hash(snapshot)
		event_count:         event_count
	}
}

pub fn replay_meta_from_events(events []SimEvent, render_every int) ReplayMeta {
	frames := replay_events_to_frames(events, render_every)
	snapshot := final_snapshot_from_frames(frames)
	return ReplayMeta{
		render_every:        render_every
		final_snapshot_hash: snapshot_hash(snapshot)
		event_count:         events.len
	}
}

pub fn replay_events_to_frames(events []SimEvent, render_every int) []SimulationFrame {
	active_mobs := replay_active_mobs(events)
	mut state := new_simulation_state()
	mut cadence := new_render_cadence(render_every)
	mut frames := []SimulationFrame{cap: events.len}
	for event in events {
		state.apply_event(event)
		snapshot := state.snapshot()
		frames << SimulationFrame{
			event:      event
			snapshot:   snapshot
			render_due: cadence.due(event, snapshot, active_mobs)
		}
	}
	return frames
}

pub fn validate_replay_compatibility(replay ReplayFile, mods []VgMod, world &World) ! {
	if !replay.has_header {
		return
	}
	if replay.schema != replay_schema_version {
		return error('unsupported replay schema ${replay.schema}')
	}
	if replay.meta.event_count > 0 && replay.meta.event_count != replay.events.len {
		return error('replay event count mismatch: expected ${replay.meta.event_count}, got ${replay.events.len}')
	}
	if replay.meta.world_hash != '' {
		current_world_hash := world_hash(world)
		if replay.meta.world_hash != current_world_hash {
			return error('replay world hash mismatch: expected ${replay.meta.world_hash}, got ${current_world_hash}')
		}
	}
	if replay.meta.mods.len > 0 {
		current_mods := replay_mods_from_mods(mods)
		if !same_replay_mods(replay.meta.mods, current_mods) {
			return error('replay mod metadata mismatch')
		}
	}
}

pub fn verify_replay_file(path string, mods []VgMod, world &World, fallback_render_every int) !ReplayVerifyResult {
	replay := load_replay(path)!
	validate_replay_compatibility(replay, mods, world)!
	if !replay.has_header || replay.meta.final_snapshot_hash == '' {
		return error('${path}: replay verify requires v1 metadata with final_snapshot_hash')
	}
	frames := replay_events_to_frames(replay.events, replay_render_every(replay, fallback_render_every))
	snapshot := final_snapshot_from_frames(frames)
	actual_hash := snapshot_hash(snapshot)
	expected_hash := replay.meta.final_snapshot_hash
	if actual_hash != expected_hash {
		return error('replay verify failed: expected snapshot hash ${expected_hash}, got ${actual_hash}')
	}
	return ReplayVerifyResult{
		path:          path
		event_count:   replay.events.len
		expected_hash: expected_hash
		actual_hash:   actual_hash
	}
}

pub fn replay_render_every(replay ReplayFile, fallback int) int {
	if replay.has_header && replay.meta.render_every > 0 {
		return replay.meta.render_every
	}
	return fallback
}

pub fn final_snapshot_from_frames(frames []SimulationFrame) SimulationSnapshot {
	if frames.len == 0 {
		return SimulationSnapshot{}
	}
	return frames[frames.len - 1].snapshot
}

pub fn snapshot_hash(snapshot SimulationSnapshot) string {
	return sha256.hexhash(snapshot_signature(snapshot))
}

pub fn world_hash(world &World) string {
	mut signature := strings.new_builder(1024)
	size := world.world_size()
	signature.write_string('world:${replay_world_seed}:${size.x}x${size.y}:chunk=${world.chunk_size}\n')
	for line in world.render([]MobView{}) {
		signature.write_string(line)
		signature.write_string('\n')
	}
	return sha256.hexhash(signature.str())
}

fn replay_mods_from_mods(mods []VgMod) []ReplayMod {
	mut replay_mods := []ReplayMod{cap: mods.len}
	for mod in mods {
		replay_mods << ReplayMod{
			id:      mod.id
			version: mod.version
			runtime: mod.runtime
		}
	}
	replay_mods.sort_with_compare(compare_replay_mods)
	return replay_mods
}

fn same_replay_mods(left []ReplayMod, right []ReplayMod) bool {
	if left.len != right.len {
		return false
	}
	mut sorted_left := left.clone()
	mut sorted_right := right.clone()
	sorted_left.sort_with_compare(compare_replay_mods)
	sorted_right.sort_with_compare(compare_replay_mods)
	for idx, left_mod in sorted_left {
		right_mod := sorted_right[idx]
		if left_mod.id != right_mod.id || left_mod.version != right_mod.version
			|| left_mod.runtime != right_mod.runtime {
			return false
		}
	}
	return true
}

fn compare_replay_mods(a &ReplayMod, b &ReplayMod) int {
	return compare_strings(a.id, b.id)
}

fn snapshot_signature(snapshot SimulationSnapshot) string {
	mut signature := strings.new_builder(1024)
	signature.write_string('done=${snapshot.done}\n')
	mut mobs := snapshot.mobs.clone()
	mobs.sort_with_compare(compare_mob_views)
	for mob in mobs {
		signature.write_string('mob:${mob.id}:${mob.name}:${mob.glyph}:${mob.pos.x},${mob.pos.y}\n')
	}
	mut tick_ids := snapshot.ticks.keys()
	tick_ids.sort()
	for id in tick_ids {
		signature.write_string('tick:${id}:${snapshot.ticks[id] or { 0 }}\n')
	}
	return signature.str()
}

fn compare_mob_views(a &MobView, b &MobView) int {
	return compare_strings(a.id, b.id)
}

fn compare_strings(a string, b string) int {
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}

fn replay_active_mobs(events []SimEvent) int {
	mut ids := map[string]bool{}
	for event in events {
		if event.kind == .spawned && event.mob_id != '' {
			ids[event.mob_id] = true
		}
	}
	if ids.len > 0 {
		return ids.len
	}
	for event in events {
		if event.mob_id != '' {
			ids[event.mob_id] = true
		}
	}
	return ids.len
}
