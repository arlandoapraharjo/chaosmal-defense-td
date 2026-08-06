extends Node
class_name CurrencyManager

signal currency_changed(new_amount: int)

@export var current_currency: int = 200

static var instance: CurrencyManager = null

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	currency_changed.emit(current_currency)

func add_currency(amount: int) -> void:
	current_currency += amount
	currency_changed.emit(current_currency)

func spend_currency(amount: int) -> bool:
	if current_currency >= amount:
		current_currency -= amount
		currency_changed.emit(current_currency)
		return true
	return false

func get_currency() -> int:
	return current_currency
