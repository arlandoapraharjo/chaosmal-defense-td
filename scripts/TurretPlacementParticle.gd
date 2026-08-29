class_name TurretPlacementParticle
extends Node3D

## TurretPlacementParticle
## Spawns tiny stylized low-poly dirt/pebble chunks, subtle micro-dust,
## and a vibrant burst of bright glowing sparks when a turret is placed down on the map.

@onready var pebbles: GPUParticles3D = get_node_or_null("Pebbles")
@onready var dust: GPUParticles3D = get_node_or_null("ImpactDust")
@onready var sparks: GPUParticles3D = get_node_or_null("Sparks")

func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.restart()
			child.emitting = true
			
	var timer = get_tree().create_timer(0.55)
	timer.timeout.connect(queue_free)

## Adjust particle scale for 2x2 or larger turret footprints
func setup_footprint(footprint: Vector2i) -> void:
	if footprint.x > 1 or footprint.y > 1:
		scale = Vector3(1.3, 1.1, 1.3)
