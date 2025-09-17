@tool
class_name ObjectPoolMonitor
extends Node

## Displays a real-time monitor of all object pools in the game.
## The tool is active in-game when the 'enabled' property is checked.

@export var enabled: bool = false:
	set(value):
		enabled = value
		if not is_inside_tree():
			await ready
		_update_monitor_visibility()

## Dependencies
var _pool_manager = null

## UI Nodes
var _monitor_panel: PanelContainer = null
var _label_container: VBoxContainer = null


func _ready():
	# Wait a frame to ensure the parent is ready and singletons are available.
	await get_tree().create_timer(0.01).timeout
	if get_tree().get_root().has_node("ObjectPoolManager"):
		_pool_manager = get_tree().get_root().get_node("ObjectPoolManager")
	else:
		if enabled and not Engine.is_editor_hint():
			push_warning("ObjectPoolManager singleton not found. The monitor will not work.")

	_update_monitor_visibility()


func _process(_delta):
	if enabled and _monitor_panel and is_instance_valid(_monitor_panel):
		_update_display()


func _update_monitor_visibility():
	if Engine.is_editor_hint() and not get_tree().get_root().has_node("EditorRoot"):
		return

	if enabled:
		if not _monitor_panel or not is_instance_valid(_monitor_panel):
			_create_monitor_panel()
	else:
		if _monitor_panel and is_instance_valid(_monitor_panel):
			_destroy_monitor_panel()


func _create_monitor_panel():
	if _monitor_panel and is_instance_valid(_monitor_panel):
		_monitor_panel.queue_free()

	_monitor_panel = PanelContainer.new()
	_monitor_panel.name = "ObjectPoolMonitor"
	_monitor_panel.custom_minimum_size = Vector2(450, 100)

	# Center the panel horizontally with a fixed y position.
	var screen_size = get_viewport().get_visible_rect().size
	_monitor_panel.position.x = (screen_size.x - _monitor_panel.custom_minimum_size.x) / 2.0
	_monitor_panel.position.y = 25

	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 25)
	margin_container.add_theme_constant_override("margin_top", 25)
	margin_container.add_theme_constant_override("margin_right", 25)
	margin_container.add_theme_constant_override("margin_bottom", 25)
	_monitor_panel.add_child(margin_container)

	_label_container = VBoxContainer.new()
	_label_container.name = "LabelContainer"
	margin_container.add_child(_label_container)

	var title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "--- Object Pool Monitor ---"
	_label_container.add_child(title_label)

	get_parent().add_child.call_deferred(_monitor_panel)


func _destroy_monitor_panel():
	if _monitor_panel and is_instance_valid(_monitor_panel):
		_monitor_panel.queue_free()
		_monitor_panel = null
		_label_container = null


func _update_display():
	if not _pool_manager or not _label_container:
		return

	var pool_data = _pool_manager.get_all_pool_stats()

	var pool_names_from_manager = pool_data.keys()

	var existing_labels = {}
	for child in _label_container.get_children():
		if child.has_meta("pool_name"):
			existing_labels[child.get_meta("pool_name")] = child

	for pool_name in pool_names_from_manager:
		var stats = pool_data[pool_name]
		var usage_percent = int(float(stats.in_use) / stats.total_size * 100) if stats.total_size > 0 else 0
		var text = "%s | Total: %d | Use: %d (%d%%) | Peak: %d | Growth: %d | Batch: %d" % [
				pool_name.get_file().get_basename() if "res://" in pool_name else pool_name,
				stats.total_size,
				stats.in_use,
				usage_percent,
				stats.peak_usage,
				stats.growth_count,
				stats.batch_size
		]

		if existing_labels.has(pool_name):
			var label = existing_labels[pool_name]
			label.text = text
			existing_labels.erase(pool_name)
		else:
			var new_label = Label.new()
			new_label.name = pool_name.get_file().get_basename() if "res://" in pool_name else pool_name
			new_label.set_meta("pool_name", pool_name)
			new_label.text = text
			_label_container.add_child(new_label)

	for pool_name in existing_labels:
		existing_labels[pool_name].queue_free()
