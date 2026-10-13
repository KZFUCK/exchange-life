extends RefCounted
var host:Control
var model:RefCounted
var fields:Dictionary={}
var lab_output:Label
var values:Dictionary={}
func _init(main:Control,channels:RefCounted)->void:host=main;model=channels
func catalog(parent:Node)->void:
	host.text(parent,"四渠道研修 / 从机制到客户沟通",25)
	host.paragraph(parent,"Uniswap、币安 Alpha、交易所现货、交易所合约 · 每课 4 个机制主题 + 计算实验 + 4 道情景题。",15,host.MUTED)
	var cards:=GridContainer.new();cards.columns=2;cards.add_theme_constant_override("h_separation",14);cards.add_theme_constant_override("v_separation",14);parent.add_child(cards)
	for i in model.data.modules.size():
		var m:Dictionary=model.data.modules[i];var box:VBoxContainer=host.panel(cards)
		host.text(box,m.tag,11,host.BLUE);host.text(box,m.title,21);host.paragraph(box,m.summary,15)
		var result:Dictionary=model.grade(model.current(i))
		host.text(box,"本轮 %d / %d 题 · %s"%[result.answered,result.total,"完成 · %d 分"%result.score if result.complete else "进行中" if result.answered>0 else "尚未开始"],13,host.TEAL)
		host.btn(box,"进入渠道课  →",open.bind(i),"channel_%d"%i,true)
		host.btn(box,"进入完整客户委托  →",client_flow.bind(i),"channel_client_%d"%i)
	host.paragraph(parent,"四渠道均有客户业务流程。现货在研修主页；Uniswap、Alpha 与合约在“客户委托”。机制课可先学，再进入情景研修。",13,host.MUTED)
	if not model.boot_error.is_empty():host.paragraph(parent,model.boot_error,14,Color("ad6073"))
func open(index:int)->void:
	var error:String=model.select(index)
	if not error.is_empty():host.toast(error);return
	host.remember_draft();host.page="channel";host.build();host.toast("渠道课回答自动保存。先学习机制，再完成客户情景测验。")
func build()->void:
	var m:Dictionary=model.data.modules[int(model.state.selected)]
	var top:=HBoxContainer.new();host.content.add_child(top);var heading:=VBoxContainer.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(heading)
	host.text(heading,m.tag+" / 流動性フィールドノート",11,host.BLUE);host.text(heading,m.title,27);host.paragraph(heading,m.summary,16)
	host.btn(heading,"返回渠道课程",host.navigate.bind("channels"),"channel_back")
	host.btn(heading,"进入完整客户委托",client_flow.bind(int(model.state.selected)),"channel_client_start",true)
	host.portrait(top,0,160)
	var lessons:=GridContainer.new();lessons.columns=2;lessons.add_theme_constant_override("h_separation",14);lessons.add_theme_constant_override("v_separation",14);host.content.add_child(lessons)
	for lesson in m.lessons:
		var card:VBoxContainer=host.panel(lessons);host.text(card,lesson.title,19,host.BLUE);host.paragraph(card,lesson.text,15)
	var discovery:VBoxContainer=host.panel(host.content,Color("fffaf1"));host.text(discovery,"客户会谈 / 先确认这三件事",20)
	for question in m.discovery:host.paragraph(discovery,"＋ "+question,15)
	host.paragraph(discovery,m.boundary,14,Color("ad6073"))
	build_lab(m.id)
	build_quiz(m)
	var source_box:VBoxContainer=host.panel(host.content);host.text(source_box,"参考来源 / 核对日期 "+model.data.reviewed_at,17)
	for source in m.sources:host.btn(source_box,source.title,func():OS.shell_open(source.url))
	host.paragraph(source_box,"平台功能与条款可能变更；客户报价前复核当前官方规则和公司 SOP。计算器金额、费率和 MMR 是教学参数。",12,host.MUTED)
func field(parent:Node,key:String,title:String,min_:float,max_:float,step_:float,initial:float,suffix:String)->void:
	var row:=HBoxContainer.new();parent.add_child(row);var label:Label=host.text(row,title,14);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var spin:=SpinBox.new();spin.min_value=min_;spin.max_value=max_;spin.step=step_;spin.value=values.get(str(model.state.selected)+key,initial);spin.suffix=suffix;spin.custom_minimum_size=Vector2(175,40);row.add_child(spin)
	fields[key]=spin;host.controls["lab_"+key]=spin
	spin.value_changed.connect(func(v):values[str(model.state.selected)+key]=v;refresh_lab())
func build_lab(id:String)->void:
	fields.clear();var box:VBoxContainer=host.panel(host.content,Color("eef1fb"));host.text(box,"机制实验 / 调整参数，观察取舍",21)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",24);box.add_child(row)
	var input:=VBoxContainer.new();input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(input)
	lab_output=host.paragraph(row,"",16,host.BLUE);lab_output.size_flags_horizontal=Control.SIZE_EXPAND_FILL;lab_output.custom_minimum_size.x=280
	match id:
		"uniswap":
			field(input,"capital","初始头寸价值",1000,1000000,1000,100000,"USDT")
			field(input,"entry","初始价格",.1,10,.1,1,"USDT")
			field(input,"lower","固定区间下界",.1,10,.1,.8,"USDT")
			field(input,"upper","固定区间上界",.1,10,.1,1.2,"USDT")
			field(input,"price","观察价格",.1,10,.1,1.3,"USDT")
			host.paragraph(box,"基础 v3 / 标准 v4 固定区间头寸，token 精度归一，不模拟 ticks 舍入、hook 自定义逻辑、手续费、gas 或再平衡。持币基准使用初始头寸实际两币数量，非强制 50/50。",12,host.MUTED)
		"alpha":
			field(input,"quoted","报价预计接收",10,1000000,10,10000,"TOKEN")
			field(input,"tolerance","接收数量容忍度",0,30,.1,1,"%")
			field(input,"actual","执行前预计接收",0,1000000,10,9800,"TOKEN")
			field(input,"fee","示例接收币手续费",0,500,1,10,"bps")
			field(input,"gas","另计网络成本",0,1000,1,3,"USDT")
			host.paragraph(box,"通用数量保护示意：先对费用前接收量检查下限，再示例扣接收币手续费；并非 Alpha 实际扣费或撮合算法。网络成本另列，不承诺失败免 gas。真实最低接收、扣费顺序和订单状态须逐单核对。",12,host.MUTED)
		"spot":
			field(input,"request","模拟市价买入预算",1000,200000,1000,20000,"USDT")
			field(input,"depth","三档卖单名义总额",1000,200000,1000,15000,"USDT")
			field(input,"step","每档偏离中间价步长",1,30,1,10,"bps")
			host.paragraph(box,"中间价固定 1 USDT；三档分别 +1、+2、+3 倍步长，各占总挂单名义额 1/3。按实际代币数量计算均价，深度耗尽只部分成交；不计手续费。",12,host.MUTED)
		"futures":
			field(input,"notional","初始名义仓位",1000,1000000,1000,100000,"USDT")
			field(input,"margin","独立分配保证金",100,500000,100,20000,"USDT")
			field(input,"entry","入场价格",.1,10,.1,1,"USDT")
			field(input,"mark","结算观察标记价",.1,10,.1,1.2,"USDT")
			field(input,"funding","单次资金费率",-100,100,1,1,"bps")
			field(input,"mmr","固定示例维持保证金率",.1,20,.1,.5,"%")
			field(input,"fee","观察时名义额的成本",0,100,1,4,"bps")
			var side:=OptionButton.new();side.add_item("空仓：观察价格上涨压力");side.add_item("多仓：观察价格下跌压力");side.selected=int(values.get("side",0));input.add_child(side);fields.side=side;host.controls.lab_side=side
			side.item_selected.connect(func(v):values.side=v;refresh_lab())
			host.paragraph(box,"单仓 USDT 线性永续快照，正资金费多付空收；已发生该次结算后计算保证金压力。固定 MMR 无档位、全仓抵押品、阶梯减仓与强平费，不能作为实盘强平引擎或价格。合约做市、币本位和交割合约需另外配置。",12,host.MUTED)
	refresh_lab()
func val(key:String)->float:return float(fields[key].value)
func refresh_lab()->void:
	if not is_instance_valid(lab_output):return
	var id:String=model.data.modules[int(model.state.selected)].id;var r:Dictionary
	match id:
		"uniswap":
			r=model.lp_lab(val("capital"),val("entry"),val("price"),val("lower"),val("upper"))
			if r.has("error"):lab_output.text=r.error;return
			lab_output.text="%s\n\n代币 %.2f\n报价资产 %.2f USDT\n头寸价值 %.2f USDT\n持币基准 %.2f USDT\n相对持币 %.2f USDT（%.2f%%）\n\n手续费与执行成本尚未计入。"%["区间内 · 活跃" if r.active else "区间外 · 不活跃",r.token,r.quote,r.value,r.hold,r.difference,r.relative_pct]
		"alpha":
			r=model.alpha_lab(val("quoted"),val("tolerance"),val("actual"),val("fee"),val("gas"))
			lab_output.text="示例最低接收 %.2f TOKEN\n执行前预计接收 %.2f TOKEN\n\n%s\n示例费后数量 %.2f TOKEN\n网络成本另计 %.2f USDT\n\n实际处理/失败/到账状态须查询确认。"%[r.minimum,val("actual"),"达到示例数量下限，仍不保证成交" if r.passes else "低于保护下限 · 不通过示例检查",r.net_qty,r.gas]
		"spot":
			r=model.spot_lab(val("request"),val("depth"),val("step"))
			lab_output.text="%s\n\n实际消耗 %.2f USDT\n未成交预算 %.2f USDT\n成交均价 %.6f\n相对中间价滑点 %.2f bps\n\n挂单深度与真实成交额分别报告。"%["模拟足额成交" if r.complete else "深度不足 · 仅部分成交",r.spent,r.unfilled,r.vwap,r.slippage_bps]
		"futures":
			r=model.futures_lab(val("notional"),val("margin"),val("entry"),val("mark"),val("funding"),val("mmr"),-1 if fields.side.selected==0 else 1,val("fee"))
			lab_output.text="初始杠杆 %.2f 倍\n盯市损益 %.2f USDT\n单次资金费现金流 %+.2f USDT\n示例成本 %.2f USDT\n保证金余额 %.2f USDT\n示例维持要求 %.2f USDT\n\n%s\n\n正现金流为收入，负值为支出。"%[r.initial_leverage,r.pnl,r.funding,r.fee,r.equity,r.maintenance,"触及示例维持要求 · 升级风控" if r.breach else "快照高于示例维持要求，仍需监控"]
func build_quiz(m:Dictionary)->void:
	var run:Dictionary=model.current();var result:Dictionary=model.grade(run)
	var box:VBoxContainer=host.panel(host.content);host.text(box,"客户情景测验 / %d / %d 题"%[result.answered,result.total],21)
	host.paragraph(box,"按首次回答记录本轮成绩；每题立即显示带教解释。可重练，旧轮次仍保留。回答自动保存到独立渠道课存档。",13,host.MUTED)
	for i in run.answers.size():
		var q:Dictionary=m.quiz[i];var correct:bool=int(run.answers[i])==int(q.correct)
		host.paragraph(box,("✓ " if correct else "需复训 · ")+q.prompt,16,host.TEAL if correct else Color("ad6073"))
		host.paragraph(box,"你的回答："+q.options[int(run.answers[i])]+"\n带教解释："+q.explanation,14)
	if not result.complete:
		var q:Dictionary=m.quiz[result.answered];host.paragraph(box,q.prompt,21)
		for i in q.options.size():host.btn(box,q.options[i],respond.bind(i),"channel_answer_%d"%i)
	else:
		host.text(box,"本轮 %d / 100 · %d / %d 题正确"%[result.score,result.correct,result.total],26,host.BLUE)
		host.paragraph(box,"完成机制测验。分数供带教讨论；计算实验和情景题不能证明已具备真实交易交付能力。",14)
		host.btn(box,"导出本轮带教记录",export_review,"channel_export",true)
		host.btn(box,"再练一轮（保留旧记录）",retry,"channel_retry")
func respond(choice:int)->void:
	var error:String=model.answer(choice)
	if not error.is_empty():host.toast(error);return
	host.build();host.toast("渠道课回答已保存；请阅读本题带教解释。")
	var id:String="channel_export" if model.grade(model.current()).complete else "channel_answer_0"
	host.call_deferred("reveal_channel_control",id)
func retry()->void:
	var error:String=model.retry()
	if not error.is_empty():host.toast(error);return
	host.build();host.toast("已开始新一轮，旧回答仍保留。")
func export_review()->void:
	var m:Dictionary=model.data.modules[int(model.state.selected)];var run:Dictionary=model.current();var result:Dictionary=model.grade(run)
	var path:String="user://mm_bd_channel_%s_%d.md"%[m.id,Time.get_unix_time_from_system()]
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f==null:host.toast("导出失败。请检查目录权限。");return
	var copy:String="# 渠道课带教复盘 · %s\n\n本轮 %d/100；%d/%d 题正确。虚构练习，不是正式考核。\n\n"%[m.title,result.score,result.correct,result.total]
	for i in run.answers.size():copy+="## %d. %s\n\n回答：%s\n\n带教解释：%s\n\n"%[i+1,m.quiz[i].prompt,m.quiz[i].options[int(run.answers[i])],m.quiz[i].explanation]
	copy+="## 服务边界\n\n"+m.boundary+"\n\n## 参考（"+model.data.reviewed_at+" 核对）\n\n"
	for source in m.sources:copy+="- [%s](%s)\n"%[source.title,source.url]
	f.store_string(copy);f.close();host.toast("渠道复盘已导出："+ProjectSettings.globalize_path(path))

func client_flow(index:int)->void:
	if index==2:host.choose_case(0)
	else:host.mandate_view.choose([0,1,0,2][index])
