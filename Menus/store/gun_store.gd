extends CanvasLayer

var gun_data_format = "Name : %s\nGun Type : %s\nDamage : %d\nClip Size : %d"

class WeaponType:
	var wpn_type = ""
	var weapons = Array()
	var current_wpn = null
	var cur_wpn_id = 0
	
	func _init(t):
		wpn_type = t

var weapon_types = Array()
var current_type = null

func _ready():
	initWeaponTypes()
	loadWeapons()
	initialTween()
	

func initWeaponTypes():
	var pistols = WeaponType.new("pistol")
	var smg = WeaponType.new("smg")
	var rifle = WeaponType.new("rifle")
	var nades = WeaponType.new("explosive")
	var armour = WeaponType.new("armour")
	
	weapon_types.append(pistols)
	weapon_types.append(smg)
	weapon_types.append(rifle)
	weapon_types.append(nades)
	weapon_types.append(armour)

func loadWeapons():
	var path = "res://Objects/Weapons"
	var dir = Directory.new()
	dir.change_dir(path)
	dir.list_dir_begin()
	
	var d = dir.get_next()
	while d != "":
		if d.get_extension() == "tscn":
			var script = load(path + "/" + d).instance()
			for i in weapon_types:
				var gun_t = script.get("gun_type")
				if not gun_t:
					break
				if i.wpn_type == gun_t:
					print(gun_t)
					i.weapons.append(script)
					break
		d = dir.get_next()
	setCurrentWeaponType("pistol")


func setCurrentWeaponType(type):
	if not current_type or current_type.wpn_type != type:
		for i in weapon_types:
			if i.wpn_type == type:
				current_type = i
				break
	$icon/TextureRect.texture = null
	if current_type:
		if not current_type.weapons.empty():
			print(current_type.wpn_type)
			current_type.current_wpn = current_type.weapons[0]
			$icon/TextureRect.texture = current_type.current_wpn.gun_portrait
			setGunInfo()
		


func setGunInfo():
	var w = current_type.current_wpn
	$gun_desc/Label.text = gun_data_format % [w.gun_name,w.gun_type,w.damage,w.rounds_in_clip]

func _on_pistol_pressed():
	setCurrentWeaponType("pistol")


func _on_smg_pressed():
	setCurrentWeaponType("smg")


func _on_rifle_pressed():
	setCurrentWeaponType("rifle")


func _on_nades_pressed():
	setCurrentWeaponType("nades")


func _on_armour_pressed():
	setCurrentWeaponType("armour")


func _on_next_wpn_pressed():
	if current_type.weapons.size() > 1:
		current_type.cur_wpn_id += 1
		if current_type.cur_wpn_id >= current_type.weapons.size():
			current_type.cur_wpn_id = 0
		current_type.current_wpn = current_type.weapons[current_type.cur_wpn_id] 
		$icon/TextureRect.texture = current_type.current_wpn.gun_portrait


func _on_prev_wpn_pressed():
	if current_type.weapons.size() > 1:
		current_type.cur_wpn_id -= 1
		if current_type.cur_wpn_id < 0:
			current_type.cur_wpn_id = current_type.weapons.size() - 1
		current_type.current_wpn = current_type.weapons[current_type.cur_wpn_id] 
		$icon/TextureRect.texture = current_type.current_wpn.gun_portrait

####################Tweening##########################

func initialTween():
	var duration = 0.5
	#tween gun desc
	var node = $gun_desc
	var old_rectpos = node.rect_position
	node.rect_position += Vector2(400,0) 
	$Tween.interpolate_property(node,"rect_position",node.rect_position,
		old_rectpos,duration,Tween.TRANS_QUAD,Tween.EASE_OUT)
	#tween icon
	node = $icon
	old_rectpos = node.rect_position
	node.rect_position -= Vector2(0,400) 
	$Tween.interpolate_property(node,"rect_position",node.rect_position,
		old_rectpos,duration,Tween.TRANS_QUAD,Tween.EASE_OUT)
	#tween wepon types
	node = $weapon_types
	old_rectpos = node.rect_position
	node.rect_position -= Vector2(400,0) 
	$Tween.interpolate_property(node,"rect_position",node.rect_position,
		old_rectpos,duration,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.start()


