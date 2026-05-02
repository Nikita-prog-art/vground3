module vground

import json
import os

pub struct ScriptHook {
pub:
	language string
	entry    string
	abi      string
}

pub struct BlockDef {
pub:
	id    string
	name  string
	glyph string
	solid bool
	tags  []string
	hooks []ScriptHook
}

pub struct ItemDef {
pub:
	id    string
	name  string
	glyph string
	tags  []string
	hooks []ScriptHook
}

pub struct MobDef {
pub:
	id       string
	name     string
	glyph    string
	max_hp   int
	behavior string
	runtime  string
	tick_ms  int
	tags     []string
	hooks    []ScriptHook
}

pub struct RuntimeDef {
pub:
	id       string
	language string
	kind     string
	entry    string
	status   string
}

pub struct VgMod {
pub:
	schema      int
	id          string
	name        string
	version     string
	description string
	blocks      []BlockDef
	items       []ItemDef
	mobs        []MobDef
	runtimes    []RuntimeDef
}

pub fn load_mod(path string) !VgMod {
	body := os.read_file(path)!
	mod := json.decode(VgMod, body)!
	if mod.schema != 1 {
		return error('${path}: unsupported vgmod schema ${mod.schema}')
	}
	if mod.id == '' {
		return error('${path}: mod id is required')
	}
	return mod
}

pub fn load_mods(paths []string) ![]VgMod {
	mut mods := []VgMod{cap: paths.len}
	for path in paths {
		mods << load_mod(path)!
	}
	return mods
}
