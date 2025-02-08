extends Node3D



@onready var items_holder = $Items
@onready var chest = $Open/ChestObject
@onready var open_store = $Open

func _enter_tree():
	set_multiplayer_authority(1)

func _ready():
	open_store.add_to_group("interactable")
	open_store.collision_layer = 9
	hide_all_items()
	$OpenTimer.timeout.connect(show_all_items)
	$AutoCloseTimer.timeout.connect(activate)
	
	for item in items_holder.get_children():
		item.add_to_group("interactable")
		item.collision_layer = 9

func activate(_activated_player: CharacterBody3D = null, _activated_item = null):
	if not $PreventTimer.is_stopped(): 
		return
	$PreventTimer.start()
	if chest && chest.has_method("activate"):
		chest.activate(_activated_player)
			
	if chest.opened == false:
		$AutoCloseTimer.stop()
		$OpenTimer.stop()
		hide_all_items()
	else:
		$AutoCloseTimer.stop()
		$OpenTimer.start(0.9)

func hide_all_items():
	items_holder.visible = false
	for item in items_holder.get_children():
		var col:CollisionShape3D = item.get_node("CollisionShape3D")
		col.disabled = true
	

func show_all_items():
	items_holder.visible = true
	for item in items_holder.get_children():
		var col:CollisionShape3D = item.get_node("CollisionShape3D")
		col.disabled = false
	$AutoCloseTimer.start(20.0)
	

func buy_item(player, item_area_name):
	if not $PreventTimer.is_stopped(): 
		return
	$PreventTimer.start()
	var item_name = item_area_name.split("(")[0].strip_edges()
	# please don't look at me like that. this is game dev.
	var item_cost = int(item_area_name.split("(")[1].split(")")[0].split('g')[0])
	match item_name:
		'Potion':
			player.add_new_potion(item_cost)
			pass
		'Bow':
			player.replace_empty_on_system.rpc('WeaponSystem', "bow_scene", item_cost)
			pass
		'Shield':
			player.replace_empty_on_system.rpc('GadgetSystem', "shield_scene", item_cost)
			pass
		'Axe':
			player.replace_empty_on_system.rpc('WeaponSystem', "axe_scene", item_cost)
			pass
