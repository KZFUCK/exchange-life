extends SceneTree
const Model=preload("res://scripts/mm_bd_mandate_model.gd")
const Store=preload("res://scripts/mm_bd_mandate_store.gd")
var checks:int=0
var failures:Array=[]
var qa:String="res://qa/mm_mandates"
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL MANDATE: ",label)
func _initialize()->void:call_deferred("run")
func near(a:float,b:float)->bool:return absf(a-b)<.000001
func ready(model:RefCounted,index:int)->Dictionary:
	var s:Dictionary=model.initial(index);check(model.apply(s,{"kind":"begin"}).is_empty(),"begin specific mandate")
	for q in model.data.questions:check(model.apply(s,{"kind":"ask","id":q.id}).is_empty(),"record actual channel fact")
	check(model.apply(s,{"kind":"draft"}).is_empty(),"six facts unlock quotation");return s
func accept(model:RefCounted,s:Dictionary)->void:
	check(model.apply(s,{"kind":"propose","proposal":model.default_proposal(s)}).is_empty(),"channel-specific proposal accepted for negotiation")
	for turn in model.scenario(s).negotiation:check(model.apply(s,{"kind":"answer","choice":turn.correct}).is_empty(),"three distinct customer objections handled")
	check(s.phase=="execution","only matched authorized proposal reaches delivery")
func run()->void:
	var m=Model.new();var store=Store.new("/tmp/mm-mandate-%d.json"%OS.get_process_id());var records:Array=[]
	check(m.data.cases.size()==3 and store.model.data.cases[0].channel=="uniswap","store uses new channel-specific replay model")
	for index in range(3):
		var s:Dictionary=m.initial(index);var before:Dictionary=s.duplicate(true)
		check(not m.apply(s,{"kind":"day","action":"keep","notify":true}).is_empty() and m.same(s,before),"invalid phase fails atomically")
		m.apply(s,{"kind":"begin"});check(not m.apply(s,{"kind":"draft"}).is_empty(),"missing discovery cannot quote")
		s=ready(m,index);var proposal:Dictionary=m.default_proposal(s);proposal.capital=m.scenario(s).capital+1
		check(not m.apply(s,{"kind":"propose","proposal":proposal}).is_empty() and s.phase=="proposal","unfunded customer capital blocked")
		proposal=m.default_proposal(s);proposal.fee=m.scenario(s).budget+500;m.apply(s,{"kind":"propose","proposal":proposal})
		for turn in m.scenario(s).negotiation:m.apply(s,{"kind":"answer","choice":turn.correct})
		check(s.phase=="proposal" and s.cash==0,"successful wording cannot accept over-budget commercial scope")
		accept(m,s);check(near(m.equity(s),s.proposal.capital),"initial assets fully funded without duplicated capital")
		for day in range(6):
			var e:Dictionary=m.scenario(s).events[day];var prior:Dictionary=s.duplicate(true)
			check(m.apply(s,{"kind":"day","action":e.expected,"notify":true}).is_empty(),"delivery action accepted")
			check(m.valid(s),"financial state can be replayed after every delivery day")
			check(s.daily[-1].cost>=0 and is_finite(m.equity(s)),"costs finite and non-negative")
			check(near(m.equity(s)-m.equity(prior),s.daily[-1].change),"daily equity change reconciles with ledger")
			check(store.write_course({"active":s,"completed":records,"draft":{}}).is_empty(),"mid-course save uses precise payload")
			var loaded:Dictionary=store.read_course();check(loaded.has("course") and m.same(loaded.course.active,s) and m.grade(loaded.course.active).score==m.grade(s).score,"reload restores exact model and competency score")
			if index==0 and day==1:check(s.daily[-1].active and s.gas_used>0 and s.daily[-1].fees==0,"out-of-range adjustment charges gas without inventing transition fees")
			if index==0 and day==3:check(s.daily[-1].fees==0 and s.lp_L==prior.lp_L,"chain pause does not erase existing LP exposure")
			if index==1 and day==0:check(s.pending.size()>0 and s.tokens==0 and s.reserved>0 and s.daily[-1].executed==0,"pending instruction locks funds without claiming confirmed fill")
			if index==1 and day==1:check(m.same(s.pending,prior.pending) and s.tokens==0 and s.cash==prior.cash,"pending pause cannot duplicate or lose prior instruction")
			if index==1 and day==2:check(s.pending.is_empty() and s.tokens>0 and s.daily[-1].executed>0,"confirmed settlement records funded assets and partial new instruction")
			if index==1 and day in [3,4]:check(s.tokens==prior.tokens and s.cash==prior.cash and s.daily[-1].executed==0,"identity mismatch or gas spike prevents new execution")
			if index==2 and day==3:check(s.position==prior.position and s.daily[-1].funding!=0 and s.daily[-1].executed==0,"interface pause still marks and settles existing position")
		check(s.phase=="debrief" and s.daily.size()==6 and m.grade(s).score==100,"six days complete specific-channel coaching result")
		before=s.duplicate(true);check(not m.apply(s,{"kind":"day","action":"keep","notify":true}).is_empty() and m.same(before,s),"duplicate final delivery rejected")
		var tampered:Dictionary=s.duplicate(true);tampered.daily[0].equity+=1;check(not m.valid(tampered),"fabricated financial results rejected by replay")
		records.append(s)
	check(store.write_course({"active":records[-1],"completed":records,"draft":{}}).is_empty() and store.read_course().course.completed.size()==3,"all three mandate records remain in own save")
	for index in range(3):
		var s:Dictionary=ready(m,index);m.apply(s,{"kind":"propose","proposal":m.default_proposal(s)})
		var correct:int=int(m.scenario(s).negotiation[0].correct);m.apply(s,{"kind":"answer","choice":(correct+1)%3})
		check(s.phase=="negotiation" and s.round==0 and s.cash==0,"incorrect warranty cannot advance negotiation or allocate assets")
		for turn in m.scenario(s).negotiation:m.apply(s,{"kind":"answer","choice":turn.correct})
		check(m.grade(s).boundaries<25,"wrong commercial promise remains in coaching score")
	var f:Dictionary=ready(m,2);accept(m,f);f.mid=2.0
	var capital_before:float=m.equity(f);var old_margin:float=f.margin;var old_unrealized:float=m.unrealized(f);var close_fee:float=absf(f.position)*f.mid*.001
	check(m.check_pressure(f) and f.position==0 and near(f.margin,old_margin+old_unrealized-close_fee) and near(m.equity(f),capital_before-close_fee),"pressure close realizes prior loss and fee, cannot invent capital")
	f=ready(m,2);accept(m,f);var old:float=f.position;var margin_before:float=f.margin
	var trade:Dictionary=m.position_trade(f,absf(old)*.5,1.2,4)
	check(near(f.position,old*.5) and near(trade.realized,-absf(old)*.5*.2) and near(f.margin,margin_before+trade.realized-trade.fee),"contract partial close updates position, realized PNL and fees")
	var bad_path:String=store.path+".bad";var file:=FileAccess.open(bad_path,FileAccess.WRITE);file.store_string("corrupt");file.close();var bad=Store.new(bad_path)
	check(not bad.write_course({"active":records[-1],"completed":records,"draft":{}}).is_empty() and FileAccess.get_file_as_string(bad_path)=="corrupt","corrupt independent mandate save protected")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa));var output:=FileAccess.open(qa+"/model_results.json",FileAccess.WRITE);output.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t",true,true));output.close()
	print("Mandate model checks: %d; failures: %d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
