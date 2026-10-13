extends Control
var state:Dictionary={}
var model:RefCounted
var mode:String="equity"
func _draw()->void:
	var box:Rect2=Rect2(Vector2(12,12),size-Vector2(24,32))
	for i in range(5):draw_line(Vector2(box.position.x,box.position.y+box.size.y*i/4),Vector2(box.end.x,box.position.y+box.size.y*i/4),Color("e7eaf3"),1)
	if mode=="equity":
		var values:Array=[float(state.proposal.get("capital",100000))]
		for row in state.daily:values.append(float(row.equity))
		var low:float=float(values.min())*.992;var high:float=float(values.max())*1.008
		var font:Font=get_theme_default_font()
		draw_string(font,Vector2(box.position.x,box.position.y+12),"%.0f USDT"%high,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("59657e"))
		draw_string(font,Vector2(box.position.x,box.end.y),"%.0f"%low,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("59657e"))
		for day in [0,3,6]:draw_string(font,Vector2(box.position.x+box.size.x*day/6,box.end.y+17),"D%d"%day,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("59657e"))
		var points:=PackedVector2Array()
		for i in values.size():points.append(Vector2(box.position.x+box.size.x*i/maxf(6,values.size()-1),box.end.y-(float(values[i])-low)/maxf(high-low,.01)*box.size.y))
		if points.size()>1:draw_polyline(points,Color("6675cc"),3,true)
		for point in points:draw_circle(point,4,Color("6675cc"))
	else:
		var quotes:Dictionary=model.book(state)
		var center:float=box.position.x+box.size.x*.5;var scale:float=box.size.x*.44/maxf(float(state.proposal.get("depth",15000))/3,1)
		for i in range(3):
			var y:float=box.position.y+14+i*30
			draw_style_box(bar(Color("66b5a3")),Rect2(Vector2(center-float(quotes.bids[i].notional)*scale-6,y),Vector2(float(quotes.bids[i].notional)*scale,16)))
			draw_style_box(bar(Color("df9aab")),Rect2(Vector2(center+6,y),Vector2(float(quotes.asks[i].notional)*scale,16)))
func bar(color:Color)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(4);return style
