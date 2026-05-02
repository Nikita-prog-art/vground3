module vground

import sync

pub struct BlockCell {
pub:
	block_id string
	glyph    string
	solid    bool
pub mut:
	visits int
}

pub struct Chunk {
pub:
	pos ChunkPos
pub mut:
	mu    &sync.Mutex = unsafe { nil }
	cells []BlockCell
}

pub struct World {
pub:
	chunk_size    int
	width_chunks  int
	height_chunks int
pub mut:
	chunks map[string]&Chunk
}

pub struct StepResult {
pub:
	ok       bool
	from     Vec2
	to       Vec2
	block_id string
	reason   string
	chunk    ChunkPos
	visits   int
}

pub struct MobView {
pub:
	id    string
	name  string
	glyph string
	pos   Vec2
}

pub fn new_demo_world(registry Registry) !&World {
	chunk_size := 8
	width_chunks := 3
	height_chunks := 2
	mut world := &World{
		chunk_size:    chunk_size
		width_chunks:  width_chunks
		height_chunks: height_chunks
		chunks:        map[string]&Chunk{}
	}
	for cy in 0 .. height_chunks {
		for cx in 0 .. width_chunks {
			world.chunks[chunk_key(cx, cy)] = new_chunk(cx, cy, chunk_size, registry)!
		}
	}
	return world
}

fn new_chunk(cx int, cy int, chunk_size int, registry Registry) !&Chunk {
	mut cells := []BlockCell{cap: chunk_size * chunk_size}
	for ly in 0 .. chunk_size {
		for lx in 0 .. chunk_size {
			wx := cx * chunk_size + lx
			wy := cy * chunk_size + ly
			block_id := block_for_demo_world(wx, wy)
			block := registry.blocks[block_id] or {
				return error('demo world references missing block `${block_id}`')
			}
			cells << BlockCell{
				block_id: block.id
				glyph:    block.glyph
				solid:    block.solid
			}
		}
	}
	return &Chunk{
		pos:   ChunkPos{
			x: cx
			y: cy
		}
		mu:    sync.new_mutex()
		cells: cells
	}
}

fn block_for_demo_world(x int, y int) string {
	world_w := 24
	world_h := 16
	if x == 0 || y == 0 || x == world_w - 1 || y == world_h - 1 {
		return 'core:stone'
	}
	if y == 5 && x >= 3 && x <= 14 {
		return 'core:water'
	}
	if x >= 17 && x <= 21 && y >= 3 && y <= 7 {
		return 'core:crop'
	}
	if x == 11 && y >= 9 && y <= 13 {
		return 'core:tree'
	}
	return 'core:grass'
}

pub fn (w &World) world_size() Vec2 {
	return Vec2{
		x: w.width_chunks * w.chunk_size
		y: w.height_chunks * w.chunk_size
	}
}

pub fn (w &World) in_bounds(p Vec2) bool {
	size := w.world_size()
	return p.x >= 0 && p.y >= 0 && p.x < size.x && p.y < size.y
}

pub fn (w &World) try_step(from Vec2, to Vec2) StepResult {
	if !w.in_bounds(to) {
		return StepResult{
			ok:     false
			from:   from
			to:     to
			reason: 'world edge'
		}
	}
	mut chunk := w.chunk_for_world(to) or {
		return StepResult{
			ok:     false
			from:   from
			to:     to
			reason: 'missing chunk'
		}
	}
	local := w.local_pos(to)
	idx := local.y * w.chunk_size + local.x
	chunk.mu.lock()
	cell := chunk.cells[idx]
	if cell.solid {
		chunk.mu.unlock()
		return StepResult{
			ok:       false
			from:     from
			to:       to
			block_id: cell.block_id
			reason:   'blocked by ${cell.block_id}'
			chunk:    chunk.pos
			visits:   cell.visits
		}
	}
	chunk.cells[idx].visits++
	visits := chunk.cells[idx].visits
	chunk.mu.unlock()
	return StepResult{
		ok:       true
		from:     from
		to:       to
		block_id: cell.block_id
		chunk:    chunk.pos
		visits:   visits
	}
}

fn (w &World) chunk_for_world(p Vec2) ?&Chunk {
	cx := p.x / w.chunk_size
	cy := p.y / w.chunk_size
	return w.chunks[chunk_key(cx, cy)] or { return none }
}

fn (w &World) local_pos(p Vec2) Vec2 {
	return Vec2{
		x: p.x % w.chunk_size
		y: p.y % w.chunk_size
	}
}

pub fn (w &World) render(mobs []MobView) []string {
	size := w.world_size()
	mut mob_glyphs := map[string]string{}
	for mob in mobs {
		mob_glyphs[pos_key(mob.pos)] = mob.glyph
	}
	mut lines := []string{cap: size.y}
	for y in 0 .. size.y {
		mut line := ''
		for x in 0 .. size.x {
			key := pos_key(Vec2{
				x: x
				y: y
			})
			if glyph := mob_glyphs[key] {
				line += glyph
			} else {
				line += w.block_glyph(Vec2{
					x: x
					y: y
				})
			}
		}
		lines << line
	}
	return lines
}

fn (w &World) block_glyph(p Vec2) string {
	mut chunk := w.chunk_for_world(p) or { return '?' }
	local := w.local_pos(p)
	idx := local.y * w.chunk_size + local.x
	chunk.mu.lock()
	glyph := chunk.cells[idx].glyph
	chunk.mu.unlock()
	return glyph
}
