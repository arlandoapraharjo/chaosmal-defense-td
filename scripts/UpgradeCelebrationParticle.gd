class_name UpgradeCelebrationParticle
extends Node3D

## Plays a 3D fireworks sparkle burst and rising embers for turret level upgrades.
## Dynamically tinted to the upgraded rarity color with emission glow.

@export var default_color: Color = Color(1.0, 0.85, 0.2, 1.0)
var _color: Color = Color.WHITE

func setup_color(color: Color) -> void:
	_color = color
	_apply_color(color)

func _apply_color(color: Color) -> void:
	for child in get_children():
		if child is GPUParticles3D:
			if child.draw_pass_1 and child.draw_pass_1.material:
				var mat = child.draw_pass_1.material.duplicate() as StandardMaterial3D
				if mat:
					mat.albedo_color = color
					if mat.emission_enabled:
						mat.emission = color
						mat.emission_energy_multiplier = 6.0
					child.draw_pass_1 = child.draw_pass_1.duplicate()
					child.draw_pass_1.material = mat

func _ready() -> void:
	var active_color = _color if _color != Color.WHITE else default_color
	_apply_color(active_color)

	var max_lifetime: float = 0.85
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			if child.lifetime > max_lifetime:
				max_lifetime = child.lifetime

	get_tree().create_timer(max_lifetime + 0.2).timeout.connect(queue_free)
