module vground

import os
import toml

pub struct ScriptHook {
pub:
	entry string
	abi   string
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
	tick_ms  int
	tags     []string
	hooks    []ScriptHook
}

pub struct VgMod {
pub:
	schema      int
	id          string
	name        string
	version     string
	runtime     string
	description string
	blocks      []BlockDef
	items       []ItemDef
	mobs        []MobDef
}

pub fn load_mod(path string) !VgMod {
	body := os.read_file(path)!
	doc := toml.parse_text(body)!
	mod := parse_mod_doc(doc)!
	if mod.schema != 1 {
		return error('${path}: unsupported vgmod schema ${mod.schema}')
	}
	if mod.id == '' {
		return error('${path}: mod id is required')
	}
	if mod.runtime == '' {
		return error('${path}: runtime is required')
	}
	return mod
}

fn parse_mod_doc(doc toml.Doc) !VgMod {
	root_any := doc.to_any()
	root := match root_any {
		map[string]toml.Any {
			root_any
		}
		else {
			return error('mod root must be a TOML table')
		}
	}
	return VgMod{
		schema:      any_int(root, 'schema', 0)
		id:          any_string(root, 'id', '')
		name:        any_string(root, 'name', '')
		version:     any_string(root, 'version', '')
		runtime:     any_string(root, 'runtime', '')
		description: any_string(root, 'description', '')
		blocks:      parse_blocks(doc.value('blocks'))!
		items:       parse_items(doc.value('items'))!
		mobs:        parse_mobs(doc.value('mobs'))!
	}
}

fn parse_blocks(value toml.Any) ![]BlockDef {
	mut blocks := []BlockDef{}
	for table in table_array(value, 'blocks')! {
		blocks << BlockDef{
			id:    any_string(table, 'id', '')
			name:  any_string(table, 'name', '')
			glyph: any_string(table, 'glyph', '?')
			solid: any_bool(table, 'solid', false)
			tags:  any_strings(table, 'tags')
			hooks: parse_hooks(table)!
		}
	}
	return blocks
}

fn parse_items(value toml.Any) ![]ItemDef {
	mut items := []ItemDef{}
	for table in table_array(value, 'items')! {
		items << ItemDef{
			id:    any_string(table, 'id', '')
			name:  any_string(table, 'name', '')
			glyph: any_string(table, 'glyph', '?')
			tags:  any_strings(table, 'tags')
			hooks: parse_hooks(table)!
		}
	}
	return items
}

fn parse_mobs(value toml.Any) ![]MobDef {
	mut mobs := []MobDef{}
	for table in table_array(value, 'mobs')! {
		mobs << MobDef{
			id:       any_string(table, 'id', '')
			name:     any_string(table, 'name', '')
			glyph:    any_string(table, 'glyph', '?')
			max_hp:   any_int(table, 'max_hp', 1)
			behavior: any_string(table, 'behavior', '')
			tick_ms:  any_int(table, 'tick_ms', 0)
			tags:     any_strings(table, 'tags')
			hooks:    parse_hooks(table)!
		}
	}
	return mobs
}

fn parse_hooks(table map[string]toml.Any) ![]ScriptHook {
	value := table['hooks'] or { return []ScriptHook{} }
	mut hooks := []ScriptHook{}
	match value {
		[]toml.Any {
			for raw in value {
				match raw {
					map[string]toml.Any {
						hooks << ScriptHook{
							entry: any_string(raw, 'entry', '')
							abi:   any_string(raw, 'abi', '')
						}
					}
					else {
						return error('hooks: expected table entry')
					}
				}
			}
		}
		toml.Null {
			return hooks
		}
		else {
			return error('hooks: expected table array')
		}
	}
	return hooks
}

fn table_array(value toml.Any, key string) ![]map[string]toml.Any {
	match value {
		[]toml.Any {
			mut tables := []map[string]toml.Any{cap: value.len}
			for raw in value {
				match raw {
					map[string]toml.Any {
						tables << raw
					}
					else {
						return error('${key}: expected table entry')
					}
				}
			}
			return tables
		}
		toml.Null {
			return []map[string]toml.Any{}
		}
		else {
			return error('${key}: expected table array')
		}
	}
}

fn any_string(table map[string]toml.Any, key string, fallback string) string {
	value := table[key] or { return fallback }
	return value.string()
}

fn any_int(table map[string]toml.Any, key string, fallback int) int {
	value := table[key] or { return fallback }
	return value.int()
}

fn any_bool(table map[string]toml.Any, key string, fallback bool) bool {
	value := table[key] or { return fallback }
	return value.bool()
}

fn any_strings(table map[string]toml.Any, key string) []string {
	value := table[key] or { return []string{} }
	return value.array().map(it.string())
}

pub fn load_mods(paths []string) ![]VgMod {
	mut mods := []VgMod{cap: paths.len}
	for path in paths {
		mods << load_mod(path)!
	}
	return mods
}
