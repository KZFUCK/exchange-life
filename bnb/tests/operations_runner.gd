extends SceneTree

const Model=preload("res://scripts/operations_model.gd")
const Store=preload("res://scripts/operations_store.gd")
const Main=preload("res://scripts/operations_main.gd")
var checks:=0
var failures:=0

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL OPERATIONS: ",description)

func equal(a:Variant,b:Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<.00001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in a:
			if not b.has(k) or not equal(a[k],b[k]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not equal(a[i],b[i]):return false
		return true
	return a==b

func _initialize() -> void:
	call_deferred("run")

func click_cell(game: Control,c: Array) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=game.board.point(c)
	game.board._gui_input(event)

func run() -> void:
	var m=Model.new();var s:Dictionary=m.initial()
	check(m.valid(s),"empty company is a valid save state")
	check(not m.upgrade(s).is_empty(),"upgrade requires actual first settlement")
	check(m.hire(s,"engineer").is_empty(),"recruitment succeeds")
	check(s.cash==19400 and s.staff.size()==1 and s.staff[0].desk==0,"hiring charges fee and creates idle independent worker")
	m.begin(s)
	for i in range(80):m.tick(s,.1)
	check(s.jobs==0 and s.cash==18450,"unassigned employee earns zero but incurs weekly salary and rent")
	s=m.initial();m.hire(s,"engineer");m.buy(s)
	check(s.inventory==1 and s.furniture.is_empty(),"purchase goes to inventory before placement")
	var before:=JSON.stringify(s)
	check(not m.place(s,[0,6]).is_empty() and JSON.stringify(s)==before,"entrance overlap rejected without mutation")
	check(not m.place(s,[2,6]).is_empty(),"chair outside floor rejected")
	check(m.place(s,[2,1]).is_empty(),"place a reachable table and chair")
	check(s.inventory==0 and s.staff[0].desk==1 and s.furniture[0].worker==1,"placed desk assigns employee and consumes stock")
	check(s.staff[0].path.size()==6,"real grid route has six cardinal steps")
	check(m.valid(s),"staff, furniture and route save consistently")
	m.buy(s);before=JSON.stringify(s)
	check(not m.place(s,[2,1]).is_empty() and JSON.stringify(s)==before,"furniture overlap rejected without charging again")
	check(not m.place(s,[2,4]).is_empty(),"new furniture cannot occupy current employee route")
	m.begin(s)
	check(not m.hire(s,"support").is_empty() and not m.buy(s).is_empty() and not m.upgrade(s).is_empty(),"live week prohibits planning mutations")
	for i in range(5):m.tick(s,.1)
	check(s.staff[0].pos!=[0.0,6.0] and s.staff[0].progress==0 and s.jobs==0,"worker really walks and earns nothing during travel")
	var store=Store.new("/tmp/bnb-operations-model-%d.json" % OS.get_process_id())
	check(store.write_game(m.initial()).is_empty(),"new mode has its own save format")
	check(store.write_game(s).is_empty(),"save while walking includes route and fractional position")
	var loaded:Dictionary=store.read_game().state
	check(equal(s,loaded),"mid-route state restored exactly within numeric precision")
	for i in range(75):m.tick(s,.1);m.tick(loaded,.1)
	check(equal(s,loaded),"uninterrupted and restored route yield identical weekly outcome")
	check(s.week==1 and not s.running and s.jobs==2,"arrival permits two completed batches before first weekly close")
	# Two desks were purchased; one is still in inventory. Independent cash equation.
	check(s.cash==19570,"cash includes 600 hiring + 1600 furniture + 2800 income - 80 servers - 450 wages - 500 rent")
	check(s.reports[0].profit==1770 and s.reports[0].investment==-2200,"operating profit is distinct from setup investments")
	check(m.valid(s),"settled company remains structurally and financially valid")
	before=JSON.stringify(s);m.tick(s,.1)
	check(JSON.stringify(s)==before,"completed week cannot settle or charge payroll twice")
	check(m.upgrade(s).is_empty() and s.office==2 and s.cash==16570,"upgrade pays 3000 and expands capacity")
	check(s.staff[0].desk==1 and s.furniture[0].cell==[2,1],"upgrade preserves original employee and furniture identity")
	var no_money:=m.initial();no_money.cash=0
	check(not m.hire(no_money,"engineer").is_empty() and not m.buy(no_money).is_empty(),"cash gates recruitment and furniture")
	var blocked:=m.initial();blocked.inventory=1
	blocked.furniture=[{"id":1,"cell":[2,1],"worker":0},{"id":2,"cell":[1,2],"worker":0},{"id":3,"cell":[3,2],"worker":0}]
	blocked.next_furniture=4
	check(not m.place_error(blocked,[2,3]).is_empty(),"last surrounding desk that cuts seat access is rejected")
	var broken:=loaded.duplicate(true);broken.staff[0].desk=999
	check(not m.valid(broken),"orphaned assignment rejected")
	broken=loaded.duplicate(true);broken.cash+=1
	check(not m.valid(broken),"ledger/cash mismatch rejected")
	broken=loaded.duplicate(true);broken.staff[0].pos=[NAN,2]
	check(not m.valid(broken),"non-finite positions rejected")
	broken=loaded.duplicate(true);broken.reports[0].totals.income+=1
	check(not m.valid(broken),"report income must agree with actual ledger")
	broken=loaded.duplicate(true);broken.staff[0].jobs+=1
	check(not m.valid(broken),"employee production count must agree with actual fees")
	var primary:=FileAccess.open(store.path,FileAccess.WRITE);primary.store_string("{bad");primary.close()
	check(store.read_game().has("error"),"corrupt save rejected")
	check(not store.write_game(s).is_empty() and FileAccess.get_file_as_string(store.path)=="{bad","bad save protected from overwrite")
	check(not store.restore_backup().has("error"),"retained valid backup restores after corruption")
	# Actual controls and board input drive the complete acceptance path.
	var game=Main.new();game.store=Store.new("/tmp/bnb-operations-ui-%d.json" % OS.get_process_id())
	root.add_child(game);game.clock_speed=1.0;await process_frame;await process_frame;game.set_physics_process(false)
	check(game.state.staff.is_empty() and game.state.furniture.is_empty(),"new default scene starts with empty company")
	game.hire_button.pressed.emit();game.buy_button.pressed.emit();click_cell(game,[2,1])
	check(game.state.staff.size()==1 and game.state.furniture.size()==1 and not game.placing,"real buttons and floor click recruit, buy and place")
	check(game.board.worker_nodes.size()==1 and game.board.furniture_nodes.size()==1,"independent worker and furniture scene instances appear")
	game.start_button.pressed.emit()
	for i in range(5):game._physics_process(.1)
	game.start_button.pressed.emit();before=JSON.stringify(game.state)
	game._physics_process(1)
	check(game.paused and before==JSON.stringify(game.state),"pause freezes route, earnings and clock")
	game.save_button.pressed.emit();var checkpoint:Dictionary=game.state.duplicate(true)
	game.start_button.pressed.emit();game._physics_process(.2);game.load_game()
	check(equal(checkpoint,game.state) and game.paused,"UI save/load resumes midweek paused at same employee position")
	game.start_button.pressed.emit()
	for i in range(75):game._physics_process(.1)
	check(game.state.week==1 and game.state.jobs==2 and game.state.cash==20370,"runtime controller completes actual first week and financial loop")
	check(not game.store.read_game().has("error"),"end-of-week auto-save is readable")
	game.upgrade_button.pressed.emit()
	for c in [[4,1],[6,1],[8,1],[2,4],[4,4],[6,4],[8,4]]:
		game.buy_button.pressed.emit();click_cell(game,c)
	for i in range(7):game.hire_button.pressed.emit()
	check(game.state.staff.size()==8 and game.state.furniture.size()==8 and game.state.office==2,"office upgrade supports eight employees and eight independently placed stations")
	check(game.board.worker_nodes.size()==8 and game.board.furniture_nodes.size()==8,"batch instances exist in live view")
	for node in game.board.worker_nodes.values():check(node.scene_file_path=="res://scenes/worker_token.tscn","same character scene reused independently")
	for node in game.board.furniture_nodes.values():check(node.scene_file_path=="res://scenes/workstation_token.tscn","same furniture scene reused independently")
	game.start_button.pressed.emit()
	for i in range(80):game._physics_process(.1)
	var all_arrived:=true
	for worker in game.state.staff:all_arrived=all_arrived and worker.path.is_empty() and worker.jobs>0
	check(all_arrived and game.state.week==2 and game.state.jobs>2,"all eight find their own seats and contribute work to second settlement")
	check(m.valid(game.state),"batch company validates cash, assignments and stock")
	game.save_game();var batch:Dictionary=game.state.duplicate(true);game.load_game()
	check(equal(batch,game.state),"full upgraded eight-person company reloads intact")
	check(game.board.worker_nodes.size()==8 and game.board.furniture_nodes.size()==8,"view reconstructs shared resources after load")
	var eight_person_company:Dictionary=game.state.duplicate(true)
	game.upgrade_button.pressed.emit()
	for c in [[1,7],[3,7],[5,7],[7,7]]:
		game.buy_button.pressed.emit();click_cell(game,c)
	for i in range(4):game.hire_button.pressed.emit()
	check(game.state.office==3 and game.state.staff.size()==12 and game.state.furniture.size()==12,"same templates extend to final 12-person office")
	var capped:=JSON.stringify(game.state)
	check(not m.hire(game.state,"engineer").is_empty() and not m.buy(game.state).is_empty() and not m.upgrade(game.state).is_empty() and JSON.stringify(game.state)==capped,"max tier and capacity fail without charging cash")
	game.start_button.pressed.emit()
	for i in range(80):game._physics_process(.1)
	check(game.state.week==3 and m.valid(game.state),"third office settles with all preserved identities and new production")
	var bankrupt:=m.initial()
	for i in range(41):m.begin(bankrupt);m.tick(bankrupt,8)
	check(bankrupt.closed and bankrupt.cash==-500 and m.valid(bankrupt),"unproductive rent-only company stops when cash goes negative")
	var failed_cash:float=bankrupt.cash;m.tick(bankrupt,8)
	check(bankrupt.cash==failed_cash and not m.begin(bankrupt).is_empty(),"closed company cannot continue generating or charging")
	var evidence:={"checks":checks,"failures":failures,"first_week_cash":20370,"batch_state":game.state,
		"eight_person_company":eight_person_company,
		"worker_scene":"res://scenes/worker_token.tscn","furniture_scene":"res://scenes/workstation_token.tscn"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/operations_v011"))
	var file:=FileAccess.open("res://qa/operations_v011/test_evidence.json",FileAccess.WRITE);file.store_string(JSON.stringify(evidence,"\t"));file.close()
	print("Operations checks: %d; failures: %d" % [checks,failures])
	game.queue_free();await process_frame;quit(0 if failures==0 else 1)
