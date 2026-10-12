extends SceneTree
const Main=preload("res://scripts/mm_bd_main.gd")
const Store=preload("res://scripts/mm_bd_store.gd")
var game:Control
var checks:int=0
var failures:Array=[]
var qa:String="res://qa/mm_bd/"
class SyntheticOnly extends Node:
	func _input(event:InputEvent)->void:
		if event.device!=991:get_viewport().set_input_as_handled()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL MM UI: ",label)
func _initialize()->void:call_deferred("run")
func frames(n:int=3)->void:
	for i in n:await process_frame
func click(id:String)->void:
	await frames()
	var control:Control=game.controls.get(id)
	if not is_instance_valid(control):check(false,"control available: "+id);return
	var parent:Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control);break
		parent=parent.get_parent()
	await frames()
	var point:Vector2=control.get_global_rect().get_center()
	if control.get_viewport()!=root:point+=Vector2(control.get_viewport().position)
	check(control.is_visible_in_tree() and point.y>=0 and point.y<root.size.y,"click target visible: "+id)
	root.grab_focus()
	var motion:=InputEventMouseMotion.new();motion.device=991;motion.position=point;motion.global_position=point;root.push_input(motion)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.device=991;event.position=point;event.global_position=point;event.button_mask=1 if down else 0;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event);await process_frame
	await frames()
func capture(name:String)->void:
	game.page_scroll.scroll_vertical=0;await frames(6);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(qa+name+".png")==OK,"capture "+name)
func run()->void:
	root.size=Vector2i(1440,900);game=Main.new();game.store=Store.new("/tmp/mm-bd-ui-%d.json"%OS.get_process_id());root.add_child(game);root.add_child(SyntheticOnly.new());await frames(8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa));await capture("home")
	check(game.page=="home" and game.model.valid_course(game.course),"new default anime training scene starts")
	for case_index in range(3):
		if game.page!="home":await click("home")
		await click("case_%d"%case_index);check(game.s().phase=="discovery","real mouse starts scenario")
		if case_index==0:await capture("discovery")
		await click("draft");check(game.s().phase=="discovery","premature quotation is blocked")
		for id in ["metrics","funding","ownership","budget","flow","venues"]:await click("ask_"+id)
		check(game.s().asked.size()==6,"six real choices record actual customer facts")
		await click("draft");check(game.s().phase=="proposal","proposal workshop opens")
		if case_index==0:
			game.form.fee.value=7000;await click("save");check(game.store.read_course().course.draft.fee==7000,"edited proposal draft saved without losing values")
			game.form.fee.value=5000;await capture("proposal")
		await click("propose");check(game.s().phase=="negotiation","real form submits proposal")
		if case_index==0:
			await capture("negotiation");await click("answer_0");check(game.s().phase=="negotiation" and game.s().cash==0,"unbounded commercial promise is blocked")
		await click("answer_1");check(game.s().phase=="execution","service boundaries permit delivery")
		if game.s().phase!="execution":finish();return
		for day in range(6):
			var event:Dictionary=game.model.scenario(game.s()).events[day]
			if day==0 and case_index==0:await capture("delivery")
			if day==0 and case_index==0:
				root.size=Vector2i(1200,720);await frames(6);await capture("delivery_720p")
				for id in ["day_keep","day_risk","day_pause"]:check(game.controls[id].get_global_rect().end.y<=game.size.y+1,"delivery action stays visible at laptop size")
				root.size=Vector2i(1440,900);await frames(6)
			if day==2 and case_index==0:await capture("delivery_day3")
			var action:String="pause" if event.outage else ("risk" if absf(float(event["return"]))>=.06 else "keep")
			await click("day_"+action)
		check(game.s().phase=="debrief" and game.course.completed.size()==case_index+1,"mouse-driven case completes and records progress")
		if case_index==0:await capture("debrief")
		await click("save");check(game.store.read_course().has("course"),"completed course saves and reloads")
		await click("export");check(game.status_label.text.contains("复盘已导出"),"Markdown coach review exported")
	await click("nav_records");await capture("records");check(game.course.completed.size()==3,"all three cases remain in training records")
	var grades:Array=[]
	for item in game.course.completed:grades.append(game.model.grade(item).score)
	game.course.active=game.model.initial();game.course.draft={}
	await click("load");check(game.confirmation.visible and game.s().phase=="brief","load confirmation visible before state change")
	game.controls.confirm=game.confirmation.get_ok_button();await click("confirm");check(game.course.completed.size()==3 and game.s().phase=="debrief" and not game.confirmation.visible,"actual confirmation restores training record")
	for i in grades.size():check(game.model.grade(game.course.completed[i]).score==grades[i],"saved and displayed competency score remains unchanged")
	await click("nav_records")
	var before:Dictionary=game.course.duplicate(true);var disk:String=FileAccess.get_file_as_string(game.store.path)
	await click("restore");game.controls.cancel=game.confirmation.get_cancel_button();await click("cancel")
	check(game.model.same(before,game.course) and FileAccess.get_file_as_string(game.store.path)==disk and not game.confirmation.visible,"backup cancel preserves memory and disk")
	var original_store=game.store
	game.store=Store.new("/tmp/mm-bd-corrupt-close-%d.json"%OS.get_process_id())
	var bad_file:=FileAccess.open(game.store.path,FileAccess.WRITE);bad_file.store_string("corrupt");bad_file.close()
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(game.confirmation.visible and FileAccess.get_file_as_string(game.store.path)=="corrupt","failed close save offers explicit exit choice and preserves corrupt file")
	game.controls.cancel=game.confirmation.get_cancel_button();await click("cancel")
	check(not game.confirmation.visible,"cancel failed-close exit keeps the training scene active")
	game.store=original_store
	# Resize to smaller laptop dimensions; gameplay remains accessible in the scroll area.
	root.size=Vector2i(1200,720);await frames(6);await capture("laptop_720p")
	check(game.content.size.x>750 and game.controls.save.get_global_rect().end.x<=game.size.x+1,"laptop layout retains usable content and save entry")
	finish()
func finish()->void:
	var f:=FileAccess.open(qa+"ui_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"course":game.course,"save_path":game.store.path},"\t",true,true));f.close()
	print("MM BD graphical checks: %d; failures: %d"%[checks,failures.size()]);game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
