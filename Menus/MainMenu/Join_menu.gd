extends CanvasLayer

var servers = Array()
var serverListener = preload("res://Objects/Global/ServerListener.gd").new()
var current_server = null
var serverInfoFormatStr = "Server Name : %s\nGame Mode : %s\nMap : %s\nPlayers : %s"
var level_info = preload("res://Maps/level_info.gd").new()

func _ready():
	network.connect("join_fail", self, "_on_join_fail")
	network.connect("join_success", self, "_join_game")
	add_child(serverListener)
	serverListener.connect("new_server",self,"on_server_found")
	serverListener.connect("remove_server", self, "on_server_closed")
	startingTween()
	#$Admob.load_banner()
	MenuManager.connect("back_pressed", self,"_on_back_button_pressed")
	MenuManager.admob.show_banner()

func _on_join_fail():
	print("Failed to join server")
	$pop.show()
	$con.hide()

func _join_game():
	$con.hide()
	game_server.serverInfo = current_server
	var l_info = level_info.getLevelInfo(current_server.map)
	
	if l_info == {}:
		Logger.LogError("_join_game", "Map %s does not exist." % [current_server.map])
		return
	
	var l_path = level_info.getLevelGameModePath(l_info, current_server.game_mode)
	
	if l_path == "":
		Logger.LogError("_join_game", "Map %s does not have game mode %s" % [current_server.map, current_server.game_mode])
		return
	
	get_tree().change_scene(l_path)

func _on_back_button_pressed():
	MusicMan.click()
	MenuManager.changeScene("mainMenu")

func on_server_found(server_info):
	current_server = server_info
	$manual_ip/container/port.text = server_info.port
	$manual_ip/container/ip.text = server_info.ip
	updateServerInfo()
	if not servers.has(server_info):
		servers.append(server_info)
		updateServerList()

func on_server_closed(ip):
	for i in servers:
		if i.ip == ip:
			servers.erase(i)
			print("removing ",ip)
			updateServerList()
			break

func updateServerList():
	var slots = $serverList/serverList.get_children()
	var index = 0
	for i in slots:
		if index < servers.size():
			i.show()
			i.get_node("label").text = servers[index].name
		else:
			i.hide()
		index += 1
	

func _on_manualIp_btn_pressed():
	manualIpOpenTween()


func _on_auto_pressed():
	manualIpCloseTween()

func _on_join_button_pressed():
	MusicMan.click()
	if current_server.min_v > game_states.current_game_version:
		Logger.LogError("on_join_button_pressed", "Server is running on higher game version")
		Logger.notice.showNotice(self, "Join Failed", "Server is running on newer version of game. Update to Version %d" % [current_server.min_v])
		return
	$con.show()
	var port = int($manual_ip/container/port.text)
	var ip = $manual_ip/container/ip.text
	#game_server.serverInfo = current_server
	network.join_server(ip,port)


func _on_b1_pressed():
	MusicMan.click()
	current_server = servers[0]
	var svr = servers[0]
	$manual_ip/container/port.text = svr.port
	$manual_ip/container/ip.text = svr.ip

func _on_b2_pressed():
	MusicMan.click()
	current_server = servers[1]
	var svr = servers[1]
	$manual_ip/container/port.text = svr.port
	$manual_ip/container/ip.text = svr.ip
	
func _on_b3_pressed():
	MusicMan.click()
	current_server = servers[2]
	var svr = servers[2]
	$manual_ip/container/port.text = svr.port
	$manual_ip/container/ip.text = svr.ip

func _on_b4_pressed():
	MusicMan.click()
	current_server = servers[3]
	var svr = servers[3]
	$manual_ip/container/port.text = svr.port
	$manual_ip/container/ip.text = svr.ip

func _on_b5_pressed():
	MusicMan.click()
	current_server = servers[4]
	var svr = servers[4]
	$manual_ip/container/port.text = svr.port
	$manual_ip/container/ip.text = svr.ip

func updateServerInfo():
	var serverInfoStr = serverInfoFormatStr % [current_server.name,current_server.game_mode,
						current_server.map, current_server.plrs + "/" + current_server.max_p]
	$serverInfo/Label.text = serverInfoStr



################################################################################
################Tweeeeeeeeeeeeeeeeeeeeeeening###################################

onready var servInf_ipos = $serverInfo.rect_position
onready var serList_ipos = $serverList.rect_position

func startingTween():
	$Tween.remove_all()
	$manual_ip.rect_position += Vector2(0,550)
	$serverList.rect_position = serList_ipos - Vector2(400,0)
	$serverInfo.rect_position = servInf_ipos + Vector2(400,0)
	
	$Tween.interpolate_property($serverList,"rect_position",$serverList.rect_position,
		serList_ipos,0.5,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.interpolate_property($serverInfo,"rect_position",$serverInfo.rect_position,
		servInf_ipos,0.5,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.start()

onready var manIp_ipos = $manual_ip.rect_position

func manualIpOpenTween():
	var duration  = 0.5
	$Tween.remove_all()
	$manual_ip.rect_position = manIp_ipos + Vector2(0,550)
	$Tween.interpolate_property($manual_ip,"rect_position",$manual_ip.rect_position,
		manIp_ipos,duration,Tween.TRANS_QUAD,Tween.EASE_OUT,duration * 0.75)
	$Tween.interpolate_property($serverList,"rect_position",$serverList.rect_position,
		$serverList.rect_position - Vector2(500,0),duration,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.interpolate_property($serverInfo,"rect_position",$serverInfo.rect_position,
		$serverInfo.rect_position + Vector2(500,0),duration,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.start()

func manualIpCloseTween():
	var duration  = 0.5
	$Tween.remove_all()
	$manual_ip.rect_position = manIp_ipos
	$Tween.interpolate_property($manual_ip,"rect_position",manIp_ipos,
		$manual_ip.rect_position + Vector2(0,550),duration,Tween.TRANS_QUAD,Tween.EASE_OUT)
	$Tween.interpolate_property($serverList,"rect_position",$serverList.rect_position,
		serList_ipos,duration,Tween.TRANS_QUAD,Tween.EASE_OUT,duration * 0.75)
	$Tween.interpolate_property($serverInfo,"rect_position",$serverInfo.rect_position,
		servInf_ipos,duration,Tween.TRANS_QUAD,Tween.EASE_OUT,duration * 0.75)
	$Tween.start()
