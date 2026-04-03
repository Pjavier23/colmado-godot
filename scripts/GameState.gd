extends Node
## GameState.gd - Autoload Singleton
## Persists game data across scenes.

var money: int = 0
var vehicle: String = "bicycle"
var score: int = 0
var high_score: int = 0
var lives: int = 3
var current_mission: int = 0
var unlocked_vehicles: Array = ["bicycle"]
var owned_weapons: Dictionary = {
	"platano": true,
	"huevo": false,
	"salami": false,
	"fart": false
}
var weapon_ammo: Dictionary = {
	"platano": 5,
	"huevo": 3,
	"salami": 2,
	"fart": 3
}

const SAVE_PATH = "user://savegame.cfg"

func _ready() -> void:
	load_game()

func add_money(amount: int) -> void:
	money += amount

func add_score(amount: int) -> void:
	score += amount
	if score > high_score:
		high_score = score

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		return true
	return false

func unlock_vehicle(v: String) -> void:
	if not v in unlocked_vehicles:
		unlocked_vehicles.append(v)

func unlock_weapon(w: String) -> void:
	owned_weapons[w] = true

func reset_run() -> void:
	score = 0
	lives = 3
	weapon_ammo = {"platano": 5, "huevo": 3, "salami": 2, "fart": 3}

func save() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "money", money)
	config.set_value("game", "vehicle", vehicle)
	config.set_value("game", "high_score", high_score)
	config.set_value("game", "unlocked_vehicles", unlocked_vehicles)
	config.set_value("game", "owned_weapons", owned_weapons)
	config.save(SAVE_PATH)

func load_game() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		money = config.get_value("game", "money", 0)
		vehicle = config.get_value("game", "vehicle", "bicycle")
		high_score = config.get_value("game", "high_score", 0)
		unlocked_vehicles = config.get_value("game", "unlocked_vehicles", ["bicycle"])
		owned_weapons = config.get_value("game", "owned_weapons", owned_weapons)
