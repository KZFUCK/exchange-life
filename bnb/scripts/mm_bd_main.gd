extends Control
const Model=preload("res://scripts/mm_bd_model.gd")
const Store=preload("res://scripts/mm_bd_store.gd")
const Chart=preload("res://scripts/mm_bd_chart.gd")
const CAST="res://assets/mm_anime/characters_v1.png"
const BACKGROUND="res://assets/mm_anime/studio_v1.png"
const INK=Color("28304d")
const MUTED=Color("778097")
const BLUE=Color("6675cc")
const TEAL=Color("409c8c")
var model=Model.new()
var store=Store.new()
var course:Dictionary={}
var page:String="home"
var content:VBoxContainer
var status_label:Label
var stage_label:Label
var controls:Dictionary={}
var form:Dictionary={}
var preview_label:Label
var guide:AcceptDialog
var confirmation:ConfirmationDialog
var pending:Callable
var notify_client:CheckButton
var page_scroll:ScrollContainer
var action_bar:HBoxContainer

func _ready()->void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var boot_message:String=""
	if course.is_empty():
		var saved:Dictionary=store.read_course()
		if saved.has("course"):
			course=saved.course;page=str(s().phase) if s().phase!="brief" else "home";boot_message="已继续上次保存的研修。"
		else:
			course={"active":model.initial(),"completed":[],"draft":{}}
			if FileAccess.file_exists(store.path):boot_message=saved.error
	get_tree().root.gui_embed_subwindows=true
	get_tree().auto_accept_quit=false
	var skin:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Hiragino Sans GB","Noto Sans CJK SC","Microsoft YaHei"])
	skin.default_font=font;skin.default_font_size=16
	for type in ["Label","Button","OptionButton","CheckButton","SpinBox","LineEdit"]:skin.set_color("font_color",type,INK)
	for state_name in ["font_hover_color","font_pressed_color","font_focus_color"]:skin.set_color(state_name,"Button",INK)
	skin.set_color("default_color","RichTextLabel",INK)
	for type in ["Button","OptionButton"]:
		skin.set_stylebox("normal",type,style(Color("ffffff"),Color("e1e4ef"),12))
		skin.set_stylebox("hover",type,style(Color("f0f2ff"),BLUE,12))
		skin.set_stylebox("pressed",type,style(Color("e3e8fc"),BLUE,12))
		skin.set_stylebox("disabled",type,style(Color("f1f2f5"),Color("e4e6ed"),12))
		skin.set_color("font_disabled_color",type,MUTED)
		skin.set_stylebox("focus",type,style(Color(0,0,0,0),BLUE,12))
	skin.set_stylebox("normal","LineEdit",style(Color("f7f8fc"),Color("e1e4ef"),8))
	skin.set_stylebox("panel","AcceptDialog",style(Color("fafbff"),Color("ccd3ec"),16))
	theme=skin
	var bg:=ColorRect.new();bg.color=Color("f4f5fa");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);bg.mouse_filter=MOUSE_FILTER_IGNORE;add_child(bg)
	var layout:=HBoxContainer.new();layout.set_anchors_and_offsets_preset(PRESET_FULL_RECT);layout.add_theme_constant_override("separation",0);add_child(layout)
	var side:=PanelContainer.new();side.custom_minimum_size.x=190;side.add_theme_stylebox_override("panel",style(Color("242d49"),Color("242d49"),0,22));layout.add_child(side)
	var sidebar:=VBoxContainer.new();sidebar.add_theme_constant_override("separation",16);side.add_child(sidebar)
	text(sidebar,"✦",36,Color("b7c4ee"));text(sidebar,"流動性\n研修室",27,Color("ffffff"))
	text(sidebar,"MARKET MAKER\nACADEMY",11,Color("a3aecf"))
	space(sidebar,22);text(sidebar,"课程导航",12,Color("a3aecf"))
	for row in [["研修主页","home"],["继续会谈","continue"],["学习手册","guide"],["训练记录","records"]]:
		var b:Button=btn(sidebar,row[0],navigate.bind(str(row[1])),"nav_"+str(row[1]))
		b.add_theme_stylebox_override("normal",style(Color("303a59"),Color("303a59"),10));b.add_theme_color_override("font_color",Color("e4e9fb"))
	var grow:=Control.new();grow.size_flags_vertical=SIZE_EXPAND_FILL;sidebar.add_child(grow)
	text(sidebar,"BD FIELD NOTES",11,Color("a3aecf"));text(sidebar,"学会提问\n说清边界\n交付可衡量的价值",15,Color("e4e9fb"));space(sidebar,6)
	text(sidebar,"OFFLINE TRAINING",10,Color("8f9fbe"))
	var margin:=MarginContainer.new();margin.size_flags_horizontal=SIZE_EXPAND_FILL;layout.add_child(margin)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,24)
	var main:=VBoxContainer.new();main.add_theme_constant_override("separation",12);margin.add_child(main)
	var header:=HBoxContainer.new();main.add_child(header)
	var heading:=VBoxContainer.new();heading.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(heading)
	text(heading,"研修日誌  /  BUSINESS DEVELOPMENT",11,MUTED);text(heading,"做市商模拟器",28)
	btn(header,"保存",save_course,"save");btn(header,"读取",func():confirm_action("读取研修档会替换当前未保存进度。",load_course),"load")
	btn(header,"恢复备份",func():confirm_action("恢复前会保留当前文件。确认恢复上一份有效研修档？",restore_course),"restore")
	stage_label=text(main,"",13,MUTED)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=SIZE_EXPAND_FILL;scroll.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;main.add_child(scroll)
	page_scroll=scroll
	content=VBoxContainer.new();content.size_flags_horizontal=SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",16);scroll.add_child(content)
	action_bar=HBoxContainer.new();action_bar.add_theme_constant_override("separation",12);main.add_child(action_bar)
	status_label=text(main,"准备好与第一位客户见面了吗？",14,TEAL)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text(main,"训练参数 · 虚构客户与资金 · 公司 SOP 可在案例配置中替换",11,MUTED)
	guide=AcceptDialog.new();guide.title="流动性服务 · 带教手册";guide.size=Vector2i(780,550);guide.theme=theme;guide.ok_button_text="返回研修";add_child(guide)
	var guide_text:=RichTextLabel.new();guide_text.bbcode_enabled=true;guide_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT);guide_text.offset_left=20;guide_text.offset_top=15;guide_text.offset_right=-20;guide_text.offset_bottom=-50;guide.add_child(guide_text)
	guide_text.text="[font_size=24]做市服务，先把需求问清楚[/font_size]\n\n[b]1. 双边报价[/b]\n买价 Bid 是愿意买入的价格，卖价 Ask 是愿意卖出的价格。价差 bps = (Ask − Bid) / 中间价 × 10,000。1 bps = 0.01%。\n\n[b]2. 深度与场所[/b]\n本案例深度是每个交易场所、每一侧在中间价 ±1% 内的订单名义金额。总资金不能在多个场所重复承诺。模拟订单簿只有三档，用来观察取舍，不代表真实撮合模型。\n\n[b]3. 商业条款[/b]\n交易资金、资产权属和月度服务费分别约定。问清授权、对账、费用、到期退出和事故联系人。固定服务毛利 = 月度服务费 − 训练交付成本；它和客户资产损益分开。\n\n[b]4. 服务边界[/b]\n不承诺币价、收益、虚假交易量或排名。不接受自成交、非真实挂单来制造活跃度。把价差、双边深度、观测窗口和异常市场条款写清。\n\n[b]5. 模拟与复盘[/b]\n三档报价、固定情景交易流、成本和逆向选择是简化训练估算。库存按市值计量；对冲以中间价和 3 bps 示例成本再平衡。暂停与通知会影响交付指标，已约定的故障免责须另行解释。模型不预测真实交易收益。\n\n[b]6. 参考[/b]\n[url=https://www.coinbase.com/en-de/learn/advanced-trading/what-is-an-order-book]Coinbase · Order book[/url]\n[url=https://www.kraken.com/compliance/market-integrity]Kraken · Market Integrity[/url]\n\n评分只用于本次练习与带教讨论，不作为公司的正式考核结论。"
	guide_text.meta_clicked.connect(func(url):OS.shell_open(str(url)))
	confirmation=ConfirmationDialog.new();confirmation.theme=theme;confirmation.title="研修操作确认";confirmation.ok_button_text="确认";confirmation.cancel_button_text="取消";confirmation.size=Vector2i(480,190);add_child(confirmation)
	confirmation.confirmed.connect(func():if pending.is_valid():pending.call())
	build()
	if not boot_message.is_empty():toast(boot_message)

func style(color:Color,border:Color,radius:int=16,pad:int=16)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(radius)
	s.content_margin_left=pad;s.content_margin_right=pad;s.content_margin_top=pad;s.content_margin_bottom=pad;return s
func text(parent:Node,value:String,size_:int=16,color:Color=INK)->Label:
	var l:=Label.new();l.text=value;l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func paragraph(parent:Node,value:String,size_:int=16,color:Color=INK)->Label:
	var l:Label=text(parent,value,size_,color);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size_flags_horizontal=SIZE_EXPAND_FILL;return l
func btn(parent:Node,value:String,callback:Callable,id:String="",primary:bool=false)->Button:
	var b:=Button.new();b.text=value;b.custom_minimum_size.y=44;b.pressed.connect(callback);parent.add_child(b)
	if not id.is_empty():controls[id]=b;b.set_meta("control_id",id)
	if primary:
		b.add_theme_stylebox_override("normal",style(BLUE,BLUE,12,12));b.add_theme_color_override("font_color",Color.WHITE)
	return b
func space(parent:Node,height:float)->void:
	var node:=Control.new();node.custom_minimum_size.y=height;parent.add_child(node)
func panel(parent:Node,color:Color=Color.WHITE)->VBoxContainer:
	var p:=PanelContainer.new();p.size_flags_horizontal=SIZE_EXPAND_FILL;p.add_theme_stylebox_override("panel",style(color,Color("e1e5f0")));parent.add_child(p)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);p.add_child(box);return box
func portrait(parent:Node,index:int,height:float=420)->TextureRect:
	var image:Texture2D=load(CAST);var atlas:=AtlasTexture.new();atlas.atlas=image;atlas.region=Rect2(float(index)*image.get_width()/3,0,float(image.get_width())/3,image.get_height())
	if index==1:atlas.region=Rect2(image.get_width()*.34,0,image.get_width()*.35,image.get_height())
	if index==2:atlas.region=Rect2(image.get_width()*.70,0,image.get_width()*.30,image.get_height())
	var rect:=TextureRect.new();rect.texture=atlas;rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size=Vector2(230,height);rect.size_flags_horizontal=SIZE_SHRINK_CENTER;parent.add_child(rect);return rect
func meter(parent:Node,title:String,value:String,color:Color=BLUE)->VBoxContainer:
	var box:VBoxContainer=panel(parent);text(box,title,12,MUTED);text(box,value,23,color);return box
func clear_page()->void:
	for child in content.get_children():content.remove_child(child);child.queue_free()
	for child in action_bar.get_children():action_bar.remove_child(child);child.queue_free()
	action_bar.visible=false
	form.clear()
func s()->Dictionary:return course.active
func toast(value:String)->void:status_label.text=value
func navigate(target:String)->void:
	remember_draft()
	if target=="guide":guide.popup_centered();return
	page="home" if target=="home" else ("records" if target=="records" else str(s().phase))
	if page=="brief":page="home"
	build()
func build()->void:
	clear_page();stage_label.text="01 需求会谈   ›   02 方案与报价   ›   03 客户谈判   ›   04 交付观察   ›   05 带教复盘"
	if page_scroll!=null:page_scroll.scroll_vertical=0
	match page:
		"home":build_home()
		"discovery":build_discovery()
		"proposal":build_proposal()
		"negotiation":build_negotiation()
		"execution":build_execution()
		"debrief":build_debrief(s())
		"records":build_records()

func build_home()->void:
	var hero:=PanelContainer.new();hero.custom_minimum_size.y=320;hero.clip_contents=true;content.add_child(hero)
	if ResourceLoader.exists(BACKGROUND):
		var bg:=TextureRect.new();bg.texture=load(BACKGROUND);bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.mouse_filter=MOUSE_FILTER_IGNORE;hero.add_child(bg)
	var shade:=ColorRect.new();shade.color=Color(.94,.95,1,.7);shade.mouse_filter=MOUSE_FILTER_IGNORE;hero.add_child(shade)
	var row:=HBoxContainer.new();hero.add_child(row);var intro:=VBoxContainer.new();intro.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(intro)
	space(intro,24);text(intro,"ようこそ · 流动性研修室",13,BLUE);text(intro,"每一份报价，\n都是一次信任的练习。",32)
	paragraph(intro,"从第一句需求访谈，到交付后的客户复盘。\n与客户、交易和风控一起，把做市服务讲清楚。",17)
	space(intro,8)
	if s().phase!="brief":btn(intro,"继续当前研修  →",navigate.bind("continue"),"resume",true)
	else:
		var start_row:=HBoxContainer.new();intro.add_child(start_row)
		var start:Button=btn(start_row,"开始第一场客户会谈  →",choose_case.bind(0),"hero_start",true);start.custom_minimum_size.x=360
	portrait(row,0,320)
	var heading:=HBoxContainer.new();content.add_child(heading);text(heading,"选择你的客户委托",22);text(heading,"3 个案例 · 每案约 10–15 分钟",13,MUTED)
	var cards:=HBoxContainer.new();cards.add_theme_constant_override("separation",14);content.add_child(cards)
	for i in model.data.cases.size():
		var c:Dictionary=model.data.cases[i];var card:VBoxContainer=panel(cards)
		text(card,c.level,11,BLUE);text(card,c.name,22);paragraph(card,c.subtitle,14,MUTED);paragraph(card,c.objective,15)
		var best:int=-1
		for completed in course.completed:
			if int(completed.case_id)==i:best=maxi(best,int(model.grade(completed).score))
		text(card,"尚未研修" if best<0 else "最高练习分 · %d / 100"%best,12,TEAL)
		btn(card,"进入会谈  →",choose_case.bind(i),"case_%d"%i,true)

func choose_case(index:int)->void:
	if s().phase not in ["brief","debrief"] and not s().commands.is_empty():confirm_action("开始新案例会替换当前未完成会谈；已完成的训练记录会保留。",start_case.bind(index));return
	start_case(index)
func start_case(index:int)->void:
	course.active=model.initial(index);course.draft={};action({"kind":"begin"})
func action(cmd:Dictionary)->void:
	var error:String=model.apply(s(),cmd)
	if not error.is_empty():toast(error);return
	if s().phase=="debrief":course.completed.append(s().duplicate(true))
	page=str(s().phase);build();toast("会谈记录已更新。" if cmd.kind=="ask" else "研修进度已更新；可随时保存。")
func build_discovery()->void:
	var c:Dictionary=model.scenario(s());text(content,c.name+" / 客户需求会谈",25)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);content.add_child(row)
	var scene:VBoxContainer=panel(row,Color("edf0fa"));scene.get_parent().custom_minimum_size.x=300
	portrait(scene,1,350);text(scene,c.client,14,BLUE)
	var talk:VBoxContainer=panel(row);text(talk,"先听懂客户，再给出答案。",21)
	paragraph(talk,str(s().notes[-1]),17)
	text(talk,"选择一个问题",12,MUTED)
	for q in model.data.questions:
		var asked:bool=q.id in s().asked
		var b:Button=btn(talk,("✓  " if asked else "＋  ")+q.label,action.bind({"kind":"ask","id":q.id}),"ask_"+str(q.id));b.disabled=asked
	btn(talk,"整理需求，进入方案工坊  →",action.bind({"kind":"draft"}),"draft",true)
	var notebook:VBoxContainer=panel(content,Color("fffaf1"));text(notebook,"会谈笔记 · 已确认 %d / 6 项"%s().asked.size(),17)
	paragraph(notebook,"验收指标、资金安排和服务边界是报价前必须确认的三项。",13,MUTED)
	for id in s().asked:paragraph(notebook,str(c.facts[id]),14)

func spin(parent:Node,key:String,title:String,min_:float,max_:float,step_:float,value:float,suffix:String)->void:
	var row:=HBoxContainer.new();parent.add_child(row);var label:Label=text(row,title,15);label.size_flags_horizontal=SIZE_EXPAND_FILL
	var field:=SpinBox.new();field.min_value=min_;field.max_value=max_;field.step=step_;field.value=value;field.suffix=suffix;field.custom_minimum_size=Vector2(170,40);row.add_child(field);form[key]=field;controls["form_"+key]=field
	field.value_changed.connect(func(_v):update_preview())
func read_form()->Dictionary:
	var p:Dictionary={}
	for key in ["spread","depth","capital","fee","venues"]:p[key]=form[key].value
	p.risk=form.risk.selected;return p
func remember_draft()->void:
	if page=="proposal" and not form.is_empty():course.draft=read_form()
func build_proposal()->void:
	var c:Dictionary=model.scenario(s());text(content,c.name+" / 方案工坊",25)
	if not s().notes.is_empty() and str(s().notes[-1]).contains("请调整方案"):paragraph(content,str(s().notes[-1]),15,Color("ac6d73"))
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);content.add_child(row)
	var box:VBoxContainer=panel(row);text(box,"拟定可交付的服务范围",21);paragraph(box,"每侧深度按每个场所分别约定。服务费与客户交易资金分开。",14,MUTED)
	var p:Dictionary=course.get("draft",{});if p.is_empty():p=model.default_proposal(s())
	spin(box,"spread","目标报价价差",6,80,2,p.spread,"bps")
	spin(box,"depth","±1% 每场所每侧深度",5000,40000,1000,p.depth,"USDT")
	spin(box,"capital","客户授权交易资金",50000,c.capital,10000,p.capital,"USDT")
	spin(box,"fee","月度服务费",2000,12000,100,p.fee,"USDT")
	spin(box,"venues","覆盖交易场所",1,3,1,p.venues,"个")
	var risk:=OptionButton.new();risk.add_item("事后人工处理");risk.add_item("分级限额 + 对冲 + 暂停／恢复条件");risk.selected=int(p.risk);risk.custom_minimum_size.y=42;box.add_child(risk);form.risk=risk;controls.form_risk=risk;risk.item_selected.connect(func(_v):update_preview())
	btn(box,"提交方案，进入客户谈判  →",submit_proposal,"propose",true)
	var side:VBoxContainer=panel(row,Color("eef1fb"));side.get_parent().custom_minimum_size.x=340
	portrait(side,0,250);text(side,"青岚 · BD 带教",15,BLUE);preview_label=paragraph(side,"",15);update_preview()
	paragraph(content,"报价可以有取舍，但每一项未满足的目标都应该向客户解释，并获得确认。案例金额是训练示例。",13,MUTED)
func update_preview()->void:
	if preview_label==null or form.is_empty():return
	var p:Dictionary=read_form();var warning:Array[String]=model.proposal_warnings(s(),p);var error:String=model.proposal_error(s(),p)
	var copy:Dictionary=s().duplicate(true);copy.proposal=p;copy.cash=p.capital*.5;copy.tokens=p.capital*.5/copy.mid
	var book:Dictionary=model.book(copy)
	preview_label.text="示例买／卖价  %.4f / %.4f\n预估月度服务毛利  %s USDT\n双边挂单占用  %s USDT\n\n%s"%[book.bids[0].price,book.asks[0].price,money(p.fee-model.monthly_cost(s(),p)),money(p.depth*2*p.venues),error if not error.is_empty() else ("\n".join(warning) if not warning.is_empty() else "✓ 资金、目标和服务范围基本匹配。请继续检查客户承诺边界。")]
func submit_proposal()->void:
	course.draft=read_form();action({"kind":"propose","proposal":course.draft.duplicate(true)})

func build_negotiation()->void:
	text(content,"客户谈判 / 把承诺说准确",25)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);content.add_child(row)
	var character:VBoxContainer=panel(row,Color("edf0fa"));character.get_parent().custom_minimum_size.x=300;portrait(character,1,420)
	var talk:VBoxContainer=panel(row);text(talk,model.scenario(s()).client,14,BLUE);paragraph(talk,model.scenario(s()).objection,23)
	space(talk,14)
	btn(talk,"为了成交，先承诺价格和成交量结果",action.bind({"kind":"answer","choice":0}),"answer_0")
	btn(talk,"解释真实流动性指标，明确资产权属与异常条款",action.bind({"kind":"answer","choice":1}),"answer_1",true)
	btn(talk,"合同不写，口头答应兜底损失／排名",action.bind({"kind":"answer","choice":2}),"answer_2")
	if not s().answers.is_empty() and s().answers[-1]!=1:
		var warning:VBoxContainer=panel(talk,Color("fff1f2"));paragraph(warning,str(s().notes[-1]),16,Color("ad6073"))
	paragraph(talk,"你可以承诺服务范围和响应机制。价格、自然成交量与客户资产损益不能用销售话术保证。",14,MUTED)

func money(value:float)->String:return String.num(value,0)
func build_execution()->void:
	var c:Dictionary=model.scenario(s());var event:Dictionary=c.events[int(s().day)]
	text(content,"交付观察台 / 第 %d 天，共 6 天"%(int(s().day)+1),25)
	var metrics:=HBoxContainer.new();metrics.add_theme_constant_override("separation",12);content.add_child(metrics)
	meter(metrics,"中间价",String.num(s().mid,4)+" USDT");meter(metrics,"客户资产市值",money(model.equity(s()))+" USDT");meter(metrics,"代币库存占比","%.1f%%"%(float(s().tokens)*float(s().mid)/maxf(model.equity(s()),.01)*100),TEAL)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);content.add_child(row)
	var left:VBoxContainer=panel(row);text(left,"客户资产曲线",17)
	var plot=Chart.new();plot.state=s();plot.model=model;plot.custom_minimum_size=Vector2(350,110);left.add_child(plot)
	text(left,"模拟订单簿 · ±1% 深度",17)
	var bars=Chart.new();bars.state=s();bars.model=model;bars.mode="book";bars.custom_minimum_size=Vector2(350,110);left.add_child(bars)
	var book:Dictionary=model.book(s());var table:=HBoxContainer.new();left.add_child(table)
	var bids:=VBoxContainer.new();bids.size_flags_horizontal=SIZE_EXPAND_FILL;table.add_child(bids);text(bids,"买价 / USDT 名义金额",12,TEAL)
	var asks:=VBoxContainer.new();asks.size_flags_horizontal=SIZE_EXPAND_FILL;table.add_child(asks);text(asks,"卖价 / USDT 名义金额",12,Color("b86f83"))
	for i in range(3):text(bids,"%.4f   ·   %s"%[book.bids[i].price,money(book.bids[i].notional)],13);text(asks,"%.4f   ·   %s"%[book.asks[i].price,money(book.asks[i].notional)],13)
	var trial:Dictionary=model.walk_book(book,"asks",10000,float(s().mid))
	paragraph(left,"10,000 USDT 模拟买入：均价 %.4f，滑点 %.1f bps，%s。"%[trial.vwap,trial.slippage_bps,"足额成交" if trial.complete else "深度不足，仅部分成交"],13,BLUE)
	paragraph(left,"曲线是客户资产的盯市变化，不是服务费收入。",12,MUTED)
	var right:VBoxContainer=panel(row,Color("eef1fb"));right.get_parent().custom_minimum_size.x=340;portrait(right,2,240)
	text(right,"澪 · 交易与风控",14,BLUE);text(right,event.title,21)
	paragraph(right,"本轮训练情景：价格变化 %.1f%%，%s。\n你会如何向交易团队提出处置建议？"%[float(event["return"])*100,"交易接口故障" if event.outage else "交易流偏向买方" if event.flow>0 else "交易流偏向卖方"],16)
	if int(s().proposal.risk)==0:paragraph(right,"当前为事后人工方案，尚未授权自动库存再平衡；风险动作本轮只放宽报价。",13,Color("ac6d73"))
	notify_client=CheckButton.new();notify_client.text="同步客户：原因、影响与恢复条件";notify_client.button_pressed=true;right.add_child(notify_client);controls.notify=notify_client
	action_bar.visible=true
	var risk_label:String="放宽价差 + 库存再平衡" if int(s().proposal.risk)==1 else "放宽报价，升级风险授权"
	for entry in [["按原方案继续报价","keep"],[risk_label,"risk"],["暂停受影响报价，升级核查","pause"]]:
		var action_button:Button=btn(action_bar,entry[0],deliver.bind(str(entry[1])),"day_"+str(entry[1]),entry[1]=="risk");action_button.size_flags_horizontal=SIZE_EXPAND_FILL
	if not s().daily.is_empty():paragraph(content,"上一训练日："+str(s().notes[-1])+"  客户资产变化 %s USDT；成交额 %s USDT。"%[money(s().daily[-1].change),money(s().daily[-1].executed)],14,MUTED)
func deliver(kind:String)->void:action({"kind":"day","action":kind,"notify":notify_client.button_pressed})

func build_debrief(state:Dictionary)->void:
	var grade:Dictionary=model.grade(state);text(content,"带教复盘 / "+model.scenario(state).name,25)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);content.add_child(row)
	var character:VBoxContainer=panel(row,Color("eef1fb"));character.get_parent().custom_minimum_size.x=270;portrait(character,0,350);text(character,"青岚 · 你的带教搭档",14,BLUE)
	var results:VBoxContainer=panel(row);text(results,"%d / 100"%grade.score,46,BLUE);text(results,grade.focus,20)
	for item in [["需求访谈","discovery",20],["方案匹配","proposal",25],["承诺边界","boundaries",25],["交付判断","delivery",20],["客户沟通","communication",10]]:
		var line:=HBoxContainer.new();results.add_child(line);var label:Label=text(line,item[0],15);label.size_flags_horizontal=SIZE_EXPAND_FILL;text(line,"%d / %d"%[grade[item[1]],model.data.scoring[item[1]]],17,BLUE)
	paragraph(results,"客户资产盯市变化：%s USDT\n月度服务毛利（另计）：%s USDT"%[money(grade.equity_change),money(grade.service_margin)],16)
	paragraph(results,"练习分用于复盘讨论。良好的 BD 交付不是承诺客户资产必然获利。",13,MUTED)
	for warning in grade.warnings:paragraph(results,"• "+warning,14,Color("ac6d73"))
	btn(results,"导出带教复盘",export_report.bind(state),"export",true);btn(results,"返回研修主页",navigate.bind("home"),"home")
	var journal:VBoxContainer=panel(content);text(journal,"逐日决策记录",18)
	for day in state.daily:paragraph(journal,"D%d · %s · %s · %s · 库存 %.1f%% · 资产变化 %s USDT"%[day.day,day.event,{"keep":"继续报价","risk":"放宽与再平衡","pause":"暂停核查"}.get(day.action),"已同步客户" if day.notify else "未同步客户",day.inventory*100,money(day.change)],14)
func build_records()->void:
	text(content,"训练记录 / 带教讨论材料",25)
	if course.completed.is_empty():paragraph(content,"完成第一份客户委托后，这里会记录你的方案、处置与练习分。",18,MUTED)
	for i in range(course.completed.size()-1,-1,-1):
		var record:Dictionary=course.completed[i];var grade:Dictionary=model.grade(record);var box:VBoxContainer=panel(content)
		text(box,"%s · %d / 100"%[model.scenario(record).name,grade.score],21);paragraph(box,grade.focus,15,MUTED)
		btn(box,"导出这次复盘",export_report.bind(record),"record_export_%d"%i)

func confirm_action(message:String,callback:Callable)->void:
	pending=callback;confirmation.dialog_text=message;confirmation.popup_centered()
func save_course()->void:
	remember_draft();var error:String=store.write_course(course);toast("研修已保存。旧经营存档保留。" if error.is_empty() else error)
func load_course()->void:
	var result:Dictionary=store.read_course()
	if result.has("error"):toast(result.error);return
	course=result.course;page=str(s().phase) if s().phase!="brief" else "home";build();toast("研修进度已读取。")
func restore_course()->void:
	var result:Dictionary=store.restore_backup()
	if result.has("error"):toast(result.error);return
	course=result.course;page=str(s().phase) if s().phase!="brief" else "home";build();toast("备份已恢复，原文件已保留。")
func export_report(state:Dictionary)->void:
	var grade:Dictionary=model.grade(state);var c:Dictionary=model.scenario(state)
	var path:String="user://mm_bd_report_%s_%d.md"%[c.id,Time.get_unix_time_from_system()]
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f==null:toast("复盘导出失败。");return
	var report:String="# 做市商 BD 训练复盘 · %s\n\n练习分：%d/100；%s。\n\n训练参数与虚构客户案例，不是公司正式报价或考核结论。\n\n## 服务方案\n\n%s\n\n## 决策与证据\n\n"%[c.name,grade.score,grade.focus,JSON.stringify(state.proposal,"\t")]
	for note in state.notes:report+="- "+str(note)+"\n"
	report+="\n## 资产与商业结果\n\n客户资产盯市变化：%s USDT；月度服务毛利：%s USDT（分开计算）。\n\n## 下一轮练习\n\n%s\n"%[money(grade.equity_change),money(grade.service_margin),"\n".join(grade.warnings)]
	f.store_string(report);f.close();toast("复盘已导出："+ProjectSettings.globalize_path(path))
func _notification(what:int)->void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		remember_draft();var error:String=store.write_course(course)
		if not error.is_empty():
			toast(error+" 请确认后再退出。")
			confirm_action(error+"\n保留原存档并退出，不保存本次进度？",func():get_tree().quit());return
		get_tree().quit()
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:navigate("home");get_viewport().set_input_as_handled()
