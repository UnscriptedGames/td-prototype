extends Node

## Manages all object pools for reusing nodes like enemies and projectiles.
##
## Optimization system that prevents expensive instancing/freeing during gameplay.
## Maintains separate pools for Scenes (packed scenes) and Nodes (class names).

## Internal State
# Stores pools as {scene_path: { "objects": [Array], "batch_size": int, ... }}
var _pools: Dictionary[String, Dictionary] = {}
# Stores pools for nodes as {class_name: { "objects": [Array], "batch_size": int, ... }}
var _node_pools: Dictionary[String, Dictionary] = {}


## Creates and pre-populates a pool for a given scene.
func create_pool(scene: PackedScene, initial_size: int, batch_size: int = 5) -> void:
	if _pools.has(scene.resource_path):
		return
	
	var scene_name: String = scene.resource_path.get_file().get_basename()
	print("POOL MANAGER: Creating scene pool for '%s' with %d objects (batch size: %d)..." % [scene_name, initial_size, batch_size])

	_pools[scene.resource_path] = {
		"objects": [],
		"batch_size": batch_size,
		"scene": scene,
		"total_size": initial_size,
		"in_use": 0,
		"peak_usage": 0,
		"growth_count": 0,
	}

	var container := Node.new()
	container.name = "%s_pool" % scene_name
	add_child(container)
	container.owner = self

	for index in range(initial_size):
		var object: Node = scene.instantiate()
		object.set_process(false)
		object.set_physics_process(false)
		object.visible = false
		_pools[scene.resource_path]["objects"].append(object)
		container.add_child(object)
	
	print("POOL MANAGER: Pool for '%s' created." % scene_name)


## Creates and pre-populates a pool for a given node type name.
func create_node_pool(p_class_name: String, initial_size: int, batch_size: int = 10) -> void:
	if _node_pools.has(p_class_name):
		return

	print("POOL MANAGER: Creating node pool for '%s' with %d objects (batch size: %d)..." % [p_class_name, initial_size, batch_size])

	_node_pools[p_class_name] = {
		"objects": [],
		"batch_size": batch_size,
		"total_size": initial_size,
		"in_use": 0,
		"peak_usage": 0,
		"growth_count": 0,
	}

	var container := Node.new()
	container.name = "%s_pool" % p_class_name
	add_child(container)
	container.owner = self

	for index in range(initial_size):
		var object := ClassDB.instantiate(p_class_name) as Node
		if not object:
			push_error("Failed to instantiate node of type '%s'" % p_class_name)
			return
		object.set_meta("pool_class_name", p_class_name)
		_node_pools[p_class_name]["objects"].append(object)
		container.add_child(object)

	print("POOL MANAGER: Node pool for '%s' created." % p_class_name)


## Retrieves an object from the specified scene pool and resets it.
func get_object(scene: PackedScene) -> Node:
	var scene_path: String = scene.resource_path
	if not _pools.has(scene_path):
		push_error("This object pool does not exist: %s" % scene_path)
		return null

	var pool: Dictionary = _pools[scene_path]
	if pool["objects"].is_empty():
		_grow_pool(scene_path)

	var object: Node = pool["objects"].pop_front()
	if is_instance_valid(object.get_parent()):
		object.get_parent().remove_child(object)

	pool.in_use += 1
	pool.peak_usage = max(pool.peak_usage, pool.in_use)

	if object.has_method("reset"):
		object.reset()

	return object


## Retrieves a node from the specified node pool.
func get_pooled_node(p_class_name: String) -> Node:
	if not _node_pools.has(p_class_name):
		push_error("This node pool does not exist: %s" % p_class_name)
		return null

	var pool: Dictionary = _node_pools[p_class_name]
	if pool["objects"].is_empty():
		_grow_node_pool(p_class_name)

	var object: Node = pool["objects"].pop_front()
	if is_instance_valid(object.get_parent()):
		object.get_parent().remove_child(object)

	pool.in_use += 1
	pool.peak_usage = max(pool.peak_usage, pool.in_use)

	if object.has_method("reset"):
		object.reset()

	return object


## Returns an object to its corresponding scene pool.
func return_object(object: Node) -> void:
	var scene_path: String = object.scene_file_path
	if not _pools.has(scene_path):
		push_error("Cannot return object. Pool does not exist for: %s" % scene_path)
		object.queue_free()
		return
	
	var container_name: String = "%s_pool" % scene_path.get_file().get_basename()
	var container: Node = find_child(container_name, false)

	# Prevent object from being returned twice.
	if is_instance_valid(container) and object.get_parent() == container:
		if OS.is_debug_build():
			push_warning("Attempted to return an object that is already in the pool: %s" % object.name)
		return

	_pools[scene_path].in_use -= 1

	object.set_process(false)
	object.set_physics_process(false)
	object.visible = false
	
	if is_instance_valid(container):
		if object.get_parent():
			object.get_parent().remove_child(object)
		container.add_child(object)
	else:
		push_error("Pool container not found: %s" % container_name)

	_pools[scene_path]["objects"].append(object)


## Returns a node to its corresponding node pool.
func return_node(object: Node) -> void:
	if not object.has_meta("pool_class_name"):
		push_error("Cannot return node. It was not created by the pool manager.")
		object.queue_free()
		return

	var p_class_name: String = object.get_meta("pool_class_name")
	if not _node_pools.has(p_class_name):
		push_error("Cannot return node. Pool does not exist for: %s" % p_class_name)
		object.queue_free()
		return

	var container_name: String = "%s_pool" % p_class_name
	var container: Node = find_child(container_name, false)

	# Prevent node from being returned twice.
	if is_instance_valid(container) and object.get_parent() == container:
		if OS.is_debug_build():
			push_warning("Attempted to return a node that is already in the pool: %s" % object.name)
		return

	_node_pools[p_class_name].in_use -= 1

	if is_instance_valid(container):
		if object.get_parent():
			object.get_parent().remove_child(object)
		container.add_child(object)
	else:
		push_error("Pool container not found: %s" % container_name)

	_node_pools[p_class_name]["objects"].append(object)


func _grow_pool(scene_path: String) -> void:
	var pool: Dictionary = _pools[scene_path]
	var scene: PackedScene = pool.scene

	pool.growth_count += 1
	pool.total_size += pool.batch_size

	if OS.is_debug_build():
		print("Object pool for '%s' was empty. Instantiating a new batch of %d." % [scene_path, pool.batch_size])

	var container_name: String = "%s_pool" % scene_path.get_file().get_basename()
	var container: Node = find_child(container_name, false)
	if not is_instance_valid(container):
		push_error("Pool container not found: %s" % container_name)
		container = Node.new()
		container.name = container_name
		add_child(container)
		container.owner = self

	for index in range(pool.batch_size):
		var new_object: Node = scene.instantiate()
		new_object.set_process(false)
		new_object.set_physics_process(false)
		new_object.visible = false
		pool["objects"].append(new_object)
		container.add_child(new_object)


func _grow_node_pool(p_class_name: String) -> void:
	var pool: Dictionary = _node_pools[p_class_name]

	pool.growth_count += 1
	pool.total_size += pool.batch_size

	if OS.is_debug_build():
		print("Node pool for '%s' was empty. Instantiating a new batch of %d." % [p_class_name, pool.batch_size])

	var container_name: String = "%s_pool" % p_class_name
	var container: Node = find_child(container_name, false)
	if not is_instance_valid(container):
		push_error("Pool container not found: %s" % container_name)
		container = Node.new()
		container.name = container_name
		add_child(container)
		container.owner = self

	for index in range(pool.batch_size):
		var new_object: Node = ClassDB.instantiate(p_class_name) as Node
		if not new_object:
			push_error("Failed to instantiate node of type '%s'" % p_class_name)
			return
		new_object.set_meta("pool_class_name", p_class_name)
		pool["objects"].append(new_object)
		container.add_child(new_object)


## PUBLIC API for monitor tool
func get_all_pool_stats() -> Dictionary:
	var all_stats: Dictionary = {}

	for pool_name in _pools:
		var pool: Dictionary = _pools[pool_name]
		all_stats[pool_name] = {
			"total_size": pool.total_size,
			"batch_size": pool.batch_size,
			"in_use": pool.in_use,
			"peak_usage": pool.peak_usage,
			"growth_count": pool.growth_count,
		}

	for pool_name in _node_pools:
		var pool: Dictionary = _node_pools[pool_name]
		all_stats[pool_name] = {
			"total_size": pool.total_size,
			"batch_size": pool.batch_size,
			"in_use": pool.in_use,
			"peak_usage": pool.peak_usage,
			"growth_count": pool.growth_count,
		}

	return all_stats
