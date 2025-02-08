extends Node3D

func activate(player, item_name):
	get_parent().buy_item(player, item_name)
