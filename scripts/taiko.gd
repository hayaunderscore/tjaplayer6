extends Sprite2D
class_name TaikoDrum

@onready var ka: Array[Sprite2D] = [$KaLeft, $KaRight]
@onready var don: Array[Sprite2D] = [$DonLeft, $DonRight]
var ka_delay: PackedFloat32Array = [0.0, 0.0]
var don_delay: PackedFloat32Array = [0.0, 0.0]
@onready var sound: Array[AudioStreamPlayer] = [$AudioKaLeft, $AudioKaRight, $AudioDonLeft, $AudioDonRight]

@onready var sfield: Array[Sprite2D] = [$SFieldEffects/SfieldRed, $SFieldEffects/SfieldBlue, $SFieldEffects/SfieldHit]
var sfield_delay: PackedFloat32Array = [0.0, 0.0, 0.0]

@onready var combo_text: Label = $Combo/ComboText
@onready var combo_parent: Node2D = $Combo

var combo_fonts: Array[Font] = [
	preload("res://gfx/number/combo_normal.tres"),
	preload("res://gfx/number/combo_medium.tres"),
	preload("res://gfx/number/combo_beeg.tres"),
]

enum TaikoType {DON, KAT}
enum TaikoHit {LEFT, RIGHT}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in ka:
		i.modulate.a = 0
	for i in don:
		i.modulate.a = 0

func taiko_input(type: int, side: int, hit: bool):
	sfield[type].modulate.a = 0.5
	sfield_delay[type] = 0.1+0.016
	sfield[absi(type-1)].modulate.a = 0.0
	sfield_delay[absi(type-1)] = 0.0
	# Also display the yellow sfield effect when hitting
	if hit:
		sfield[2].modulate.a = 0.5
		sfield_delay[2] = 0.0
	match type:
		TaikoType.KAT:
			ka[side].modulate.a = 1.0
			ka_delay[side] = 0.1
			sound[side].play()
		TaikoType.DON:
			don[side].modulate.a = 1.0
			don_delay[side] = 0.1
			sound[2+side].play()

func change_combo(combo: int):
	if combo < 10: return
	combo_parent.visible = true
	combo_text.text = str(combo)
	if combo < 50:
		combo_text.set("theme_override_fonts/font", combo_fonts[0])
	elif combo >= 50 and combo < 100:
		combo_text.set("theme_override_fonts/font", combo_fonts[1])
	else:
		combo_text.set("theme_override_fonts/font", combo_fonts[2])
	combo_text.scale.y = 1.2
	if combo_text.text.length() > 2:
		combo_text.scale.x = (3.0 / (combo_text.text.length()))

func drop_combo():
	combo_parent.visible = false
	combo_text.text = ""
	combo_text.scale = Vector2.ONE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	combo_text.scale.y = max(1, combo_text.scale.y-delta*2)
	for i in range(0, ka.size()):
		ka_delay[i] = max(0, ka_delay[i]-delta)
		if ka_delay[i] <= 0:
			ka[i].modulate.a = move_toward(ka[i].modulate.a, 0, 0.25)
	for i in range(0, don.size()):
		don_delay[i] = max(0, don_delay[i]-delta)
		if don_delay[i] <= 0:
			don[i].modulate.a = move_toward(don[i].modulate.a, 0, 0.25)
	for i in range(0, sfield.size()):
		sfield_delay[i] = max(0, sfield_delay[i]-delta)
		if sfield_delay[i] <= 0:
			sfield[i].modulate.a = move_toward(sfield[i].modulate.a, 0, 0.15)
