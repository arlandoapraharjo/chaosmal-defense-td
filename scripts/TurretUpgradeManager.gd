extends Node
class_name TurretUpgradeManager

static var instance: TurretUpgradeManager = null

const MAX_LEVEL: int = 5
# Multipliers applied to the turret's base cost for transitions (L1->L2, L2->L3, L3->L4, L4->L5)
const COST_MULTIPLIERS: Array[float] = [1.5, 2.5, 4.0, 6.5]
# Minimum upgrade cost floor per level transition
const MIN_UPGRADE_COSTS: Array[int] = [2, 3, 5, 8]
# Refund rate when selling / recycling
const SELL_REFUND_RATE: float = 0.60

signal turret_upgraded(turret: Node3D, new_level: int)
signal turret_sold(turret: Node3D, refund: int)

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

static func calculate_upgrade_cost(base_cost: int, current_level: int) -> int:
	if current_level >= MAX_LEVEL or current_level < 1:
		return 0
	var idx = current_level - 1
	var mult = COST_MULTIPLIERS[idx]
	var min_cost = MIN_UPGRADE_COSTS[idx]
	return maxi(min_cost, int(round(float(base_cost) * mult)))

static func calculate_sell_refund(total_invested: int) -> int:
	return maxi(1, int(floor(float(total_invested) * SELL_REFUND_RATE)))

func try_upgrade_turret(turret: Node3D) -> bool:
	if not is_instance_valid(turret) or not turret.has_method("get_upgrade_cost") or not turret.has_method("upgrade"):
		return false
	
	if turret.turret_level >= MAX_LEVEL:
		return false # Max level reached

	var cost = turret.get_upgrade_cost()
	if CurrencyManager.instance and CurrencyManager.instance.spend_currency(cost):
		var success = turret.upgrade()
		if success:
			turret_upgraded.emit(turret, turret.turret_level)
		return success
	else:
		var wave_ui = get_tree().get_first_node_in_group("wave_ui")
		if not wave_ui:
			wave_ui = get_node_or_null("/root/World/WaveUI")
		if wave_ui and wave_ui.has_method("show_insufficient_funds"):
			wave_ui.show_insufficient_funds()

		return false
