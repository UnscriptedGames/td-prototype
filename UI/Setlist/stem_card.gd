extends PanelContainer

## A reusable UI card representing a single stem on the Setlist screen.
##
## Displays the stem's label, instrument type, current status (Locked/Available/
## Completed), and quality grade badge. Emits a signal when clicked while
## available.

# --- Signals ---

## Emitted when the player clicks this card while it is available.
signal stem_selected(stem_index: int)


# --- Constants ---

## Colour map for quality badges.
const COLOUR_GOOD: Color = Color("4caf50")
const COLOUR_AVERAGE: Color = Color("ffeb3b")
const COLOUR_ABOMINATION: Color = Color("f44336")
const COLOUR_LOCKED: Color = Color("555555")
const COLOUR_AVAILABLE: Color = Color("1de9b6")
const COLOUR_COMPLETED: Color = Color("8e8e8e")


# --- State ---

## The stem index this card represents (set by the Setlist screen).
var _stem_index: int = -1

## Cached current status for click gating.
var _current_status: StemResult.StemStatus = StemResult.StemStatus.LOCKED


# --- Node References ---

@onready var label_stem_name: Label = $VBoxContainer/StemNameLabel
@onready var label_instrument: Label = $VBoxContainer/InstrumentLabel
@onready var label_status: Label = $VBoxContainer/StatusLabel
@onready var label_quality: Label = $VBoxContainer/QualityLabel
@onready var label_preview: Label = $VBoxContainer/PreviewLabel
@onready var quality_select: OptionButton = $VBoxContainer/QualitySelect


# --- Lifecycle ---

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	quality_select.item_selected.connect(_on_quality_item_selected)
	mouse_default_cursor_shape = Control.CURSOR_ARROW


# --- Public Methods ---

## Configures this card with static stem data and its index.
func setup(stem_index: int, stem_data: StemData) -> void:
	_stem_index = stem_index
	if stem_data:
		label_stem_name.text = stem_data.stem_label
		label_instrument.text = ""
		label_preview.text = stem_data.enemy_preview_hint
	else:
		label_stem_name.text = "???"
		label_instrument.text = ""
		label_preview.text = ""


## Updates the card's visual state based on the current StemResult.
func update_state(result: StemResult) -> void:
	_current_status = result.status

	match result.status:
		StemResult.StemStatus.LOCKED:
			label_status.text = "LOCKED"
			label_quality.text = ""
			_set_card_colour(COLOUR_LOCKED)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		StemResult.StemStatus.AVAILABLE:
			label_status.text = "AVAILABLE"
			label_quality.text = ""
			quality_select.visible = false
			_set_card_colour(COLOUR_AVAILABLE)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		StemResult.StemStatus.COMPLETED:
			label_status.text = "COMPLETED"
			label_quality.text = _quality_text(result.quality)
			label_quality.add_theme_color_override(
				"font_color", _quality_colour(result.quality)
			)
			_populate_quality_dropdown(result)
			quality_select.visible = true
			_set_card_colour(COLOUR_COMPLETED)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# --- Private Methods ---

## Handles click input on the card.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		# Ensure we are not clicking the OptionButton itself, which handles its own consumption
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _current_status != StemResult.StemStatus.LOCKED:
				stem_selected.emit(_stem_index)
				
				
## Populates the manual playback override dropdown based on best achieved score.
func _populate_quality_dropdown(result: StemResult) -> void:
	# Temporarily disconnect so we don't fire signals while building
	if quality_select.item_selected.is_connected(_on_quality_item_selected):
		quality_select.item_selected.disconnect(_on_quality_item_selected)
		
	quality_select.clear()
	
	# Only allow them to select qualities up to their highest achieved grade.
	# Enums are: GOOD=1, AVERAGE=2, ABOMINATION=3
	var best_q: int = result.quality
	
	if best_q <= StemResult.StemQuality.GOOD and best_q != StemResult.StemQuality.NONE:
		quality_select.add_item("★ Good Mix", StemResult.StemQuality.GOOD)
		quality_select.set_item_metadata(quality_select.item_count - 1, StemResult.StemQuality.GOOD)
		
	if best_q <= StemResult.StemQuality.AVERAGE and best_q != StemResult.StemQuality.NONE:
		quality_select.add_item("◆ Average Mix", StemResult.StemQuality.AVERAGE)
		quality_select.set_item_metadata(quality_select.item_count - 1, StemResult.StemQuality.AVERAGE)
		
	if best_q <= StemResult.StemQuality.ABOMINATION and best_q != StemResult.StemQuality.NONE:
		quality_select.add_item("✖ Abomination Mix", StemResult.StemQuality.ABOMINATION)
		quality_select.set_item_metadata(quality_select.item_count - 1, StemResult.StemQuality.ABOMINATION)
		
	# Reselect their currently active choice
	for i in range(quality_select.item_count):
		if quality_select.get_item_metadata(i) == result.active_playback_quality:
			quality_select.select(i)
			break
			
	# Reconnect
	quality_select.item_selected.connect(_on_quality_item_selected)


## Saves their new playback preference into the global StageManager results array.
func _on_quality_item_selected(index: int) -> void:
	var specific_quality: StemResult.StemQuality = quality_select.get_item_metadata(index)
	# Update the backing data in StageManager so it persists and AudioManager sees it
	var result: StemResult = StageManager.stem_results[_stem_index]
	if result:
		result.active_playback_quality = specific_quality


## Applies a tint colour to the card's panel stylebox.
func _set_card_colour(colour: Color) -> void:
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if stylebox:
		stylebox.bg_color = colour
		add_theme_stylebox_override("panel", stylebox)


## Returns display text for a quality grade.
func _quality_text(quality: StemResult.StemQuality) -> String:
	match quality:
		StemResult.StemQuality.GOOD:
			return "★ GOOD"
		StemResult.StemQuality.AVERAGE:
			return "◆ AVERAGE"
		StemResult.StemQuality.ABOMINATION:
			return "✖ ABOMINATION"
		_:
			return ""


## Returns the colour for a quality grade badge.
func _quality_colour(quality: StemResult.StemQuality) -> Color:
	match quality:
		StemResult.StemQuality.GOOD:
			return COLOUR_GOOD
		StemResult.StemQuality.AVERAGE:
			return COLOUR_AVERAGE
		StemResult.StemQuality.ABOMINATION:
			return COLOUR_ABOMINATION
		_:
			return Color.WHITE
