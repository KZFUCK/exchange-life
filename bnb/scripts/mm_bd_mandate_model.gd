extends "res://scripts/mm_bd_model.gd"
const MANDATE_DATA_PATH="res://data/mm_bd_mandates_v1.json"
func _init()->void:data=JSON.parse_string(FileAccess.get_file_as_string(MANDATE_DATA_PATH))
func initial(case_id:int=0)->Dictionary:
	var s:Dictionary=super.initial(case_id)
	s.merge({"round":0,"cash":0.0,"tokens":0.0,"lp_L":0.0,"lp_tokens":0.0,"lp_quote":0.0,"lower":0.0,"upper":0.0,"hold_tokens":0.0,"hold_quote":0.0,"gas_used":0.0,"fees_earned":0.0,"pending":{},"reserved":0.0,"position":0.0,"entry":0.0,"margin":0.0,"funding_total":0.0,"trade_cost":0.0,"liquidations":0})
	return s
func default_proposal(s:Dictionary)->Dictionary:
	var c:Dictionary=scenario(s);var p:Dictionary={"capital":c.capital,"fee":ceilf(c.monthly_cost*1.45),"risk":1}
	match c.channel:
		"uniswap":p.merge({"width_pct":20.0,"reserve_pct":20.0,"gas_budget":400.0})
		"alpha":p.merge({"max_order":8000.0,"daily_limit":15000.0,"slippage_pct":1.0,"reserve_pct":20.0,"gas_budget":400.0})
		"futures":p.merge({"spread":30.0,"depth":10000.0,"spot_pct":60.0,"margin_pct":30.0,"hedge_pct":100.0,"leverage_cap":3.0})
	return p
func proposal_error(s:Dictionary,p:Dictionary)->String:
	var c:Dictionary=scenario(s)
	if p.size()!=c.fields.size()+1:return "方案字段不匹配当前渠道。"
	for field in c.fields:
		var k:String=field[0]
		if not number(p.get(k)) or float(p[k])<float(field[2]) or float(p[k])>float(field[3]):return "方案中的“%s”缺失或超出训练范围。"%field[1]
	if not number(p.get("risk")) or float(p.risk)!=floorf(float(p.risk)) or int(p.risk) not in [0,1]:return "风险授权选择无效。"
	if p.capital>c.capital:return "客户资金不能超出确认额度。"
	if c.channel in ["uniswap","alpha"] and p.gas_budget>400:return "网络成本预算不能超出客户授权的 400 USDT。"
	if c.channel=="uniswap" and p.capital*p.reserve_pct/100<p.gas_budget:return "现金储备不足以覆盖授权 gas 上限。"
	if c.channel=="alpha" and (p.max_order>p.daily_limit or p.max_order>p.capital*(1-p.reserve_pct/100)):return "单笔额度不能超过每日额度或非储备现金。"
	if c.channel=="futures":
		if p.spot_pct+p.margin_pct>90:return "现货与保证金分配合计不能超过资金的 90%。"
		if p.spot_pct*p.hedge_pct/100>p.margin_pct*p.leverage_cap*data.simulation.quote_buffer:return "初始对冲名义额超过保证金杠杆缓冲上限。"
		if p.depth*2>p.capital*p.margin_pct/100*p.leverage_cap*data.simulation.quote_buffer:return "双边合约深度超过保证金支持的名义额度。"
	return ""
func monthly_cost(s:Dictionary,_p:Dictionary)->float:return float(scenario(s).monthly_cost)
func proposal_warnings(s:Dictionary,p:Dictionary)->Array[String]:
	var c:Dictionary=scenario(s);var out:Array[String]=[]
	if p.fee>c.budget:out.append("月度服务费超过客户预算。")
	if p.fee<c.monthly_cost*1.2:out.append("报价缺少成本缓冲；本练习未授予低价审批。")
	if int(p.risk)!=1:out.append("须明确调整／增减仓、暂停、对账和恢复条件。")
	match c.channel:
		"uniswap":
			if p.width_pct<20 or p.width_pct>35:out.append("区间半宽需满足客户确认的 20%–35%。")
			if p.reserve_pct<20 or p.gas_budget<200:out.append("需要至少 20% 储备与 200 USDT 网络预算。")
		"alpha":
			if p.max_order>8000 or p.daily_limit>15000:out.append("委托额度超出客户业务目标。")
			if p.slippage_pct>1:out.append("接收容忍度不能超过已确认的 1%。")
			if p.reserve_pct<20 or p.gas_budget<100:out.append("现金储备或网络预算未覆盖服务需要。")
		"futures":
			if p.spread>30 or p.depth<10000:out.append("正常价差或双边名义深度未匹配客户需求。")
			if p.spot_pct<50 or p.spot_pct>65 or p.margin_pct<25 or p.hedge_pct<80:out.append("初始现货、保证金或对冲范围未匹配客户需求。")
			if p.leverage_cap>4:out.append("杠杆上限超过客户确认的 4 倍。")
	return out
func apply_raw(s:Dictionary,cmd:Dictionary)->String:
	var c:Dictionary=scenario(s);var kind:String=str(cmd.get("kind",""))
	match kind:
		"begin":
			if s.phase!="brief":return "委托已经开始。"
			s.phase="discovery";s.notes.append("客户："+c.intro)
		"ask":
			var id:String=str(cmd.get("id",""))
			if s.phase!="discovery" or not c.facts.has(id) or id in s.asked:return "当前问题无效或已记录。"
			s.asked.append(id);s.notes.append("客户："+c.facts[id])
		"draft":
			if s.phase!="discovery" or s.asked.size()!=6:return "先确认六项需求、资金与授权，再进入渠道报价。"
			s.phase="proposal"
		"propose":
			if s.phase!="proposal" or not cmd.get("proposal") is Dictionary:return "当前不能提交方案。"
			var error:String=proposal_error(s,cmd.proposal)
			if not error.is_empty():return error
			s.proposal=cmd.proposal.duplicate(true);s.round=0;s.phase="negotiation";s.notes.append("方案已提交；进入三轮客户异议处理。")
		"revise":
			if s.phase!="negotiation":return "当前不能返回报价。"
			s.phase="proposal";s.round=0;s.notes.append("BD 主动返回方案工坊，调整范围与报价。")
		"answer":
			if s.phase!="negotiation" or not number(cmd.get("choice")) or cmd.choice!=floorf(float(cmd.choice)) or cmd.choice<0 or cmd.choice>2:return "当前谈判回答无效。"
			var turn:Dictionary=c.negotiation[int(s.round)];var good:bool=int(cmd.choice)==int(turn.correct)
			s.answers.append({"round":int(s.round),"choice":int(cmd.choice)});s.notes.append("谈判 %d：%s；带教：%s"%[int(s.round)+1,turn.options[int(cmd.choice)],turn.feedback])
			if not good:return ""
			s.round+=1
			if s.round==3:
				var warnings:Array[String]=proposal_warnings(s,s.proposal)
				if not warnings.is_empty():s.phase="proposal";s.round=0;s.notes.append("客户：请调整方案后再谈。"+"；".join(warnings))
				else:activate(s);s.phase="execution";s.notes.append("客户接受服务范围、资金授权和异常条件；开始六个训练日。")
		"day":
			if s.phase!="execution" or s.day>=6 or cmd.get("action") not in ["keep","risk","pause"] or not cmd.get("notify") is bool:return "交付操作无效。"
			simulate_day(s,str(cmd.action),bool(cmd.notify))
		_:return "未知委托操作。"
	return ""
func lp_amounts(liquidity:float,price:float,lower:float,upper:float)->Dictionary:
	var a:float=sqrt(lower);var b:float=sqrt(upper);var p:float=sqrt(clampf(price,lower,upper))
	return {"token":liquidity*(b-p)/(p*b),"quote":liquidity*(p-a)}
func set_lp(s:Dictionary,value:float)->void:
	s.lower=s.mid*(1-s.proposal.width_pct/100);s.upper=s.mid*(1+s.proposal.width_pct/100)
	var unit:Dictionary=lp_amounts(1,float(s.mid),float(s.lower),float(s.upper))
	s.lp_L=value/(unit.token*s.mid+unit.quote);mark_lp(s)
func mark_lp(s:Dictionary)->void:
	var amounts:Dictionary=lp_amounts(float(s.lp_L),float(s.mid),float(s.lower),float(s.upper));s.lp_tokens=amounts.token;s.lp_quote=amounts.quote
func activate(s:Dictionary)->void:
	var p:Dictionary=s.proposal;s.cash=p.capital
	match scenario(s).channel:
		"uniswap":
			s.cash=p.capital*p.reserve_pct/100;set_lp(s,p.capital-s.cash);s.hold_tokens=s.lp_tokens;s.hold_quote=s.lp_quote+s.cash
		"futures":
			s.tokens=p.capital*p.spot_pct/100/s.mid;s.margin=p.capital*p.margin_pct/100;s.cash=p.capital-s.tokens*s.mid-s.margin
			s.position=-s.tokens*p.hedge_pct/100;s.entry=s.mid
func unrealized(s:Dictionary)->float:return s.position*(s.mid-s.entry)
func equity(s:Dictionary)->float:return s.cash+(s.tokens+s.lp_tokens)*s.mid+s.lp_quote+s.margin+unrealized(s)
func margin_equity(s:Dictionary)->float:return s.margin+unrealized(s)
func maintenance(s:Dictionary)->float:return absf(s.position)*s.mid*data.simulation.mmr_pct/100
func available(s:Dictionary)->float:return maxf(0,s.cash-s.reserved-s.proposal.capital*s.proposal.get("reserve_pct",0)/100)
func book(s:Dictionary,spread_override:float=-1)->Dictionary:
	var p:Dictionary=s.proposal;var spread:float=p.spread if spread_override<0 else spread_override
	var max_notional:float=maxf(0,margin_equity(s))*p.leverage_cap*data.simulation.quote_buffer
	var current:float=s.position*s.mid
	var bids:Array=[];var asks:Array=[]
	var bid_depth:float=minf(p.depth,maxf(0,max_notional-current)) if margin_equity(s)>maintenance(s) else 0.0
	var ask_depth:float=minf(p.depth,maxf(0,max_notional+current)) if margin_equity(s)>maintenance(s) else 0.0
	for i in range(3):
		var distance:float=spread/2+i*(100-spread/2)/2
		bids.append({"price":s.mid*(1-distance/10000),"notional":bid_depth/3});asks.append({"price":s.mid*(1+distance/10000),"notional":ask_depth/3})
	return {"bids":bids,"asks":asks,"spread":spread,"bid_depth":bid_depth,"ask_depth":ask_depth}
func position_trade(s:Dictionary,qty:float,price:float,cost_bps:float=-1)->Dictionary:
	if cost_bps<0:cost_bps=float(data.simulation.trade_fee_bps)
	var old:float=s.position;var realized:float=0.0
	if old*qty<0:realized=minf(absf(old),absf(qty))*(price-s.entry)*signf(old)
	var next:float=old+qty
	if old==0 or old*qty>0:s.entry=(absf(old)*s.entry+absf(qty)*price)/maxf(absf(next),.0000001)
	elif old*next<0:s.entry=price
	if absf(next)<.0000001:next=0.0;s.entry=0.0
	var fee:float=absf(qty)*price*cost_bps/10000;s.position=next;s.margin+=realized-fee;s.trade_cost+=fee
	return {"realized":realized,"fee":fee,"notional":absf(qty)*price}
func check_pressure(s:Dictionary)->bool:
	if absf(s.position)>.0000001 and margin_equity(s)<=maintenance(s):
		position_trade(s,-s.position,s.mid,float(data.simulation.pressure_close_bps));s.liquidations+=1;s.violations+=1
		return true
	return false
func simulate_day(s:Dictionary,action:String,notify:bool)->void:
	var c:Dictionary=scenario(s);var event:Dictionary=c.events[int(s.day)];var start:float=equity(s);var cost_before:float=s.trade_cost;var gas_before:float=s.gas_used
	s.mid*=1+float(event.price_return)
	var row:Dictionary={"day":int(s.day)+1,"event":event.title,"action":action,"notify":notify,"price":s.mid,"cost":0.0,"executed":0.0,"sla_met":false,"detail":""}
	match c.channel:
		"uniswap":simulate_uni(s,event,action,row)
		"alpha":simulate_alpha(s,event,action,row)
		"futures":simulate_futures(s,event,action,row)
	if notify:s.notifications+=1
	row.cost=float(s.trade_cost)-cost_before+float(s.gas_used)-gas_before
	row.equity=equity(s);row.change=row.equity-start;row.violations=s.violations
	s.daily.append(row);s.day+=1;s.notes.append("D%d · %s · %s · %s"%[s.day,event.title,row.detail,"已同步客户及恢复条件" if notify else "未同步客户"])
	if s.day==6:s.phase="debrief"
func simulate_uni(s:Dictionary,e:Dictionary,action:String,row:Dictionary)->void:
	var active_before:bool=s.mid/(1+float(e.price_return))>=s.lower and s.mid/(1+float(e.price_return))<s.upper
	mark_lp(s);var active_after:bool=s.mid>=s.lower and s.mid<s.upper
	var fees:float=0.0;var gas:float=0.0;var swap_cost:float=0.0;var detail:String="保留固定区间。"
	if e.outage:
		if action!="pause":s.violations+=1
		detail="链状态异常，冻结新增调整；LP 仍随池价变化，需核对原头寸。"
	elif action=="pause":detail="暂停新增调整和本轮费用估算；原 LP 头寸仍在池内。"
	else:
		if active_before and active_after:fees=float(e.volume)*float(data.simulation.lp_fee_bps)/10000;s.cash+=fees;s.fees_earned+=fees
		if action=="risk":
			if int(s.proposal.risk)!=1 or s.gas_used+e.gas>s.proposal.gas_budget or s.cash<e.gas:
				s.violations+=1;detail="调整权限或网络预算不足；保留原头寸并升级审批。"
			else:
				gas=float(e.gas);var value:float=s.lp_tokens*s.mid+s.lp_quote;swap_cost=value*float(data.simulation.trade_fee_bps)/10000;s.cash-=gas;s.gas_used+=gas;s.trade_cost+=swap_cost;set_lp(s,value-swap_cost)
				active_after=true;detail="在授权与成本上限内重设区间，记录交换成本与 gas。"
		elif not active_after:detail="已出区间，当前头寸不活跃；仍保留原两币资产。"
	row.merge({"lower":s.lower,"upper":s.upper,"lp_tokens":s.lp_tokens,"lp_quote":s.lp_quote,"reserve_cash":s.cash,"active":active_after,"fees":fees,"gas":gas,"cost":gas+swap_cost,"hold_equity":s.hold_tokens*s.mid+s.hold_quote,"relative_hold":equity(s)-(s.hold_tokens*s.mid+s.hold_quote),"sla_met":active_after and not e.outage and action!="pause","detail":detail},true)
func simulate_alpha(s:Dictionary,e:Dictionary,action:String,row:Dictionary)->void:
	var detail:String="";var settled:float=0.0
	if not s.pending.is_empty() and e.confirm:
		var order:Dictionary=s.pending;s.cash-=order.amount+order.fee;s.tokens+=order.qty;s.reserved=0.0;s.pending={};settled=order.amount;detail="上一笔已确认到账并对账。"
	if not s.pending.is_empty():
		if action!="pause":s.violations+=1
		detail+="已有待确认委托，禁止重复使用预算；保持状态核查。"
	elif not e.identity:
		if action!="pause":s.violations+=1
		detail+="代币／渠道身份不一致，已阻断新增委托。"
	elif action=="pause":detail+="暂停新增委托，核对恢复条件。"
	elif s.gas_used+e.gas>s.proposal.gas_budget or e.gas>data.simulation.alpha_max_gas:
		s.violations+=1;detail+="网络成本超出单次教学限额或累计预算，阻断委托并升级审批。"
	else:
		var amount:float=minf(s.proposal.max_order*(.5 if action=="risk" else 1),minf(s.proposal.daily_limit,maxf(0,available(s)-e.gas)))
		# Reserve trade fee as well as principal; no borrowing or repeated budget use.
		amount=minf(amount,maxf(0,(available(s)-e.gas)/(1+float(data.simulation.trade_fee_bps)/10000)))
		if amount<=0:detail+="非储备资金不足，未提交新委托。"
		else:
			var quote_qty:float=amount/s.mid;var impact:float=e.slippage*(.4 if action=="risk" else 1)
			var received:float=quote_qty/(1+impact/100);var minimum:float=quote_qty*(1-s.proposal.slippage_pct/100)
			s.cash-=e.gas;s.gas_used+=e.gas;row.cost=e.gas
			row.merge({"quoted_qty":quote_qty,"minimum_qty":minimum,"received_qty":received,"attempt_amount":amount,"impact_pct":impact})
			if received<minimum:detail+="低于接收保护下限，本次失败；仍单列示例网络成本。"
			else:
				var fee:float=amount*float(data.simulation.trade_fee_bps)/10000
				if e.pending:s.pending={"amount":amount,"qty":received,"fee":fee};s.reserved=amount+fee;detail+="本次进入处理中，金额已锁定，未记作已成交。"
				else:s.cash-=amount+fee;s.tokens+=received;s.trade_cost+=fee;row.executed=amount;row.cost+=fee;row.sla_met=true;detail+="接收保护通过且已确认成交；记录示例成本。"
	row.executed+=settled
	if settled>0:row.sla_met=true;s.trade_cost+=settled*float(data.simulation.trade_fee_bps)/10000;row.cost+=settled*float(data.simulation.trade_fee_bps)/10000
	row.merge({"cash":s.cash,"tokens":s.tokens,"reserved":s.reserved,"pending":not s.pending.is_empty(),"gas_total":s.gas_used,"detail":detail},true)
func simulate_futures(s:Dictionary,e:Dictionary,action:String,row:Dictionary)->void:
	var pressure:bool=check_pressure(s);var detail:String="压力触发示例关闭，合约仓位已清除。" if pressure else ""
	var spread:float=s.proposal.spread*(1.8 if action=="risk" else 1);var quotes:Dictionary=book(s,spread)
	if e.outage:
		if action!="pause":s.violations+=1
		detail+="接口异常，不能假设增减仓成功；原仓位仍盯市和结算。"
	elif action=="pause":detail+="暂停新增合约报价，已有持仓仍保留。"
	elif s.margin<=0:detail+="保证金资金不足，不能恢复报价。"
	else:
		var fill:Dictionary=walk_book(quotes,"bids" if e.flow<0 else "asks",absf(float(e.flow))*s.proposal.depth*.6,float(s.mid))
		if fill.quantity>0:
			var trade:Dictionary=position_trade(s,fill.quantity*(1 if e.flow<0 else -1),fill.vwap);row.executed=trade.notional;row.cost+=trade.fee
		if action=="risk":
			if int(s.proposal.risk)!=1:s.violations+=1;detail+="尚未获得调整授权，未对冲。"
			else:
				var max_risk:float=maxf(0,margin_equity(s))*s.proposal.leverage_cap*.65
				var target:float=-minf(s.tokens*s.proposal.hedge_pct/100,max_risk/s.mid)
				var adjust:Dictionary=position_trade(s,target-s.position,s.mid);row.cost+=adjust.fee;row.executed+=adjust.notional;detail+="放宽报价并按保证金缓冲调整空仓，复核剩余净敞口。"
		else:detail+="按已授权双边方案成交，实际仓位随成交改变。"
		row.sla_met=spread<=30 and quotes.bid_depth>=10000 and quotes.ask_depth>=10000
	var funding:float=-s.position*s.mid*float(e.funding_bps)/10000;s.margin+=funding;s.funding_total+=funding
	if check_pressure(s):pressure=true;detail+="结算后触及维持要求，已执行示例压力关闭。"
	row.merge({"position":s.position,"entry":s.entry,"spot_tokens":s.tokens,"margin_balance":s.margin,"margin_equity":margin_equity(s),"maintenance":maintenance(s),"funding":funding,"funding_bps":e.funding_bps,"spread":spread,"net_exposure":(s.tokens+s.position)*s.mid,"liquidated":pressure,"bid_depth":quotes.bid_depth,"ask_depth":quotes.ask_depth,"detail":detail},true)
func grade(s:Dictionary)->Dictionary:
	var w:Dictionary=data.scoring;var proposal:int=0;var boundary:int=0;var bad:int=0;var good_rounds:Array=[];var warnings:Array[String]=[]
	if not s.proposal.is_empty():warnings=proposal_warnings(s,s.proposal);proposal=maxi(0,int(w.proposal)-warnings.size()*5)
	for answer in s.answers:
		if int(answer.choice)==int(scenario(s).negotiation[int(answer.round)].correct):
			if int(answer.round) not in good_rounds:good_rounds.append(int(answer.round))
		else:bad+=1
	boundary=maxi(0,roundi(float(good_rounds.size())/3*float(w.boundaries))-bad*7)
	var careful:int=0
	for day in s.daily:
		if day.action==scenario(s).events[int(day.day)-1].expected:careful+=1
	var discovery:int=roundi(s.asked.size()/6.0*float(w.discovery));var delivery:int=maxi(0,roundi(careful/6.0*float(w.delivery))-int(s.violations)*4)
	var communication:int=roundi(s.notifications/6.0*float(w.communication))
	if bad>0:warnings.append("谈判中承诺边界偏差 %d 次，原回答仍保留。"%bad)
	if s.violations>0:warnings.append("风险或授权处置偏差 %d 次，需逐日复盘。"%s.violations)
	if s.notifications<6:warnings.append("客户通知不足，补充原因、影响与恢复条件。")
	if scenario(s).channel=="futures" and s.liquidations>0:warnings.append("发生示例压力关闭，不得把对冲当作强平保障。")
	return {"score":discovery+proposal+boundary+delivery+communication,"discovery":discovery,"proposal":proposal,"boundaries":boundary,"delivery":delivery,"communication":communication,"warnings":warnings,"focus":"继续复训边界与异常处置" if bad>0 or s.violations>0 else "可进入带教讨论","equity_change":equity(s)-float(s.proposal.get("capital",0)),"service_margin":float(s.proposal.get("fee",0))-monthly_cost(s,s.proposal) if not s.proposal.is_empty() else 0}
