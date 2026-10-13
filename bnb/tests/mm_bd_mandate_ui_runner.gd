extends "res://tests/mm_bd_ui_runner.gd"
const MandateStore=preload("res://scripts/mm_bd_mandate_store.gd")
const Channels=preload("res://scripts/mm_bd_channels.gd")
var fixture:String
func make_game()->Control:
	var g=Main.new();g.store=Store.new(fixture+".spot");g.mandate_store=MandateStore.new(fixture);g.channels=Channels.new(fixture+".lesson");return g
func run()->void:
	qa="res://qa/mm_mandates/";fixture="/tmp/mm-mandate-ui-%d.json"%OS.get_process_id();root.size=Vector2i(1440,900);game=make_game();root.add_child(game);root.add_child(SyntheticOnly.new());await frames(8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa));var original_course:Dictionary=game.course.duplicate(true);var lessons_before:Dictionary=game.channels.state.duplicate(true)
	await click("channels_entry");await click("channel_client_0");check(game.page=="mandate" and game.mandate_view.s().phase=="discovery","channel lesson links to full Uniswap client workflow")
	for index in range(3):
		if index>0:
			await click("mandate_home");await click("mandate_%d"%index)
		await capture("discovery_%d"%index);await click("mandate_draft");check(game.mandate_view.s().phase=="discovery","incomplete new-channel discovery blocks pricing")
		for q in game.mandate_view.model.data.questions:await click("mandate_ask_"+q.id)
		await click("mandate_draft");check(game.mandate_view.s().phase=="proposal","all channel-specific facts unlock proposal fields")
		await capture("proposal_%d"%index)
		if index==0:
			game.controls.mandate_form_fee.value=7000;await click("mandate_propose")
			for turn in game.mandate_view.model.scenario(game.mandate_view.s()).negotiation:await click("mandate_answer_%d"%int(turn.correct))
			check(game.mandate_view.s().phase=="proposal","over-budget offer returns to live proposal UI")
			game.controls.mandate_form_fee.value=5300;await click("save");check(game.mandate_store.read_course().course.draft.fee==5300,"global save routes to new mandate draft")
			game.controls.mandate_form_fee.value=6000;await click("load");game.controls.confirm=game.confirmation.get_ok_button();await click("confirm")
			check(game.controls.mandate_form_fee.value==5300,"global load confirmation restores correct mandate draft")
		await click("mandate_propose");await capture("negotiation_%d"%index)
		if index==0:
			await click("mandate_answer_1");check(game.mandate_view.s().phase=="negotiation" and game.mandate_view.s().round==0,"wrong guarantee cannot advance first negotiation round")
		for turn in game.mandate_view.model.scenario(game.mandate_view.s()).negotiation:await click("mandate_answer_%d"%int(turn.correct))
		check(game.mandate_view.s().phase=="execution","three actual objections lead to authorized delivery")
		if game.mandate_view.s().phase!="execution":finish();return
		for day in range(6):
			if day==0:await capture("delivery_%d"%index)
			if day==0:
				root.size=Vector2i(1200,720);await frames(6);await capture("delivery_%d_720p"%index)
				for id in ["mandate_day_keep","mandate_day_risk","mandate_day_pause"]:check(game.controls[id].get_global_rect().end.y<=game.size.y+1,"channel delivery actions pinned at laptop size")
			if day==1:root.size=Vector2i(1440,900);await frames(6)
			var e:Dictionary=game.mandate_view.model.scenario(game.mandate_view.s()).events[day];await click("mandate_day_"+e.expected)
			if day==2:
				var before:Dictionary=game.mandate_view.course.duplicate(true);game.queue_free();await frames(3);game=make_game();root.add_child(game);await frames(8)
				check(game.page=="mandate" and game.mandate_view.model.same(before,game.mandate_view.course) and game.mandate_view.s().day==3,"new scene automatically resumes day three for this channel")
		check(game.mandate_view.s().phase=="debrief" and game.mandate_view.course.completed.size()==index+1,"complete mouse-driven mandate recorded exactly once")
		await capture("debrief_%d"%index);await click("mandate_export");check(game.status_label.text.contains("完整委托复盘已导出"),"complete mandate report exports proposal negotiations and delivery ledger")
	check(game.model.same(original_course,game.course),"original spot case progress unchanged")
	check(game.channels.same_state(lessons_before,game.channels.state),"mechanism quiz records unchanged")
	await click("nav_records");await capture("records")
	for i in range(3):check(is_instance_valid(game.controls.get("mandate_record_%d"%i)),"unified records includes new channel mandate")
	await click("nav_mandates");await capture("catalog");root.size=Vector2i(1200,720);await frames(6);await capture("catalog_720p")
	await click("mandate_resume");check(game.page=="mandate","resume control works at laptop size")
	finish()
func finish()->void:
	var f:=FileAccess.open(qa+"ui_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"mandates":game.mandate_view.course},"\t",true,true));f.close()
	print("Mandate graphical checks: %d; failures: %d"%[checks,failures.size()]);game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
