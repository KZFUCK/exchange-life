extends Control

const Model=preload("res://scripts/operations_model.gd")
const Store=preload("res://scripts/operations_store.gd")
const Development=preload("res://scripts/office_development.gd")
const View=preload("res://scripts/operations_view.gd")
var model=Model.new()
var store=Store.new()
var state: Dictionary
var board: Control
var cash_label: Label
var week_label: Label
var roster: RichTextLabel
var report_label: RichTextLabel
var status: Label
var role_choice: OptionButton
var hire_button: Button
var buy_button: Button
var place_button: Button
var upgrade_button: Button
var start_button: Button
var save_button: Button
var load_button: Button
var furniture_dialog:AcceptDialog
var furniture_label:Label
var move_button:Button
var sell_button:Button
var select_furniture_button:Button
var backup_button:Button
var sell_dialog:ConfirmationDialog
var backup_dialog:ConfirmationDialog
var selected_furniture:=0
var selling_furniture:=0
var moving_furniture:=0
var selecting_furniture:=false
var backup_checksum:=""
var edit_row:HBoxContainer
var edit_label:Label
var cancel_edit_button:Button
var reset_dialog: ConfirmationDialog
var load_dialog: ConfirmationDialog
var placing:=false
var paused:=false
var accumulator:=0.0
var selected_worker:=0
var clock_speed:=.25
var project_label:Label
var development_label:Label
var project_bar:ProgressBar
var project_button:Button
var speed_button:Button
var training_button:Button
var starter_button:Button
var commission_button:Button
var product_choice:OptionButton
var audience_choice:OptionButton
var project_history:RichTextLabel
var staff_dialog:AcceptDialog
var office_dialog:AcceptDialog
var report_dialog:AcceptDialog
var project_dialog:AcceptDialog
var system_dialog:AcceptDialog
var result_dialog:AcceptDialog
var result_label:Label

func label(parent: Node, text: String, font_size: int=16) -> Label:
	var node:=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);parent.add_child(node);return node

func button(parent: Node, text: String, call: Callable) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size.y=38;node.pressed.connect(call);parent.add_child(node);return node

func style(color:Color,border:Color,width:int=2) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(7)
	s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=9;s.content_margin_bottom=9
	s.shadow_color=Color(0,0,0,.18);s.shadow_size=3;s.shadow_offset=Vector2(0,3);return s

func dialog(title:String,dimensions:Vector2i) -> AcceptDialog:
	var d:=AcceptDialog.new();d.title=title;d.size=dimensions;d.theme=theme;d.ok_button_text="返回办公室";add_child(d);return d

func hide_menus() -> void:
	for menu in [staff_dialog,office_dialog,project_dialog,report_dialog,result_dialog,system_dialog,furniture_dialog,sell_dialog,backup_dialog,reset_dialog,load_dialog]:
		if menu!=null:menu.hide()

func open_confirmation(d:ConfirmationDialog) -> void:
	hide_menus()
	if state.running:paused=true;refresh()
	d.popup_centered()

func open_menu(d:AcceptDialog) -> void:
	hide_menus()
	if state.running:paused=true;refresh()
	d.popup_centered(d.size)

func _ready() -> void:
	state=model.initial()
	get_tree().root.gui_embed_subwindows=true
	var skin:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC"])
	skin.default_font=font;skin.default_font_size=17
	for type in ["Label","Button","OptionButton"]:skin.set_color("font_color",type,Color("333e36"))
	skin.set_color("default_color","RichTextLabel",Color("333e36"))
	for type in ["Button","OptionButton"]:
		skin.set_stylebox("normal",type,style(Color("f3dfac"),Color("876e45")))
		skin.set_stylebox("hover",type,style(Color("ffecc3"),Color("b58642")))
		skin.set_stylebox("pressed",type,style(Color("d8bd7e"),Color("725e3b")))
		skin.set_stylebox("disabled",type,style(Color("d4ccb7"),Color("b1a68b")))
		skin.set_color("font_disabled_color",type,Color("807762"))
		for state_name in ["font_hover_color","font_pressed_color","font_focus_color"]:skin.set_color(state_name,type,Color("333e36"))
	skin.set_stylebox("panel","AcceptDialog",style(Color("f6ecd6"),Color("796344"),3))
	theme=skin
	var background:=ColorRect.new();background.color=Color("efe1c6");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,14)
	add_child(margin)
	var root:=VBoxContainer.new();root.add_theme_constant_override("separation",7);margin.add_child(root)
	var top:=PanelContainer.new();top.add_theme_stylebox_override("panel",style(Color("34584b"),Color("213f36")));root.add_child(top)
	var title_row:=HBoxContainer.new();top.add_child(title_row)
	var title:=label(title_row,"交易所人生",25);title.add_theme_color_override("font_color",Color("fff2ca"));title.size_flags_horizontal=SIZE_EXPAND_FILL
	week_label=label(title_row,"",17);week_label.add_theme_color_override("font_color",Color("fff2ca"))
	var stats:=HBoxContainer.new();root.add_child(stats)
	cash_label=label(stats,"",21);cash_label.size_flags_horizontal=SIZE_EXPAND_FILL
	development_label=label(stats,"",17)
	var project_panel:=PanelContainer.new();project_panel.add_theme_stylebox_override("panel",style(Color("f7ecd2"),Color("b49a6a"),1));root.add_child(project_panel)
	var project_row:=HBoxContainer.new();project_panel.add_child(project_row)
	project_label=label(project_row,"",16);project_label.size_flags_horizontal=SIZE_EXPAND_FILL
	project_bar=ProgressBar.new();project_bar.custom_minimum_size=Vector2(270,24);project_bar.show_percentage=true;project_bar.add_theme_color_override("font_color",Color("344e3f"))
	project_bar.add_theme_stylebox_override("background",style(Color("d5c9a7"),Color("a1916f"),1))
	project_bar.add_theme_stylebox_override("fill",style(Color("659675"),Color("3f7659"),0));project_row.add_child(project_bar)
	edit_row=HBoxContainer.new();root.add_child(edit_row)
	edit_label=label(edit_row,"",16);edit_label.size_flags_horizontal=SIZE_EXPAND_FILL
	cancel_edit_button=button(edit_row,"取消布局操作",cancel_edit)
	board=View.new();board.size_flags_vertical=SIZE_EXPAND_FILL;root.add_child(board)
	board.cell_clicked.connect(place_at)
	board.furniture_clicked.connect(select_furniture)
	board.employee_clicked.connect(func(id:int):selected_worker=id;refresh();open_menu(staff_dialog))
	status=label(root,"社长，可先购买办公室的创业布局，或招聘后自行摆工位，再选项目营业。",15);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",10);root.add_child(footer)
	project_button=button(footer,"新项目",func():open_menu(project_dialog))
	button(footer,"员工",func():open_menu(staff_dialog))
	button(footer,"办公室",func():open_menu(office_dialog))
	start_button=button(footer,"开始营业",start_or_pause);start_button.size_flags_horizontal=SIZE_EXPAND_FILL
	speed_button=button(footer,"速度 ×1",change_speed)
	button(footer,"菜单",func():open_menu(system_dialog))
	for control in footer.get_children():control.size_flags_horizontal=SIZE_EXPAND_FILL
	start_button.add_theme_stylebox_override("normal",style(Color("5b8169"),Color("345940")))
	start_button.add_theme_color_override("font_color",Color("fff4ce"))
	# All management panels are modal; the office remains the permanent main scene.
	staff_dialog=dialog("员工 · 招聘与培养",Vector2i(610,470));var staff_box:=VBoxContainer.new();staff_dialog.add_child(staff_box)
	var recruit:=HBoxContainer.new();staff_box.add_child(recruit)
	role_choice=OptionButton.new()
	for job in model.rules.roles:role_choice.add_item("%s · 周薪 ¥%d" % [job.name,job.salary])
	recruit.add_child(role_choice);hire_button=button(recruit,"招聘 ¥600",hire)
	roster=RichTextLabel.new();roster.custom_minimum_size=Vector2(560,290);roster.size_flags_vertical=SIZE_EXPAND_FILL
	roster.bbcode_enabled=true;staff_box.add_child(roster)
	roster.meta_clicked.connect(func(meta):selected_worker=int(meta);refresh())
	training_button=button(staff_box,"培养选中的员工 · 5 研发点",train_worker)
	office_dialog=dialog("办公室 · 家具与搬迁",Vector2i(620,270));var office_box:=VBoxContainer.new();office_dialog.add_child(office_box)
	label(office_box,"每套工位占桌子与座位两格。保留通道，员工才会到岗。",16)
	var row:=HBoxContainer.new();office_box.add_child(row)
	buy_button=button(row,"购买工位 ¥800",buy);place_button=button(row,"摆放库存",toggle_place);upgrade_button=button(row,"扩建办公室",upgrade_office)
	select_furniture_button=button(office_box,"选择已有工位 · 移动 / 出售",begin_furniture_selection)
	starter_button=button(office_box,"创业两组布局 · 4 套工位 ¥3200",buy_starter_layout)
	report_dialog=dialog("周末经营报告",Vector2i(530,400));report_label=RichTextLabel.new();report_label.custom_minimum_size=Vector2(470,300);report_dialog.add_child(report_label)
	system_dialog=dialog("公司菜单",Vector2i(520,200));var system_box:=VBoxContainer.new();system_dialog.add_child(system_box)
	var system_row:=HBoxContainer.new();system_box.add_child(system_row)
	save_button=button(system_row,"保存",save_game)
	load_button=button(system_row,"读档",func():open_confirmation(load_dialog))
	backup_button=button(system_row,"恢复备份",confirm_backup);button(system_row,"新公司",func():open_confirmation(reset_dialog))
	button(system_box,"查看周报",func():system_dialog.hide();open_menu(report_dialog))
	project_dialog=dialog("新项目 · 产品 × 目标用户",Vector2i(570,360));var project_box:=VBoxContainer.new();project_dialog.add_child(project_box)
	label(project_box,"员工到岗后的工作才会推进项目；能力与搭配影响评价。",16)
	product_choice=OptionButton.new();project_box.add_child(product_choice)
	for p in Development.PRODUCTS:product_choice.add_item("%s · ¥%d · %d 研发 · 口碑 %d" % [p.name,p.price,p.cost,p.unlock])
	audience_choice=OptionButton.new();project_box.add_child(audience_choice)
	for a in Development.AUDIENCES:audience_choice.add_item(a)
	commission_button=button(project_box,"立项",commission_project)
	project_history=RichTextLabel.new();project_history.custom_minimum_size=Vector2(500,120);project_box.add_child(project_history)
	result_dialog=dialog("项目上线 · 市场评价",Vector2i(520,310));result_label=label(result_dialog,"",21)
	result_dialog.confirmed.connect(func():paused=false;refresh())
	furniture_dialog=dialog("工位管理",Vector2i(520,220));var furniture_box:=VBoxContainer.new();furniture_dialog.add_child(furniture_box)
	furniture_label=label(furniture_box,"",17)
	var furniture_row:=HBoxContainer.new();furniture_box.add_child(furniture_row)
	move_button=button(furniture_row,"移动工位",begin_move)
	sell_button=button(furniture_row,"出售 · 回收 ¥%d"%model.rules.workstation_resale_price,confirm_sale)
	sell_dialog=ConfirmationDialog.new();sell_dialog.title="确认出售工位";sell_dialog.confirmed.connect(sell_selected);sell_dialog.canceled.connect(func():selling_furniture=0;message("","出售已取消，工位和现金保留。"));add_child(sell_dialog)
	backup_dialog=ConfirmationDialog.new();backup_dialog.title="确认恢复备份";backup_dialog.confirmed.connect(restore_confirmed_backup);backup_dialog.canceled.connect(func():backup_checksum="";message("","恢复已取消，当前公司和存档保留。"));add_child(backup_dialog)
	reset_dialog=ConfirmationDialog.new();reset_dialog.dialog_text="创建新公司？当前有效存档将保留为上一份备份。";reset_dialog.confirmed.connect(new_game);add_child(reset_dialog)
	load_dialog=ConfirmationDialog.new();load_dialog.dialog_text="读取已保存的公司？当前未保存的进度会被替换。";load_dialog.confirmed.connect(load_game);add_child(load_dialog)
	for d in [reset_dialog,load_dialog,sell_dialog,backup_dialog]:d.ok_button_text="确认";d.cancel_button_text="取消";d.theme=theme
	if FileAccess.file_exists(store.path):load_game()
	refresh();get_tree().auto_accept_quit=false

func change_speed() -> void:
	clock_speed=.25 if clock_speed>=1 else clock_speed*2
	speed_button.text="速度 ×%d" % roundi(clock_speed/.25)

func train_worker() -> void:message(Development.train(state,selected_worker),"培训完成，员工项目能力提升。")

func commission_project() -> void:
	var error:=model.commission(state,product_choice.selected,audience_choice.selected)
	if error.is_empty():project_dialog.hide()
	message(error,"项目已立项。开始营业后，员工将在到岗工作时推进企划、开发和测试。")

func message(error: String, success: String) -> void:
	status.text=success if error.is_empty() else error
	refresh()

func hire() -> void:
	message(model.hire(state,model.rules.roles[role_choice.selected].id),"员工已招聘；有空闲工位时自动安排到岗。")

func buy() -> void:
	var error:=model.buy(state)
	if error.is_empty():cancel_edit(false);placing=true;office_dialog.hide()
	message(error,"已购买工位。点击地板摆放；再次点击“取消摆放”可以退出。")

func toggle_place() -> void:
	if state.inventory<=0:message("请先购买工位。","");return
	var was_placing:=placing;cancel_edit(false);placing=not was_placing;office_dialog.hide();refresh()

func place_at(cell: Array) -> void:
	if moving_furniture!=0:
		var error:=model.move(state,moving_furniture,cell)
		if error.is_empty():moving_furniture=0
		message(error,"工位已移动；受影响的未完成业务已取消并记入丢弃工时，员工已重新安排。")
		return
	if not placing:return
	var error:=model.place(state,cell)
	if error.is_empty():placing=state.inventory>0
	message(error,"工位已摆好，员工将在本周开始后沿通道前往座位。")

func buy_starter_layout() -> void:
	var error:=model.starter_layout(state,View.Furnishings.STARTER_DESKS)
	if error.is_empty():cancel_edit(false);office_dialog.hide()
	message(error,"已购置四套工位，支出 ¥3200；两组成对布局已完成，可以招聘员工。")

func upgrade_office() -> void:
	message(model.upgrade(state),"办公室已扩建，已有员工和工位保留；可继续招聘和购买工位。")

func start_or_pause() -> void:
	if state.running:
		paused=not paused;refresh();return
	var error:=model.begin(state)
	if error.is_empty():paused=false;cancel_edit(false)
	for d in [staff_dialog,office_dialog,project_dialog,report_dialog,result_dialog,system_dialog,furniture_dialog,sell_dialog,backup_dialog,reset_dialog,load_dialog]:d.hide()
	message(error,"本周开始。走路和等待不产生收入；到岗后才开始处理业务。")

func save_game() -> void:
	message(store.write_game(state),"公司已保存，包括员工位置、路线、工作进度、库存和账本。")

func load_game() -> void:
	var result:=store.read_game()
	if result.has("error"):message(result.error,"");return
	state=result.state;paused=state.running;cancel_edit(false);selected_furniture=0;selling_furniture=0;accumulator=0
	message("","公司已读取。未结束的一周保持暂停，点击“继续本周”恢复。" if state.running else "公司已读取。点击“开始本周”进入下一周。")

func restore_backup() -> void:
	paused=state.running
	var result:=store.restore_backup()
	if result.has("error"):message(result.error,"");return
	state=result.state;paused=state.running;cancel_edit(false);selected_furniture=0;selling_furniture=0;accumulator=0
	message("","已恢复上一份有效备份；替换前的文件另存保留。")

func new_game() -> void:
	var candidate:=model.initial();var error:=store.write_game(candidate)
	if not error.is_empty():message(error,"");return
	state=candidate;paused=false;cancel_edit(false);selected_furniture=0;accumulator=0;selected_worker=0;message("","新公司已创建。")

func _physics_process(delta: float) -> void:
	if state.is_empty() or paused or not state.running:return
	accumulator+=delta*clock_speed
	while accumulator>=.1 and state.running and not paused:
		accumulator-=.1
		var finished_projects:int=state.development.history.size()
		var week_done:bool=model.tick(state,.1)
		if week_done:
			paused=false;accumulator=0
			var error:=store.write_game(state)
			status.text="第 %d 周已结算，自动保存完成。可调整员工与工位或升级办公室。" % state.week if error.is_empty() else error
		if state.development.history.size()>finished_projects:
			var p:Dictionary=state.development.history[-1]
			result_label.text="%s 上线了！\n\n市场评价    %d / 100\n新增用户    %d\n口碑提升    +%d\n首期销售    ¥%d" % [Development.PRODUCTS[int(p.product)].name,p.score,p.users,p.trust,p.sales]
			paused=state.running;refresh();result_dialog.popup_centered(result_dialog.size)
			store.write_game(state)
		elif week_done:refresh();report_dialog.popup_centered(report_dialog.size)
	board.time+=delta
	refresh()

func refresh() -> void:
	if board==null:return
	var o:=model.office(state)
	cash_label.text="现金 ¥%d  |  累计业务 %d 批" % [state.cash,state.jobs]
	week_label.text="%s · %d/%d 人 · 第 %d 周 %0.1f/8 小时" % [o.name,state.staff.size(),o.capacity,int(state.week)+1,state.hour]
	board.selecting_furniture=selecting_furniture;board.moving_furniture=moving_furniture
	edit_row.visible=placing or moving_furniture!=0 or selecting_furniture
	edit_label.text="点击地板放置工位 #%d；红色位置不可放置，Esc 取消。"%moving_furniture if moving_furniture!=0 else ("点击原有工位选择移动或出售；Esc 取消。" if selecting_furniture else "点击地板摆放库存工位；Esc 取消。")
	board.placing=placing;board.paused=paused;board.simulation_speed=clock_speed;board.sync(state)
	var text:="工位 %d · 仓库 %d · 周租金 ¥%d\n\n" % [state.furniture.size(),state.inventory,o.rent]
	if state.staff.is_empty():text+="尚未招聘员工。\n"
	for employee in state.staff:
		var job:=model.role(employee.role)
		var phase:=model.phase(employee)
		if state.running and not paused:phase="前往工位" if not employee.path.is_empty() else ("在岗工作" if employee.desk!=0 else "等待工位")
		text+="[url=%d]#%d %s · Lv.%d[/url]  %s\n  工位 %s · 累计 %d 批 · 本批 %0.1f/%0.1f 小时\n" % [employee.id,employee.id,job.name,Development.level(state,int(employee.id)),phase,str(int(employee.desk)) if employee.desk!=0 else "未分配",employee.jobs,employee.progress,job.cycle]
		if employee.discarded_hours>0:text+="  已取消业务工时 %0.1f 小时（累计实际工时保留）。\n"%employee.discarded_hours
		if int(employee.id)==selected_worker:text+="  周薪 ¥%d；每批收入 ¥%d，服务器成本 ¥40。\n" % [job.salary,job.revenue]
	roster.text=text
	development_label.text="用户 %d  ·  口碑 %d  ·  研发 %d" % [state.development.users,state.development.trust,state.development.research]
	var p:Dictionary=state.development.active
	project_label.text="项目：等待立项 · 产品与用户的搭配会影响市场评价"
	project_bar.value=0
	if not p.is_empty():
		project_label.text="%s / %s · %s  %0.1f/%d 工时" % [Development.PRODUCTS[int(p.product)].name,Development.AUDIENCES[int(p.audience)],Development.stage(p),p.work,Development.PRODUCTS[int(p.product)].hours]
		project_bar.value=float(p.work)/float(Development.PRODUCTS[int(p.product)].hours)*100
	elif not state.development.history.is_empty():
		var last:Dictionary=state.development.history[-1]
		project_label.text="%s已上线 · 评价 %d 分 · 新增 %d 用户 · 可以立项新产品" % [Development.PRODUCTS[int(last.product)].name,last.score,last.users]
	project_history.text="已上线 %d 个项目\n" % state.development.history.size()
	for past in state.development.history:project_history.text+="%s × %s  %d 分 · %d 用户\n" % [Development.PRODUCTS[int(past.product)].name,Development.AUDIENCES[int(past.audience)],past.score,past.users]
	select_furniture_button.disabled=state.running or state.closed or state.furniture.is_empty()
	move_button.disabled=state.running or state.closed or model.find_desk(state,selected_furniture).is_empty()
	sell_button.disabled=move_button.disabled
	starter_button.disabled=state.running or state.closed or state.office!=1 or not state.staff.is_empty() or not state.furniture.is_empty() or state.inventory!=0
	commission_button.disabled=state.running or state.closed or not p.is_empty()
	training_button.disabled=state.running or state.closed or selected_worker==0 or state.development.research<5
	training_button.text="培养 #%d · 5 研发点" % selected_worker if selected_worker>0 else "先点击办公室人物或员工名单选人"
	if state.reports.is_empty():report_label.text="尚未周结算。\n\n工作完成一批即入账；周末再扣工资和租金。\n每周 8 个游戏小时，常速约 32 秒；可暂停和加速。\n招聘、工位和升级为一次性支出。"
	else:
		var r: Dictionary=state.reports[-1];var totals: Dictionary=r.totals
		report_label.text="第 %d 周\n收入              ¥%d\n服务器成本     ¥%d\n工资              ¥%d\n租金              ¥%d\n经营利润        ¥%d\n家具回收        ¥%d\n投资净支出     ¥%d\n结余现金        ¥%d" % [r.week,totals.income+totals.launch,-totals.server,-totals.salary,-totals.rent,r.profit,totals.furniture_sale,-r.investment,r.cash]
	for node in [hire_button,buy_button,place_button,upgrade_button]:node.disabled=state.running or state.closed
	place_button.text="取消摆放" if placing else "摆放工位"
	upgrade_button.text="升级 ¥%d" % model.rules.offices[int(state.office)].upgrade_price if state.office<3 else "最高级办公室"
	upgrade_button.disabled=upgrade_button.disabled or state.office>=3 or state.week<1
	start_button.disabled=state.closed
	start_button.text=("继续营业" if paused else "暂停") if state.running else "开始营业"
	if state.closed:status.text="现金耗尽，公司停业。可读取之前的存档或创建新公司。"

func cancel_edit(show_message:bool=true) -> void:
	placing=false;moving_furniture=0;selecting_furniture=false
	if show_message:message("","布局操作已取消，原布局保留；已购买的库存仍可摆放。")

func begin_furniture_selection() -> void:
	if state.running or state.closed:message("请在周间休息时调整工位。","");return
	cancel_edit(false);selecting_furniture=true;office_dialog.hide()
	message("","点击办公室内已有工位，选择移动或出售。")

func select_furniture(id:int) -> void:
	var desk:=model.find_desk(state,id)
	if not selecting_furniture or desk.is_empty():return
	selected_furniture=id;selecting_furniture=false
	var progress:=0.0
	for worker in state.staff:
		if int(worker.desk)==id:progress=float(worker.progress)
	furniture_label.text="工位 #%d · 桌位 (%d, %d)\n员工 #%d · 未完成本批 %0.1f 小时\n移动或出售会取消受影响的未完成业务；已赚收入保留。"%[id,desk.cell[0],desk.cell[1],desk.worker,progress]
	open_menu(furniture_dialog);refresh()

func begin_move() -> void:
	if state.running or state.closed or model.find_desk(state,selected_furniture).is_empty():message("无法移动该工位。","");return
	cancel_edit(false);moving_furniture=selected_furniture;furniture_dialog.hide()
	message("","选择新的桌位。确认有效落点前，原工位和员工安排保留。")

func confirm_sale() -> void:
	var desk:=model.find_desk(state,selected_furniture)
	if state.running or state.closed or desk.is_empty():message("无法出售该工位。","");return
	selling_furniture=selected_furniture
	sell_dialog.dialog_text="出售工位 #%d？\n确认后移除桌椅，回收 ¥%d。\n相关员工将释放预约并重新安排，未完成业务取消。\n取消不会改变工位、现金和员工安排。"%[selling_furniture,model.rules.workstation_resale_price]
	open_confirmation(sell_dialog)

func sell_selected() -> void:
	var error:=model.sell(state,selling_furniture)
	if error.is_empty():selected_furniture=0;cancel_edit(false)
	selling_furniture=0
	message(error,"工位已出售，回收 ¥%d；相关员工已重新安排。"%model.rules.workstation_resale_price)

func confirm_backup() -> void:
	var result:=store.read_game(store.path+".bak")
	if result.has("error"):message(result.error,"");return
	backup_checksum=FileAccess.get_file_as_string(store.path+".bak").sha256_text()
	backup_dialog.dialog_text="恢复上一份有效备份？\n备份：已结算 %d 周，现金 ¥%d，%d 人。\n当前未保存进度将被替换。替换前的存档文件会另存保留。\n取消不会更改当前公司或任何存档文件。"%[result.state.week,result.state.cash,result.state.staff.size()]
	open_confirmation(backup_dialog)

func restore_confirmed_backup() -> void:
	if backup_checksum.is_empty() or FileAccess.get_file_as_string(store.path+".bak").sha256_text()!=backup_checksum:
		backup_checksum="";message("备份已变化，请重新查看并确认。","");return
	backup_checksum="";restore_backup()

func _unhandled_key_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and (placing or moving_furniture!=0 or selecting_furniture):
		cancel_edit();get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		var error:=store.write_game(state)
		if error.is_empty():get_tree().quit()
		else:message(error,"")
