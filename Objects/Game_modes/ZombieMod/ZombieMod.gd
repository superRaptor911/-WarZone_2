extends CanvasLayer

var Custom_teamSelector = "res://Objects/Game_modes/ZombieMod/Zm_TeamSelect.tscn"

var current_round = 0
var z_count = 0

var zombie_spawns = Array()
var selected_zombie_spawn = null
var is_player_playing = false

# Boss scenes
var zombieBossScenes = [
	preload("res://Objects/Bots/BullSquid.tscn"),
	preload("res://Objects/Bots/GargantuaBoss.tscn"),
]

onready var tween =$Tween
onready var label = $Label

#Props are objects that can be destroyed / damaged
var Props_scene = {
	barrel = preload("res://Objects/Weapons/barrel.tscn")
}
var prop_parent = null
var Props = Array()



func getZombieCount() -> int:
	return 10 + 5 * current_round
	
func getZombieHealth() ->int:
	return 100 + 10 * current_round

func getZombieSpeed() -> int:
	return 80 + 12 * current_round

func showLabel(text : String, clr = Color.white):
	tween.interpolate_property(label, "modulate", Color(1,1,1,0) ,Color(1,1,1,1),
		1,Tween.TRANS_LINEAR,Tween.EASE_IN_OUT)
	
	tween.interpolate_property(label, "modulate", Color(1,1,1,1) ,Color(1,1,1,0),
		1,Tween.TRANS_LINEAR,Tween.EASE_IN_OUT, 2)
	
	tween.start()
	label.text = text
	label.set("custom_colors/font_color", clr)


func _ready():
	# Get Position of props for respawning them on each round
	var props = get_tree().get_nodes_in_group("Prop")
	for i in props:
		# Prop type, position of prop , referance to prop
		Props.append({type = i.prop_type, pos = i.position, ref = i})
	
	if props.size() != 0:
		prop_parent = props[0].get_parent()
	
	if get_tree().is_network_server():
		zombie_spawns = get_tree().get_nodes_in_group("ZspawnPoint")
		var teams = get_tree().get_nodes_in_group("Team")
		
		for i in teams:
			i.connect("team_eliminated", self, "on_team_eliminated")
		
		var level = get_tree().get_nodes_in_group("Level")[0]
		level.connect("player_created", self, "on_player_created")
		createBots()
	else:
		rpc_id(1, "S_getExistingZombies", String(game_states.player_info.net_id))

func on_player_created(_plr):
	if not is_player_playing:
		is_player_playing = true
		$round_start_dl.start()
	# Show msg
	rpc_unreliable_id(int(_plr.name), "P_showMessage", "Survive 10 waves of zombies.")

remotesync func P_showMessage(msg : String):
	showLabel(msg)

# Called when any team is eliminated (Server side)
func on_team_eliminated(team):
	var team_id = team.team_id
	if team_id == 0:
		rpc("P_roundEnd")
		$round_start_dl.start()
		respawnEveryOne()
		print("round end")
	else:
		$restart_delay.start()
		rpc("P_gameOver")
		print("game over")
	
	for i in zombie_spawns:
		i.deactivateZ()

# Called when round starts ( server side)
func _on_round_start_dl_timeout():
	current_round += 1
	if current_round == 10:
		current_round = 1
		
	rpc("P_roundStarted", current_round)	
	if current_round % 3 == 0 and current_round < 10:
		bossRound(current_round / 3)
		return
		
	z_count = getZombieCount()
	var num = int(z_count / zombie_spawns.size())
	var HP = getZombieHealth()
	var speed = getZombieSpeed()
	# Ready zombie spawn
	for i in zombie_spawns:
		i.max_zombies = num
		i.frequency = 0.75
		i.HP = HP
		i.speed = speed
		i.activateZ()

# Local function (client side), called when a new round starts 
remotesync func P_roundStarted(r : int):
	showLabel("Round %d started. Get ready !!" % [r], Color.red)
	$roundStart.play()	
	# Respawn destroyed props
	for i in Props:
		#Check existance of prop
		if not is_instance_valid(i.ref):
			#Get prop scene
			var prop_scn = Props_scene.get(i.type)
			#Chk error
			if prop_scn:
				var prop = prop_scn.instance()
				prop.position = i.pos
				prop_parent.add_child(prop)
				i.ref = prop

# Local Function (client side)
remotesync func P_roundEnd():
	if current_round == 9:
		showLabel("You are the best of the best!.", Color.blue)
	showLabel("You survived this wave.", Color.green)
	
# Local Function (client side)
remotesync func P_gameOver():
	showLabel("Humans eliminated, zombies win")

# Called when restart timer timeouts (Server Side)
func _on_restart_delay_timeout():
	current_round = 0
	# Respawn everyone
	var players = get_tree().get_nodes_in_group("Unit")
	for i in players:
		i.S_respawnUnit()
	
	rpc("P_restart")
	$round_start_dl.start()

# Local function to restart game
remotesync func P_restart():
	#remove existing zombies
	var zombies = get_tree().get_nodes_in_group("Monster")
	for i in zombies:
		i.team.removePlayer(i)
		i.queue_free()
	
	showLabel("New game starting")

# Function to spawn bots (not zombies)
func createBots():
	Logger.Log("Creating bots")
	var bots = Array()
	var bot_count = min(game_server.bot_settings.bot_count, 10)
	print("Bot count = ",game_server.bot_settings.bot_count)
	game_server.bot_settings.index = 0
	var level = get_tree().get_nodes_in_group("Level")[0]
	
	if bot_count > game_states.bot_profiles.bot.size():
		Logger.Log("Not enough bot profiles. Required %d , Got %d" % [bot_count, game_states.bot_profiles.bot.size()])
	
	for i in game_states.bot_profiles.bot:
		i.is_in_use = false
		if game_server.bot_settings.index < bot_count:
			i.is_in_use = true
			var data = level.unit_data_dict.duplicate(true)
			data.pn = i.bot_name
			data.g1 = i.bot_primary_gun
			data.g2 = i.bot_sec_gun
			data.b = true
			data.k = 0
			data.d = 0
			data.scr = 0
			data.pg = i.bot_primary_gun
			data.sg = i.bot_sec_gun
			
			#assign team
			data.tId = 1
			data.s = i.bot_ct_skin

			data.p = level.getSpawnPosition(data.tId)
			#giving unique node name
			data.n = "bot" + String(69 + game_server.bot_settings.index)
			bots.append(data)
			game_server.bot_settings.index += 1
	
	#spawn bot
	for i in bots:
		level.createUnit(i)
		Logger.Log("Created bot [%s] with ID %s" % [i.pn, i.n])

# Resawn Units ( Players + Bots)
func respawnEveryOne():
	var players = get_tree().get_nodes_in_group("Unit")
	for i in players:
		if not i.alive:
			i.S_respawnUnit()

remote func S_getExistingZombies(pid : String):
	var zData = Array()
	#var data_dict = { name = "", pos = Vector2(), skin = "", hp = 0}
	var spawned_zombies = get_tree().get_nodes_in_group("Monster")
	# Fill zData
	for i in spawned_zombies:
		var dict = {}
		dict["name"] = i.name
		dict["pos"] = i.position
		dict["skin"] = i.get_node("Model").skin_name
		zData.append(dict)
	# Send data to peer
	rpc_id(int(pid), "P_spawnZombies", zData)

# Local funtion to spawn existing Zombies.
# Called when a new player joins and requests server for existing zms
remote func P_spawnZombies(zData : Array):
	var level = get_tree().get_nodes_in_group("Level")[0]
	for i in zData:
		var zm = game_states.classResource.get("zombie").instance()
		zm.position = i.pos
		zm.name = i.name
		level.add_child(zm)


func bossRound(boss_round : int):
	rpc("P_BossRound_" + String(boss_round))


remotesync func P_BossRound_1():
	showLabel("Boss Round ! Gargantua is comming", Color.red)
	var boss0 = zombieBossScenes[1].instance()
	var boss1 = zombieBossScenes[1].instance()
	var spawn_locs = get_tree().get_nodes_in_group("ZspawnPoint")
	var level = get_tree().get_nodes_in_group("Level")[0]
	boss0.name = "gargantua0"
	boss1.name = "gargantua1"
	boss0.position = spawn_locs[randi() % spawn_locs.size()].position
	boss1.position = spawn_locs[randi() % spawn_locs.size()].position
	level.add_child(boss0)
	level.add_child(boss1)


remotesync func P_BossRound_2():
	showLabel("Boss Round ! Scp 682 is set free", Color.red)
	var boss0 = zombieBossScenes[0].instance()
	var boss1 = zombieBossScenes[0].instance()
	var spawn_locs = get_tree().get_nodes_in_group("ZspawnPoint")
	var level = get_tree().get_nodes_in_group("Level")[0]
	boss0.name = "zBullsqid0"
	boss1.name = "zBullsqid1"
	boss0.position = spawn_locs[randi() % spawn_locs.size()].position
	boss1.position = spawn_locs[randi() % spawn_locs.size()].position
	level.add_child(boss0)
	level.add_child(boss1)


remotesync func P_BossRound_3():
	showLabel("Final Round ! prepare for your end", Color.red)
	var boss0 = zombieBossScenes[1].instance()
	var boss1 = zombieBossScenes[1].instance()
	var boss2 = zombieBossScenes[0].instance()
	var boss3 = zombieBossScenes[0].instance()
	var spawn_locs = get_tree().get_nodes_in_group("ZspawnPoint")
	var level = get_tree().get_nodes_in_group("Level")[0]
	boss0.name = "gargantua0"
	boss1.name = "gargantua1"
	boss2.name = "zBullsqid0"
	boss3.name = "zBullsqid1"
	boss0.position = spawn_locs[randi() % spawn_locs.size()].position
	boss1.position = spawn_locs[randi() % spawn_locs.size()].position
	boss2.position = spawn_locs[randi() % spawn_locs.size()].position
	boss3.position = spawn_locs[randi() % spawn_locs.size()].position
	level.add_child(boss0)
	level.add_child(boss1)
	level.add_child(boss2)
	level.add_child(boss3)
