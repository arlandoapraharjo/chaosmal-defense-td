extends Node3D

@onready var particles: GPUParticles3D = $Debris if has_node("Debris") else ($GPUParticles3D if has_node("GPUParticles3D") else null)

func _ready() -> void:
	if particles:
		particles.emitting = true
		get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(queue_free)
	else:
		get_tree().create_timer(0.5).timeout.connect(queue_free)
