module vground

import time

pub enum EventKind {
	spawned
	moved
	blocked
	done
}

pub struct MobActor {
pub:
	id     string
	def_id string
	name   string
	glyph  string
	hp     int
	pos    Vec2
}

pub struct SimEvent {
pub:
	kind     EventKind
	mob_id   string
	mob_name string
	glyph    string
	tick     int
	from     Vec2
	to       Vec2
	reason   string
	chunk    ChunkPos
	visits   int
}

pub struct SimulationSnapshot {
pub:
	mobs  []MobView
	ticks map[string]int
	done  int
}

pub struct SimulationState {
mut:
	mob_views map[string]MobView
	mob_ticks map[string]int
	done      int
}

pub struct SimulationRun {
mut:
	events        chan SimEvent
	workers       []thread
	done          int
	expected_done int
}

struct DeterministicStep {
	actor_idx int
	tick      int
	due_ms    int
}

pub fn new_simulation_state() SimulationState {
	return SimulationState{
		mob_views: map[string]MobView{}
		mob_ticks: map[string]int{}
	}
}

pub fn (mut state SimulationState) apply_event(event SimEvent) {
	match event.kind {
		.spawned {
			state.mob_views[event.mob_id] = MobView{
				id:    event.mob_id
				name:  event.mob_name
				glyph: event.glyph
				pos:   event.to
			}
			state.mob_ticks[event.mob_id] = 0
		}
		.moved {
			state.mob_views[event.mob_id] = MobView{
				id:    event.mob_id
				name:  event.mob_name
				glyph: event.glyph
				pos:   event.to
			}
			state.mob_ticks[event.mob_id] = event.tick
		}
		.blocked {
			state.mob_ticks[event.mob_id] = event.tick
		}
		.done {
			if event.mob_id in state.mob_views {
				state.mob_views[event.mob_id] = MobView{
					id:    event.mob_id
					name:  event.mob_name
					glyph: event.glyph
					pos:   event.to
				}
			}
			state.done++
		}
	}
}

pub fn (state &SimulationState) snapshot() SimulationSnapshot {
	return SimulationSnapshot{
		mobs:  state.mob_views.values()
		ticks: state.mob_ticks.clone()
		done:  state.done
	}
}

pub fn start_simulation(world &World, registry Registry, actors []MobActor, config AppConfig) SimulationRun {
	match config.scheduler {
		.go {
			events := chan SimEvent{cap: 128}
			workers := start_mob_threads(world, registry, actors, events, config)
			return SimulationRun{
				events:        events
				workers:       workers
				expected_done: workers.len
			}
		}
		.deterministic {
			sim_events := run_deterministic_simulation(world, registry, actors, config)
			events := chan SimEvent{cap: sim_events.len}
			for event in sim_events {
				events <- event
			}
			return SimulationRun{
				events:        events
				expected_done: actors.len
			}
		}
	}
}

pub fn (run &SimulationRun) active_mobs() int {
	return run.expected_done
}

pub fn (mut run SimulationRun) next_event() ?SimEvent {
	if run.done >= run.expected_done {
		return none
	}
	event := <-run.events or { return none }
	if event.kind == .done {
		run.done++
	}
	return event
}

pub fn (mut run SimulationRun) wait() {
	for worker in run.workers {
		worker.wait()
	}
}

pub fn demo_mobs(registry Registry) []MobActor {
	candidates := [
		['core:slime', '1', '3', '3'],
		['core:forager', '2', '9', '10'],
		['core:farmer', '3', '19', '4'],
	]
	mut actors := []MobActor{}
	for row in candidates {
		def_id := row[0]
		def := registry.mobs[def_id] or { continue }
		actors << MobActor{
			id:     '${def_id}/${row[1]}'
			def_id: def_id
			name:   def.name
			glyph:  def.glyph
			hp:     def.max_hp
			pos:    Vec2{
				x: row[2].int()
				y: row[3].int()
			}
		}
	}
	return actors
}

fn start_mob_threads(world &World, registry Registry, actors []MobActor, events chan SimEvent, config AppConfig) []thread {
	mut threads := []thread{cap: actors.len}
	for actor in actors {
		def := registry.mobs[actor.def_id] or { continue }
		threads << go mob_loop(actor, def, world, events, config.ticks, config.tick_ms)
	}
	return threads
}

fn mob_loop(actor MobActor, def MobDef, world &World, events chan SimEvent, ticks int, default_tick_ms int) {
	mut state := actor
	events <- SimEvent{
		kind:     .spawned
		mob_id:   state.id
		mob_name: state.name
		glyph:    state.glyph
		to:       state.pos
	}
	for tick in 1 .. ticks + 1 {
		events <- step_actor(mut state, def, world, tick)
		sleep_ms := actor_tick_ms(def, default_tick_ms)
		if sleep_ms > 0 {
			time.sleep(sleep_ms * time.millisecond)
		}
	}
	events <- SimEvent{
		kind:     .done
		mob_id:   state.id
		mob_name: state.name
		glyph:    state.glyph
		tick:     ticks
		to:       state.pos
	}
}

pub fn run_deterministic_simulation(world &World, registry Registry, actors []MobActor, config AppConfig) []SimEvent {
	mut states := actors.clone()
	mut events := []SimEvent{cap: actors.len * (config.ticks + 2)}
	for state in states {
		events << SimEvent{
			kind:     .spawned
			mob_id:   state.id
			mob_name: state.name
			glyph:    state.glyph
			to:       state.pos
		}
	}
	mut steps := []DeterministicStep{cap: states.len * config.ticks}
	for idx, state in states {
		def := registry.mobs[state.def_id] or { continue }
		interval_ms := actor_tick_ms(def, config.tick_ms)
		for tick in 1 .. config.ticks + 1 {
			steps << DeterministicStep{
				actor_idx: idx
				tick:      tick
				due_ms:    (tick - 1) * interval_ms
			}
		}
	}
	steps.sort_with_compare(compare_deterministic_steps)
	for step in steps {
		def := registry.mobs[states[step.actor_idx].def_id] or { continue }
		mut state := states[step.actor_idx]
		events << step_actor(mut state, def, world, step.tick)
		states[step.actor_idx] = state
	}
	for state in states {
		events << SimEvent{
			kind:     .done
			mob_id:   state.id
			mob_name: state.name
			glyph:    state.glyph
			tick:     config.ticks
			to:       state.pos
		}
	}
	return events
}

fn actor_tick_ms(def MobDef, default_tick_ms int) int {
	return if def.tick_ms > 0 { def.tick_ms } else { default_tick_ms }
}

fn compare_deterministic_steps(a &DeterministicStep, b &DeterministicStep) int {
	if a.due_ms < b.due_ms {
		return -1
	}
	if a.due_ms > b.due_ms {
		return 1
	}
	if a.tick < b.tick {
		return -1
	}
	if a.tick > b.tick {
		return 1
	}
	if a.actor_idx < b.actor_idx {
		return -1
	}
	if a.actor_idx > b.actor_idx {
		return 1
	}
	return 0
}

fn step_actor(mut state MobActor, def MobDef, world &World, tick int) SimEvent {
	dir := direction_for(def.behavior, state.id, tick)
	target := state.pos.add(dir)
	result := world.try_mob_step(state.id, state.pos, target)
	old_pos := state.pos
	if result.ok {
		state = MobActor{
			...state
			pos: target
		}
		return SimEvent{
			kind:     .moved
			mob_id:   state.id
			mob_name: state.name
			glyph:    state.glyph
			tick:     tick
			from:     old_pos
			to:       state.pos
			chunk:    result.chunk
			visits:   result.visits
		}
	}
	return SimEvent{
		kind:     .blocked
		mob_id:   state.id
		mob_name: state.name
		glyph:    state.glyph
		tick:     tick
		from:     old_pos
		to:       target
		reason:   result.reason
		chunk:    result.chunk
		visits:   result.visits
	}
}

fn direction_for(behavior string, id string, tick int) Vec2 {
	match behavior {
		'slime_bounce' {
			pattern := [
				Vec2{1, 0},
				Vec2{0, 1},
				Vec2{-1, 0},
				Vec2{0, -1},
			]
			return pattern[(tick + stable_hash(id)) % pattern.len]
		}
		'forage_loop' {
			pattern := [
				Vec2{0, -1},
				Vec2{1, 0},
				Vec2{1, 0},
				Vec2{0, 1},
				Vec2{-1, 0},
				Vec2{-1, 0},
			]
			return pattern[(tick + stable_hash(id)) % pattern.len]
		}
		'farm_patrol' {
			pattern := [
				Vec2{1, 0},
				Vec2{0, 1},
				Vec2{-1, 0},
				Vec2{0, -1},
			]
			return pattern[tick % pattern.len]
		}
		else {
			pattern := [
				Vec2{1, 0},
				Vec2{0, 1},
				Vec2{-1, 0},
				Vec2{0, -1},
			]
			return pattern[(tick + stable_hash(id)) % pattern.len]
		}
	}
}

fn stable_hash(text string) int {
	mut h := 0
	for b in text.bytes() {
		h += int(b)
	}
	return h
}
