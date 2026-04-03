extends Node2D
## Shop.gd - Weapon and power-up shop.

const SHOP_ITEMS = [
	{
		"id": "huevo",
		"name": "Huevo",
		"desc": "Recto y rapido.\nDeja mancha verde.",
		"cost": 100,
		"ammo_refill": 5,
		"color": Color(0.95, 0.95, 0.85)
	},
	{
		"id": "salami",
		"name": "Salami",
		"desc": "Arco explosivo.\n2x damage!",
		"cost": 200,
		"ammo_refill": 3,
		"color": Color(0.8, 0.2, 0.2)
	},
	{
		"id": "fart",
		"name": "Peo",
		"desc": "Nube toxica.\nLentifica enemigos.",
		"cost": 150,
		"ammo_refill": 4,
		"color": Color(0.5, 0.9, 0.3)
	},
	{
		"id": "platano_refill",
		"name": "Platanos x5",
		"desc": "Recarga tus platanos.",
		"cost": 50,
		"ammo_refill": 5,
		"color": Color(1.0, 0.85, 0.1)
	}
]

@onready var money_label: Label = $TopBar/MoneyLabel
@onready var item_list: VBoxContainer = $ItemList
@onready var item_name: Label = $Panel/ItemName
@onready var item_desc: Label = $Panel/ItemDesc
@onready var item_cost: Label = $Panel/ItemCost
@onready var item_status: Label = $Panel/ItemStatus
@onready var buy_button: Button = $ButtonPanel/BuyButton
@onready var item_display: ColorRect = $ItemDisplay

var selected_idx: int = 0

func _ready() -> void:
	_populate_list()
	_update_panel()
	if money_label:
		money_label.text = "$ %d" % GameState.money
	# Connect button signals
	if buy_button and not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)
	var back_btn = get_node_or_null("ButtonPanel/BackButton")
	if back_btn and not back_btn.pressed.is_connected(_on_back_button_pressed):
		back_btn.pressed.connect(_on_back_button_pressed)

func _populate_list() -> void:
	if not item_list:
		return
	for i in SHOP_ITEMS.size():
		var item = SHOP_ITEMS[i]
		var btn = Button.new()
		btn.text = item["name"]
		btn.add_theme_font_size_override("font_size", 16)
		var idx = i
		btn.pressed.connect(func(): _select_item(idx))
		item_list.add_child(btn)

func _select_item(idx: int) -> void:
	selected_idx = idx
	_update_panel()

func _update_panel() -> void:
	if selected_idx >= SHOP_ITEMS.size():
		return
	var item = SHOP_ITEMS[selected_idx]

	if item_name: item_name.text = item["name"]
	if item_desc: item_desc.text = item["desc"]
	if item_cost: item_cost.text = "PRECIO: $%d" % item["cost"]
	if item_display: item_display.color = item["color"]

	var owned = GameState.owned_weapons.get(item["id"], false)
	if item_status:
		if item["id"] == "platano_refill":
			item_status.text = "Ammo: x%d" % GameState.weapon_ammo.get("platano", 0)
			item_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		elif owned:
			item_status.text = "✓ COMPRADO\nAmmo: x%d" % GameState.weapon_ammo.get(item["id"], 0)
			item_status.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			item_status.text = "NO DESBLOQUEADO"
			item_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))

	if buy_button:
		buy_button.disabled = GameState.money < item["cost"]
		if item["id"] == "platano_refill":
			buy_button.text = "RECARGAR"
		elif owned:
			buy_button.text = "RECARGAR AMMO"
		else:
			buy_button.text = "COMPRAR"

func _on_buy_button_pressed() -> void:
	var item = SHOP_ITEMS[selected_idx]
	if GameState.spend_money(item["cost"]):
		if item["id"] == "platano_refill":
			GameState.weapon_ammo["platano"] = GameState.weapon_ammo.get("platano", 0) + item["ammo_refill"]
		else:
			GameState.unlock_weapon(item["id"])
			GameState.weapon_ammo[item["id"]] = GameState.weapon_ammo.get(item["id"], 0) + item["ammo_refill"]
		GameState.save()
		_update_panel()
		if money_label:
			money_label.text = "$ %d" % GameState.money

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MissionSelect.tscn")
