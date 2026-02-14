class_name SidebarButton
extends Button

var data: Resource
var type: String = "tower" # "tower" or "buff" (though buff is specific)

func setup_tower(tower_data: Resource) -> void:
    data = tower_data
    type = "tower"
    # icon = tower_data.icon # Assuming icon exists
    # If no icon, use placeholder text?
    text = "" # Clear text if icon used
    expand_icon = true
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

func setup_buff(buff_data: Resource) -> void:
    data = buff_data
    type = "buff"
    

func _get_drag_data(_at_position: Vector2) -> Variant:
    if not data: return null
    
    # Create Preview
    var preview = TextureRect.new()
    # preview.texture = icon
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.size = Vector2(64, 64)
    preview.modulate = Color(1, 1, 1, 0.8)
    
    set_drag_preview(preview)
    
    # Drag Data
    var drag_id = Time.get_ticks_msec() + get_instance_id()
    
    return {
        "type": "card_drag", # Keeping legacy type for compatibility
        "subtype": type,
        "data": data,
        "drag_id": drag_id,
        "source": self,
        "preview": preview # To toggle visibility
    }
