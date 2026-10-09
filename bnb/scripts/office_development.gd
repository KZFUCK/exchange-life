extends RefCounted
# Project work consumes actual seated working hours from the operations simulation.
const PRODUCTS=[{"name":"现货撮合","hours":20.0,"cost":0,"unlock":0,"price":1500}, {"name":"专业行情","hours":32.0,"cost":12,"unlock":10,"price":3000}, {"name":"机构服务","hours":44.0,"cost":24,"unlock":25,"price":5000}]
const AUDIENCES=["个人用户","专业交易员","机构客户"]
const FIT=[[1.0,1.15,.8],[.8,1.25,1.1],[.7,1.0,1.3]]

static func initial() -> Dictionary:return {"active":{},"history":[],"training":{},"research":0,"users":0,"trust":0}

static func level(s:Dictionary,id:int) -> int:
	for w in s.staff:
		if int(w.id)==id:return mini(10,1+int((int(w.jobs)+int(s.development.training.get(str(id),0))*3)/3))
	return 1

static func train(s:Dictionary,id:int) -> String:
	if s.running or s.closed:return "请在周间休息时培训。"
	var found:=false
	for w in s.staff:if int(w.id)==id:found=true
	if not found:return "先选择一名员工。"
	if level(s,id)>=10:return "员工已达到最高等级。"
	if s.development.research<5:return "研发点不足；员工每完成一批业务获得 2 点。"
	s.development.research-=5
	s.development.training[str(id)]=int(s.development.training.get(str(id),0))+1
	return ""

static func launch(s:Dictionary,product:int,audience:int) -> String:
	if s.running or s.closed:return "请在周间休息时立项。"
	if not s.development.active.is_empty():return "当前项目尚未完成。"
	if product<0 or product>=PRODUCTS.size() or audience<0 or audience>=AUDIENCES.size():return "项目类型无效。"
	if s.staff.is_empty():return "先招聘员工。"
	var rule:Dictionary=PRODUCTS[product]
	if s.cash<rule.price:return "现金不足，需要项目预算 ¥%d。" % rule.price
	if s.development.trust<rule.unlock:return "口碑达到 %d 才能解锁。" % rule.unlock
	if s.development.research<rule.cost:return "需要 %d 研发点。" % rule.cost
	var team:=[]
	for w in s.staff:team.append({"id":int(w.id),"role":w.role,"level":level(s,int(w.id)),"start":float(w.hours),"end":float(w.hours)})
	s.development.research-=rule.cost
	s.development.active={"product":product,"audience":audience,"team":team,"work":0.0,"quality":0.0,"score":0,"users":0,"trust":0,"sales":0}
	return ""

static func evaluate(p:Dictionary) -> Dictionary:
	var work:=0.0;var quality:=0.0;var roles:={}
	for member in p.team:
		var hours:float=member.end-member.start;work+=hours
		quality+=hours*(1.0+.15*(member.level-1));if hours>.001:roles[member.role]=true
	var target:float=PRODUCTS[int(p.product)].hours
	var score:=clampi(roundi(quality/target*50.0*float(FIT[int(p.product)][int(p.audience)])+roles.size()*8),1,100)
	return {"work":work,"quality":quality,"score":score,"users":score*(120+int(p.product)*80),"trust":maxi(1,score/5),"sales":score*(120+int(p.product)*80)/4}

static func advance(s:Dictionary) -> bool:
	var d:Dictionary=s.development
	if d.active.is_empty():return false
	var p:Dictionary=d.active
	# Stop exactly at the target. Excess business work belongs to the next project only after it is commissioned.
	var left:float=PRODUCTS[int(p.product)].hours-float(p.work)
	for member in p.team:
		for w in s.staff:
			if int(w.id)==int(member.id):
				var available:=maxf(0,float(w.hours)-float(member.end));var used:=minf(left,available)
				member.end+=used;left-=used
	var result:=evaluate(p);p.work=result.work;p.quality=result.quality
	if p.work<PRODUCTS[int(p.product)].hours-.00001:return false
	p.score=result.score;p.users=result.users;p.trust=result.trust;p.sales=result.sales
	d.users+=p.users;d.trust+=p.trust;d.history.append(p.duplicate(true));d.active={}
	return true

static func stage(p:Dictionary) -> String:
	if p.is_empty():return "等待新项目"
	var ratio:float=float(p.work)/float(PRODUCTS[int(p.product)].hours)
	return "需求企划" if ratio<.2 else ("功能开发" if ratio<.7 else "测试上线")

static func valid(s:Dictionary) -> bool:
	var d:Variant=s.get("development")
	if not d is Dictionary or d.size()!=6 or not d.has_all(["active","history","training","research","users","trust"]):return false
	if not d.training is Dictionary or not d.history is Array or not d.active is Dictionary:return false
	for key in ["research","users","trust"]:
		if not (d[key] is int or d[key] is float) or not is_finite(float(d[key])) or d[key]!=int(d[key]) or d[key]<0:return false
	var workers:={};var spent:=0;var users:=0;var trust:=0;var ends:={}
	for w in s.staff:workers[str(int(w.id))]=w
	for key in d.training:
		if not workers.has(key) or not (d.training[key] is int or d.training[key] is float):return false
		var n:float=d.training[key]
		if not is_finite(n) or n!=int(n) or n<0 or n>9:return false
		spent+=int(n)*5
	var projects:Array=d.history.duplicate()
	if not d.active.is_empty():projects.append(d.active)
	for index in projects.size():
		var p:Variant=projects[index]
		if not p is Dictionary or p.size()!=9 or not p.has_all(["product","audience","team","work","quality","score","users","trust","sales"]):return false
		for key in ["product","audience","score","users","trust","sales"]:
			if not (p[key] is int or p[key] is float) or not is_finite(float(p[key])) or p[key]!=int(p[key]):return false
		if p.product<0 or p.product>=PRODUCTS.size() or p.audience<0 or p.audience>=AUDIENCES.size():return false
		if not p.team is Array or p.team.is_empty():return false
		var ids:={}
		for member in p.team:
			if not member is Dictionary or member.size()!=5 or not member.has_all(["id","role","level","start","end"]):return false
			for key in ["id","level","start","end"]:
				if not (member[key] is int or member[key] is float) or not is_finite(float(member[key])):return false
			var id:=str(int(member.id))
			if member.id!=int(member.id) or ids.has(id) or not workers.has(id) or member.role!=workers[id].role:return false
			if member.level!=int(member.level) or member.level<1 or member.level>10:return false
			if member.start<0 or member.end<member.start or member.end>workers[id].hours+.00001 or member.start<float(ends.get(id,0))-.00001:return false
			ids[id]=true;ends[id]=member.end
		var computed:=evaluate(p)
		for key in ["work","quality"]:
			if not (p[key] is int or p[key] is float) or not is_finite(float(p[key])) or absf(p[key]-computed[key])>.0001:return false
		spent+=int(PRODUCTS[int(p.product)].cost)
		if index<d.history.size():
			if absf(p.work-PRODUCTS[int(p.product)].hours)>.0001:return false
			for key in ["score","users","trust","sales"]:if p[key]!=computed[key]:return false
			users+=int(p.users);trust+=int(p.trust)
		else:
			if p.work>=PRODUCTS[int(p.product)].hours or p.score!=0 or p.users!=0 or p.trust!=0 or p.sales!=0:return false
	return d.research==int(s.jobs)*2-spent and d.users==users and d.trust==trust
