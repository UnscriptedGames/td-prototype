extends Node

## Manages all object pools for reusing nodes like enemies and projectiles.

## Internal State
var _pools: Dictionary = {} # Stores pools as {scene_path: [Array of objects]}


## Creates and pre-populates a pool for a given scene.
func create_pool(scene: PackedScene, initial_size: int) -> void:
	# Don't create the same pool twice
	if _pools.has(scene.resource_path):
		return

	# Create a new array to hold the pooled objects
	_pools[scene.resource_path] = []

	# Create a container node to hold the objects for better organization
	var container := Node.new()
	container.name = "%s_pool" % scene.resource_path.get_file().get_basename()
	add_child(container)
	container.owner = self

	# Instantiate the desired number of objects and add them to the pool
	for i in range(initial_size):
		var obj := scene.instantiate()
		# Deactivate the object until it's needed
		obj.set_process(false)
		obj.visible = false
		# Add the object to our internal array and the container node
		_pools[scene.resource_path].append(obj)
		container.add_child(obj)


## Retrieves an object from the specified pool and resets it.
func get_object(scene: PackedScene) -> Node:
	var scene_path := scene.resource_path
	# Ensure a pool for this scene exists
	if not _pools.has(scene_path):
		push_error("This object pool does not exist: %s" % scene_path)
		return null

	var obj: Node
	# If the pool is empty, create a new object as a fallback
	if _pools[scene_path].is_empty():
		if OS.is_debug_build():
			print("Object pool for '%s' was empty. Instantiating a new one." % scene_path)
		obj = scene.instantiate()
	# If the pool has objects, get one from the front of the array
	else:
		obj = _pools[scene_path].pop_front()
		# Reparent the object from the pool container to the main scene tree
		obj.get_parent().remove_child(obj)

	# If the object has a reset function, call it.
	if obj.has_method("reset"):
		obj.reset()

	return obj


## Returns an object to its corresponding pool.
func return_object(obj: Node) -> void:
	var scene_path := obj.scene_file_path
	if not _pools.has(scene_path):
		push_error("Cannot return object. Pool does not exist for: %s" % scene_path)
		obj.queue_free() # Destroy the object if its pool doesn't exist
		return
	
	# Deactivate the object
	obj.set_process(false)
	obj.visible = false
	
	# Find the correct container node to reparent the object to
	var container_name := "%s_pool" % scene_path.get_file().get_basename()
	var container := find_child(container_name, false) # Use non-recursive search
	if is_instance_valid(container):
		# If the object is not already in the scene tree, it may have been freed
		if obj.get_parent():
			obj.get_parent().remove_child(obj)
		container.add_child(obj)
	else:
		# Fallback if container is not found for some reason
		push_error("Pool container not found: %s" % container_name)

	# Add the object back to the end of the pool array
	_pools[scene_path].append(obj)