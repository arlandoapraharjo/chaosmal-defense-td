extends Node3D

func _ready() -> void:
	var max_lifetime: float = 0.8
	var has_particles: bool = false
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			has_particles = true
			if child.lifetime > max_lifetime:
				max_lifetime = child.lifetime
	
	if has_particles:
		get_tree().create_timer(max_lifetime + 0.15).timeout.connect(queue_free)
	else:
		get_tree().create_timer(1.0).timeout.connect(queue_free)
