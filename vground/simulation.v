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

pub fn start_mob_threads(world &World, registry Registry, actors []MobActor, events chan SimEvent, config AppConfig) []thread {
	mut threads := []thread{cap: actors.len}
	for actor in actors {
		def := registry.mobs[actor.def_id] or { continue }
		match config.scheduler {
			'spawn' {
				threads << spawn mob_loop(actor, def, world, events, config.ticks, config.tick_ms)
			}
			else {
				threads << go mob_loop(actor, def, world, events, config.ticks, config.tick_ms)
			}
		}
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
		sleep_ms := if def.tick_ms > 0 { def.tick_ms } else { default_tick_ms }
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

pub fn run_green_simulation(world &World, registry Registry, actors []MobActor, config AppConfig) []SimEvent {
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
	for tick in 1 .. config.ticks + 1 {
		for idx in 0 .. states.len {
			def := registry.mobs[states[idx].def_id] or { continue }
			mut state := states[idx]
			events << step_actor(mut state, def, world, tick)
			states[idx] = state
		}
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

fn step_actor(mut state MobActor, def MobDef, world &World, tick int) SimEvent {
	dir := direction_for(def.behavior, state.id, tick)
	target := state.pos.add(dir)
	result := world.try_step(state.pos, target)
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
				Vec2{1, 0},
				Vec2{0, 1},
				Vec2{-1, 0},
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
