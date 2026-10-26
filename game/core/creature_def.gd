class_name CreatureDef
extends Resource

@export var id := ""
@export var key := ""
@export var name_en := ""
@export var name_tr := ""
@export var tier := 1
@export var oz_cost := 1
@export var hp := 1
@export var damage := 1
@export var speed := 1
@export var jump := 0
@export var flight := false
@export var abilities: PackedStringArray = []
@export var role := ""
@export var blurb_tr := ""
@export var blurb_en := ""
@export var ability_tr := ""
@export var ability_en := ""
@export var accent := Color.WHITE
@export var size_tiles := 1.0
@export var texture: Texture2D

const TILE := 64.0

var display_name: String:
	get:
		return name_tr if Game.lang == "tr" else name_en

var blurb: String:
	get:
		return blurb_tr if Game.lang == "tr" else blurb_en

var ability_text: String:
	get:
		return ability_tr if Game.lang == "tr" else ability_en

func max_hp() -> int:
	return 10 + hp * 10

func hit_damage() -> int:
	return 4 + damage * 2

func run_speed() -> float:
	return 150.0 + speed * 42.0

func jump_velocity(gravity: float) -> float:
	if jump <= 0:
		return 0.0
	var h := (1.2 + jump * 0.42) * TILE
	return sqrt(2.0 * gravity * h)

func has(ability: String) -> bool:
	return abilities.has(ability)

func height_px() -> float:
	return size_tiles * TILE
