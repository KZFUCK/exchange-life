extends SceneTree
const Model=preload("res://scripts/mm_bd_mandate_model.gd")
const Store=preload("res://scripts/mm_bd_mandate_store.gd")
const Legacy=preload("res://scripts/mm_bd_mandate_legacy_model.gd")
const Channels=preload("res://scripts/mm_bd_channels.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL REGRESSION: ",label)
func work()->Dictionary:return {"0":"核对客户资金和风险授权，不能保证固定收益；未知状态待查。","1":"说明实际执行事实与影响，停止新增操作不等于资产已撤出。","2":"确认责任人、恢复条件和下一次报告时间，交带教审阅。"}
func prepared(m:RefCounted,index:int,mode:String="guided",variant:int=0,width:float=20)->Dictionary:
	var s:Dictionary=m.initial(index);check(m.apply(s,{"kind":"begin","mode":mode,"variant":variant}).is_empty(),"begin mode recorded")
	for q in m.data.questions:m.apply(s,{"kind":"ask","id":q.id})
	var before:Dictionary=s.duplicate(true)
	check(not m.apply(s,{"kind":"draft"}).is_empty() and m.same(before,s),"six clicks alone do not submit interview memo")
	m.apply(s,{"kind":"draft","work":work()})
	var p:Dictionary=m.default_proposal(s)
	if index==0:p.width_pct=width
	check(not m.apply(s,{"kind":"propose","proposal":p}).is_empty(),"valid numbers alone cannot submit proposal")
	m.apply(s,{"kind":"propose","proposal":p,"work":work()})
	for t in m.scenario(s).negotiation:
		check(not m.apply(s,{"kind":"answer","choice":t.correct}).is_empty(),"correct multiple choice still needs authored response")
		m.apply(s,{"kind":"answer","choice":t.correct,"work":work()})
	check(s.phase=="execution" and m.valid(s),"valid authored proposal and negotiation reach delivery")
	return s
func _initialize()->void:call_deferred("run")
func run()->void:
	var m=Model.new();var s:Dictionary=prepared(m,0,"guided",0,35)
	m.apply(s,{"kind":"day","action":"keep","notify":false,"work":work()})
	var keep:Dictionary=s.duplicate(true);var risk:Dictionary=s.duplicate(true)
	m.apply(keep,{"kind":"day","action":"keep","notify":true,"work":work()});m.apply(risk,{"kind":"day","action":"risk","notify":true,"work":work()})
	check(keep.daily[-1].active and keep.daily[-1].sla_met and keep.daily[-1].constraint_met,"audit reproducer: 35% range stays active at 1.275")
	check(keep.daily[-1].cost==0 and risk.daily[-1].cost>0 and m.grade(keep).delivery==m.grade(risk).delivery,"unnecessary reset no longer earns extra judgment points")
	s=prepared(m,0);var keep_pause:Dictionary=s.duplicate(true)
	m.apply(s,{"kind":"day","action":"keep","notify":false,"work":work()});m.apply(keep_pause,{"kind":"day","action":"pause","notify":false,"work":work()})
	check(s.fees_earned>0 and s.fees_earned==keep_pause.fees_earned and keep_pause.lp_L==s.lp_L and keep_pause.daily[-1].sla_met,"pausing adjustment does not remove LP or stop eligible example fees")
	var before:Dictionary=s.duplicate(true)
	check(not m.apply(s,{"kind":"day","action":"keep","notify":true}).is_empty() and m.same(before,s),"notification checkbox alone cannot replace notice text")
	var noisy:Dictionary=s.duplicate(true);noisy.notifications=6
	check(m.grade(noisy).communication==0 and m.grade(noisy).focus.contains("不授予"),"notification count cannot qualify written communication or job readiness")
	for index in range(4):
		for variant in [1,2]:
			var v:Dictionary=prepared(m,index,"assessment",variant)
			check(m.scenario(v).capital<m.data.cases[index].capital and m.scenario(v).budget<m.data.cases[index].budget,"independent numerical variant changes funding and budget")
			check(m.valid(v) and m.scenario(v).facts.funding.contains(str(roundi(m.scenario(v).capital))),"variant survives deterministic replay with consistent stated capital")
			for e in m.scenario(v).events:m.apply(v,{"kind":"day","action":e.expected,"notify":false,"work":work()})
			check(v.phase=="handoff" and not m.apply(v,{"kind":"handoff"}).is_empty(),"six days cannot complete without internal handoff")
			m.apply(v,{"kind":"handoff","work":work()})
			check(m.valid(v) and m.grade(v).score<=90 and m.grade(v).communication==0,"completed variant always retains manual review and example policy gate")
			if index==2:check(v.daily[1].spot_price!=v.daily[1].price and absf(v.daily[1].basis_pct)>.1,"futures scenario actually changes spot/mark basis")
			var altered:Dictionary=v.duplicate(true);altered.work.memo["0"]="伪造已核验的授权与客户会谈信息。";check(not m.valid(altered),"authored record tampering fails replay")
			var st=Store.new("/tmp/mm-bd-v2-regression-%d-%d-%d.json"%[OS.get_process_id(),index,variant])
			var course:Dictionary={"active":v,"completed":[v],"draft":{},"work_drafts":{"notice_0":{"0":"尚未写完","1":"","2":""}},"reviews":{}}
			check(st.write_course(course).is_empty() and m.same(st.read_course().course,course),"incomplete writing draft persists precisely without pretending submitted")
	var exam:Dictionary=m.initial();m.apply(exam,{"kind":"begin","mode":"assessment","variant":1})
	for q in m.data.questions:m.apply(exam,{"kind":"ask","id":q.id})
	m.apply(exam,{"kind":"draft","work":work()});m.apply(exam,{"kind":"propose","proposal":m.default_proposal(exam),"work":work()})
	var wrong:int=(int(m.scenario(exam).negotiation[0].correct)+1)%3;m.apply(exam,{"kind":"answer","choice":wrong,"work":work()})
	check(exam.round==1 and not str(exam.notes[-1]).contains("带教：") and m.grade(exam).boundaries==0,"independent exercise preserves wrong first answer without corrective hint")
	var longest_hits:int=0
	for c in m.data.cases:
		for q in c.negotiation:
			var longest:int=0
			for i in range(1,3):
				if q.options[i].length()>q.options[longest].length():longest=i
			if longest==int(q.correct):longest_hits+=1
	check(longest_hits<=4,"longest-option shortcut no longer solves all twelve negotiation decisions")
	var labels:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/mm_bd_channel_labels_v2.json"));var lesson=Channels.new("/tmp/mm-bd-label-%d.json"%OS.get_process_id());var quiz_hits:int=0
	for i in range(4):
		for j in range(4):
			var longest:int=0
			for k in range(1,3):
				if labels[i][j][k].length()>labels[i][j][longest].length():longest=k
			if longest==int(lesson.data.modules[i].quiz[j].correct):quiz_hits+=1
	check(quiz_hits<10,"visible mechanism labels remove the previous 14/16 length shortcut")
	var legacy=Legacy.new();check(legacy.valid(legacy.initial()) and legacy.MANDATE_DATA_PATH.ends_with("v1.json"),"legacy replay stays available on original immutable case data")
	var draft_state:Dictionary=m.initial(2);var invalid_draft:Dictionary=m.blank_proposal(draft_state);invalid_draft.spot_pct=70;invalid_draft.margin_pct=40
	var draft_course:Dictionary={"active":draft_state,"completed":[],"draft":invalid_draft,"work_drafts":{},"reviews":{}}
	check(not m.proposal_error(draft_state,invalid_draft).is_empty() and m.valid_course(draft_course),"financially incomplete proposal can be retained as draft without becoming submitted authorization")
	var out:String="res://qa/mm_bd_onboarding_v2/regression_results.json";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()));var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"longest_negotiation_hits":longest_hits,"longest_quiz_hits":quiz_hits},"\t",true,true));f.close();print("Training regression checks: %d; failures: %d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
