@tool
class_name CatalogItem
extends Button

signal item_clicked(item_data: Resource)

var data: Resource
var type: String = "tower"  # "tower", "buff", "relic"

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel


# --- OVERRIDES ---


func _ready() -> void:
	pressed.connect(func(): item_clicked.emit(data))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not data:
		return null

	var drag_texture: Texture2D = null
	if icon_rect and icon_rect.texture:
		drag_texture = icon_rect.texture

	var preview: TextureRect = TextureRect.new()
	if drag_texture:
		preview.texture = drag_texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(80, 80)
		preview.size = Vector2(80, 80)
		preview.modulate = Color(1.0, 1.0, 1.0, 0.75)

	var offset_root: Control = Control.new()
	offset_root.set_z_index(100)
	offset_root.add_child(preview)
	preview.position = -_at_position

	set_drag_preview(offset_root)
	return {"type": "catalog_drag", "subtype": type, "data": data, "source": self}


# --- METHODS ---


func setup(item_data: Resource, item_type: String) -> void:
	data = item_data
	type = item_type

	if type == "tower":
		var tower_data: TowerData = item_data as TowerData
		if tower_data:
			name_label.text = tower_data.display_name
			cost_label.text = "AP: " + str(tower_data.allocation_cost)
			if tower_data.icon:
				icon_rect.texture = tower_data.icon
	elif type == "buff":
		var buff_data: BuffData = item_data as BuffData
		if buff_data:
			name_label.text = buff_data.display_name
			cost_label.text = "AP: " + str(buff_data.allocation_cost)
			if buff_data.icon:
				icon_rect.texture = buff_data.icon
	elif type == "relic":
		var relic_data: RelicData = item_data as RelicData
		if relic_data:
			name_label.text = relic_data.display_name
			cost_label.text = "AP: " + str(relic_data.allocation_cost)
			if relic_data.icon:
				icon_rect.texture = relic_data.icon
