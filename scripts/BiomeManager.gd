extends Node

enum BiomeType { GRASS, SNOW, DESERT }

var biomes: Array[BiomeData] = [
	preload("res://biomes/biome_grass.tres"),
	preload("res://biomes/biome_snow.tres"),
	preload("res://biomes/biome_desert.tres")
]

var current_biome: BiomeData = null

func _ready() -> void:
	randomize_biome()

func randomize_biome() -> BiomeData:
	if biomes.is_empty():
		return null
	var idx := randi() % biomes.size()
	current_biome = biomes[idx]
	return current_biome

func set_biome(biome: BiomeData) -> void:
	current_biome = biome

func set_biome_by_index(idx: int) -> BiomeData:
	if idx >= 0 and idx < biomes.size():
		current_biome = biomes[idx]
		return current_biome
	return null
