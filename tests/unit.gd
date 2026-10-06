extends Node

var checks=0
var failures=0

func check(condition: bool, label: String):
	checks+=1
	if not condition:failures+=1;push_error("FAIL: "+label)

func _ready():
	check(is_equal_approx(CombatRules.damage(100,"sensor","android",0),180),"sensor multiplier")
	check(is_equal_approx(CombatRules.damage(100,"core","android",0),130),"core multiplier")
	check(is_equal_approx(CombatRules.damage(100,"leg","heavy",0),38.4),"heavy plate armor")
	check(is_equal_approx(CombatRules.damage(100,"leg","heavy",2),80),"coil bypasses armor")
	check(CombatRules.damage(-12,"core","drone",1)==0,"negative damage bounded")
	check(CombatRules.reload_transfer(6,12,36)==Vector2i(18,0),"partial reserve reload")
	check(CombatRules.reload_transfer(34,90,36)==Vector2i(36,88),"reload conservation")
	check(CombatRules.reload_transfer(36,90,36)==Vector2i(36,90),"full magazine")
	check(CombatRules.reload_transfer(0,0,8)==Vector2i.ZERO,"empty reserve")
	check(CombatRules.ai_state(false,9,0,0,false)=="patrol","patrol without memory")
	check(CombatRules.ai_state(false,9,3,0,false)=="search","search after losing visibility")
	check(CombatRules.ai_state(true,12,0,0,false)=="engage","visible engagement")
	check(CombatRules.ai_state(true,31,0,0,false)=="pursue","distant pursuit")
	check(CombatRules.ai_state(true,12,0,.5,false)=="stagger","stagger interrupts engage")
	check(CombatRules.ai_state(true,12,3,.5,true)=="dead","death precedence")
	check(not CombatRules.valid_stage(3,2,1),"extraction guarded")
	check(CombatRules.valid_stage(3,2,0),"extraction after elimination")
	check(not CombatRules.valid_stage(1,9,0),"terminal interaction range")
	check(not CombatRules.valid_stage(4,1,0),"stage bounds")
	var settings_script=load("res://scripts/settings.gd")
	var cfg=settings_script.sanitized({"fov":999.0,"render_scale":-1.0,"volume":4.0,"gyro":"corrupt","preset":2.0})
	check(cfg.fov==100 and cfg.render_scale==.5 and cfg.volume==1,"numeric settings clamping")
	check(cfg.gyro==false and cfg.preset==2,"type safe settings")
	check(settings_script.atomic_write("user://test-settings.json",{"version":1,"stage":2}),"atomic write")
	check(settings_script.read_json("user://test-settings.json").stage==2,"JSON roundtrip")
	var f=FileAccess.open("user://test-settings.json",FileAccess.WRITE);f.store_string("broken JSON");f.close()
	check(settings_script.read_json("user://test-settings.json").is_empty(),"corrupt JSON fallback")
	DirAccess.remove_absolute("user://test-settings.json")
	var knee=RobotVisual.solve_knee(Vector3(0,1,0),Vector3(0,0,0),.53,.54)
	check(absf(knee.distance_to(Vector3(0,1,0))-.53)<.02,"IK upper length")
	check(absf(knee.length()-.54)<.02,"IK lower length")
	print("UNIT: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
