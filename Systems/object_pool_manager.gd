extends Node

## Manages all object pools for reusing nodes like enemies and projectiles.

## Internal State
var _pools: Dictionary = {} # Stores pools as {scene_path: { "objects": [Array of objects], "batch_size": int }}
var _node_pools: Dictionary = {} # Stores pools for nodes as {class_name: { "objects": [Array of objects], "batch_size": int }}


## Creates and pre-populates a pool for a given scene.
func create_pool(scene: PackedScene, initial_size: int, batch_size: int = 5) -> void:
	# Don't create the same pool twice
	if _pools.has(scene.resource_path):
		return
	
	var scene_name := scene.resource_path.get_file().get_basename()
	print("POOL MANAGER: Creating scene pool for '%s' with %d objects (batch size: %d)..." % [scene_name, initial_size, batch_size])

	# Create a new dictionary to hold the pool data
	_pools[scene.resource_path] = {
		"objects": [],
		"batch_size": batch_size,
		"scene": scene
	}

	# Create a container node to hold the objects for better organisation
	var container := Node.new()
	container.name = "%s_pool" % scene_name
	add_child(container)
	container.owner = self

	# Instantiate the desired number of objects and add them to the pool
	for i in range(initial_size):
		var obj := scene.instantiate()
		obj.set_process(false)
		obj.set_physics_process(false)
		obj.visible = false
		_pools[scene.resource_path]["objects"].append(obj)
		container.add_child(obj)
	
	print("POOL MANAGER: Pool for '%s' created." % scene_name)


## Creates and pre-populates a pool for a given node type.
func create_node_pool(p_class_name, initial_size, batch_size = 10):
	if _node_pools.has(p_class_name):
		return

	print("POOL MANAGER: Creating node pool for '%s' with %d objects (batch size: %d)..." % [p_class_name, initial_size, batch_size])

	_node_pools[p_class_name] = {
		"objects": [],
		"batch_size": batch_size
	}

	var container := Node.new()
	container.name = "%s_pool" % p_class_name
	add_child(container)
	container.owner = self

	for i in range(initial_size):
		var obj := ClassDB.instantiate(p_class_name) as Node
		if not obj:
			push_error("Failed to instantiate node of type '%s'" % p_class_name)
			return
		obj.set_meta("pool_class_name", p_class_name)
		_node_pools[p_class_name]["objects"].append(obj)
		container.add_child(obj)

	print("POOL MANAGER: Node pool for '%s' created." % p_class_name)


## Retrieves an object from the specified scene pool and resets it.
func get_object(scene: PackedScene) -> Node:
	var scene_path := scene.resource_path
	if not _pools.has(scene_path):
		push_error("This object pool does not exist: %s" % scene_path)
		return null

	var pool = _pools[scene_path]
	if pool["objects"].is_empty():
		_grow_pool(scene_path)

	var obj: Node = pool["objects"].pop_front()
	if is_instance_valid(obj.get_parent()):
		obj.get_parent().remove_child(obj)

	return obj


## Retrieves a node from the specified node pool.
func get_pooled_node(p_class_name):
	if not _node_pools.has(p_class_name):
		push_error("This node pool does not exist: %s" % p_class_name)
		return null

	var pool = _node_pools[p_class_name]
	if pool["objects"].is_empty():
		_grow_node_pool(p_class_name)

	var obj: Node = pool["objects"].pop_front()
	if is_instance_valid(obj.get_parent()):
		obj.get_parent().remove_child(obj)

	return obj


## Returns an object to its corresponding scene pool.
func return_object(obj: Node) -> void:
	var scene_path := obj.scene_file_path
	if not _pools.has(scene_path):
		push_error("Cannot return object. Pool does not exist for: %s" % scene_path)
		obj.queue_free()
		return
	
	obj.set_process(false)
	obj.set_physics_process(false)
	obj.visible = false
	
	var container_name := "%s_pool" % scene_path.get_file().get_basename()
	var container := find_child(container_name, false)
	if is_instance_valid(container):
		if obj.get_parent():
			obj.get_parent().remove_child(obj)
		container.add_child(obj)
	else:
		push_error("Pool container not found: %s" % container_name)

	_pools[scene_path]["objects"].append(obj)


## Returns a node to its corresponding node pool.
func return_node(obj):
	if not obj.has_meta("pool_class_name"):
		push_error("Cannot return node. It was not created by the pool manager.")
		obj.queue_free()
		return

	var p_class_name = obj.get_meta("pool_class_name")
	if not _node_pools.has(p_class_name):
		push_error("Cannot return node. Pool does not exist for: %s" % p_class_name)
		obj.queue_free()
		return

	var container_name := "%s_pool" % p_class_name
	var container := find_child(container_name, false)
	if is_instance_valid(container):
		if obj.get_parent():
			obj.get_parent().remove_child(obj)
		container.add_child(obj)
	else:
		push_error("Pool container not found: %s" % container_name)

	_node_pools[p_class_name]["objects"].append(obj)


func _grow_pool(scene_path: String) -> void:
	var pool = _pools[scene_path]
	var scene = pool.scene
	if OS.is_debug_build():
		print("Object pool for '%s' was empty. Instantiating a new batch of %d." % [scene_path, pool.batch_size])

	var container_name := "%s_pool" % scene_path.get_file().get_basename()
	var container = find_child(container_name, false)
	if not is_instance_valid(container):
		push_error("Pool container not found: %s" % container_name)
		container = Node.new()
		container.name = container_name
		add_child(container)
		container.owner = self

	for i in range(pool.batch_size):
		var new_obj := scene.instantiate()
		new_obj.set_process(false)
		new_obj.set_physics_process(false)
		new_obj.visible = false
		pool["objects"].append(new_obj)
		container.add_child(new_obj)


func _grow_node_pool(p_class_name):
	var pool = _node_pools[p_class_name]
	if OS.is_debug_build():
		print("Node pool for '%s' was empty. Instantiating a new batch of %d." % [p_class_name, pool.batch_size])

	var container_name := "%s_pool" % p_class_name
	var container = find_child(container_name, false)
	if not is_instance_valid(container):
		push_error("Pool container not found: %s" % container_name)
		container = Node.new()
		container.name = container_name
		add_child(container)
		container.owner = self

	for i in range(pool.batch_size):
		var new_obj := ClassDB.instantiate(p_class_name) as Node
		if not new_obj:
			push_error("Failed to instantiate node of type '%s'" % p_class_name)
			return
		new_obj.set_meta("pool_class_name", p_class_name)
		pool["objects"].append(new_obj)
		container.add_child(new_obj)
