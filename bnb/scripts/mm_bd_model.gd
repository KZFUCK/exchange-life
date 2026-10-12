extends RefCounted

const DATA_PATH="res://data/mm_bd_cases_v1.json"
var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

func scenario(state:Dictionary)->Dictionary:return data.cases[int(state.case_id)]

func initial(case_id:int=0)->Dictionary:
	var c:Dictionary=data.cases[case_id]
	return {"case_id":case_id,"phase":"brief","asked":[],"proposal":{},"answers":[],"commands":[],"day":0,"mid":c.price,"cash":0.0,"tokens":0.0,"daily":[],"notes":[],"violations":0,"notifications":0}

func default_proposal(s:Dictionary)->Dictionary:
	var c:Dictionary=scenario(s)
	return {"spread":c.max_spread,"depth":c.depth,"capital":c.capital,"fee":ceilf(c.monthly_cost*1.45),"venues":c.venues,"risk":1}

func number(v:Variant)->bool:return (v is int or v is float) and is_finite(float(v))

func proposal_error(s:Dictionary,p:Dictionary)->String:
	var c:Dictionary=scenario(s)
	for k in ["spread","depth","capital","fee","venues","risk"]:
		if not number(p.get(k)):return "方案字段缺失或不是有限数值。"
	if p.spread<6 or p.spread>80 or p.depth<5000 or p.depth>40000 or p.fee<2000 or p.fee>12000:return "方案超出本次训练参数范围。"
	if p.capital<50000 or p.capital>c.capital:return "可用资金不能超过已访谈确认的客户额度。"
	if float(p.venues)!=floorf(float(p.venues)) or p.venues<1 or p.venues>3 or float(p.risk)!=floorf(float(p.risk)) or p.risk<0 or p.risk>1:return "场所数量或风险方案无效。"
	if p.depth*2*p.venues>p.capital*.8:return "双边深度 × 场所数量超过资金的 80%；请留出库存与风险缓冲。"
	return ""

func monthly_cost(s:Dictionary,p:Dictionary)->float:return float(scenario(s).monthly_cost)*float(p.venues)/float(scenario(s).venues)

func proposal_warnings(s:Dictionary,p:Dictionary)->Array[String]:
	var c:Dictionary=scenario(s);var messages:Array[String]=[]
	if p.spread<float(c.cost_bps)*2:messages.append("价差空间偏小：交易成本与逆向选择可能吞噬报价收益。")
	if p.depth<c.depth or p.venues<c.venues:messages.append("覆盖不足：客户要求的每场所每侧深度或场所数量未满足。")
	if p.spread>c.max_spread:messages.append("价差超过客户目标，需先重新约定交付标准。")
	if p.fee>c.budget:messages.append("服务费超过客户预算，需要调整范围或获得审批。")
	if p.fee<monthly_cost(s,p)*1.2:messages.append("服务报价接近／低于交付成本，应按公司审批流程确认。")
	if p.risk==0:messages.append("尚未约定限额、暂停、对冲与恢复条件，极端行情下风险更高。")
	return messages

func apply(s:Dictionary,command:Dictionary)->String:
	var candidate:Dictionary=s.duplicate(true)
	var error:String=apply_raw(candidate,command)
	if not error.is_empty():return error
	candidate.commands.append(command.duplicate(true));s.clear();s.merge(candidate,true);return ""

func apply_raw(s:Dictionary,cmd:Dictionary)->String:
	var kind:String=str(cmd.get("kind",""))
	if kind=="begin":
		if s.phase!="brief":return "会谈已开始。"
		s.phase="discovery";s.notes.append("客户："+str(scenario(s).intro));return ""
	if kind=="ask":
		if s.phase!="discovery":return "请在需求会谈阶段提问。"
		var id:String=str(cmd.get("id",""))
		if not scenario(s).facts.has(id) or id in s.asked:return "这个问题不存在或已记录。"
		s.asked.append(id);s.notes.append("客户："+str(scenario(s).facts[id]));return ""
	if kind=="draft":
		if s.phase!="discovery":return "当前不能拟定方案。"
		for id in ["metrics","funding","ownership"]:
			if not id in s.asked:return "先确认验收指标、资金安排与服务边界，再进入报价。"
		s.phase="proposal";return ""
	if kind=="propose":
		if s.phase!="proposal" or not cmd.get("proposal") is Dictionary:return "当前不能提交报价。"
		var p:Dictionary=cmd.proposal.duplicate(true);var error:String=proposal_error(s,p)
		if not error.is_empty():return error
		s.proposal=p;s.phase="negotiation";s.notes.append("客户："+str(scenario(s).objection));return ""
	if kind=="answer":
		if s.phase!="negotiation" or not number(cmd.get("choice")) or float(cmd.choice)!=floorf(float(cmd.choice)) or cmd.choice<0 or cmd.choice>2:return "当前不能回应谈判。"
		var choice:int=int(cmd.choice);s.answers.append(choice)
		if choice!=1:
			s.notes.append("风控导师：价格、成交量或损失兜底不是流动性服务的正常交付承诺。请重新界定边界。")
			return ""
		var c:Dictionary=scenario(s)
		if s.proposal.fee>c.budget or s.proposal.spread>c.max_spread or s.proposal.depth<c.depth or s.proposal.venues<c.venues:
			s.phase="proposal";s.notes.append("客户：边界说明可以接受，但报价、价差、深度或场所覆盖还没有匹配需求。请调整方案后再谈。")
			return ""
		s.phase="execution";s.cash=float(s.proposal.capital)*.5;s.tokens=float(s.proposal.capital)*.5/float(s.mid)
		s.notes.append("客户：接受以价差、真实双边深度与风险响应为交付目标。进入六个训练日。")
		return ""
	if kind=="day":
		if s.phase!="execution" or cmd.get("action") not in ["keep","risk","pause"] or not cmd.get("notify") is bool:return "交付动作无效。"
		simulate_day(s,str(cmd.action),bool(cmd.notify));return ""
	return "未知操作。"

func book(s:Dictionary,spread_override:float=-1.0)->Dictionary:
	if s.proposal.is_empty():return {"bids":[],"asks":[],"spread":0.0,"bid_depth":0.0,"ask_depth":0.0}
	var p:Dictionary=s.proposal
	var spread:float=float(p.spread) if spread_override<0 else spread_override
	var bid_depth:float=minf(float(p.depth),float(s.cash)*.8/float(p.venues))
	var ask_depth:float=minf(float(p.depth),float(s.tokens)*float(s.mid)*.8/float(p.venues))
	var bids:Array=[];var asks:Array=[]
	for i in range(3):
		var distance:float=spread*.5+float(i)*(100.0-spread*.5)*.5
		bids.append({"price":float(s.mid)*(1-distance/10000.0),"notional":bid_depth/3})
		asks.append({"price":float(s.mid)*(1+distance/10000.0),"notional":ask_depth/3})
	return {"bids":bids,"asks":asks,"spread":spread,"bid_depth":bid_depth,"ask_depth":ask_depth}

func equity(s:Dictionary)->float:return float(s.cash)+float(s.tokens)*float(s.mid)

func walk_book(quotes:Dictionary,side:String,amount:float,mid:float)->Dictionary:
	var remaining:float=maxf(0,amount);var filled:float=0.0;var qty:float=0.0
	for row in quotes[side]:
		var take:float=minf(remaining,float(row.notional));filled+=take;qty+=take/float(row.price);remaining-=take
		if remaining<=.000001:break
	var vwap:float=filled/qty if qty>0 else 0.0
	return {"filled":filled,"quantity":qty,"vwap":vwap,"complete":remaining<=.000001,"slippage_bps":absf(vwap/mid-1)*10000 if qty>0 else 0.0}

func simulate_day(s:Dictionary,action:String,notify:bool)->void:
	var c:Dictionary=scenario(s);var event:Dictionary=c.events[int(s.day)];var p:Dictionary=s.proposal
	var start_equity:float=equity(s);s.mid=float(s.mid)*(1+float(event["return"]))
	var paused:bool=action=="pause" or bool(event.outage)
	var spread:float=float(p.spread)*(1.8 if action=="risk" else 1.0)
	var quotes:Dictionary=book(s,spread);var executed:float=0.0;var cost:float=0.0;var hedge_cost:float=0.0;var execution_price:float=0.0;var slippage:float=0.0
	if bool(event.outage) and action=="keep":s.violations+=1
	if not paused:
		var buying:bool=float(event.flow)<0
		var fill:Dictionary=walk_book(quotes,"bids" if buying else "asks",absf(float(event.flow))*float(p.depth)*.7,float(s.mid))
		executed=fill.filled;execution_price=fill.vwap;slippage=fill.slippage_bps
		var qty:float=fill.quantity
		cost=executed*(float(c.cost_bps)+float(event.toxic_bps))/10000.0
		if buying:s.cash=float(s.cash)-executed-cost;s.tokens=float(s.tokens)+qty
		else:s.cash=float(s.cash)+executed-cost;s.tokens=float(s.tokens)-qty
	if action=="risk" and p.risk==1 and not event.outage:
		var total:float=equity(s);var target:float=total*.5/float(s.mid);var delta:float=target-float(s.tokens)
		s.cash=float(s.cash)-delta*float(s.mid);s.tokens=target
		hedge_cost=absf(delta*float(s.mid))*3/10000.0;s.cash=float(s.cash)-hedge_cost
	var value:float=equity(s);var inventory:float=float(s.tokens)*float(s.mid)/maxf(value,.01)
	if inventory>.72 or inventory<.28:s.violations+=1
	if notify:s.notifications+=1
	var met:bool=not paused and spread<=float(c.max_spread) and float(quotes.bid_depth)>=float(c.depth)*.95 and float(quotes.ask_depth)>=float(c.depth)*.95 and p.venues>=c.venues
	var record:Dictionary={"day":int(s.day)+1,"event":event.title,"action":action,"notify":notify,"return":event["return"],"outage":event.outage,"mid":s.mid,"cash":s.cash,"tokens":s.tokens,"equity":value,"change":value-start_equity,"spread":spread,"executed":executed,"execution_price":execution_price,"slippage_bps":slippage,"cost":cost,"hedge_cost":hedge_cost,"bid_depth":quotes.bid_depth,"ask_depth":quotes.ask_depth,"inventory":inventory,"sla_met":met,"paused":paused}
	s.daily.append(record);s.day+=1
	s.notes.append("交付日 %d：%s；%s。"%[s.day,event.title,"已向客户说明处置与恢复条件" if notify else "尚未向客户发送状态说明"])
	if s.day==6:s.phase="debrief"

func grade(s:Dictionary)->Dictionary:
	var weights:Dictionary=data.scoring
	var discovery:int=roundi(float(s.asked.size())/6*float(weights.discovery))
	var proposal:int=0;var boundary:int=0;var delivery:int=0;var communication:int=0;var warnings:Array[String]=[]
	if not s.proposal.is_empty():
		warnings=proposal_warnings(s,s.proposal);proposal=maxi(0,int(weights.proposal)-roundi(warnings.size()*float(weights.proposal)/5))
	var good_answer:bool=false;var bad:int=0
	for answer in s.answers:
		if int(answer)==1:good_answer=true
		else:bad+=1
	if good_answer:boundary=maxi(0,int(weights.boundaries)-roundi(bad*float(weights.boundaries)*.28))
	if not s.daily.is_empty():
		var careful:int=0
		for row in s.daily:
			if (absf(float(row["return"]))>=.06 and row.action in ["risk","pause"]) or (absf(float(row["return"]))<.06 and not row.outage and row.action in ["keep","risk"]) or (row.outage and row.action=="pause"):careful+=1
		delivery=maxi(0,roundi(float(careful)/6*float(weights.delivery))-roundi(float(s.violations)*float(weights.delivery)*.2))
		communication=roundi(float(s.notifications)/6*float(weights.communication))
	var score:int=discovery+proposal+boundary+delivery+communication
	return {"score":score,"discovery":discovery,"proposal":proposal,"boundaries":boundary,"delivery":delivery,"communication":communication,"warnings":warnings,"focus":"边界与异常沟通需复训" if boundary<int(weights.boundaries) or s.violations>0 else ("继续练习方案取舍" if proposal<float(weights.proposal)*.8 else "可进入带教讨论"),"equity_change":equity(s)-float(s.proposal.get("capital",0)),"service_margin":float(s.proposal.get("fee",0))-monthly_cost(s,s.proposal) if not s.proposal.is_empty() else 0}

func same(a:Variant,b:Variant)->bool:
	if number(a) and number(b):return absf(float(a)-float(b))<=.0000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in a:
			if not b.has(k) or not same(a[k],b[k]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same(a[i],b[i]):return false
		return true
	return a==b

func valid(s:Variant)->bool:
	if not s is Dictionary or not number(s.get("case_id")) or int(s.case_id)!=float(s.case_id) or s.case_id<0 or s.case_id>=data.cases.size():return false
	if not s.get("commands") is Array or s.commands.size()>60:return false
	var replay:Dictionary=initial(int(s.case_id))
	for cmd in s.commands:
		if not cmd is Dictionary or not apply_raw(replay,cmd).is_empty():return false
		replay.commands.append(cmd.duplicate(true))
	return same(replay,s)

func valid_course(course:Variant)->bool:
	if not course is Dictionary or not valid(course.get("active")) or not course.get("completed") is Array or course.completed.size()>30:return false
	if not course.get("draft") is Dictionary:return false
	if not course.draft.is_empty() and not proposal_error(course.active,course.draft).is_empty():return false
	for item in course.completed:
		if not valid(item) or item.phase!="debrief":return false
	return true
