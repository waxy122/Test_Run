extends Node

signal inventory_changed

var items := {
	"kunai": 10,
	"shuriken": 5,
	"coins": 0,
	"silver_key": 0,
	"gold_key": 0,
	"letter": 0,
	"beef": 0, 
	"honey": 0,
	"noodle": 0
}

func has(item: String) -> bool:
	return items.get(item, 0) > 0

func get_count(item: String) -> int:
	return items.get(item, 0)

func add(item: String, amount: int = 1):
	if not items.has(item):
		items[item] = 0
	items[item] += amount
	inventory_changed.emit()

func remove(item: String, amount: int = 1) -> bool:
	if not items.has(item) or items[item] < amount:
		return false
	items[item] -= amount
	inventory_changed.emit()
	return true
