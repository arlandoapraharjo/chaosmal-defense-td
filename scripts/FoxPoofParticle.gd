class_name FoxPoofParticle
extends Node3D

## Cartoon poof smoke & sparkle burst played when Fox enters/exits turrets.

func _ready() -> void:
	var max_lifetime: float = 0.65
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			if child.lifetime > max_lifetime:
				max_lifetime = child.lifetime
	
	get_tree().create_timer(max_lifetime + 0.15).timeout.connect(queue_free)
