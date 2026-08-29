class_name TurretDismantleParticle
extends Node3D

## TurretDismantleParticle
## Spawns a burst of debris chunks, a puff of dust/smoke, and tiny sparks
## when a turret is dismantled/sold by the player.

func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()
			child.emitting = true
			
	var timer = get_tree().create_timer(0.65)
	timer.timeout.connect(queue_free)
