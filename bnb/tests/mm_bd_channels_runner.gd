extends SceneTree
const Channels=preload("res://scripts/mm_bd_channels.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL CHANNEL: ",label)
func near(a:float,b:float)->bool:return absf(a-b)<.000001
func _initialize()->void:call_deferred("run")
func run()->void:
	var fixture:String="/tmp/mm-bd-channels-%d.json"%OS.get_process_id();var m=Channels.new(fixture)
	check(m.data.modules.size()==4 and m.valid(m.state),"four channel modules initialized")
	for index in range(4):
		check(m.select(index).is_empty(),"channel selection saved")
		var module:Dictionary=m.data.modules[index]
		check(module.lessons.size()==4 and module.quiz.size()==4 and module.sources.size()>=2,"mechanism lessons and sourced quizzes provided")
		for question in module.quiz:
			var before:String=JSON.stringify(m.state)
			check(not m.answer(3).is_empty() and before==JSON.stringify(m.state),"out-of-range option rejected without mutation")
			check(m.answer(int(question.correct)).is_empty(),"correct scenario answer stored")
		var g:Dictionary=m.grade(m.current());check(g.complete and g.score==100,"channel mastery result derived from recorded answers")
		var restored=Channels.new(fixture);check(m.same_state(restored.state,m.state) and restored.grade(restored.current()).score==100,"new model resumes course and identical grade")
		check(not m.answer(0).is_empty(),"completed quiz cannot add answers")
		var old_size:int=m.state.runs.size();check(m.retry().is_empty() and m.state.runs.size()==old_size+1 and m.current().answers.is_empty(),"retry preserves previous run")
		check(m.answer((int(module.quiz[0].correct)+1)%3).is_empty() and m.grade(m.current()).score==0,"wrong answer remains recorded with zero credit")
	var invalid:Dictionary=m.state.duplicate(true);invalid.runs[0].answers=[.5];check(not m.valid(invalid),"fractional choice invalid")
	invalid=m.state.duplicate(true);invalid.selected=9;check(not m.valid(invalid),"unknown channel invalid")
	var p:Dictionary=m.lp_lab(100000,1,1,.25,4);check(near(p.value,100000) and near(p.hold,100000) and near(p.difference,0),"LP initial value equals funded capital and holding benchmark")
	p=m.lp_lab(100000,1,4,.25,4);check(near(p.token,0) and near(p.quote,150000) and near(p.hold,250000) and not p.active,"upper bound converts all to quote with correct relative difference")
	p=m.lp_lab(100000,1,.25,.25,4);check(near(p.token,150000) and near(p.quote,0) and near(p.value,37500),"lower bound inventory correctly becomes token")
	check(m.lp_lab(100000,1,1,1,1).has("error"),"invalid LP ranges rejected")
	for price in [.1,.3,.7,1.0,1.3,3.0,5.0]:
		p=m.lp_lab(100000,1,price,.25,4);check(p.token>=0 and p.quote>=0 and p.value<=p.hold+.000001,"fee-free fixed LP does not invent excess value")
	p=m.alpha_lab(10000,1,9800,10,3);check(near(p.minimum,9900) and not p.passes and p.net_qty==0,"alpha protection breach cannot claim filled tokens")
	p=m.alpha_lab(10000,1,9900,10,3);check(p.passes and near(p.net_qty,9890.1),"alpha protection threshold and explicit illustrative fee separated")
	check(m.alpha_lab(10000,100,9900,10,3).has("error"),"invalid alpha tolerance rejected")
	p=m.spot_lab(20000,15000,10);check(not p.complete and near(p.spent,15000) and near(p.unfilled,5000) and p.vwap>1.001 and p.vwap<1.003,"spot walk respects finite depth and weighted fills")
	p=m.spot_lab(1000,15000,10);check(p.complete and near(p.vwap,1.001) and near(p.slippage_bps,10),"small spot order fills only best level")
	p=m.futures_lab(100000,20000,1,1,1,.5,-1,0);check(near(p.funding,10) and near(p.pnl,0) and near(p.equity,20010),"positive funding pays short at mark notional")
	p=m.futures_lab(100000,20000,1,1,1,.5,1,0);check(near(p.funding,-10),"positive funding charges long")
	p=m.futures_lab(100000,20000,1,1,-1,.5,-1,0);check(near(p.funding,-10),"negative funding charges short")
	p=m.futures_lab(100000,20000,1,1.2,1,.5,-1,4);check(near(p.pnl,-20000) and near(p.funding,12) and near(p.fee,48) and near(p.equity,-36) and p.breach,"short pressure includes mark PNL funding fees and maintenance")
	var bad_path:String=fixture+".bad";var file:=FileAccess.open(bad_path,FileAccess.WRITE);file.store_string("broken");file.close()
	var bad=Channels.new(bad_path);var before:Dictionary=bad.state.duplicate(true)
	check(not bad.boot_error.is_empty() and not bad.answer(0).is_empty() and before==bad.state and FileAccess.get_file_as_string(bad_path)=="broken","corrupt file protected and unsaved answer cannot advance")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/mm_channels"))
	var f:=FileAccess.open("res://qa/mm_channels/model_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("Channel model checks: %d; failures: %d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
