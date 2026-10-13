extends "res://tests/mm_bd_ui_runner.gd"
const Channels=preload("res://scripts/mm_bd_channels.gd")
func run()->void:
	qa="res://qa/mm_channels/";root.size=Vector2i(1440,900)
	game=Main.new();game.channels=Channels.new("/tmp/mm-bd-channel-ui-%d.json"%OS.get_process_id());game.store=Store.new("/tmp/mm-bd-channel-case-ui-%d.json"%OS.get_process_id());root.add_child(game);root.add_child(SyntheticOnly.new());await frames(8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa));await capture("home")
	await click("channels_entry");check(game.page=="channels","home opens four channel catalog");await capture("catalog")
	var case_before:Dictionary=game.course.duplicate(true)
	for index in range(4):
		if game.page!="channels":await click("channel_back")
		await click("channel_%d"%index);check(game.page=="channel" and int(game.channels.state.selected)==index,"channel lesson opens via mouse")
		await capture("lesson_%d"%index)
		if index==0:
			game.controls.lab_price.value=1.0;await frames();check(game.channel_view.lab_output.text.contains("区间内 · 活跃"),"changing LP observation updates computed range state")
			game.controls.lab_lower.value=1.2;await frames();check(game.channel_view.lab_output.text.contains("初始价格"),"invalid LP input visible without crashing")
			game.controls.lab_lower.value=.8
		if index==1:
			game.controls.lab_actual.value=10000;await frames();check(game.channel_view.lab_output.text.contains("达到示例数量下限"),"alpha lab recomputes protection pass")
		if index==2:
			game.controls.lab_request.value=1000;await frames();check(game.channel_view.lab_output.text.contains("模拟足额成交"),"spot lab recomputes finite fill")
		if index==3:
			game.controls.lab_mark.value=1.0;await frames();check(game.channel_view.lab_output.text.contains("高于示例维持要求"),"futures mark change recomputes margin stress")
		for question in game.channels.data.modules[index].quiz:await click("channel_answer_%d"%int(question.correct))
		check(game.channels.grade(game.channels.current()).score==100,"four mouse answers produce channel score")
		await click("channel_export");check(game.status_label.text.contains("渠道复盘已导出"),"channel coaching export available")
		game.page_scroll.ensure_control_visible(game.controls.channel_export);await frames(6);await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(qa+"quiz_%d.png"%index)==OK,"capture actual quiz feedback")
		if index==0:
			await click("channel_retry");check(game.channels.current().answers.is_empty() and game.channels.state.runs.size()==5,"real retry preserves completed run")
			await click("channel_answer_0");check(game.channels.grade(game.channels.current()).score==0,"wrong response displays explanation without credit")
	check(game.model.same(case_before,game.course),"channel training never changes existing customer-case progress")
	var reloaded=Channels.new(game.channels.path);check(game.channels.same_state(reloaded.state,game.channels.state),"all channels restore stored answers in new model")
	await click("channel_back");root.size=Vector2i(1200,720);await frames(8);await capture("catalog_720p")
	check(game.content.size.x<=game.page_scroll.size.x+1,"catalog fits laptop content width")
	await click("channel_3");check(game.page=="channel","laptop native viewport input opens lesson");await capture("futures_720p");check(game.content.size.x<=game.page_scroll.size.x+1,"long futures lesson fits laptop width")
	finish()
