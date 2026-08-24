extends Node
class_name TurretUpgradeManager

static var instance: TurretUpgradeManager = null

# Upgrade costs per level transition (L1->L2, L2->L3)
const UPGRADE_COSTS: Array[int] = [8, 20]

signal turret_upgraded(turret: Node3D, new_level: int)

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func try_upgrade_turret(turret: Node3D) -> bool:
	if not is_instance_valid(turret) or not turret.has_method("get_upgrade_cost") or not turret.has_method("upgrade"):
		return false
	
	if turret.turret_level >= 3:
		return false # Max level reached

	var cost = turret.get_upgrade_cost()
	if CurrencyManager.instance and CurrencyManager.instance.spend_currency(cost):
		var success = turret.upgrade()
		if success:
			turret_upgraded.emit(turret, turret.turret_level)
		return success
	else:
		# Could trigger a UI feedback for insufficient funds here
		var wave_ui = get_tree().get_first_node_in_group("wave_ui")
		if not wave_ui:
			wave_ui = get_node_or_null("/root/World/WaveUI")
		if wave_ui and wave_ui.has_method("show_insufficient_funds"):
			wave_ui.show_insufficient_funds()

		return false
