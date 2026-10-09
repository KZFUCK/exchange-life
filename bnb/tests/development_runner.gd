extends SceneTree
const Model=preload("res://scripts/operations_model.gd")
const Store=preload("res://scripts/operations_store.gd")
const Development=preload("res://scripts/office_development.gd")
var checks:=0
var failures:=0
func check(ok:bool,description:String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL DEVELOPMENT: ",description)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var m=Model.new();var s:Dictionary=m.initial()
	check(not m.commission(s,0,0).is_empty(),"empty staff cannot start a project")
	m.hire(s,"engineer");m.buy(s);m.place(s,[2,1])
	check(not m.commission(s,1,1).is_empty(),"advanced product requires earned reputation")
	var cash:float=s.cash
	check(m.commission(s,0,1).is_empty() and s.cash==cash-1500,"commission charges project budget exactly once")
	check(not m.commission(s,0,1).is_empty() and s.cash==cash-1500,"second concurrent project rejected without extra charge")
	check(m.valid(s),"commissioned project and finance ledger validate together")
	m.begin(s)
	for i in range(5):m.tick(s,.1)
	check(s.development.active.work==0 and s.development.history.is_empty(),"walking never advances a project")
	for i in range(35):m.tick(s,.1)
	check(s.development.active.work>0 and s.development.active.work<=s.staff[0].hours,"project progress comes from actual seated working hours")
	var store=Store.new("/tmp/bnb-development-%d.json" % OS.get_process_id())
	check(store.write_game(s).is_empty(),"mid-project save includes development and work team")
	var restored:Dictionary=store.read_game().state
	for i in range(40):m.tick(s,.1);m.tick(restored,.1)
	check(JSON.stringify(s)==JSON.stringify(restored) or absf(s.development.active.work-restored.development.active.work)<.000001,"restored project reaches the same first-week work total")
	check(m.valid(s) and m.valid(restored),"first-week reports account for project investment")
	check(not Development.train(s,999).is_empty(),"training requires a real employee")
	check(not Development.train(s,1).is_empty(),"insufficient research cannot train")
	var iterations:=0
	while s.development.history.is_empty() and iterations<6:
		m.begin(s)
		for i in range(80):m.tick(s,.1)
		iterations+=1
	check(s.development.history.size()==1 and s.development.active.is_empty(),"working across weeks reaches a single project release")
	var result:Dictionary=s.development.history[0]
	check(absf(result.work-20)<.0001 and result.score==66 and result.users==7920 and result.sales==1980,"known single-role product combination yields independently expected work, review, users and sales")
	check(s.development.users==7920 and s.development.trust==13,"release accumulates user base and reputation")
	var launch_count:=0
	for e in s.ledger:if e.kind=="launch":launch_count+=1
	check(launch_count==1 and m.valid(s),"release revenue appears once and matches company cash and reports")
	var previous_research:int=s.development.research;var old_level:=Development.level(s,1)
	check(Development.train(s,1).is_empty() and s.development.research==previous_research-5 and Development.level(s,1)==old_level+1,"training spends five earned research points and raises actual project ability")
	check(m.valid(s),"training state remains valid and saveable")
	check(m.commission(s,1,1).is_empty(),"earned reputation and research unlock professional product")
	check(s.development.active.team[0].level==Development.level(s,1),"new project captures trained employee ability")
	check(store.write_game(s).is_empty() and not store.read_game().has("error"),"unlocked trained company saves and reloads")
	var broken:Dictionary=s.duplicate(true);broken.development.history[0].users+=1
	check(not m.valid(broken),"forged release users rejected")
	broken=s.duplicate(true);broken.development.active.work+=1
	check(not m.valid(broken),"forged project work rejected")
	broken=s.duplicate(true);broken.staff[0].hours+=10
	check(not m.valid(broken),"forged seated work hours rejected against employee output and partial progress")
	broken=s.duplicate(true);broken.development.research+=1
	check(not m.valid(broken),"forged research balance rejected")
	broken=s.duplicate(true);broken.ledger.append(broken.ledger.filter(func(e):return e.kind=="launch")[0].duplicate());broken.cash+=1980
	check(not m.valid(broken),"duplicate release payment rejected")
	# Fractional work hours near a scoring boundary must remain saveable.
	var precise:Dictionary=m.initial()
	m.starter_layout(precise,[[1,1],[2,1],[1,4],[2,4]])
	for role in ["engineer","engineer","support","analyst"]:m.hire(precise,role)
	m.commission(precise,0,1);m.begin(precise)
	for i in range(80):m.tick(precise,.1)
	check(m.valid(precise) and precise.development.history[0].score==82,"fractional project has its original valid 82-point result")
	var precise_store=Store.new("/tmp/bnb-development-precision-%d.json"%OS.get_process_id())
	check(precise_store.write_game(precise).is_empty(),"fractional released project saves without rounding into a different score")
	var precise_loaded:Dictionary=precise_store.read_game()
	check(precise_loaded.has("state"),"fractional released project reloads")
	if precise_loaded.has("state"):
		check(precise_loaded.state.cash==precise.cash and precise_loaded.state.development.history[0].score==82 and precise_loaded.state.development.users==precise.development.users,"save reload preserves score, users and earned cash")
	# Existing v010 payload migrates only presentation/progression fields; cash and work stay exact.
	var old=m.initial();old.erase("development")
	var payload:=JSON.stringify(old);var f:=FileAccess.open(store.path+".legacy",FileAccess.WRITE)
	f.store_string(JSON.stringify({"version":1,"mode":"operations_v1","rules_hash":store.rules_hash,"payload":payload,"checksum":payload.sha256_text()}));f.close()
	var migrated:Dictionary=store.read_game(store.path+".legacy")
	check(not migrated.has("error") and migrated.state.cash==20000 and migrated.state.development.research==0,"old business save migrates without resetting company finance")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/operations_v011"))
	var file:=FileAccess.open("res://qa/operations_v011/development_tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"release":result,"final_company":s},"\t"));file.close()
	print("Development checks: %d; failures: %d" % [checks,failures]);quit(0 if failures==0 else 1)
