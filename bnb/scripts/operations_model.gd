extends RefCounted

const Development=preload("res://scripts/office_development.gd")
const RULES_PATH := "res://data/operations_v1.json"
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))

func initial() -> Dictionary:
	return {"week":0,"hour":0.0,"office":1,"cash":float(rules.starting_cash),"running":false,"closed":false,
		"staff":[],"furniture":[],"inventory":0,"next_staff":1,"next_furniture":1,"jobs":0,"ledger":[],"reports":[],"discarded_work":[],"development":Development.initial()}

func office(s: Dictionary) -> Dictionary:
	return rules.offices[int(s.office)-1]

func role(id: String) -> Dictionary:
	for entry in rules.roles:
		if entry.id == id: return entry
	return {}

func key(c: Array) -> String:
	return "%d,%d" % [int(c[0]),int(c[1])]

func same(a: Array,b: Array) -> bool:
	return key(a)==key(b)

func inside(s: Dictionary,c: Array) -> bool:
	var o := office(s)
	return c.size()==2 and c[0]>=0 and c[0]<o.width and c[1]>=0 and c[1]<o.height

func entrance(s: Dictionary) -> Array:
	return [0,int(office(s).height)-1]

func blocked(s: Dictionary, goal: Array = []) -> Dictionary:
	var result := {}
	for desk in s.furniture:
		result[key(desk.cell)] = true
		var seat := [desk.cell[0],desk.cell[1]+1]
		if goal.size()!=2 or not same(seat,goal): result[key(seat)] = true
	return result

func route(s: Dictionary, start: Array, goal: Array) -> Array:
	if not inside(s,start) or not inside(s,goal): return []
	start=[int(start[0]),int(start[1])];goal=[int(goal[0]),int(goal[1])]
	var obstacles := blocked(s,goal)
	if obstacles.has(key(start)) or obstacles.has(key(goal)): return []
	var frontier: Array = [start]
	var parents := {key(start): []}
	var cells := {key(start): start}
	var head := 0
	while head < frontier.size():
		var at: Array = frontier[head]; head += 1
		if at == goal:
			var path: Array = []
			var cursor: Array = goal
			while cursor != start:
				path.push_front(cursor)
				cursor = parents[key(cursor)]
			return path
		for d in [[1,0],[0,-1],[-1,0],[0,1]]:
			var next := [int(at[0])+d[0],int(at[1])+d[1]]
			var id := key(next)
			if inside(s,next) and not obstacles.has(id) and not parents.has(id):
				parents[id] = at; cells[id] = next; frontier.append(next)
	return []

func entry(s: Dictionary, kind: String, amount: float, employee: int = 0) -> void:
	s.cash += amount
	s.ledger.append({"week":int(s.week)+1,"hour":s.hour,"kind":kind,"amount":amount,"employee":employee})

func hire(s: Dictionary, role_id: String) -> String:
	if s.running or s.closed: return "请在周间休息时招聘。"
	if s.staff.size() >= int(office(s).capacity): return "办公室编制已满，请先升级。"
	if s.cash < rules.hire_price: return "现金不足，无法支付招聘费。"
	if role(role_id).is_empty(): return "岗位无效。"
	var spawn := entrance(s)
	var occupied := {}
	for worker in s.staff: occupied[key([roundi(worker.pos[0]),roundi(worker.pos[1])])] = true
	var obstacles := blocked(s)
	for x in range(int(office(s).width)):
		var c := [x,int(office(s).height)-1]
		if not occupied.has(key(c)) and not obstacles.has(key(c)) and (same(c,entrance(s)) or not route(s,entrance(s),c).is_empty()):
			spawn = c; break
	var worker := {"id":int(s.next_staff),"role":role_id,"pos":[float(spawn[0]),float(spawn[1])],
		"desk":0,"path":[],"progress":0.0,"hours":0.0,"jobs":0,"discarded_hours":0.0}
	s.next_staff += 1; s.staff.append(worker)
	entry(s,"hire",-float(rules.hire_price),worker.id)
	assign(s)
	return ""

func buy(s: Dictionary) -> String:
	if s.running or s.closed: return "请在周间休息时购买工位。"
	if s.cash < rules.workstation_price: return "现金不足。"
	if s.furniture.size()+int(s.inventory) >= int(office(s).capacity): return "工位数量已到办公室上限。"
	s.inventory += 1; entry(s,"furniture",-float(rules.workstation_price))
	return ""

func place_error(s: Dictionary, cell: Array) -> String:
	if s.running or s.closed: return "请在周间休息时摆放。"
	if s.inventory <= 0: return "请先购买一个工位。"
	var seat := [cell[0],cell[1]+1]
	if not inside(s,cell) or not inside(s,seat): return "桌椅需要连续两格，不能超出地板。"
	if same(cell,entrance(s)) or same(seat,entrance(s)): return "入口需要保持畅通。"
	for desk in s.furniture:
		var old_seat := [desk.cell[0],desk.cell[1]+1]
		if key(cell) in [key(desk.cell),key(old_seat)] or key(seat) in [key(desk.cell),key(old_seat)]: return "桌椅不能重叠。"
	for worker in s.staff:
		if key([roundi(worker.pos[0]),roundi(worker.pos[1])]) in [key(cell),key(seat)]: return "这里站着员工，请选择另一格。"
		for step in worker.path:
			if same(step,cell) or same(step,seat):return "这里是员工已安排的行走路线，请保留通道。"
	var trial := s.duplicate(true)
	trial.furniture.append({"id":int(s.next_furniture),"cell":cell,"worker":0})
	for desk in trial.furniture:
		var target := [desk.cell[0],desk.cell[1]+1]
		if not same(entrance(trial),target) and route(trial,entrance(trial),target).is_empty(): return "这个位置会阻断工位通道。"
	for worker in trial.staff:
		if worker.desk == 0: continue
		var desk := find_desk(trial,int(worker.desk))
		var target := [desk.cell[0],desk.cell[1]+1]
		var at := [roundi(worker.pos[0]),roundi(worker.pos[1])]
		if not same(at,target) and route(trial,at,target).is_empty(): return "这个位置会挡住员工到岗。"
	return ""

func place(s: Dictionary, cell: Array) -> String:
	var error := place_error(s,cell)
	if not error.is_empty(): return error
	s.furniture.append({"id":int(s.next_furniture),"cell":cell.duplicate(),"worker":0})
	s.next_furniture += 1; s.inventory -= 1
	assign(s)
	return ""

func starter_layout(s:Dictionary,cells:Array) -> String:
	if s.running or s.closed:return "请在周间休息时布置。"
	if s.office!=1 or not s.staff.is_empty() or not s.furniture.is_empty() or s.inventory!=0:return "创业布局仅用于尚未招聘、无工位与库存的起步办公室。"
	if cells.size()!=4:return "创业布局需要四套工位。"
	if s.cash<float(rules.workstation_price)*4:return "现金不足，需要支付四套工位的实际购置费用。"
	var trial:=s.duplicate(true)
	for cell in cells:
		if not cell is Array or cell.size()!=2 or not whole(cell[0]) or not whole(cell[1]):return "布局坐标无效。"
		var error:=buy(trial)
		if error.is_empty():error=place(trial,cell)
		if not error.is_empty():return error
	if not valid(trial):return "布局状态无效，未扣款。"
	s.clear();s.merge(trial,true)
	return ""

func find_desk(s: Dictionary,id: int) -> Dictionary:
	for d in s.furniture:
		if int(d.id)==id:return d
	return {}

func assign(s: Dictionary) -> void:
	for worker in s.staff:
		if worker.desk != 0: continue
		for desk in s.furniture:
			if desk.worker != 0: continue
			var goal := [desk.cell[0],desk.cell[1]+1]
			var at := [roundi(worker.pos[0]),roundi(worker.pos[1])]
			var path := route(s,at,goal)
			if (same(at,goal) or not path.is_empty()) and Vector2(worker.pos[0],worker.pos[1]).distance_to(Vector2(at[0],at[1]))>.0001:path.push_front(at)
			if same(at,goal) or not path.is_empty():
				worker.desk = int(desk.id); desk.worker = int(worker.id); worker.path = path; break

func release_worker(s:Dictionary,worker:Dictionary,reason:String) -> void:
	var desk:=find_desk(s,int(worker.desk))
	if float(worker.progress)>0:
		s.discarded_work.append({"employee":int(worker.id),"furniture":int(worker.desk),"week":int(s.week)+1,"hours":float(worker.progress),"reason":reason})
		worker.discarded_hours+=float(worker.progress)
	worker.progress=0.0;worker.path=[];worker.desk=0
	if not desk.is_empty():desk.worker=0

func layout_error(s:Dictionary) -> String:
	var occupied:Dictionary={}
	for desk in s.furniture:
		for cell in [desk.cell,[desk.cell[0],desk.cell[1]+1]]:
			if not inside(s,cell):return "桌椅需要连续两格，不能超出地板。"
			if same(cell,entrance(s)):return "入口需要保持畅通。"
			if occupied.has(key(cell)):return "桌椅不能重叠。"
			occupied[key(cell)]=true
	for desk in s.furniture:
		var goal:=[desk.cell[0],desk.cell[1]+1]
		if route(s,entrance(s),goal).is_empty():return "这个位置会阻断工位通道。"
	for worker in s.staff:
		var at:=[roundi(worker.pos[0]),roundi(worker.pos[1])]
		var desk:=find_desk(s,int(worker.desk))
		var goal:Array=entrance(s) if desk.is_empty() else [desk.cell[0],desk.cell[1]+1]
		if not same(at,goal) and route(s,at,goal).is_empty():return "这个位置会挡住员工到岗或离开。"
	return ""

func move_error(s:Dictionary,id:int,cell:Array) -> String:
	var copy:=s.duplicate(true)
	return move(copy,id,cell)

func move(s:Dictionary,id:int,cell:Array) -> String:
	if s.running or s.closed:return "请在周间休息时调整工位。"
	if not valid(s):return "公司状态无效，未移动。"
	var old:=find_desk(s,id)
	if old.is_empty():return "工位已不存在。"
	if cell.size()!=2 or not whole(cell[0]) or not whole(cell[1]):return "布局坐标无效。"
	if same(old.cell,cell):return ""
	var footprint:=[key(cell),key([cell[0],cell[1]+1])]
	for worker in s.staff:
		if key([roundi(worker.pos[0]),roundi(worker.pos[1])]) in footprint:return "这里站着员工，请选择另一格。"
	var trial:=s.duplicate(true);var desk:=find_desk(trial,id)
	for worker in trial.staff:
		var affected:=int(worker.desk)==id
		for step in worker.path:
			if key(step) in footprint:affected=true
		if affected:release_worker(trial,worker,"move")
	desk.cell=cell.duplicate()
	var error:=layout_error(trial)
	if not error.is_empty():return error
	assign(trial)
	if not valid(trial):return "移动后的状态无效，原布局已保留。"
	s.clear();s.merge(trial,true)
	return ""

func sell(s:Dictionary,id:int) -> String:
	if s.running or s.closed:return "请在周间休息时出售工位。"
	if not valid(s):return "公司状态无效，未出售。"
	if find_desk(s,id).is_empty():return "工位已不存在，不能再次出售。"
	var trial:=s.duplicate(true)
	for worker in trial.staff:
		if int(worker.desk)==id:release_worker(trial,worker,"sale")
	for i in range(trial.furniture.size()):
		if int(trial.furniture[i].id)==id:trial.furniture.remove_at(i);break
	assign(trial)
	entry(trial,"furniture_sale",float(rules.workstation_resale_price))
	trial.ledger[-1].furniture_id=id
	if not valid(trial):return "出售后的状态无效，原工位与现金已保留。"
	s.clear();s.merge(trial,true)
	return ""

func phase(worker: Dictionary) -> String:
	if worker.desk == 0: return "等待工位"
	return "待出发" if not worker.path.is_empty() else "已到岗"

func begin(s: Dictionary) -> String:
	if s.closed: return "现金耗尽，公司已停业。"
	if s.running: return "本周正在进行。"
	s.running = true
	return ""

func tick(s: Dictionary, dt: float) -> bool:
	if not s.running or s.closed or not is_finite(dt) or dt<=0: return false
	var remaining := minf(dt,float(rules.week_hours)-float(s.hour))
	s.hour += remaining
	for worker in s.staff:
		if worker.desk == 0: continue
		var available := remaining
		while available > .0000001 and not worker.path.is_empty():
			var next: Array = worker.path[0]
			var pos := Vector2(worker.pos[0],worker.pos[1])
			var target := Vector2(next[0],next[1])
			var distance := pos.distance_to(target)
			var travel := minf(distance,float(rules.walk_speed)*available)
			if distance > .000001: pos = pos.move_toward(target,travel)
			worker.pos = [pos.x,pos.y]
			available -= travel/float(rules.walk_speed)
			if travel >= distance-.000001: worker.pos = [float(next[0]),float(next[1])]; worker.path.pop_front()
			else: break
		if worker.path.is_empty() and available > 0:
			worker.hours += available; worker.progress += available
			var job := role(worker.role)
			while worker.progress >= float(job.cycle)-.000001:
				worker.progress = maxf(0,worker.progress-float(job.cycle)); worker.jobs += 1; s.jobs += 1; s.development.research += 2
				entry(s,"income",float(job.revenue),worker.id)
				entry(s,"server",-float(rules.batch_server_cost),worker.id)
	if Development.advance(s):entry(s,"launch",float(s.development.history[-1].sales))
	if s.hour >= float(rules.week_hours)-.000001:
		settle(s); return true
	return false

func settle(s: Dictionary) -> void:
	for worker in s.staff: entry(s,"salary",-float(role(worker.role).salary),worker.id)
	entry(s,"rent",-float(office(s).rent))
	var totals := {"income":0.0,"server":0.0,"salary":0.0,"rent":0.0,"hire":0.0,"furniture":0.0,"upgrade":0.0,"development":0.0,"launch":0.0,"furniture_sale":0.0}
	for item in s.ledger:
		if int(item.week)==int(s.week)+1: totals[item.kind] += item.amount
	var investment: float = totals.hire+totals.furniture+totals.upgrade+totals.development+totals.furniture_sale
	var profit: float = totals.income+totals.server+totals.salary+totals.rent+totals.launch
	s.week += 1; s.hour = 0.0; s.running = false; s.closed = s.cash < 0
	s.reports.append({"week":int(s.week),"totals":totals,"profit":profit,"investment":investment,"cash":s.cash,"jobs":s.jobs})

func upgrade(s: Dictionary) -> String:
	if s.running or s.closed: return "请在周间休息时升级办公室。"
	if s.office >= rules.offices.size(): return "办公室已达到最高等级。"
	if s.week < 1: return "先完成一次周结算。"
	var price: float = rules.offices[int(s.office)].upgrade_price
	if s.cash < price: return "现金不足，无法升级。"
	entry(s,"upgrade",-price); s.office += 1
	return ""

func commission(s:Dictionary,product:int,audience:int) -> String:
	var error:=Development.launch(s,product,audience)
	if error.is_empty():entry(s,"development",-float(Development.PRODUCTS[product].price))
	return error

func whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value)

func valid(s: Variant) -> bool:
	if not s is Dictionary or s.size()!=initial().size(): return false
	for field in initial():
		if not s.has(field): return false
	for field in ["week","office","inventory","next_staff","next_furniture","jobs"]:
		if not whole(s[field]): return false
	if s.week<0 or s.week>9999 or s.office<1 or s.office>3 or s.inventory<0: return false
	if not s.running is bool or not s.closed is bool: return false
	for field in ["hour","cash"]:
		if not (s[field] is float or s[field] is int) or not is_finite(float(s[field])): return false
	if s.hour<0 or s.hour>=rules.week_hours or (s.closed and s.running) or s.closed!=(s.cash<0): return false
	if not s.running and absf(s.hour)>.000001:return false
	for field in ["staff","furniture","ledger","reports","discarded_work"]:
		if not s[field] is Array: return false
	if s.reports.size()!=int(s.week) or s.staff.size()>int(office(s).capacity) or s.furniture.size()+s.inventory>office(s).capacity: return false
	var desk_ids := {}; var worker_ids := {}; var occupied := {}
	for desk in s.furniture:
		if not desk is Dictionary or desk.size()!=3 or not desk.has_all(["id","cell","worker"]):return false
		if not whole(desk.id) or desk.id<=0 or desk_ids.has(int(desk.id)) or not whole(desk.worker):return false
		if not desk.cell is Array or desk.cell.size()!=2 or not whole(desk.cell[0]) or not whole(desk.cell[1]):return false
		for c in [desk.cell,[desk.cell[0],desk.cell[1]+1]]:
			if not inside(s,c) or same(c,entrance(s)) or occupied.has(key(c)):return false
			occupied[key(c)]=true
		desk_ids[int(desk.id)]=desk
	for worker in s.staff:
		if not worker is Dictionary or worker.size()!=9 or not worker.has_all(["id","role","pos","desk","path","progress","hours","jobs","discarded_hours"]):return false
		if not whole(worker.id) or worker.id<=0 or worker_ids.has(int(worker.id)) or not worker.role is String or role(worker.role).is_empty():return false
		if not whole(worker.desk) or not whole(worker.jobs) or worker.jobs<0:return false
		if not worker.pos is Array or worker.pos.size()!=2 or not inside(s,worker.pos):return false
		for v in worker.pos+[worker.progress,worker.hours,worker.discarded_hours]:
			if not (v is int or v is float) or not is_finite(float(v)):return false
		if worker.progress<0 or worker.progress>=role(worker.role).cycle or worker.hours<0 or worker.discarded_hours<0:return false
		if absf(float(worker.hours)-float(worker.jobs)*float(role(worker.role).cycle)-float(worker.progress)-float(worker.discarded_hours))>.0001:return false
		if not worker.path is Array:return false
		if worker.desk!=0:
			if not desk_ids.has(int(worker.desk)) or desk_ids[int(worker.desk)].worker!=worker.id:return false
			var goal := [desk_ids[int(worker.desk)].cell[0],desk_ids[int(worker.desk)].cell[1]+1]
			if worker.path.is_empty() and Vector2(worker.pos[0],worker.pos[1]).distance_to(Vector2(goal[0],goal[1]))>.0001:return false
			var prev := Vector2(worker.pos[0],worker.pos[1])
			for c in worker.path:
				if not c is Array or c.size()!=2 or not whole(c[0]) or not whole(c[1]) or not inside(s,c) or blocked(s,goal).has(key(c)):return false
				var point := Vector2(c[0],c[1])
				if prev.distance_to(point)>1.0001:return false
				prev = point
			if not worker.path.is_empty() and not same(worker.path[-1],goal):return false
		else:
			if not worker.path.is_empty():return false
		worker_ids[int(worker.id)]=worker
	for desk in s.furniture:
		if desk.worker!=0 and (not worker_ids.has(int(desk.worker)) or worker_ids[int(desk.worker)].desk!=desk.id):return false
	if s.next_staff<=0 or s.next_furniture<=0:return false
	for id in worker_ids:
		if s.next_staff<=id:return false
	for id in desk_ids:
		if s.next_furniture<=id:return false
	var discarded:Dictionary={}
	for record in s.discarded_work:
		if not record is Dictionary or record.size()!=5 or not record.has_all(["employee","furniture","week","hours","reason"]):return false
		if not whole(record.employee) or not worker_ids.has(int(record.employee)) or not whole(record.furniture) or record.furniture<=0 or record.furniture>=s.next_furniture:return false
		if not whole(record.week) or record.week<1 or record.week>s.week+1 or record.reason not in ["move","sale"]:return false
		if not (record.hours is int or record.hours is float) or not is_finite(float(record.hours)) or record.hours<=0 or record.hours>=role(worker_ids[int(record.employee)].role).cycle:return false
		discarded[int(record.employee)]=float(discarded.get(int(record.employee),0))+record.hours
	for worker in s.staff:
		if absf(worker.discarded_hours-float(discarded.get(int(worker.id),0)))>.0001:return false
	var sale_ids:Dictionary={};var purchases:=0
	var cash := float(rules.starting_cash)
	var job_counts := {}
	var income_count := 0
	for item in s.ledger:
		if not item is Dictionary or item.size()!=(6 if item.get("kind")=="furniture_sale" else 5) or not item.has_all(["week","hour","kind","amount","employee"]):return false
		if item.kind not in ["hire","furniture","upgrade","income","server","salary","rent","development","launch","furniture_sale"] or not whole(item.week) or item.week<1 or item.week>s.week+1:return false
		if not (item.amount is int or item.amount is float) or not is_finite(float(item.amount)):return false
		if not whole(item.employee) or item.employee<0:return false
		if not (item.hour is int or item.hour is float) or not is_finite(float(item.hour)) or item.hour<0 or item.hour>rules.week_hours:return false
		if (item.kind in ["income","launch","furniture_sale"] and item.amount<=0) or (item.kind not in ["income","launch","furniture_sale"] and item.amount>=0):return false
		if item.kind in ["hire","income","server","salary"] and not worker_ids.has(int(item.employee)):return false
		if item.kind=="furniture":
			if item.amount!=-float(rules.workstation_price):return false
			purchases+=1
		if item.kind=="furniture_sale":
			if not whole(item.get("furniture_id")) or item.furniture_id<=0 or item.furniture_id>=s.next_furniture or sale_ids.has(int(item.furniture_id)) or desk_ids.has(int(item.furniture_id)):return false
			if item.amount!=float(rules.workstation_resale_price) or item.employee!=0:return false
			sale_ids[int(item.furniture_id)]=true
		if item.kind=="income":
			income_count+=1
			var id:=int(item.employee)
			job_counts[id]=int(job_counts.get(id,0))+1
			if item.amount!=role(worker_ids[id].role).revenue:return false
		cash += item.amount
	if s.furniture.size()+sale_ids.size()!=int(s.next_furniture)-1 or purchases!=int(s.next_furniture)-1+int(s.inventory):return false
	if int(s.jobs)!=income_count:return false
	for worker in s.staff:
		if int(worker.jobs)!=int(job_counts.get(int(worker.id),0)):return false
	for i in range(s.reports.size()):
		var report:Variant=s.reports[i]
		if not report is Dictionary or report.size()!=6 or not report.has_all(["week","totals","profit","investment","cash","jobs"]):return false
		if report.week!=i+1 or not report.totals is Dictionary or report.totals.size()!=10:return false
		var totals:={"income":0.0,"server":0.0,"salary":0.0,"rent":0.0,"hire":0.0,"furniture":0.0,"upgrade":0.0,"development":0.0,"launch":0.0,"furniture_sale":0.0}
		var close_cash:=float(rules.starting_cash)
		var close_jobs:=0
		for item in s.ledger:
			if int(item.week)<=i+1:close_cash+=item.amount;close_jobs+=1 if item.kind=="income" else 0
			if int(item.week)==i+1:totals[item.kind]+=item.amount
		for kind in totals:
			if not report.totals.has(kind) or not (report.totals[kind] is int or report.totals[kind] is float) or not is_finite(float(report.totals[kind])) or absf(totals[kind]-report.totals[kind])>.001:return false
		for field in ["profit","investment","cash","jobs"]:
			if not (report[field] is int or report[field] is float) or not is_finite(float(report[field])):return false
		if absf(report.cash-close_cash)>.001 or report.jobs!=close_jobs:return false
		if absf(report.profit-totals.income-totals.server-totals.salary-totals.rent-totals.launch)>.001:return false
		if absf(report.investment-totals.hire-totals.furniture-totals.upgrade-totals.development-totals.furniture_sale)>.001:return false
	if not Development.valid(s):return false
	var commissions:=[];var sales:=[]
	for item in s.ledger:
		if item.kind=="development":commissions.append(item)
		if item.kind=="launch":sales.append(item)
	var projects:Array=s.development.history.duplicate()
	if not s.development.active.is_empty():projects.append(s.development.active)
	if commissions.size()!=projects.size() or sales.size()!=s.development.history.size():return false
	for i in projects.size():
		if commissions[i].amount!=-float(Development.PRODUCTS[int(projects[i].product)].price):return false
	for i in sales.size():
		if sales[i].amount!=s.development.history[i].sales:return false
	return absf(cash-float(s.cash))<.001
