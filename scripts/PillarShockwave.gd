extends CanvasLayer
class_name PillarShockwave

@onready var animation_player = $AnimationPlayer
@onready var color_rect = $ColorRect

func _ready() -> void:
	# Hide by default until triggered if necessary, but typically we trigger immediately
	pass

func play_shockwave(screen_pos: Vector2) -> void:
	# Convert screen position to normalized UV coordinates (0.0 to 1.0)
	var viewport_size = get_viewport().get_visible_rect().size
	var uv_pos = screen_pos / viewport_size
	
	if color_rect.material is ShaderMaterial:
		color_rect.material.set_shader_parameter("center", uv_pos)
		
	animation_player.play("shockwave")
