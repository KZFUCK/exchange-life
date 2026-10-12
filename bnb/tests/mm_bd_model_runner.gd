extends SceneTree
const Model=preload("res://scripts/mm_bd_model.gd")
const Store=preload("res://scripts/mm_bd_store.gd")
var model=Model.new()
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL MM BD: ",label)
func act(s:Dictionary,cmd:Dictionary)->void:
	var error:String=model.apply(s,cmd);check(error.is_empty(),str(cmd.kind)+" accepted: "+error);check(model.valid(s),"command replays exactly")
func course(s:Dictionary)->Dictionary:return {"active":s,"completed":[],"draft":{}}
func _initialize()->void:call_deferred("run")
func prepared(index:int)->Dictionary:
	var state:Dictionary=model.initial(index);act(state,{"kind":"begin"})
	for q in model.data.questions:act(state,{"kind":"ask","id":q.id})
	act(state,{"kind":"draft"});return state
func run()->void:
	var default_store=Store.new();check(default_store.path.contains(default_store.rules_hash.left(12)),"training-policy version has an isolated default save namespace")
	var s:Dictionary=model.initial();check(model.valid(s),"initial state valid")
	var before:Dictionary=s.duplicate(true);check(not model.apply(s,{"kind":"day","action":"keep","notify":true}).is_empty() and model.same(s,before),"out-of-stage action rejects atomically")
	act(s,{"kind":"begin"});before=s.duplicate(true)
	check(not model.apply(s,{"kind":"draft"}).is_empty() and model.same(s,before),"essential discovery gates proposal")
	act(s,{"kind":"ask","id":"metrics"});before=s.duplicate(true)
	check(not model.apply(s,{"kind":"ask","id":"metrics"}).is_empty() and model.same(s,before),"duplicate question cannot fabricate discovery score")
	for i in range(3):
		s=prepared(i);var proposal:Dictionary=model.default_proposal(s);var bad:Dictionary=proposal.duplicate();bad.capital=1000000
		check(not model.proposal_error(s,bad).is_empty(),"capital cannot exceed customer authorization")
		bad=proposal.duplicate();bad.depth=40000;bad.venues=3;check(not model.proposal_error(s,bad).is_empty(),"per-venue bilateral capital is not counted repeatedly")
		bad=proposal.duplicate();bad.spread=NAN;check(not model.proposal_error(s,bad).is_empty(),"nonfinite quote rejects")
		act(s,{"kind":"propose","proposal":proposal})
		if i==0:
			act(s,{"kind":"answer","choice":0});check(s.phase=="negotiation" and s.cash==0,"price-volume guarantee cannot enter delivery")
		act(s,{"kind":"answer","choice":1});check(s.phase=="execution","bounded service agreement enters delivery")
		if s.phase!="execution":finish();return
		var book:Dictionary=model.book(s)
		check(absf((book.asks[0].price-book.bids[0].price)/s.mid*10000-proposal.spread)<.000001,"quoted spread has correct bps units")
		check(absf(book.bid_depth-proposal.depth)<.00001 and absf(book.ask_depth-proposal.depth)<.00001,"depth is funded per side per venue")
		check(book.bids[2].price>=s.mid*.99-.000001 and book.asks[2].price<=s.mid*1.01+.000001,"all reported depth lies within1percent")
		var trial:Dictionary=model.walk_book(book,"asks",10000,float(s.mid))
		check(trial.complete and absf(trial.filled-10000)<.000001 and trial.vwap>=book.asks[0].price,"market order walks available asks with weighted execution")
		var too_large:Dictionary=model.walk_book(book,"asks",float(book.ask_depth)+1000,float(s.mid))
		check(not too_large.complete and absf(too_large.filled-book.ask_depth)<.000001,"insufficient book cannot invent a full fill")
		var store=Store.new("/tmp/mm-bd-test-%d-%d.json"%[OS.get_process_id(),i])
		check(store.write_course(course(s)).is_empty(),"mid-delivery course writes")
		var loaded:Dictionary=store.read_course();check(loaded.has("course") and model.same(loaded.course.active,s),"save restore preserves active proposal and balances")
		check(model.same(model.grade(loaded.course.active),model.grade(s)),"JSON numeric types do not change competency grades")
		var restored:Dictionary=loaded.course.active
		for day in range(6):
			var event:Dictionary=model.scenario(s).events[day]
			var action:String="pause" if event.outage else ("risk" if absf(float(event["return"]))>=.06 else "keep")
			var cmd:Dictionary={"kind":"day","action":action,"notify":true}
			act(s,cmd);check(model.apply(restored,cmd).is_empty() and model.same(s,restored),"restored execution reaches identical outcome")
			check(s.cash>=0 and s.tokens>=0,"cash and inventory remain funded")
			if event.outage:check(s.daily[-1].executed==0 and s.daily[-1].paused,"outage does not fabricate fills")
		check(s.phase=="debrief" and s.day==6,"all three cases complete six-day delivery")
		var grade:Dictionary=model.grade(s);check(grade.communication==10 and grade.delivery==20,"risk-aware actions and communication graded correctly")
		check(grade.boundaries==18 if i==0 else grade.boundaries==25,"unsafe guarantee remains in review after correction")
		var done:Dictionary=course(s);done.completed.append(s.duplicate(true));check(model.valid_course(done) and store.write_course(done).is_empty(),"completed record is reproducible and saveable")
		check(model.same(model.grade(store.read_course().course.completed[0]),grade),"completed competency result survives actual saved history")
		var forged:Dictionary=done.duplicate(true);forged.active.cash+=10;check(not model.valid_course(forged),"cash tampering rejected by command replay")
		before=s.duplicate(true);check(not model.apply(s,{"kind":"day","action":"keep","notify":true}).is_empty() and model.same(s,before),"completed case cannot settle twice")
		check(store.restore_backup().has("course"),"valid prior backup restores while retaining current file")
		var f:=FileAccess.open(store.path,FileAccess.WRITE);f.store_string("corrupt");f.close()
		check(not store.write_course(done).is_empty() and FileAccess.get_file_as_string(store.path)=="corrupt","corrupt save is never overwritten")
	s=prepared(0);var expensive:Dictionary=model.default_proposal(s);expensive.fee=10000;act(s,{"kind":"propose","proposal":expensive});act(s,{"kind":"answer","choice":1})
	check(s.phase=="proposal" and s.cash==0,"over-budget offer returns to negotiation workshop instead of invented agreement")
	expensive.fee=5000;act(s,{"kind":"propose","proposal":expensive});act(s,{"kind":"answer","choice":1});check(s.phase=="execution" and model.grade(s).boundaries==25,"honest commercial revision does not count as a boundary violation")
	s=prepared(2);act(s,{"kind":"propose","proposal":model.default_proposal(s)});act(s,{"kind":"answer","choice":1})
	for day in range(3):act(s,{"kind":"day","action":"keep","notify":false})
	check(s.violations>0 and s.daily[-1].executed==0 and s.notifications==0,"ignoring outage is penalized without phantom execution or notifications")
	finish()
func finish()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/mm_bd"))
	var f:=FileAccess.open("res://qa/mm_bd/model_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("MM BD model checks: %d; failures: %d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
