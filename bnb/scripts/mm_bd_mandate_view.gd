extends RefCounted
const Model=preload("res://scripts/mm_bd_mandate_model.gd")
const Chart=preload("res://scripts/mm_bd_chart.gd")
var host:Control
var model=Model.new()
var store:RefCounted
var course:Dictionary={}
var fields:Dictionary={}
var preview:Label
var notify:CheckButton
var boot_error:String=""
var work_fields:Dictionary={}
var work_kind:String=""
var training_mode:String="guided"
var review_target:Dictionary={}
var legacy_course:Dictionary={}
const LegacyModel=preload("res://scripts/mm_bd_mandate_legacy_model.gd")
const BaseStore=preload("res://scripts/mm_bd_store.gd")
var legacy_model=LegacyModel.new()
func _init(main:Control,save_store:RefCounted)->void:
	host=main;store=save_store
	var archive=BaseStore.new();archive.model=legacy_model
	archive.rules_hash=FileAccess.get_file_as_string(LegacyModel.MANDATE_DATA_PATH).sha256_text()
	archive.path="user://mm_bd_mandates_v1_%s.json"%archive.rules_hash.left(12)
	if FileAccess.file_exists(archive.path):
		var old:Dictionary=archive.read_course()
		if old.has("course"):legacy_course=old.course
	var loaded:Dictionary=store.read_course()
	if loaded.has("course"):
		course=loaded.course
		# Retain the original file and normalize the numeric suffix of early local V2 drafts.
		var normalized:Dictionary={}
		for key in course.get("work_drafts",{}):
			var parts:PackedStringArray=str(key).split("_");var canonical:String=str(key)
			if parts.size()==2 and parts[1].is_valid_float():canonical=parts[0]+"_"+str(int(float(parts[1])))
			normalized[canonical]=course.work_drafts[key]
		course.work_drafts=normalized
	else:
		course={"active":model.initial(),"completed":[],"draft":{},"work_drafts":{},"reviews":{}}
		if FileAccess.file_exists(store.path):boot_error=loaded.error
func s()->Dictionary:return course.active
func catalog(parent:Node)->void:
	host.text(parent,"新人 BD / 从机制到交付",25)
	var learning:VBoxContainer=host.panel(parent,Color("fffaf1"))
	host.text(learning,"学习路线与验收边界",20)
	host.paragraph(learning,"先完成渠道机制课和计算实验 → 引导练习 → 参数变式独立练习 → 导出五类交付件 → 带教复核与公司规则校准。独立练习隐藏提示与即时答案，保留首次决策。",15)
	for objective in model.data.learning_objectives:host.paragraph(learning,"• "+objective,14)
	host.paragraph(learning,model.data.training_policy.notice,15,Color("92506a"))
	for item in model.data.training_policy.review_items:host.text(learning,"待公司确认："+item,14)
	host.paragraph(parent,"Uniswap · 币安 Alpha · 现货 · 合约：客户访谈 → 渠道方案 → 三轮谈判 → 六日交付 → 带教复盘。",15,host.MUTED)
	if not s().commands.is_empty():host.btn(parent,"继续当前委托 · "+model.scenario(s()).name,resume,"mandate_resume",true)
	for i in model.data.cases.size():
		var c:Dictionary=model.data.cases[i];var box:VBoxContainer=host.panel(parent)
		host.text(box,c.name+" / "+c.subtitle,22);host.paragraph(box,c.objective,15)
		var best:int=-1
		for record in course.completed:
			if int(record.case_id)==i:best=maxi(best,model.grade(record).score)
		host.text(box,"尚未完成" if best<0 else "最高自动约束检查 %d / 90 · 表达质量待审核"%best,13,host.TEAL)
		host.btn(box,"引导练习 · 查看示例与反馈",choose.bind(i,"guided"),"mandate_%d"%i,true)
		host.btn(box,"参数变式 · 独立作答，结束后复盘",choose.bind(i,"assessment"),"mandate_assessment_%d"%i)
	host.btn(parent,"旧版现货演示：保留原有三个委托与记录",host.navigate.bind("home"),"mandate_spot")
	if not boot_error.is_empty():host.paragraph(parent,boot_error,14,Color("ad6073"))
func choose(index:int,mode:String="guided")->void:
	training_mode=mode
	if course.completed.size()>=30:host.toast("已保存 30 份新委托记录，请导出后由带教安排新版本。原记录保留。");return
	if s().phase not in ["brief","debrief"]:
		host.confirm_action("开始新委托会替换当前未完成的新渠道委托；已完成记录和原现货会谈保留。",start.bind(index,mode));return
	start(index,mode)
func start(index:int,mode:String="guided")->void:
	host.remember_draft()
	var next:Dictionary=course.duplicate(true);next.active=model.initial(index);next.draft={};next.work_drafts={}
	var error:String=model.apply(next.active,{"kind":"begin","mode":mode,"variant":1+course.completed.size()%2})
	if error.is_empty():error=store.write_course(next)
	if not error.is_empty():host.toast(error);return
	review_target={};course=next;host.page="mandate";host.build();host.toast("新委托已开始并保存。先确认客户资金、指标和授权。")
func resume()->void:
	host.remember_draft();review_target={};host.page="mandate";host.build()
func build()->void:
	fields.clear();work_fields.clear();work_kind=""
	if not review_target.is_empty():
		host.stage_label.text="历史交付件 · 本地带教审阅，当前练习保留";debrief(review_target);return
	var c:Dictionary=model.scenario(s())
	host.stage_label.text="01 客户访谈  ›  02 渠道方案  ›  03 三轮谈判  ›  04 六日交付  ›  05 复盘 · 操作自动保存"
	host.text(host.content,c.name+" / "+c.subtitle,25)
	host.paragraph(host.content,("引导练习 · 示例方案与即时带教反馈可用" if s().mode=="guided" else "独立练习 · 参数变式，首答记录，结束后反馈")+" · 自动检查不评判书面表达质量",14,host.BLUE)
	match s().phase:
		"brief":catalog(host.content)
		"discovery":discovery(c)
		"proposal":proposal(c)
		"negotiation":negotiation(c)
		"execution":execution(c)
		"handoff":handoff()
		"debrief":debrief(s())
func act(cmd:Dictionary)->void:
	remember()
	var next:Dictionary=course.duplicate(true);var error:String=model.apply(next.active,cmd)
	if not error.is_empty():host.toast(error);return
	if next.active.phase=="debrief":next.completed.append(next.active.duplicate(true))
	if not work_kind.is_empty():next.get("work_drafts",{}).erase(work_key())
	if cmd.kind=="propose":next.draft={}
	error=store.write_course(next)
	if not error.is_empty():host.toast(error+" 本次操作未提交，原进度保留。");return
	course=next;host.page="mandate";host.build();host.toast("委托进度已自动保存。")
func discovery(c:Dictionary)->void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);host.content.add_child(row)
	var character:VBoxContainer=host.panel(row,Color("eef1fb"));character.get_parent().custom_minimum_size.x=270;host.portrait(character,1,350);host.text(character,c.client,14,host.BLUE)
	var talk:VBoxContainer=host.panel(row);host.text(talk,"客户访谈 / 先确认，再承诺",21);host.paragraph(talk,str(s().notes[-1]),17)
	for q in model.data.questions:
		var asked:bool=q.id in s().asked;var b:Button=host.btn(talk,("✓ " if asked else "＋ ")+q.label,act.bind({"kind":"ask","id":q.id}),"mandate_ask_"+q.id);b.disabled=asked
	work_form(host.content,"memo")
	host.btn(host.content,"提交访谈纪要，进入方案报价",func():act({"kind":"draft","work":read_work()}),"mandate_draft",true)
	var notes:VBoxContainer=host.panel(host.content,Color("fffaf1"));host.text(notes,"已确认 %d / 6 项"%s().asked.size(),18)
	for id in s().asked:host.paragraph(notes,c.facts[id],14)
func read_form()->Dictionary:
	var p:Dictionary={}
	for key in fields:
		p[key]=fields[key].selected if key=="risk" else fields[key].value
	return p
func work_key()->String:
	return work_kind+"_"+str(int(s().round) if work_kind=="response" else int(s().day) if work_kind=="notice" else 0)
func read_work()->Dictionary:
	var out:Dictionary={}
	for k in work_fields:
		if is_instance_valid(work_fields[k]):out[k]=work_fields[k].text
	return out
func work_form(parent:Node,kind:String)->void:
	work_kind=kind;var box:VBoxContainer=host.panel(parent,Color("f7f8ff"))
	host.text(box,{"memo":"访谈纪要","rationale":"方案说明与取舍","response":"写出你会对客户说的话","notice":"客户通知与事件记录","handoff":"内部交接单"}[kind],20)
	host.paragraph(box,"三个字段需写具体内容；这里只检查填写完整。带教按事实准确、风险边界、可执行性与表达清晰度审核。",14)
	var values:Dictionary=course.get("work_drafts",{}).get(work_key(),{})
	for i in range(3):
		var k:String=str(i);host.text(box,model.data.rubric[kind][i],15)
		var edit:=TextEdit.new();edit.custom_minimum_size=Vector2(0,96);edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;edit.text=values.get(k,"");box.add_child(edit);work_fields[k]=edit;host.controls["mandate_work_"+k]=edit
		edit.text_changed.connect(func():
			if edit.text.length()>4000:edit.text=edit.text.left(4000)
		)
func remember()->void:
	if host.page=="mandate" and not work_fields.is_empty() and is_instance_valid(work_fields.get("0")):
		if not course.has("work_drafts"):course.work_drafts={}
		course.work_drafts[work_key()]=read_work()
	if host.page=="mandate" and s().phase=="proposal" and not fields.is_empty() and is_instance_valid(fields.get("fee")):course.draft=read_form()
func proposal(c:Dictionary)->void:
	if not s().notes.is_empty() and str(s().notes[-1]).contains("请调整"):host.paragraph(host.content,str(s().notes[-1]),15,Color("ad6073"))
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);host.content.add_child(row)
	var box:VBoxContainer=host.panel(row);host.text(box,"把授权和交付范围写进报价",21)
	var p:Dictionary=course.draft if not course.draft.is_empty() else (s().proposal if not s().proposal.is_empty() else model.blank_proposal(s()))
	for f in c.fields:
		var line:=HBoxContainer.new();box.add_child(line);var label:Label=host.text(line,f[1],14);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var spin:=SpinBox.new();spin.min_value=f[2];spin.max_value=f[3];spin.step=f[4];spin.suffix=f[5];spin.value=p[f[0]];spin.custom_minimum_size=Vector2(180,40);line.add_child(spin);fields[f[0]]=spin;host.controls["mandate_form_"+f[0]]=spin;spin.value_changed.connect(func(_v):update_preview())
	var risk:=OptionButton.new();risk.add_item("尚未确认调整、暂停及恢复权限");risk.add_item("已约定限额、调整／暂停／恢复与对账");risk.selected=int(p.risk);box.add_child(risk);fields.risk=risk;host.controls.mandate_form_risk=risk;risk.item_selected.connect(func(_v):update_preview())

	var side:VBoxContainer=host.panel(row,Color("eef1fb"));side.get_parent().custom_minimum_size.x=310;host.portrait(side,0,220);host.text(side,"青岚 · BD 带教",15,host.BLUE);preview=host.paragraph(side,"",15);update_preview()
	if s().mode=="guided":host.btn(host.content,"填入示例数值（仍须自行说明）",fill_example,"mandate_example")
	work_form(host.content,"rationale")
	host.btn(host.content,"提交方案与说明，进入客户谈判",submit,"mandate_propose",true)
	host.paragraph(host.content,"报价、资金、交易成本与服务费分开。所有金额和风险阈值都是本案例训练参数。",13,host.MUTED)
func fill_example()->void:
	remember();course.draft=model.default_proposal(s());host.build()
func update_preview()->void:
	if not is_instance_valid(preview) or fields.is_empty():return
	var p:Dictionary=read_form();var error:String=model.proposal_error(s(),p)
	if not error.is_empty():preview.text=error;return
	var scope:String=""
	match model.scenario(s()).channel:
		"uniswap":scope="区间 %.4f–%.4f\nLP 分配 %.0f USDT\n报价资产储备 %.0f USDT\ngas 累计上限 %.0f USDT"%[s().mid*(1-p.width_pct/100),s().mid*(1+p.width_pct/100),p.capital*(1-p.reserve_pct/100),p.capital*p.reserve_pct/100,p.gas_budget]
		"alpha":scope="单笔 %.0f / 日额度 %.0f USDT\n接收容忍度 %.1f%%\n储备 %.0f USDT\n待确认资金禁止重复使用"%[p.max_order,p.daily_limit,p.slippage_pct,p.capital*p.reserve_pct/100]
		"spot":scope="正常价差 %.0f bps\n每侧每场所深度 %.0f USDT\n场所 %.0f 家；双边占用 %.0f USDT"%[p.spread,p.depth,p.venues,2*p.depth*p.venues]
		"futures":scope="现货 %.0f / 保证金 %.0f USDT\n初始空仓对冲 %.0f USDT\n保留现金 %.0f USDT\n杠杆上限 %.1f 倍"%[p.capital*p.spot_pct/100,p.capital*p.margin_pct/100,p.capital*p.spot_pct/100*p.hedge_pct/100,p.capital*(1-(p.spot_pct+p.margin_pct)/100),p.leverage_cap]
	var warnings:Array[String]=model.proposal_warnings(s(),p)
	if s().mode=="assessment":
		preview.text=scope+"\n\n预估月度服务毛利 %.0f USDT\n按访谈事实独立说明方案取舍；匹配反馈将在谈判后给出。"%(p.fee-model.monthly_cost(s(),p));return
	preview.text=scope+"\n\n预估月度服务毛利 %.0f USDT\n\n"%(p.fee-model.monthly_cost(s(),p))+("✓ 范围与预算匹配，可继续核对承诺边界。" if warnings.is_empty() else "\n".join(warnings))
func submit()->void:
	var p:Dictionary=read_form();var error:String=model.proposal_error(s(),p)
	if not error.is_empty():host.toast(error);return
	course.draft=p;act({"kind":"propose","proposal":p,"work":read_work()})
func negotiation(c:Dictionary)->void:
	var turn:Dictionary=c.negotiation[int(s().round)];var box:VBoxContainer=host.panel(host.content)
	host.text(box,"客户谈判 / 第 %d 轮，共 3 轮"%(int(s().round)+1),21);host.text(box,c.client,14,host.BLUE);host.paragraph(box,turn.prompt,23)
	work_form(host.content,"response")
	for i in model.option_order(s(),int(s().round)):host.btn(host.content,turn.options[i],respond.bind(i),"mandate_answer_%d"%i)
	if not s().answers.is_empty() and s().mode=="guided":host.paragraph(box,str(s().notes[-1]),15,Color("ad6073"))
	host.btn(box,"返回方案，调整报价与范围",act.bind({"kind":"revise"}),"mandate_revise")
	host.portrait(host.content,1,240)
func respond(choice:int)->void:act({"kind":"answer","choice":choice,"work":read_work()})
func execution(c:Dictionary)->void:
	var e:Dictionary=c.events[int(s().day)];host.text(host.content,"交付观察 / 第 %d 天，共 6 天"%(int(s().day)+1),23)
	var meters:=HBoxContainer.new();meters.add_theme_constant_override("separation",12);host.content.add_child(meters)
	host.meter(meters,"操作前标记／观察价","%.4f USDT"%s().mid);host.meter(meters,"客户资产账面市值","%.0f USDT"%model.equity(s()));host.meter(meters,"累计处置偏差","%d 次"%s().violations,host.TEAL)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);host.content.add_child(row)
	var ledger:VBoxContainer=host.panel(row);host.text(ledger,"截至上日的已确认状态",19)
	var plot=Chart.new();plot.state=s();plot.model=model;plot.custom_minimum_size=Vector2(330,115);ledger.add_child(plot);host.text(ledger,"横轴：训练日；纵轴：客户资产市值（USDT）",13)
	match c.channel:
		"uniswap":
			host.paragraph(ledger,"当前区间 %.4f–%.4f\nLP 代币 %.2f · LP 报价资产 %.2f USDT\n可用储备 %.2f USDT\n累计估算费用收入 %.2f / gas 支出 %.2f USDT\n相对初始持币差额 %.2f USDT"%[s().lower,s().upper,s().lp_tokens,s().lp_quote,s().cash,s().fees_earned,s().gas_used,model.equity(s())-(s().hold_tokens*s().mid+s().hold_quote)],15)
		"alpha":
			host.paragraph(ledger,"现金 %.2f USDT · 已确认代币 %.2f\n待确认锁定金额 %.2f USDT\n非储备可用预算 %.2f USDT\n累计网络成本 %.2f USDT\n当前状态：%s"%[s().cash,s().tokens,s().reserved,model.available(s()),s().gas_used,"处理中，禁止重复执行" if not s().pending.is_empty() else "无待确认委托"],15)
		"spot":
			host.paragraph(ledger,"现金 %.2f USDT · 代币 %.2f\n当前库存比例 %.1f%%；挂单深度与确认成交分别核对。"%[s().cash,s().tokens,s().tokens*s().mid/maxf(model.equity(s()),.01)*100],15)
		"futures":
			host.paragraph(ledger,"现货 %.2f TOKEN · 合约净仓 %.2f TOKEN\n保证金余额 %.2f USDT\n含未实现损益 %.2f / 维持要求 %.2f USDT\n实际净名义敞口 %+.2f USDT\n累计资金费现金流 %+.2f USDT"%[s().tokens,s().position,s().margin,model.margin_equity(s()),model.maintenance(s()),s().tokens*s().spot_mid+s().position*s().mid,s().funding_total],15)
			var quotes:Dictionary=model.book(s());host.paragraph(ledger,"当前模拟双边首档 %.4f / %.4f\n每侧名义深度 %.0f / %.0f USDT"%[quotes.bids[0].price,quotes.asks[0].price,quotes.bid_depth,quotes.ask_depth],14,host.BLUE)
	var coach:VBoxContainer=host.panel(row,Color("eef1fb"));coach.get_parent().custom_minimum_size.x=320;host.portrait(coach,2,190);host.text(coach,"澪 · 交易与风控",14,host.BLUE);host.text(coach,e.title,20)
	host.paragraph(coach,"待处理情景：价格变化 %+.1f%%。左侧为操作前状态；本次提交先盯市再处置，已发生损失不能撤销。"%(e.price_return*100),15)
	if c.channel=="alpha":host.paragraph(coach,"情景执行价格冲击 %.1f%% · 网络成本 %.0f USDT\n身份%s · 处理状态%s"%[e.slippage,e.gas,"一致" if e.identity else "待核对","可确认" if e.confirm else "尚未确认"],14)
	if c.channel=="uniswap":
		var next_price:float=s().mid*(1+float(e.price_return))
		host.paragraph(coach,"本轮目标价 %.4f，%s当前区间 %.4f–%.4f。请比较保持与调整的成本。"%[next_price,"仍在" if next_price>=s().lower and next_price<s().upper else "将离开",s().lower,s().upper],15)
		host.paragraph(coach,"调整所需示例 gas %.0f USDT · %s"%[e.gas,"链状态异常" if e.outage else "链状态正常"],14)
	if c.channel=="futures":
		host.paragraph(coach,"现货观察价 %.4f；本轮现货变动 %+.1f%%，合约与现货分别盯市。"%[s().spot_mid,e.get("spot_return",e.price_return)*100],15)
		host.paragraph(coach,"本步单次资金费率 %+.1f bps · %s"%[e.funding_bps,"接口异常，无法确认新交易" if e.outage else "接口正常"],14)
	notify=CheckButton.new();notify.text="确认本次书面通知已同步客户（仅记状态，不计表达分）";notify.button_pressed=false;coach.add_child(notify);host.controls.mandate_notify=notify
	work_form(host.content,"notice")
	host.action_bar.visible=true
	var labels:Array={"uniswap":["保持原区间","按授权重设区间","暂停调整，核对原头寸"],"alpha":["按额度提交／核对执行","缩小单笔，刷新示例报价","暂停新增，查询订单状态"],"spot":["继续双边报价","调整库存与报价","暂停新增，核对资产"],"futures":["继续授权双边报价","放宽报价，调整对冲敞口","暂停新报价，监控原仓位"]}[c.channel]
	for i in range(3):
		var action:String=["keep","risk","pause"][i];var b:Button=host.btn(host.action_bar,labels[i],deliver.bind(action),"mandate_day_"+action,false);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if not s().daily.is_empty():
		var last:Dictionary=s().daily[-1];host.paragraph(host.content,"上一训练日："+last.detail+"\n资产变化 %+.2f USDT · 处置／交易成本 %.2f USDT"%[last.change,last.cost],14,host.MUTED)
	var limits:VBoxContainer=host.panel(host.content,Color("fffaf1"));host.paragraph(limits,c.limits,12,host.MUTED)
func deliver(action:String)->void:act({"kind":"day","action":action,"notify":notify.button_pressed,"work":read_work()})
func handoff()->void:
	host.paragraph(host.content,"六日账已完成。请将客户方案、授权、未决事项和验收证据交给交易与风控，提交后生成复盘。",18)
	work_form(host.content,"handoff")
	host.btn(host.content,"提交交接单，进入带教复盘",func():act({"kind":"handoff","work":read_work()}),"mandate_handoff",true)
func debrief(state:Dictionary)->void:
	var grade:Dictionary=model.grade(state);var c:Dictionary=model.scenario(state)
	var box:VBoxContainer=host.panel(host.content);host.text(box,"自动约束检查 / %d / 90"%grade.score,32,host.BLUE);host.text(box,grade.focus,20)
	for item in [["访谈事实覆盖","discovery"],["参数匹配","proposal"],["边界选项","boundaries"],["执行约束","delivery"]]:host.text(box,"%s · %d / %d"%[item[0],grade[item[1]],model.data.scoring[item[1]]],16)
	host.paragraph(box,"客户资产变化 %+.2f USDT\n月度服务毛利 %.2f USDT（独立核算）\n成交、待确认、风险敞口与实际成本按逐日账核对。"%[grade.equity_change,grade.service_margin],16)
	for warning in grade.warnings:host.paragraph(box,warning,14,Color("ad6073"))
	host.paragraph(box,"书面表达：未自动评分。下面的带教反馈单独保存，任何分数均不授予上岗资格。",16)
	show_work(host.content,state)
	review_form(state)
	host.btn(box,"导出完整委托复盘",export_report.bind(state),"mandate_export",true);host.btn(box,"返回客户委托列表",host.navigate.bind("mandates"),"mandate_home")
	for day in state.daily:
		var record:VBoxContainer=host.panel(host.content);host.text(record,"D%d · %s"%[day.day,day.event],18)
		host.paragraph(record,day.detail+"\n%s · 资产 %+.2f · 成本 %.2f USDT"%["已通知客户" if day.notify else "未通知客户",day.change,day.cost],14)
		host.text(record,"本步模拟交付指标："+("达到" if day.sla_met else "未达到或无法确认")+"；按异常窗口和实际证据人工复核。",14)
	host.paragraph(host.content,c.limits,12,host.MUTED)
func open_record(record:Dictionary)->void:
	host.remember_draft();review_target=record;host.page="mandate";host.build()
func records(parent:Node)->void:
	host.text(parent,"客户委托与带教记录",23)
	if not legacy_course.is_empty():
		host.paragraph(parent,"旧版存档只读保留；旧分数未评估书面交付，不能与新版自动检查比较。",15)
		for old in legacy_course.completed:host.btn(parent,"导出旧版记录 · "+legacy_model.scenario(old).name,export_report.bind(old),"legacy_export_"+str(old.case_id))
		if legacy_course.active.phase!="brief":host.btn(parent,"导出旧版未完成委托",export_report.bind(legacy_course.active),"legacy_active")
	if course.completed.is_empty():host.paragraph(parent,"完成 Uniswap、Alpha、现货或合约委托后，会在这里保留方案、谈判和交付账。",14,host.MUTED)
	for i in range(course.completed.size()-1,-1,-1):
		var record:Dictionary=course.completed[i];var box:VBoxContainer=host.panel(parent);host.text(box,"%s · 自动检查 %d / 90 · 带教反馈单列"%[model.scenario(record).name,model.grade(record).score],20);host.btn(box,"导出完整委托复盘",export_report.bind(record),"mandate_record_%d"%i);host.btn(box,"查看交付件并填写带教反馈",open_record.bind(record),"mandate_record_review_%d"%i)
func save()->void:
	remember();var error:String=store.write_course(course);host.toast("当前新渠道委托及草稿已保存。" if error.is_empty() else error)
func load_saved(backup:bool=false)->void:
	var result:Dictionary=store.restore_backup() if backup else store.read_course()
	if result.has("error"):host.toast(result.error);return
	review_target={};course=result.course;host.page="mandate";host.build();host.toast("新渠道委托已恢复；原现货会谈和机制课保留。")
func export_report(state:Dictionary)->void:
	var current= model if state.has("work") else legacy_model
	var c:Dictionary=current.scenario(state);var g:Dictionary=current.grade(state);var path:String="user://mm_bd_mandate_%s_%d_%d.md"%[c.id,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:host.toast("完整复盘导出失败。");return
	var report:String="# 完整委托复盘 · %s\n\n%s\n\n自动检查 %d 分；%s。虚构客户与教学参数，不是公司正式考核或报价。\n\n## 客户需求与谈判\n\n"%[c.name,c.subtitle,g.score,g.focus]
	if state.has("work"):
		report+="研修模式："+state.mode+"；参数变式："+str(state.variant)+"。\n\n## 学员五类交付件（待人工审核）\n\n```json\n"+JSON.stringify(state.work,"\t",true,true)+"\n```\n\n## 本地带教反馈（不构成正式资格认证）\n\n```json\n"+JSON.stringify(course.get("reviews",{}).get(review_key(state),{}),"\t",true,true)+"\n```\n\n"
	else:report+="旧版只读记录；原点击分数不衡量书面表达。\n\n"
	for note in state.notes:report+="- "+str(note)+"\n"
	report+="\n## 接受的方案\n\n```json\n"+JSON.stringify(state.proposal,"\t",true,true)+"\n```\n\n## 逐日交付账\n\n"
	for day in state.daily:report+="### D%d · %s\n\n```json\n%s\n```\n\n"%[day.day,day.event,JSON.stringify(day,"\t",true,true)]
	report+="## 复盘结果\n\n客户资产变化 %+.2f USDT；月度服务毛利 %.2f USDT，分别计算。\n\n"%[g.equity_change,g.service_margin]
	for warning in g.warnings:report+="- "+warning+"\n"
	report+="\n## 模拟边界\n\n"+c.limits+"\n\n## 官方机制参考（"+model.data.reviewed_at+" 核对）\n\n"
	for source in model.data.sources:report+="- [%s](%s)\n"%[source.title,source.url]
	file.store_string(report);file.close();host.toast("完整委托复盘已导出："+ProjectSettings.globalize_path(path))

func show_work(parent:Node,state:Dictionary)->void:
	for kind in ["memo","rationale","handoff"]:
		var box:VBoxContainer=host.panel(parent);host.text(box,{"memo":"访谈纪要","rationale":"方案说明","handoff":"内部交接"}[kind],19)
		for i in range(3):host.paragraph(box,model.data.rubric[kind][i]+"："+state.work[kind].get(str(i),"未提交"),15)
	for response in state.work.responses:
		var box:VBoxContainer=host.panel(parent);host.text(box,"谈判回应 · 第 %d 轮"%(int(response.round)+1),19)
		for i in range(3):host.paragraph(box,response.fields[str(i)],15)
	for i in state.work.notices.size():
		var box:VBoxContainer=host.panel(parent);host.text(box,"D%d · 通知原文与事件记录"%(i+1),19)
		for j in range(3):host.paragraph(box,state.work.notices[i][str(j)],15)
	for answer in state.answers:
		var turn:Dictionary=model.scenario(state).negotiation[int(answer.round)]
		host.paragraph(parent,"第 %d 轮选择：%s；机制反馈：%s"%[int(answer.round)+1,turn.options[int(answer.choice)],turn.feedback],14)
func review_key(state:Dictionary)->String:return JSON.stringify(state.commands,"",true,true).sha256_text()
func review_form(state:Dictionary)->void:
	var box:VBoxContainer=host.panel(host.content,Color("fffaf1"));host.text(box,"带教审阅 · 本地反馈，未经身份认证",21)
	var previous:Dictionary=course.get("reviews",{}).get(review_key(state),{})
	var author:=LineEdit.new();author.placeholder_text="审阅人姓名";author.text=previous.get("author","");box.add_child(author);host.controls.mandate_review_author=author
	var ratings:Dictionary={}
	for kind in ["memo","rationale","response","notice","handoff"]:
		host.text(box,{"memo":"访谈准确且标注未知","rationale":"方案可执行且成本透明","response":"回应诉求并说明边界","notice":"状态、影响、恢复及更新时间","handoff":"授权、责任及证据可追溯"}[kind],14)
		var select:=OptionButton.new();select.add_item("待审核");select.add_item("需返工");select.add_item("本次表达达到练习要求");select.selected=int(previous.get("ratings",{}).get(kind,0));box.add_child(select);ratings[kind]=select;host.controls["mandate_review_"+kind]=select
	var feedback:=TextEdit.new();feedback.custom_minimum_size.y=130;feedback.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;feedback.text=previous.get("feedback","");box.add_child(feedback);host.controls.mandate_review_feedback=feedback
	host.btn(box,"保存带教反馈（不改变自动分）",func():
		if author.text.strip_edges().is_empty() or feedback.text.strip_edges().length()<8 or author.text.length()>120 or feedback.text.length()>4000:host.toast("请填写审阅人及具体反馈；姓名最多 120 字，反馈 8–4000 字。");return
		var value:Dictionary={}
		for key in ratings:value[key]=ratings[key].selected
		var next:Dictionary=course.duplicate(true)
		if not next.has("reviews"):next.reviews={}
		next.reviews[review_key(state)]={"author":author.text,"feedback":feedback.text,"ratings":value,"reviewed_at":Time.get_datetime_string_from_system()}
		var error:String=store.write_course(next)
		if not error.is_empty():host.toast(error);return
		course=next;host.toast("本地带教反馈已保存；公司审批及真实客户能力仍须另行验收。")
	,"mandate_review_save")
