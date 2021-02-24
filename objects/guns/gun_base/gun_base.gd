# Base class for guns
extends Sprite

export var wpn_name : String    = "" # Gun name
var user_name : String   = ""        # Name of gun user
var damage : int         = 0         # Damage it will cause
var rate_of_fire : float = 0         # How much bullets it can fire per seconds
var reload_time : float  = 0         # Time taken for reload
var mag_size : int       = 0         # Capacity of a magazine
var bullets_in_mag : int = 0         # bullets left in magazine
var bullets : int        = 0         # bullets remaining other than magazine
var accuracy : float     = 0         #
var recoil : float       = 0         #
var bullet_types : Array = []        #

var is_reloading : bool = false
var cur_bullet_type : String = "_9mm_fmj"

onready var timer : Timer        = get_node("Timer")
onready var reload_timer : Timer = get_node("reload_timer")
onready var muzzle_sfx : AudioStreamPlayer2D = get_node("muzzle")
onready var level = get_tree().get_nodes_in_group("Levels")[0]
onready var resource = get_tree().root.get_node("Resources")

func _ready():
	_loadStats()
	timer.wait_time = 1.0 / rate_of_fire
	reload_timer.wait_time = reload_time
	reload_timer.connect("Timeout", self, "_on_reload_complete")


func _loadStats():
	var stats = resource.gun_stats.get(wpn_name)
	damage       = stats.damage
	rate_of_fire = stats.rate_of_fire
	reload_time  = stats.reload_time
	mag_size     = stats.mag_size
	accuracy     = stats.accuracy
	recoil       = stats.recoil


func fireGun():
	if !is_reloading && timer.is_stopped():
		timer.start()
		_fire()


func reload():
	if !is_reloading && bullets > 0 && bullets_in_mag != mag_size:
		reload_timer.start()
		is_reloading = true


func _on_reload_complete():
	_reload()


func _reload():
	var decrement = min(mag_size - bullets_in_mag, bullets)
	bullets -= decrement
	bullets_in_mag += decrement
	is_reloading = false


func _fire():
	var bullet = resource.bullets.get(cur_bullet_type).instance(-global_transform.y, damage,
		user_name, wpn_name)
	bullet.position = muzzle_sfx.global_position
	level.add_child(bullet)
	muzzle_sfx.play()

