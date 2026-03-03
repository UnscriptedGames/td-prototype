@tool
class_name CatalogItem
extends Button

signal item_clicked(item_data: Resource)

var data: Resource
var type: String = "tower"  # "tower", "buff", "relic"

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel


func _ready() -> void:
	pressed.connect(func(): item_clicked.emit(data))


func setup(item_data: Resource, item_type: String) -> void:
	data = item_data
	type = item_type

	if type == "tower":
		var td = item_data as TowerData
		if td:
			name_label.text = td.display_name
			cost_label.text = "AP: " + str(td.allocation_cost)
			if td.icon:
				icon_rect.texture = td.icon
	elif type == "buff":
		var bd = item_data as BuffData
		if bd:
			name_label.text = bd.display_name
			cost_label.text = "AP: " + str(bd.allocation_cost)
			if bd.icon:
				icon_rect.texture = bd.icon
	elif type == "relic":
		var rd = item_data as RelicData
		if rd:
			name_label.text = rd.display_name
			cost_label.text = "AP: " + str(rd.allocation_cost)
			if rd.icon:
				icon_rect.texture = rd.icon


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not data:
		return null

	var drag_texture: Texture2D = null
	if icon_rect and icon_rect.texture:
		drag_texture = icon_rect.texture

	var preview = TextureRect.new()
	if drag_texture:
		preview.texture = drag_texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(80, 80)
		preview.size = Vector2(80, 80)
		preview.modulate = Color(1, 1, 1, 0.75)

	var offset_root = Control.new()
	offset_root.z_index = 100
	offset_root.add_child(preview)
	preview.position = -_at_position

	set_drag_preview(offset_root)
	return {"type": "catalog_drag", "subtype": type, "data": data, "source": self}
