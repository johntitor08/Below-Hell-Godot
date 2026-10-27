class_name LevelMap
extends RefCounted

var meta: Dictionary = {}
var rows: PackedStringArray = []
var width := 0
var height := 0

static func from_rows(r: Array, m := {}) -> LevelMap:
	var lm := LevelMap.new()
	lm.meta = m
	lm.rows = PackedStringArray(r)
	lm.height = lm.rows.size()
	for row in lm.rows:
		lm.width = maxi(lm.width, row.length())
	return lm

static func load_file(path: String) -> LevelMap:
	var m := LevelMap.new()
	var txt := FileAccess.get_file_as_string(path)
	var in_map := false
	for line in txt.split("\n"):
		var l := line.rstrip("\r")
		if not in_map:
			if l.strip_edges() == "---":
				in_map = true
				continue
			var i := l.find(":")
			if i > 0:
				m.meta[l.substr(0, i).strip_edges()] = l.substr(i + 1).strip_edges()
		else:
			m.rows.append(l)
	while m.rows.size() > 0 and m.rows[m.rows.size() - 1].strip_edges() == "":
		m.rows.remove_at(m.rows.size() - 1)
	m.height = m.rows.size()
	for r in m.rows:
		m.width = maxi(m.width, r.length())
	return m

func at(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0:
		return " "
	var r := rows[y]
	return r[x] if x < r.length() else " "

func is_solid(x: int, y: int) -> bool:
	var c := at(x, y)
	if y >= height:
		return true
	if x < 0 or x >= width:
		return true
	return c == "#" or c == "?"

func text(key: String) -> String:
	return str(meta.get(key + "_" + Game.lang, meta.get(key + "_tr", meta.get(key, ""))))
