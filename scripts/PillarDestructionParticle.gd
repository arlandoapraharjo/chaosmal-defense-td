extends Node3D
class_name PillarDestructionParticle

@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	var max_lifetime: float = 2.0
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			if child.lifetime > max_lifetime:
				max_lifetime = child.lifetime
				
	if light:
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	get_tree().create_timer(max_lifetime + 0.2).timeout.connect(queue_free)
