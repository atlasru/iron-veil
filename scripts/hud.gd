class_name TacticalHUD
extends Control

const INK=Color(.83,.9,.85)
const LIME=Color(.67,.93,.39)
const DIM=Color(.44,.56,.56)
const DARK=Color(.035,.065,.078,.94)
var game: Node3D
var menu: Control
var menu_kind=""
var return_menu="main"
var font: Font
var scale_ui=1.0
var origin=Vector2.ZERO
var hitmarker=0.0
var damage_flash=0.0
var damage_direction=Vector3.ZERO
var message_text=""
var message_left=0.0
var touches: Dictionary = {}
var stick_origin=Vector2(180,726)
var stick_point=Vector2(180,726)
var buttons={"fire":Vector3(1450,640,64),"ads":Vector3(1335,557,47),"reload":Vector3(1333,754,43),"jump":Vector3(1450,795,44),"weapon":Vector3(1190,789,47),"sprint":Vector3(298,658,42),"camera":Vector3(1420,65,34),"shoulder":Vector3(1314,65,34),"pause":Vector3(1530,65,34),"interact":Vector3(950,645,46)}
var mobile=false

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=ThemeDB.fallback_font
	mobile=OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()

func _process(delta):
	var available=size
	var safe_origin=Vector2.ZERO
	if OS.has_feature("mobile"):
		var physical=Vector2(DisplayServer.screen_get_size())
		var safe=DisplayServer.get_display_safe_area()
		if physical.x>0 and physical.y>0 and safe.size.x>0 and safe.size.y>0:
			available=Vector2(safe.size)*size/physical
			safe_origin=Vector2(safe.position)*size/physical
	scale_ui=minf(available.x/1600,available.y/900)
	origin=safe_origin+(available-Vector2(1600,900)*scale_ui)*.5
	if menu:
		menu.position=Vector2(63,285)*scale_ui+origin
		menu.scale=Vector2.ONE*scale_ui
	hitmarker=maxf(0,hitmarker-delta)
	damage_flash=maxf(0,damage_flash-delta)
	message_left=maxf(0,message_left-delta)
	queue_redraw()

func text(value: String, at: Vector2, pixels: int, color: Color=INK):
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _draw():
	if not game.player:return
	draw_set_transform(origin,0,Vector2.ONE*scale_ui)
	var p=game.player
	if menu_kind=="":
		text("IV / 09",Vector2(40,57),24,LIME)
		text(game.OBJECTIVE_TEXT[game.stage],Vector2(40,88),21)
		var distance=p.global_position.distance_to(FacilityLevel.OBJECTIVES[game.stage])
		text("UPLINK   "+str(roundi(distance))+" m",Vector2(40,114),16,DIM)
		var center=Vector2(800,450)
		var gap=6+CombatRules.WEAPONS[p.weapon].spread*180+(4 if p.sprinting else 0)
		for dir in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:draw_line(center+dir*gap,center+dir*(gap+9),INK,1.5,true)
		draw_circle(center,1.5,LIME)
		if hitmarker>0:
			for dir in [Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1)]:draw_line(center+dir*9,center+dir*16,LIME,2,true)
		if p.charge>0:draw_arc(center,28,-PI/2,-PI/2+TAU*p.charge/.65,36,Color(.3,.9,1),3,true)
		text("INTEGRITY",Vector2(42,822),14,DIM)
		text(str(roundi(p.integrity)),Vector2(42,861),34,INK)
		draw_rect(Rect2(127,839,195,5),Color(.18,.25,.24))
		draw_rect(Rect2(127,839,195*p.integrity/p.max_integrity,5),LIME if p.integrity>70 else Color(1,.3,.13))
		text(CombatRules.WEAPONS[p.weapon].name,Vector2(1090,851),16,DIM)
		text(str(p.ammo[p.weapon])+" / "+str(p.reserve[p.weapon]),Vector2(1420,858),30)
		if p.reload_left>0:
			text("CYCLING",Vector2(756,495),15,LIME)
			draw_line(Vector2(750,505),Vector2(750+(1-p.reload_left/CombatRules.WEAPONS[p.weapon].reload)*100,505),LIME,3)
		if message_left>0:
			draw_rect(Rect2(398,146,805,43),Color(.025,.05,.06,.87))
			text(message_text,Vector2(416,174),18,LIME)
		if distance<4.5:
			text("TRANSMIT" if mobile else "[E] TRANSMIT / checkpoint",Vector2(678,598),20,LIME)
			if mobile:draw_button("interact","E")
		# Project objective marker without a through-wall enemy overlay.
		var target=FacilityLevel.OBJECTIVES[game.stage]+Vector3.UP*2.5
		if not p.camera.is_position_behind(target):
			var projected=(p.camera.unproject_position(target)-origin)/scale_ui
			projected=Vector2(clampf(projected.x,50,1550),clampf(projected.y,200,620))
			draw_circle(projected,5,LIME,false,2)
		if mobile:
			draw_arc(stick_origin,88,0,TAU,48,Color(.7,.85,.76,.17),2,true)
			draw_circle(stick_point,31,Color(.65,.88,.7,.15))
			for key in ["fire","ads","reload","jump","weapon","sprint"]:
				draw_button(key,{"fire":"FIRE","ads":"ADS","reload":"R","jump":"JUMP","weapon":CombatRules.WEAPONS[p.weapon].short,"sprint":"RUN"}[key])
		else:text("WASD / MOVE    SHIFT / RUN    SPACE / JUMP    R / RELOAD    1–3 / WEAPON    V / VIEW    Q / SHOULDER",Vector2(380,884),13,DIM)
		for key in ["camera","shoulder","pause"]:draw_button(key,{"camera":"3P" if Settings.values.third_person else "1P","shoulder":"L/R","pause":"II"}[key])
		if damage_flash>0:
			var alpha=damage_flash*.32
			draw_rect(Rect2(0,0,1600,12),Color(1,.19,.07,alpha));draw_rect(Rect2(0,888,1600,12),Color(1,.19,.07,alpha))
			var local=p.camera.global_basis.inverse()*damage_direction
			var direction=Vector2(local.x,-local.z).normalized()
			draw_arc(center+direction*85,22,0,PI,12,Color(1,.3,.15,damage_flash),4,true)
		if game.stage==3:
			for enemy in game.enemies:
				if is_instance_valid(enemy) and enemy.kind=="boss" and not enemy.dead:
					text("WARDEN / SENSOR ARRAY ONLINE",Vector2(612,224),15,Color(.95,.44,.21))
					draw_rect(Rect2(580,236,440,4),Color(.17,.21,.2));draw_rect(Rect2(580,236,440*enemy.health/enemy.max_health,4),Color(.95,.42,.15))
		if Settings.values.diagnostics:
			var data="%d FPS / %.1f ms   CPU %.2f / PHYS %.2f ms\nDRAW %d / TRI %d / OBJ %d   SCALE %.2f" % [Engine.get_frames_per_second(),1000.0/maxi(1,Engine.get_frames_per_second()),Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),get_viewport().scaling_3d_scale]
			var lines=data.split("\n");text(lines[0],Vector2(42,155),15,LIME);text(lines[1],Vector2(42,177),15,LIME)
	else:
		draw_rect(Rect2(0,0,1600,900),Color(.018,.042,.05,.48))
		draw_rect(Rect2(0,0,710,900),Color(.025,.046,.057,.96))
		text("VEIL INDUSTRIAL / FIELD SYSTEMS",Vector2(63,81),16,DIM)
		text("IRON//VEIL",Vector2(58,177),67,INK)
		draw_line(Vector2(63,208),Vector2(638,208),LIME,2)
		text("WRAITH / COMBAT ANDROID",Vector2(64,244),17,LIME)
		text("RELAY YARD → COOLANT → CORE",Vector2(64,766),17,INK)
		text("An abandoned facility. An autonomous defense network.",Vector2(64,801),16,DIM)
		text("Break the interlocks. Silence the Warden. Transmit.",Vector2(64,829),16,DIM)
		text("0.1.0 / OFFLINE / NO ACCOUNT",Vector2(64,874),13,DIM)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_button(key: String, value: String):
	var data=buttons[key];var radius=data.z*Settings.values.touch_scale
	var active=(key=="fire" and game.player.fire_touch) or (key=="ads" and game.player.ads_touch) or (key=="sprint" and game.player.sprint_touch)
	var color=LIME if active else Color(.66,.81,.73,.32)
	draw_circle(Vector2(data.x,data.y),radius,Color(.03,.07,.085,.5))
	draw_arc(Vector2(data.x,data.y),radius,0,TAU,36,color,2,true)
	var pixels=17 if key=="fire" else 15
	var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	text(value,Vector2(data.x-width*.5,data.y+5),pixels,LIME if active else INK)

func message(value: String, seconds: float):
	message_text=value;message_left=seconds

func _input(event):
	if menu_kind=="pause" and ((event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)):
		game.resume_game();get_viewport().set_input_as_handled();return
	if menu_kind!="" or not game.playing:return
	if event is InputEventScreenTouch:
		var point=(event.position-origin)/scale_ui
		if event.pressed:
			var owner="look"
			for key in buttons:
				if not mobile and key not in ["camera","shoulder","pause"]:continue
				if key=="interact" and game.player.global_position.distance_to(FacilityLevel.OBJECTIVES[game.stage])>=4.5:continue
				var b=buttons[key]
				if point.distance_to(Vector2(b.x,b.y))<=b.z*Settings.values.touch_scale:
					owner=key;break
			if owner=="look" and point.x<650:
				owner="move";stick_origin=point;stick_point=point
			# Keep one owner for look and move; every held button retains its own touch ID.
			if owner in ["look","move"] and touches.values().has(owner):owner="unused"
			touches[event.index]=owner
			perform(owner,true)
		else:
			var owner=touches.get(event.index,"")
			perform(owner,false);touches.erase(event.index)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenDrag and touches.has(event.index):
		var owner=touches[event.index]
		if owner=="look":game.player.look_delta+=event.relative/scale_ui*.0025
		if owner=="move":
			var offset=(event.position-origin)/scale_ui-stick_origin
			game.player.move_stick=(offset/88).limit_length()
			stick_point=stick_origin+offset.limit_length(88)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE:
		var point=(event.position-origin)/scale_ui
		for key in ["camera","shoulder","pause"]:
			var b=buttons[key]
			if point.distance_to(Vector2(b.x,b.y))<=b.z:perform(key,true);get_viewport().set_input_as_handled()

func perform(action: String, down: bool):
	match action:
		"fire":game.player.fire_touch=down
		"ads":game.player.ads_touch=down
		"move":
			if not down:game.player.move_stick=Vector2.ZERO;stick_origin=Vector2(180,726);stick_point=stick_origin
		"sprint":
			if down:game.player.sprint_touch=not game.player.sprint_touch
		"reload":
			if down:game.player.reload_weapon()
		"jump":
			if down:game.player.jump_requested=true
		"weapon":
			if down:game.player.switch_weapon((game.player.weapon+1)%3)
		"camera":
			if down:game.player.switch_perspective()
		"shoulder":
			if down:game.player.switch_shoulder()
		"pause":
			if down:game.pause_game()
		"interact":
			if down:game.interact()

func release_touches():
	touches.clear();stick_origin=Vector2(180,726);stick_point=stick_origin
	game.player.clear_input()

func style(background: Color, border: Color) -> StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=background;box.border_color=border
	box.set_border_width_all(1);box.set_corner_radius_all(5)
	box.content_margin_left=20;box.content_margin_right=20;box.content_margin_top=12;box.content_margin_bottom=12
	return box

func button(parent: Node, value: String, callback: Callable):
	var b=Button.new();b.text=value;b.custom_minimum_size=Vector2(520,61)
	b.add_theme_font_size_override("font_size",21)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_stylebox_override("normal",style(Color(.055,.1,.12),Color(.19,.29,.29)))
	b.add_theme_stylebox_override("hover",style(Color(.09,.16,.17),LIME))
	b.add_theme_stylebox_override("pressed",style(Color(.15,.24,.19),LIME))
	parent.add_child(b);b.pressed.connect(func():Sound.ui();callback.call())
	return b

func show_menu(kind: String):
	menu_kind=kind
	if menu:menu.queue_free();menu=null
	if kind=="":return
	menu=Control.new();add_child(menu)
	menu.position=Vector2(63,285)*scale_ui+origin
	menu.scale=Vector2.ONE*scale_ui
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",13);menu.add_child(column)
	match kind:
		"main":
			button(column,"DEPLOY / NEW MISSION",func():game.start_game(false))
			if not Settings.checkpoint.is_empty():button(column,"CONTINUE / CHECKPOINT",func():game.start_game(true))
			button(column,"SYSTEM CONFIGURATION",func():return_menu="main";show_menu("settings"))
			button(column,"FIELD MANUAL",func():show_menu("manual"))
			button(column,"EXIT",func():game.shutdown())
		"pause":
			button(column,"RESUME",game.resume_game)
			button(column,"SYSTEM CONFIGURATION",func():return_menu="pause";show_menu("settings"))
			button(column,"RESTART / CHECKPOINT",func():game.start_game(true))
			button(column,"ABORT / MAIN MENU",func():get_tree().paused=false;show_menu("main"))
		"complete", "death":
			var label=Label.new();label.text="UPLINK COMPLETE" if kind=="complete" else "WRAITH OFFLINE"
			label.add_theme_font_size_override("font_size",29);label.modulate=LIME;column.add_child(label)
			var detail=Label.new();detail.text="%d machines neutralized / %02d:%02d" % [game.kills,int(game.elapsed)/60,int(game.elapsed)%60]
			detail.add_theme_font_size_override("font_size",18);column.add_child(detail)
			button(column,"REDEPLOY",func():game.start_game(kind=="death"))
			button(column,"MAIN MENU",func():get_tree().paused=false;show_menu("main"))
		"manual":
			var label=Label.new();label.text="LEFT stick: move / RIGHT region: look\nFIRE + look + movement: independent touches\nADS / RUN / JUMP / R reload / weapon cycle\n3P / 1P: shared robot, switch anytime\nL/R: camera shoulder / E: activate terminal\n\nPC: WASD, mouse, LMB / RMB, R, Shift, Space\n1–3 weapons / V camera / Q shoulder / E terminal\nGamepad: sticks, triggers, A jump, X reload\nY weapon / RB view / LB shoulder / B terminal\n\nSensor damage reduces enemy accuracy.\nLeg damage slows. Arm damage slows firing.\nCoil lance penetrates Warden armor.\nExplosive cargo affects nearby machines.";label.add_theme_font_size_override("font_size",18);column.add_child(label)
			button(column,"BACK",func():show_menu("main"))
		"settings":build_settings(column)

func build_settings(column: VBoxContainer):
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(570,380);column.add_child(scroll)
	var fields=VBoxContainer.new();fields.custom_minimum_size.x=535;fields.add_theme_constant_override("separation",12);scroll.add_child(fields)
	option(fields,"Graphics preset","preset",["LOW","MEDIUM","HIGH","ULTRA / EXPERIMENTAL"],func(i):Settings.set_preset(i);game.level.apply_graphics())
	slider(fields,"Render scale","render_scale",.5,1,.05)
	option(fields,"Shadow distance","shadows",["OFF","38 m","70 m","100 m"])
	option(fields,"Effects budget","effects",["LOW","MEDIUM","HIGH","ULTRA"])
	option(fields,"Anti-aliasing","aa",["OFF","MSAA 2x","MSAA 4x"])
	option(fields,"FPS limit","fps_limit",["30","60","90","120"],func(i):Settings.values.fps_limit=[30,60,90,120][i];changed(),[30,60,90,120].find(Settings.values.fps_limit))
	slider(fields,"Field of view","fov",60,100,1)
	slider(fields,"Camera distance","camera_distance",2.4,6,.1)
	slider(fields,"Look sensitivity","sensitivity",.2,3,.1)
	slider(fields,"Control size","touch_scale",.75,1.4,.05)
	slider(fields,"Gyro sensitivity","gyro_sensitivity",.1,3,.1)
	slider(fields,"Master volume","volume",0,1,.05)
	slider(fields,"Impact shake","shake",0,1,.05)
	for item in [["Gyroscope aiming","gyro"],["Gyro only while ADS","gyro_ads_only"],["Invert vertical aim","invert_y"],["Third-person default","third_person"],["Dynamic render scale","dynamic_resolution"],["Performance overlay","diagnostics"]]:
		var check=CheckButton.new();check.text=item[0];check.button_pressed=Settings.values[item[1]];check.custom_minimum_size.y=48;check.add_theme_font_size_override("font_size",18);fields.add_child(check)
		var key=item[1];check.toggled.connect(func(value):Settings.values[key]=value;changed())
	button(column,"BACK",func():show_menu(return_menu))

func changed():
	Settings.apply();Settings.save();game.level.apply_graphics()

func option(parent: Node, title: String, key: String, labels: Array, callback: Callable=Callable(), selected: int=-1):
	var row=HBoxContainer.new();parent.add_child(row)
	var label=Label.new();label.text=title;label.custom_minimum_size.x=270;label.add_theme_font_size_override("font_size",18);row.add_child(label)
	var select=OptionButton.new();select.custom_minimum_size=Vector2(240,48);select.add_theme_font_size_override("font_size",17)
	for value in labels:select.add_item(value)
	select.selected=int(Settings.values[key]) if selected<0 else selected;row.add_child(select)
	select.item_selected.connect(func(i):
		if callback.is_valid():callback.call(i)
		else:Settings.values[key]=i;changed())

func slider(parent: Node, title: String, key: String, minimum: float, maximum: float, step: float):
	var row=HBoxContainer.new();parent.add_child(row)
	var label=Label.new();label.text=title;label.custom_minimum_size.x=235;label.add_theme_font_size_override("font_size",18);row.add_child(label)
	var s=HSlider.new();s.min_value=minimum;s.max_value=maximum;s.step=step;s.value=Settings.values[key];s.custom_minimum_size=Vector2(230,46);row.add_child(s)
	var value=Label.new();value.text=str(s.value);value.custom_minimum_size.x=58;row.add_child(value)
	s.value_changed.connect(func(v):Settings.values[key]=v;value.text=str(snappedf(v,.01));changed())
