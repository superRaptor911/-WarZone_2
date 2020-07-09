extends CanvasLayer

var Custom_teamSelector = "res://Objects/Game_modes/ZombieMod/Zm_TeamSelect.tscn"

var current_round = 0
var z_count = 0

var zombie_spawns = Array()
var selected_zombie_spawn = null
var is_player_playing = false

onready var tween =$Tween
onready var label = $Label


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
	if get_tree().is_network_server():
		
		zombie_spawns = get_tree().get_nodes_in_group("ZspawnPoints")[0].get_children()
		var teams = get_tree().get_nodes_in_group("Team")
		
		for i in teams:
			i.connect("team_eliminated", self, "on_team_eliminated")
		
		var level = get_tree().get_nodes_in_group("Level")[0]
		level.connect("player_created", self, "on_player_created")
		createBots()

func on_player_created(_plr):
	if not is_player_playing:
		is_player_playing = true
		$round_start_dl.start()
	
	if _plr.is_network_master():
		showLabel("Survive 10 waves of zombies.")


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


func _on_round_start_dl_timeout():
	current_round += 1
	z_count = getZombieCount()
	rpc("P_roundStarted", current_round)
	
	var num = int(z_count / zombie_spawns.size())
	var HP = getZombieHealth()
	var speed = getZombieSpeed()
	
	for i in zombie_spawns:
		i.max_zombies = num
		i.frequency = 0.75
		i.HP = HP
		i.speed = speed
		i.activateZ()



remotesync func P_roundStarted(r : int):
	showLabel("Round %d started. Get ready !!" % [r], Color.red)
	$roundStart.play()


remotesync func P_roundEnd():
	showLabel("You survived this wave.", Color.green)
	


remotesync func P_gameOver():
	showLabel("Humans eliminated, zombies win")


func _on_restart_delay_timeout():
	current_round = 0
	
	#Respawn everyone
	var players = get_tree().get_nodes_in_group("Unit")
	for i in players:
		i.S_respawnUnit()
	
	rpc("P_restart")
	
	$round_start_dl.start()


remotesync func P_restart():
	#remove existing zombies
	var zombies = get_tree().get_nodes_in_group("Monster")
	for i in zombies:
		i.team.removePlayer(i)
		i.queue_free()
	
	showLabel("New game starting")


func createBots():
	Logger.Log("Creating bots")
	var bots = Array()
	var bot_count = min(game_server.bot_settings.bot_count, 6)
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

func respawnEveryOne():
	var players = get_tree().get_nodes_in_group("Unit")
	for i in players:
		if not i.alive:
			i.S_respawnUnit()