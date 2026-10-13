extends RefCounted
const DATA_PATH="res://data/mm_bd_channels_v1.json"
var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
var rules_hash:String=FileAccess.get_file_as_string(DATA_PATH).sha256_text()
var path:String
var state:Dictionary={"selected":0,"runs":[]}
var boot_error:String=""
func _init(save_path:String="")->void:
	path=save_path if not save_path.is_empty() else "user://mm_bd_channels_v1_%s.json"%rules_hash.left(12)
	for i in data.modules.size():state.runs.append({"module":i,"answers":[]})
	if FileAccess.file_exists(path):
		var loaded:Dictionary=read_state()
		if loaded.has("state"):state=loaded.state
		else:boot_error=loaded.error
func integer(v:Variant)->bool:return (v is int or v is float) and is_finite(float(v)) and float(v)==int(v)
func valid(value:Variant)->bool:
	if not value is Dictionary or value.size()!=2 or not integer(value.get("selected")) or value.selected<0 or value.selected>=data.modules.size():return false
	if not value.get("runs") is Array or value.runs.size()<4 or value.runs.size()>100:return false
	var seen:Array=[]
	for run in value.runs:
		if not run is Dictionary or run.size()!=2 or not integer(run.get("module")) or run.module<0 or run.module>=data.modules.size() or not run.get("answers") is Array:return false
		var quiz:Array=data.modules[int(run.module)].quiz
		if run.answers.size()>quiz.size():return false
		for i in run.answers.size():
			if not integer(run.answers[i]) or run.answers[i]<0 or run.answers[i]>=quiz[i].options.size():return false
		if int(run.module) not in seen:seen.append(int(run.module))
	return seen.size()==data.modules.size()
func read_state(target:String="")->Dictionary:
	if target.is_empty():target=path
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(target))!=OK or not parser.data is Dictionary:return {"error":"渠道课存档损坏，原文件已保护。"}
	var env:Dictionary=parser.data
	if env.get("rules_hash")!=rules_hash or not env.get("payload") is String or env.payload.sha256_text()!=env.get("checksum"):return {"error":"渠道课版本或校验不匹配，原文件已保护。"}
	if parser.parse(env.payload)!=OK or not valid(parser.data):return {"error":"渠道课回答记录无效，原文件已保护。"}
	return {"state":parser.data}
func persist(value:Dictionary)->String:
	if not valid(value):return "渠道课记录无效，未保存。"
	if FileAccess.file_exists(path) and read_state().has("error"):return "现有渠道课存档异常，已保护；未覆盖原文件。"
	var payload:String=JSON.stringify(value,"",true,true)
	var f:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:return "无法保存渠道课；本次回答未提交，请重试。"
	f.store_string(JSON.stringify({"rules_hash":rules_hash,"payload":payload,"checksum":payload.sha256_text()}));f.flush();var error:Error=f.get_error();f.close()
	if error!=OK or read_state(path+".tmp").has("error"):return "渠道课临时档验证失败。"
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:return "渠道课备份失败。"
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "渠道课保存失败。"
	state=value;return ""
func current(index:int=-1,value:Dictionary={})->Dictionary:
	if value.is_empty():value=state
	if index<0:index=int(value.selected)
	for i in range(value.runs.size()-1,-1,-1):
		if int(value.runs[i].module)==index:return value.runs[i]
	return {}
func select(index:int)->String:
	if index<0 or index>=data.modules.size():return "无效课程。"
	var next:Dictionary=state.duplicate(true);next.selected=index;return persist(next)
func answer(choice:int)->String:
	var next:Dictionary=state.duplicate(true);var run:Dictionary=current(-1,next);var quiz:Array=data.modules[int(next.selected)].quiz
	if run.answers.size()>=quiz.size():return "本轮已完成。请开始新一轮练习。"
	if choice<0 or choice>=quiz[run.answers.size()].options.size():return "无效选项。"
	run.answers.append(choice);return persist(next)
func retry()->String:
	if state.runs.size()>=100:return "已保留 100 轮练习。请先导出记录，由带教安排新课程版本。"
	if current().answers.is_empty():return "本轮尚未答题。"
	var next:Dictionary=state.duplicate(true);next.runs.append({"module":int(state.selected),"answers":[]});return persist(next)
func grade(run:Dictionary)->Dictionary:
	var quiz:Array=data.modules[int(run.module)].quiz;var correct:int=0
	for i in run.answers.size():
		if int(run.answers[i])==int(quiz[i].correct):correct+=1
	return {"correct":correct,"answered":run.answers.size(),"total":quiz.size(),"score":roundi(100.0*correct/quiz.size()),"complete":run.answers.size()==quiz.size()}
# Fixed basic concentrated-liquidity position. Prices are token1/token0, decimals normalized.
func lp_amounts(liquidity:float,price:float,lower:float,upper:float)->Dictionary:
	var a:float=sqrt(lower);var b:float=sqrt(upper);var p:float=sqrt(clampf(price,lower,upper))
	return {"token":liquidity*(b-p)/(p*b),"quote":liquidity*(p-a)}
func lp_lab(capital:float,entry:float,price:float,lower:float,upper:float)->Dictionary:
	if capital<=0 or entry<=0 or price<=0 or lower<=0 or upper<=lower or entry<=lower or entry>=upper:return {"error":"初始价格须严格位于正数区间内，且下界小于上界。"}
	var unit:Dictionary=lp_amounts(1,entry,lower,upper);var liquidity:float=capital/(unit.token*entry+unit.quote)
	var initial:Dictionary=lp_amounts(liquidity,entry,lower,upper);var now:Dictionary=lp_amounts(liquidity,price,lower,upper)
	var value:float=now.token*price+now.quote;var hold:float=initial.token*price+initial.quote
	return {"token":now.token,"quote":now.quote,"value":value,"hold":hold,"difference":value-hold,"relative_pct":(value/hold-1)*100,"active":price>=lower and price<upper}
func alpha_lab(quote_qty:float,slippage_pct:float,actual_qty:float,fee_bps:float,gas:float)->Dictionary:
	if quote_qty<=0 or slippage_pct<0 or slippage_pct>=100 or actual_qty<0 or fee_bps<0 or fee_bps>=10000 or gas<0:return {"error":"示例参数超出有效范围。"}
	var minimum:float=quote_qty*(1-slippage_pct/100);var passes:bool=actual_qty>=minimum
	return {"minimum":minimum,"passes":passes,"net_qty":actual_qty*(1-fee_bps/10000) if passes else 0,"gas":gas}
func spot_lab(request:float,depth:float,step_bps:float)->Dictionary:
	if request<=0 or depth<=0 or step_bps<=0 or step_bps>100:return {"error":"买单、深度与档位价差必须为正。"}
	var budget:float=request;var quantity:float=0;var cost:float=0
	for i in range(3):
		var price:float=1+(i+1)*step_bps/10000;var spend:float=minf(budget,depth/3);cost+=spend;quantity+=spend/price;budget-=spend
	var vwap:float=cost/quantity
	return {"vwap":vwap,"slippage_bps":(vwap-1)*10000,"spent":cost,"unfilled":maxf(budget,0),"complete":budget<.0000001}
# USDT linear single-position snapshot only; no real liquidation price is produced.
func futures_lab(notional:float,margin:float,entry:float,mark:float,rate_bps:float,mmr_pct:float,side:int,fee_bps:float)->Dictionary:
	if notional<=0 or margin<=0 or entry<=0 or mark<=0 or mmr_pct<=0 or mmr_pct>=100 or side not in [-1,1] or fee_bps<0:return {"error":"合约示例参数无效。"}
	var qty:float=notional/entry;var marked:float=qty*mark;var pnl:float=side*qty*(mark-entry)
	var funding:float=-side*marked*rate_bps/10000;var fee:float=marked*fee_bps/10000
	var equity:float=margin+pnl+funding-fee;var maintenance:float=marked*mmr_pct/100
	return {"quantity":qty,"marked_notional":marked,"pnl":pnl,"funding":funding,"fee":fee,"equity":equity,"maintenance":maintenance,"breach":equity<=maintenance,"margin_ratio":maintenance/equity*100 if equity>0 else INF,"initial_leverage":notional/margin}

func same_state(a:Dictionary,b:Dictionary)->bool:
	if not valid(a) or not valid(b) or int(a.selected)!=int(b.selected) or a.runs.size()!=b.runs.size():return false
	for i in a.runs.size():
		if int(a.runs[i].module)!=int(b.runs[i].module) or a.runs[i].answers.size()!=b.runs[i].answers.size():return false
		for j in a.runs[i].answers.size():
			if int(a.runs[i].answers[j])!=int(b.runs[i].answers[j]):return false
	return true
