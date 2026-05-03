module vground

import json
import os

pub fn save_replay_events(path string, events []SimEvent) ! {
	mut file := os.create(path)!
	defer {
		file.close()
	}
	for event in events {
		file.write_string(json.encode(event) + '\n')!
	}
}

pub fn load_replay_events(path string) ![]SimEvent {
	body := os.read_file(path)!
	mut events := []SimEvent{}
	for line_no, raw_line in body.split_into_lines() {
		line := raw_line.trim_space()
		if line == '' {
			continue
		}
		event := json.decode(SimEvent, line) or {
			return error('${path}:${line_no + 1}: invalid replay event: ${err.msg()}')
		}
		events << event
	}
	return events
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
