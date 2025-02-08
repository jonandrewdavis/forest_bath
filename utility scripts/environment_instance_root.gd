@tool
extends Node3D

@export var environment_root_tracker: Node3D
@export var heightmap : Texture2D

var environment_ignore = {}

signal environment_tracker_changed

func _ready():
	if !environment_root_tracker:
		var root_marker = Marker3D.new()
		root_marker.name = 'TEMP_ROOT_TRACKER'
		add_child(root_marker)
		environment_root_tracker = root_marker

	environment_tracker_changed.connect(_on_set_new_root)
	
	if not Engine.is_editor_hint():
		Hub.environment_ignore_add.connect(_on_environment_ignore_add)
		Hub.environment_ignore_remove.connect(_on_environment_ignore_remove)

	# This helps the instancer_custom children have a little buffer
	# to set up before creating the meshes.	
	if environment_root_tracker && Engine.is_editor_hint():
		environment_tracker_changed.emit(environment_root_tracker)

# TODO: (optional) Rebake nav mesh for smarter enemies.
# Could just use a flat plane. To do so, use a group & target grass.
#func _rebake_root():
	#bake_navigation_mesh()


func get_aabb_global_endpoints(mesh_instance) -> Array:
	if not is_instance_valid(mesh_instance):
		return []

	var mesh: Mesh = mesh_instance.mesh
	if not mesh:
		return []

	var aabb: AABB = mesh.get_aabb()
	var global_endpoints := []
	for i in range(8):
		var local_endpoint: Vector3 = aabb.get_endpoint(i)
		var global_endpoint: Vector3 = mesh_instance.to_global(local_endpoint)
		global_endpoints.push_back(global_endpoint)
	return global_endpoints


# Once past initialization, this shouldn't need to be here.
# All children scripts now connect to "environment_tracker_changed"
# Nothing is consuming this, so let's just add a debug statement
func _on_set_new_root(node: Node3D):
	print("DEBUG: environment_root_tracker changed: ", node)
	environment_root_tracker = node


# Updating the instancer ignore list
# TODO: It's potentially heavy to go through and have multiple of these.
func _on_environment_ignore_add(node: Node3D, given_name: String):
	# AABB is multipled by the current global position, so it blocks out the right area
	# Make sure it's in tree first so node.global_transform isn't  0.0.0
	environment_ignore[given_name] = node.global_transform * node.get_aabb()
	
	# This may not be necessary, but it assures that on adding it'll remove anything in the area.
	# Can probably turn down update freq with this. 
	# Could cause locks.
	for instance in get_children():
		if instance.has_method("distribute_meshes"):
			instance.distribute_meshes()


func _on_hide():
	for instance in get_children():
		if instance.has_method("distribute_meshes"):
			instance.hide()

func _on_show():
	for instance in get_children():
		if instance.has_method("distribute_meshes"):
			instance.show()

func _on_environment_ignore_remove(given_name: String):
	environment_ignore.erase(given_name)
