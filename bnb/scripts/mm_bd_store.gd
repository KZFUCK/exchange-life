extends RefCounted
const Model=preload("res://scripts/mm_bd_model.gd")
var model=Model.new()
var path:String
var rules_hash:String=FileAccess.get_file_as_string(Model.DATA_PATH).sha256_text()
func _init(save_path:String="")->void:
	path=save_path if not save_path.is_empty() else "user://market_maker_bd_v1_%s.json"%rules_hash.left(12)
func read_course(target:String="")->Dictionary:
	if target.is_empty():target=path
	if not FileAccess.file_exists(target):return {"error":"尚无研修存档。"}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(target))!=OK or not parser.data is Dictionary:return {"error":"研修存档损坏，未覆盖。"}
	var d:Dictionary=parser.data
	if d.get("mode")!="mm_bd_v1" or d.get("version")!=1 or d.get("rules_hash")!=rules_hash:return {"error":"研修配置或版本不匹配。"}
	if not d.get("payload") is String or d.payload.sha256_text()!=d.get("checksum"):return {"error":"研修存档校验失败。"}
	if parser.parse(d.payload)!=OK or not model.valid_course(parser.data):return {"error":"研修记录不能按操作顺序重放。"}
	return {"course":parser.data}
func write_course(course:Dictionary)->String:
	if not model.valid_course(course):return "研修状态无效，未保存。"
	if FileAccess.file_exists(path) and read_course().has("error"):return "现有研修存档异常，已保护；请先确认备份。"
	var payload:String=JSON.stringify(course,"",true,true)
	var envelope:Dictionary={"mode":"mm_bd_v1","version":1,"rules_hash":rules_hash,"payload":payload,"checksum":payload.sha256_text()}
	var f:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:return "无法写入研修存档。"
	f.store_string(JSON.stringify(envelope));f.flush();var error:Error=f.get_error();f.close()
	if error!=OK or read_course(path+".tmp").has("error"):return "研修临时存档验证失败。"
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:return "无法保留备份。"
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "无法替换研修存档。"
	return ""
func restore_backup()->Dictionary:
	var result:Dictionary=read_course(path+".bak")
	if result.has("error"):return result
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".retained."+str(Time.get_unix_time_from_system()))!=OK:return {"error":"无法保留当前存档。"}
	if DirAccess.copy_absolute(path+".bak",path+".tmp")!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:return {"error":"无法恢复备份。"}
	return result
