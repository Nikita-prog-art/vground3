module vground

pub struct Vec2 {
pub:
	x int
	y int
}

pub fn (p Vec2) add(other Vec2) Vec2 {
	return Vec2{
		x: p.x + other.x
		y: p.y + other.y
	}
}

pub fn (p Vec2) str() string {
	return '(${p.x},${p.y})'
}

pub struct ChunkPos {
pub:
	x int
	y int
}

pub fn (p ChunkPos) str() string {
	return '${p.x}:${p.y}'
}

fn pos_key(p Vec2) string {
	return '${p.x}:${p.y}'
}

fn chunk_key(x int, y int) string {
	return '${x}:${y}'
}
