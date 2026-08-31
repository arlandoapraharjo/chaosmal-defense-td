extends Resource
class_name BiomeData

## One of these should be created per biome (e.g. biome_snow.tres,
## biome_desert.tres, biome_grass.tres). Fill in the fields in the
## Inspector — drag the correct model/scene for that biome's asset kit
## into each slot. The map generator reads whichever BiomeData is active
## at runtime; it never hardcodes a specific biome's paths itself.

@export_group("Tiles")
@export var tile_base: PackedScene
@export var tile_straight: PackedScene
@export var tile_corner: PackedScene
@export var tile_spawn: PackedScene
@export var tile_end: PackedScene

@export_group("Decorations")
@export var tree_model: PackedScene
## Scale multiplier for the tree model. Adjust per-biome to control
## how big the tree appears in the world (1.0 = original mesh size).
@export_range(0.01, 50.0, 0.01) var tree_scale: float = 1.0
@export var tree_large_model: PackedScene
## Scale multiplier for the large tree model. Adjust per-biome to control
## how big the large tree appears in the world (1.0 = original mesh size).
@export_range(0.01, 50.0, 0.01) var tree_large_scale: float = 1.0
## Speed of tree swinging animation (0.0 = static / no sway).
@export_range(0.0, 20.0, 0.1) var tree_sway_speed: float = 2.0
## Strength of tree swinging animation.
@export_range(0.0, 2.0, 0.01) var tree_sway_strength: float = 0.15
@export var rock_model: PackedScene
@export var bush_model: PackedScene
## Optional grass scene for this biome. Leave empty for biomes with no grass.
@export var grass_model: PackedScene

@export_group("Look & Feel")
## Assign a different Environment resource per biome (sky, fog, ambient
## light, tonemap, etc.) — this is what actually makes each biome feel
## distinct beyond just the models.
@export var environment: Environment
## If true, forces fog to be disabled for this biome.
@export var disable_fog: bool = false
@export var has_heat_distortion: bool = false
## Optional: some biomes may want denser/sparser decoration than others.
@export_range(0.0, 1.0) var decoration_chance: float = 0.15
## Hotbar color theme for this biome. Assign a HotbarTheme .tres resource.
@export var hotbar_theme: HotbarTheme

@export_group("Character")
## 3D companion/character model for this biome (e.g. animal-penguin.glb, animal-lion.glb, animal-fox.glb).
@export var character_model: PackedScene
@export var character_name: String = "Fox"
@export var character_emoji: String = "🦊"
