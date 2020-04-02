extends "res://Objects/Character.gd"

class_name Player

export var regen_rate : float = 5
var primary_gun = null
var sec_gun = null
var selected_gun : Gun


var kills : int = 0
var deaths : int = 0
var pname : String
var id : int


var timer_time : float = 0
var hud = null

var grenade = preload("res://Objects/Weapons/grenade.tscn")
var wpn_drop = preload("res://Objects/Misc/WpnDrop.tscn").instance()
var grenade_count = 3
var _pause_cntrl : bool = false

var cur_dropped_item_id = 0

signal player_killed(player)


###################################################
#Note: free_timer is overridden to perform respawn
#
###################################################

func _ready():
	$Gun.queue_free()
	$name_tag.text = pname
	setupGun()
	if is_network_master():
		pname = game_states.player_info.name
		$Camera2D.current = true
		var cnt_path = game_states.control_types.get(game_states.game_settings.control_type)
		var controller = load(cnt_path).instance()
		controller.set_name("controller")
		add_child(controller)
		controller.user = self
		connect("char_killed",self,"_on_player_killed")
		hud = load("res://Menus/HUD/Hud.tscn").instance()
		hud.setUser(self)
		add_child(hud)
	if get_tree().is_network_server():
		connect("char_killed",self,"_on_peer_killed")

func _on_player_killed():
	$Camera2D.current = false
	pause_controls(true)
	createDropedItems()


func createDropedItems():
	var d_item_man = get_tree().get_nodes_in_group("Level")[0].dropedItem_manager
	#drop selected gun
	d_item_man.rpc_id(1,"serverMakeItem",wpn_drop.getWpnInfo(selected_gun))
	#drop health pack (10 % chance)
	var rand_num = randi() % 100
	if rand_num <= 10: 
		var item_info = {type = "med",pos = position}
		d_item_man.rpc_id(1,"serverMakeItem",item_info)
	
	#drop kevlar (20 % chance)
	rand_num = randi() % 100
	if rand_num <= 20: 
		var item_info = {type = "kevlar",pos = position}
		d_item_man.rpc_id(1,"serverMakeItem",item_info)


func pickItem(item_id = -1):
	var d_item_man = get_tree().get_nodes_in_group("Level")[0].dropedItem_manager
	if item_id == -1:
		d_item_man.rpc_id(1,"requestPickUp",name,cur_dropped_item_id)
	else:
		d_item_man.rpc_id(1,"requestPickUp",name,item_id)

remotesync func pickUpItem(item):
	if item.type == "wpn":
		var old_gun = selected_gun
		if selected_gun == primary_gun:
			primary_gun = game_states.weaponResource.get(item.wpn).instance()
			primary_gun.rounds_left = item.bul
			primary_gun.clips = item.clps
			selected_gun = primary_gun
		else:
			sec_gun = game_states.weaponResource.get(item.wpn).instance()
			sec_gun.rounds_left = item.bul
			sec_gun.clips = item.clps
			selected_gun = sec_gun
		var d_item_man = get_tree().get_nodes_in_group("Level")[0].dropedItem_manager
		d_item_man.rpc_id(1,"serverMakeItem",wpn_drop.getWpnInfo(old_gun))
		old_gun.queue_free()
		setupGun()
	elif item.type == "med":
		HP = 100
	elif item.type == "kevlar":
		AP = 100


func _on_peer_killed():
	emit_signal("player_killed",self)
	
func load_guns(nam : String , nam2 : String):
	var g = game_states.weaponResource[nam].instance()
	var g2 = game_states.weaponResource[nam2].instance()
	if primary_gun:
		primary_gun.queue_free()
	primary_gun = g
	if sec_gun:
		sec_gun.queue_free()
	sec_gun = g2
	
	if not skin:
		print("Error no skin")
	#selected_gun.position = $Model.get("fist").position



func _process(delta):
	HP = min(100,HP + regen_rate * delta)
	_get_inputs()
	if is_network_master():
		$CanvasModulate.color = Color8(255,2.55 * HP,2.55 * HP)


func _get_inputs():
	if not is_network_master():
		return
	if game_states.is_android or _pause_cntrl:
		return
	if Input.is_action_pressed("ui_fire"):
		selected_gun.fireGun()

	if Input.is_action_pressed("ui_down"):
		movement_vector.y += 1
	if Input.is_action_pressed("ui_up"):
		movement_vector.y -= 1
	if Input.is_action_pressed("ui_left"):
		movement_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		movement_vector.x += 1
	if Input.is_action_pressed("ui_sprint"):
		useSprint()
	if Input.is_action_just_pressed("ui_spl"):
		throwGrenade()
	if Input.is_action_just_pressed("ui_next_item"):
		rpc("switchGun")
	if Input.is_action_just_pressed("ui_inv"):
		pause_controls(true)
		var inv_menu = load("res://Menus/Inventory/inventory_menu.tscn").instance()
		get_tree().root.add_child(inv_menu)
	
	rotation = (get_global_mouse_position()  - global_position).angle() + 1.57

remote func throwGrenade():
	if get_tree().is_network_server():
		var g = grenade.instance()
		var nam = "g" + String(randi()%1000)
		g.set_name(nam)
		get_tree().root.add_child(g)
		var dir = (skin.get_node("body/r_shoulder/arm/joint/hand/fist").global_position - global_position).normalized()
		g.position = position + (Vector2(-1.509,-50.226)).rotated(rotation)
		g.user = self
		g.throwGrenade(dir)
		rpc("_sync_throwGrenade",nam)
	else:
		rpc_id(1,"throwGrenade")

remote func _sync_throwGrenade(nam):
	var g = grenade.instance()
	g.set_name(nam)
	get_tree().root.add_child(g)
	var dir = (skin.get("fist").global_position - global_position).normalized()
	g.position = position + (Vector2(-1.509,-50.226)).rotated(rotation)
	g.user = self
	g.throwGrenade(dir)


remotesync func sync_respawn(pos,id):
	var was_alive = alive
	show()
	$dtween.stop(skin)
	$dtween.interpolate_property(skin,"modulate",Color8(50,50,200,255),Color8(255,255,255,255),4,Tween.TRANS_LINEAR,Tween.EASE_IN)
	$dtween.start()
	alive = true
	skin.set_deferred("disabled",false)
	HP = 100
	AP = 100
	pause_controls(false)
	$movmtCPP._teleportCharacter(pos)
	load_guns(network.players[id].primary_gun_name,network.players[id].sec_gun_name)
	switchGun()
	skin.revive()
	if is_network_master():
		$Camera2D.current = true
	if not was_alive:
		emit_signal("char_born")

func switchToPrimaryGun():
	if selected_gun != primary_gun:
		rpc("switchGun")

func switchToSecGun():
	if selected_gun != sec_gun:
		rpc("switchGun")

remotesync func switchGun():
	if selected_gun == primary_gun:
		if sec_gun != null:
			skin.get_node("body/r_shoulder/arm/joint/hand/fist").remove_child(selected_gun)
			selected_gun = sec_gun
			skin.get_node("body/r_shoulder/arm/joint/hand/fist").add_child(selected_gun)
	else:
		skin.get_node("body/r_shoulder/arm/joint/hand/fist").remove_child(selected_gun)
		selected_gun = primary_gun
		skin.get_node("body/r_shoulder/arm/joint/hand/fist").add_child(selected_gun)
	
	if not selected_gun.is_connected("gun_fired",skin,"_on_gun_fired"):
		selected_gun.connect("gun_fired",skin,"_on_gun_fired")
	if not selected_gun.is_connected("reloading_gun",skin,"_on_gun_reload"):
		selected_gun.connect("reloading_gun",skin,"_on_gun_reload")
	
	selected_gun.gun_user = self
	selected_gun.position = Vector2(0,0)
	skin.switchGun(selected_gun.gun_type)


func setupGun():
	if selected_gun != null:
		skin.get_node("body/r_shoulder/arm/joint/hand/fist").add_child(selected_gun)
	else:
		print("Error no selected gun")
	
	if not selected_gun.is_connected("gun_fired",skin,"_on_gun_fired"):
		selected_gun.connect("gun_fired",skin,"_on_gun_fired")
	if not selected_gun.is_connected("reloading_gun",skin,"_on_gun_reload"):
		selected_gun.connect("reloading_gun",skin,"_on_gun_reload")
	
	selected_gun.gun_user = self
	selected_gun.position = Vector2(0,0)
	skin.switchGun(selected_gun.gun_type)
	if hud:
		hud.get_node("reload/gun_s").texture = selected_gun.gun_portrait
		hud.get_node("reload/TextureProgress").max_value = selected_gun.rounds_in_clip
		hud.get_node("reload/TextureProgress").value = selected_gun.rounds_left


func pause_controls(val : bool):
	_pause_cntrl = val
	if game_states.is_android:
		get_node("controller").enabled = !val
	
func _on_free_timer_timeout():
	respawn_player()

func respawn_player():
	position = get_tree().get_nodes_in_group("Level")[0].getSpawnPosition(team.team_id)
	rpc("sync_respawn",position,game_states.player_info.net_id)
