extends RefCounted

const Model = preload("res://scripts/operations_model.gd")
const LEGACY_RULES_HASH="ec36ecbc356f81033f91c59c753211cfb921bf70cb70895e344f2d2eaccfeeb4"
var model = Model.new()
var path: String
var rules_hash := FileAccess.get_file_as_string(Model.RULES_PATH).sha256_text()

func _init(save_path: String = "user://operations_v1.json") -> void:
	path=save_path

func read_game(source: String = "") -> Dictionary:
	var target := path if source.is_empty() else source
	if not FileAccess.file_exists(target):return {"error":"尚无存档。"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(target))!=OK:return {"error":"存档损坏。"}
	var envelope: Variant=parser.data
	if not envelope is Dictionary or envelope.get("version")!=1 or envelope.get("mode")!="operations_v1":return {"error":"存档版本不匹配。"}
	if envelope.get("rules_hash") not in [rules_hash,LEGACY_RULES_HASH]:return {"error":"存档规则版本不匹配。"}
	var payload: Variant=envelope.get("payload")
	if not payload is String or payload.sha256_text()!=envelope.get("checksum"):return {"error":"存档校验失败。"}
	if parser.parse(payload)!=OK or not parser.data is Dictionary:return {"error":"存档状态无效。"}
	# Upgrade the existing business save without touching its cash, ledger or positions.
	if not parser.data.has("development"):
		if not model.whole(parser.data.get("jobs")) or not parser.data.get("reports") is Array:return {"error":"旧存档状态无效。"}
		parser.data.development=Model.Development.initial()
		parser.data.development.research=int(parser.data.get("jobs",0))*2
		for report in parser.data.get("reports",[]):
			if not report is Dictionary or not report.get("totals") is Dictionary:return {"error":"旧存档周报无效。"}
			report.totals.development=0.0;report.totals.launch=0.0
	# v015 preserves historical hours, coordinates, ledger entries and IDs.
	if not parser.data.has("discarded_work"):parser.data.discarded_work=[]
	if not parser.data.get("staff") is Array or not parser.data.get("reports") is Array:return {"error":"存档状态无效。"}
	for worker in parser.data.staff:
		if not worker is Dictionary:return {"error":"存档员工无效。"}
		if not worker.has("discarded_hours"):worker.discarded_hours=0.0
	for report in parser.data.reports:
		if not report is Dictionary or not report.get("totals") is Dictionary:return {"error":"存档周报无效。"}
		if not report.totals.has("furniture_sale"):report.totals.furniture_sale=0.0
	if not model.valid(parser.data):return {"error":"存档状态无效。"}
	return {"state":parser.data}

func write_game(state: Dictionary) -> String:
	if not model.valid(state):return "当前状态无效，未保存。"
	if FileAccess.file_exists(path) and read_game().has("error"):return "已有存档损坏或不兼容，已保护原文件；可恢复备份。"
	var payload:=JSON.stringify(state,"",true,true)
	var data:={"version":1,"mode":"operations_v1","rules_hash":rules_hash,"payload":payload,"checksum":payload.sha256_text()}
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return "不能写入存档。"
	file.store_string(JSON.stringify(data));file.flush();var error:=file.get_error();file.close()
	if error!=OK or read_game(path+".tmp").has("error"):return "临时存档验证失败。"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak.tmp")!=OK:return "不能备份。"
		if DirAccess.rename_absolute(path+".bak.tmp",path+".bak")!=OK:return "不能保留备份。"
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "不能替换存档。"
	return ""

func restore_backup() -> Dictionary:
	var result:=read_game(path+".bak")
	if result.has("error"):return result
	if FileAccess.file_exists(path):
		var retained:=path+".retained."+str(Time.get_unix_time_from_system())
		if DirAccess.copy_absolute(path,retained)!=OK:return {"error":"不能保留当前存档。"}
	if DirAccess.copy_absolute(path+".bak",path+".tmp")!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:return {"error":"恢复失败。"}
	return result
