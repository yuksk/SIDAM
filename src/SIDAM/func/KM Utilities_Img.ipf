#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	KMGetWindowInfo
//		グラフに関する情報を得る
//******************************************************************************
Function KMGetWindowInfo(String grfName, STRUCT KMGetWindowInfoStruct &s)
	String recStr = KMGetWindowRecStr(grfName)

	//	座標軸の太さ (座標軸が表示されているかどうかの判定に用いられる)
	s.axThick = KMGetWindowValue(recStr, "axThick", 1)

	//	ウインドウの大きさ
	GetWindow $grfName psize
	s.width = V_right - V_left
	s.height = V_bottom - V_top
	s.widthStr = KMGetWindowStr(recStr, "width", "0")
	s.heightStr = KMGetWindowStr(recStr, "height", "0")

	//	マージン
	s.margin.left = KMGetWindowValue(recStr, "margin(left)",0)
	s.margin.right = KMGetWindowValue(recStr, "margin(right)",0)
	s.margin.top = KMGetWindowValue(recStr, "margin(top)",0)
	s.margin.bottom = KMGetWindowValue(recStr, "margin(bottom)",0)

	//	ラベル文字列
	KMGetWindowLabel(recStr, s)
End

//	axThick　を　得るショートカット
Function KMGetAxThick(String grfName)
	String recStr = KMGetWindowRecStr(grfName)
	return KMGetWindowValue(recStr, "axThick", 1)
End

//	expand　を　得るショートカット
Function KMGetExpand(String grfName)
	String recStr = KMGetWindowRecStr(grfName)
	return abs(KMGetWindowValue(recStr, "expand", 1))
End

//	WinRecreationで返される文字列のうち、必要な部分を抜き出す
//	grfNameがサブウインドウであるときに重要
Static Function/S KMGetWindowRecStr(String grfName)
	int type = WinType(grfName)
	if (type != 1)
		return ""
	endif

	int isSubWindow = strsearch(grfName, "#", 0) >= 0
	String recStr = WinRecreation(StringFromList(0, grfName, "#"), !isSubWindow+4)
	int v0, v1

	if (!isSubWindow)
		//	grfName自身はsubwindowではなくても、subwindowを含むとそのrecreationマクロが含まれるようだ
		//	その部分をカットするために次の2行を入れる
		v0 = strsearch(recStr, "NewPanel",0)
		v0 = (v0 == -1) ? strlen(recStr)-1 : v0
		return recStr[0,v0]
	endif

	String subWinName = ParseFilePath(0, grfName, "#", 1, 0)
	String endline
	sprintf endline, "RenameWindow #,%s", subWinName

	v1 = strsearch(recStr, endline, 0)
	v0 = strsearch(recStr, "Display", v1, 3)
	return recStr[v0, v1-1]
End

//	一般の数値に関する指定を抜き出す
Static Function KMGetWindowValue(String recStr, String key, Variable defaultValue)
	int n0 = strsearch(recStr, key, 0)
	if (n0 == -1)
		return defaultValue
	endif
	int n1 = strsearch(recStr, "\r", n0), n2 = strsearch(recStr, ",", n0)
	n1 = (n1 == -1) ? inf : n1
	n2 = (n2 == -1) ? inf : n2
	return str2num(recStr[n0+strlen(key)+1, min(n1, n2)-1])	// +1 は = の分
End

//	一般の文字列に関する指定を抜き出す
Static Function/S KMGetWindowStr(String recStr, String key, String defaultStr)
	int n0 = strsearch(recStr, key, 0)
	if (n0 == -1)
		return defaultStr
	endif

	int n1, n2

	if (!numtype(str2num(recStr[n0+strlen(key)+1])))	//	通常の数字なら
		n1 = strsearch(recStr, "\r", n0)
		n2 = strsearch(recStr, ",", n0)
		n1 = (n1 == -1) ? inf : n1
		n2 = (n2 == -1) ? inf : n2
		return recStr[n0+strlen(key)+1, min(n1, n2)-1]	// +1 は = の分
	endif

	n1 = strsearch(recStr, "{", n0)
	n2 = strsearch(recStr, "(", n0)
	if (n1 != -1 && (n1 < n2 || n2 == -1))
		n2 = strsearch(recStr, "}", n1)
		return recStr[n1, n2]
	endif

	if (n2 != -1 && (n2 < n1 || n1 == -1))
		n1 = strsearch(recStr, ")", n2)
		return recStr[n2, n1]
	endif
End

//	ラベルを抜き出す
Static Function KMGetWindowLabel(String recStr, STRUCT KMGetWindowInfoStruct &s)

	int n0, n1

	n0 = strsearch(recStr, "Label/Z left", 0)
	if (n0 == -1)
		s.labelLeft = ""
	else
		n1 = strsearch(recStr, "\r", n0)
		s.labelLeft = recStr[n0+14, n1-2]
	endif

	n0 = strsearch(recStr, "Label/Z bottom", 0)
	if (n0 == -1)
		s.labelBottom = ""
	else
		n1 = strsearch(recStr, "\r", n0)
		s.labelBottom = recStr[n0+16, n1-2]
	endif
End

Structure KMGetWindowInfoStruct
	float width
	String widthStr
	float height
	String heightStr
	float axThick
	STRUCT RectF margin
	String labelLeft
	String labelBottom
EndStructure


//******************************************************************************
//	KMGetImageWaveRef
//		grfNameの一番上に表示されているイメージウエーブの参照を返す
//		imgNameが指定されているときには、ImageNameToWaveRefと同じ動作をする
//		displayedが指定されているときには、表示されている状態(plane, imCmplxMode, 表示領域)に
//		対応する2次元フリーウエーブを返す
//******************************************************************************
Function/WAVE KMGetImageWaveRef(grfName, [imgName, displayed])
	String grfName, imgName
	Variable displayed

	if (ParamIsDefault(imgName))
		imgName = StringFromList(0, ImageNameList(grfName, ";"))
	endif

	if (!strlen(imgName))
		return $""
	endif

	Wave/Z w = ImageNameToWaveRef(grfName, imgName)
	if (!WaveExists(w))
		return $""
	elseif (ParamIsDefault(displayed))
		return w
	endif

	int isCmplx = WaveType(w) & 0x01
	String infoStr = ImageInfo(grfName, imgName, 0)
	int plane = NumberByKey("plane", infoStr, "=")
	int mode = NumberByKey("imCmplxMode", infoStr, "=")

	if (isCmplx)
		switch (mode)
			case 0:	//	magnitude
				MatrixOP/FREE tw = mag(w[][][plane])
				break
			case 1:	//	real
				MatrixOP/FREE tw = real(w[][][plane])
				break
			case 2:	//	imaginary
				MatrixOP/FREE tw = imag(w[][][plane])
				break
			case 3:	//	phase
				MatrixOP/FREE tw = phase(w[][][plane])
				break
		endswitch
	else
		MatrixOP/FREE tw = w[][][plane]
	endif
	Redimension/N=(DimSize(w,0),DimSize(w,1)) tw	//	always treat as a 2D wave
	CopyScales w tw

	GetAxis/W=$grfName/Q $StringByKey("XAXIS", infoStr)
	Variable xmin = V_min, xmax = V_max
	GetAxis/W=$grfName/Q $StringByKey("YAXIS", infoStr)
	Variable ymin = V_min, ymax = V_max
	Duplicate/R=(xmin,xmax)(ymin,ymax)/FREE tw tw2

	return tw2
end


//******************************************************************************
//	Get wave reference, wave value, etc. at the position of the mouse cursor
//******************************************************************************
Structure SIDAMMousePos
	String	xaxis
	String	yaxis
	float	x
	float	y
	Variable/C	z
	float	p
	float	q
	Wave	w
EndStructure

Function SIDAMGetMousePos(
	STRUCT SIDAMMousePos &s,
	String grfName,
	STRUCT Point &ps,		//	e.g., WMWinHookStruct.mouseLoc
	[
		int grid
	])

	grid = ParamIsDefault(grid) ? 1 : grid
	s.xaxis = ""	; s.yaxis = ""
	s.x = NaN ;	s.y = NaN ;	s.z = NaN
	s.p = NaN ;	s.q = NaN ;
	Wave/Z s.w = $""

	getWaveAndValues(s,grfName,ps)
	if (!WaveExists(s.w))	//	the mouse cursor is not on any image
		return 1
	elseif (WaveExists(ImageNameToWaveRef(grfName,NameOfWave(s.w))))
		//	The following is for when s.w is a 2D/3D wave and is displayed as an image,
		//	but even when s.w is 2D/3D, it can be displayed as a trace.
		//	The above if state is to exclude the latter situation.
		//	(WaveDims(s.w) > 1 fails.)
		Variable ox = DimOffset(s.w,0), oy = DimOffset(s.w,1)
		Variable dx = DimDelta(s.w,0), dy = DimDelta(s.w,1)
		Variable tx = limit(s.x, min(ox,ox+dx*(DimSize(s.w,0)-1)), max(ox,ox+dx*(DimSize(s.w,0)-1)))
		Variable ty = limit(s.y, min(oy,oy+dy*(DimSize(s.w,1)-1)), max(oy,oy+dy*(DimSize(s.w,1)-1)))
		Variable tp = (tx-ox)/dx, tq = (ty-oy)/dy
		s.p = grid ? round(tp) : tp
		s.q = grid ? round(tq) : tq
		s.x = grid ? (ox + dx * s.p) : tx
		s.y = grid ? (oy + dy * s.q) : ty
		//	the present layer, 0 for 2D images
		int layer = NumberByKey("plane", ImageInfo(grfName, NameOfWave(s.w), 0), "=")
		s.z = s.w(tx)(ty)[layer]
	endif
	return 0
End

Static Function getWaveAndValues(STRUCT SIDAMMousePos &ms, String grfName, STRUCT Point &ps)
	STRUCT SIDAMAxisRange as
	String listStr, itemName
	Variable mousex, mousey
	Variable axis_x_max, axis_x_min, axis_y_max, axis_y_min
	Variable wave_x_max, wave_x_min, wave_y_max, wave_y_min
	Variable ox, dx, oy, dy
	Variable isInRange	//	isInRange has to be variable (not int)
	int swap = strsearch(WinRecreation(grfName,1), "swapXY", 4) != -1
	int i, isImg, nx, ny

	//	Traces are handled only when there is no image.
	listStr = ImageNameList(grfName,";")
	if (!strlen(listStr))
		listStr = TraceNameList(grfName, ";", 1)
	endif

	//	search from the top item
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		itemName = StringFromList(i,listStr)

		SIDAMGetAxis(grfName,itemName,as)

		//	When the axis is reversed, as.xmin > as.xmax and as.ymin > as.ymax
		axis_x_min = min(as.xmin, as.xmax)
		axis_x_max = max(as.xmin, as.xmax)
		axis_y_min = min(as.ymin, as.ymax)
		axis_y_max = max(as.ymin, as.ymax)

		mousex = AxisValFromPixel(grfName, as.xaxis, (swap ? ps.v : ps.h))
		mousey = AxisValFromPixel(grfName, as.yaxis, (swap ? ps.h : ps.v))

		Wave/Z w = ImageNameToWaveRef(grfName,itemName)
		isImg = WaveExists(w)

		//	When dx (dy) is negative, min and max are reversed
		if (isImg)
			ox = DimOffset(w,0)
			oy = DimOffset(w,1)
			dx = DimDelta(w,0)
			dy = DimDelta(w,1)
			nx = DimSize(w,0)
			ny = DimSize(w,1)
			wave_x_min = dx>0 ? ox-0.5*dx : ox+dx*(nx-0.5)
			wave_x_max = dx>0 ? ox+dx*(nx-0.5) : ox-0.5*dx
			wave_y_min = dy>0 ? oy-0.5*dy : oy+dy*(ny-0.5)
			wave_y_max = dy>0 ? oy+dy*(ny-0.5) : oy-0.5*dy
		endif

		isInRange = !isImg ? 1 : \
			(mousex >= max(axis_x_min, wave_x_min)) \
			& (mousex <= min(axis_x_max, wave_x_max)) \
			& (mousey >= max(axis_y_min, wave_y_min)) \
			& (mousey <= min(axis_y_max, wave_y_max))
		if (isInRange)
			ms.xaxis = as.xaxis
			ms.yaxis = as.yaxis
			ms.x = mousex
			ms.y = mousey
			if (isImg)
				Wave ms.w = w
			else
				Wave ms.w = TraceNameToWaveRef(grfName,itemName)
			endif
			return 1
		endif
	endfor
	return 0
End

//******************************************************************************
//	KMGetCursor :	カーソル位置の座標を返す
//******************************************************************************
Structure KMCursorPos
	uchar	isImg
	uint32	p
	uint32	q
	double	x
	double	y
EndStructure

Function KMGetCursor(csrName, grfName, pos)
	String csrName, grfName
	STRUCT KMCursorPos &pos

	String infoStr = CsrInfo($csrName, grfName)
	if (!strlen(infoStr))
		return 1
	endif

	String tName = StringByKey("TNAME", infoStr)
	Variable posx = NumberByKey("POINT", infoStr)
	Variable posy = NumberByKey("YPOINT", infoStr)

	pos.isImg = (strsearch(StringByKey("RECREATION",infoStr),"/I",0) != -1)		//	カーソルの対象がイメージであるかどうか
	if (pos.isImg)
		Wave w = ImageNameToWaveRef(grfName, tName)
	else
		Wave w = TraceNameToWaveRef(grfName, tName)
	endif

	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	if (NumberByKey("ISFREE", infoStr))
		//	カーソルがフリーの場合は、posxとposyは0-1の範囲で与えられる
		//	これをまず(x,y)に直し、そこから[p,q]に直す
		STRUCT SIDAMAxisRange axis
		SIDAMGetAxis(grfName,tName,axis)
		pos.x = axis.xmin + (axis.xmax - axis.xmin) * posx
		pos.y = axis.ymin + (axis.ymax - axis.ymin) * (1 - posy)
		pos.p = pos.isImg ? round((pos.x-ox)/dy) : NaN
		pos.q = pos.isImg ? round((pos.y-oy)/dy) : NaN
	else
		//	カーソルがフリーでない場合には、posxとposyには[p,q]が与えられる
		pos.p = posx
		pos.q = posy		//	表示されているのが1次元ウエーブならNaNが入る
		pos.x = pos.isImg ? ox+dy*posx : leftx(w)+deltax(w)*posx
		pos.y = pos.isImg ? oy+dy*posy : w[posx]
	endif

	return 0
End

//******************************************************************************
//	KMSetCursor
//		カーソル位置を指定位置へ移動する
//******************************************************************************
Function KMSetCursor(csrName, grfName, mode, pos)
	String csrName, grfName
	int mode		//	0: p, q,	1: x, y
	STRUCT KMCursorPos &pos

	String infoStr = CsrInfo($csrName, grfName)
	if (!strlen(infoStr))			//	該当するカーソルが表示されていない
		return 0
	endif
	String tName = StringByKey("TNAME", infoStr)
	int isFree = NumberByKey("ISFREE", infoStr)
	int active = strsearch(infoStr, "/A=0", 0) != -1 ? 0 : 1

	if (pos.isImg)
		if (isFree)
			if (mode)
				Cursor/A=(active)/F/I/W=$grfName $csrName $tName pos.x, pos.y
			else
				STRUCT SIDAMAxisRange axis
				SIDAMGetAxis(grfName,tName,axis)
				Cursor/A=(active)/F/I/P/W=$grfName $csrName $tName (pos.p-axis.pmin)/(axis.pmax-axis.pmin), (pos.q-axis.qmax)/(axis.qmin-axis.qmax)
			endif
		else
			if (mode)
				Cursor/A=(active)/I/W=$grfName $csrName $tName pos.x, pos.y
			else
				Cursor/A=(active)/I/P/W=$grfName $csrName $tName pos.p, pos.q
			endif
		endif
	else
		if (isFree && mode)
			Cursor/A=(active)/F/W=$grfName $csrName $tName pos.x, pos.y
		endif
	endif
End

//******************************************************************************
//	Get the range of displayed axes by giving an image or a trace
//******************************************************************************
Structure SIDAMAxisRange
	double	xmin
	double	xmax
	double	ymin
	double	ymax
	uint32	pmin
	uint32	pmax
	uint32	qmin
	uint32	qmax
	String	xaxis
	String	yaxis
EndStructure

Function SIDAMGetAxis(String grfName, String tName, STRUCT SIDAMAxisRange &s)
	String info = ImageInfo(grfName, tName, 0)
	Variable isImg = strlen(info)
	if (isImg)
		Wave w = ImageNameToWaveRef(grfName, tName)
	else
		info = TraceInfo(grfName, tName, 0)
		Wave w = TraceNameToWaveRef(grfName, tName)
	endif

	s.xaxis = StringByKey("XAXIS", info)
	s.yaxis = StringByKey("YAXIS", info)
	GetAxis/W=$grfName/Q $s.xaxis ;	s.xmin = V_min ;	s.xmax = V_max
	GetAxis/W=$grfName/Q $s.yaxis ;	s.ymin = V_min ;	s.ymax = V_max

	s.pmin = isImg ? round((s.xmin-DimOffset(w,0))/DimDelta(w,0)) : round((s.xmin-leftx(w))/deltax(w))
	s.pmax = isImg ? round((s.xmax-DimOffset(w,0))/DimDelta(w,0)) : round((s.xmax-leftx(w))/deltax(w))
	s.qmin = isImg ? round((s.ymin-DimOffset(w,1))/DimDelta(w,1)) : NaN
	s.qmax = isImg ? round((s.ymax-DimOffset(w,1))/DimDelta(w,1)) : NaN
End


//******************************************************************************
//	Return the marquee position as a wave
//	The values in the returned wave are indicies (mode=0) or scaling coordinates (mode=1)
//******************************************************************************
Function/WAVE SIDAMGetMarquee(int mode)
	String grfName = WinName(0,1)
	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	Wave/Z w = ImageNameToWaveRef(grfName, imgName)
	if (!strlen(grfName) || !strlen(imgName) || !WaveExists(w))
		return $""
	endif

	String info = ImageInfo(grfName, imgName, 0)
	GetMarquee/W=$grfName $StringByKey("YAXIS", info), $StringByKey("XAXIS", info)

	if (mode)
		Make/FREE rtnw = {{V_left,V_bottom},{V_right,V_top}}
	else
		Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
		Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
		Make/FREE rtnw = {{round((V_left-ox)/dx), round((V_bottom-oy)/dy)},{round((V_right-ox)/dx), round((V_top-oy)/dy)}}
	endif

	return rtnw
End


//******************************************************************************
//	Copy the window to the clipboard with transparent background
//******************************************************************************
Function SIDAMExportGraphicsTransparent([String grfName, Variable size])
	grfName = SelectString(ParamIsDefault(grfName),grfName,WinName(0,1))
	if (!SIDAMWindowExists(grfName))
		return 0
	endif

	//	Get the background colors
	STRUCT RGBColor wbRGB
	GetWindow $grfName, wbRGB
	wbRGB.red = V_Red ;	wbRGB.green = V_Green ;	wbRGB.blue = V_Blue
	STRUCT RGBColor gbRGB
	GetWindow $grfName, gbRGB
	gbRGB.red = V_Red ;	gbRGB.green = V_Green ;	gbRGB.blue = V_Blue

	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)

	//	Make the background white to export it as transparent
	if (prefs.export[2] != 0)		//	1 or 2, Window or Both
		ModifyGraph/W=$grfName wbRGB=(65535,65535,65535)
	endif
	if (prefs.export[2] != 1)		//	0 or 2, Graph or Both
		ModifyGraph/W=$grfName gbRGB=(65535,65535,65535)
	endif

	//	Copy the window to the clipboard
	//	If an image is included in the window, copy as PNG
	//	Otherwise (only traces), copy as EMF (Win) or Quartz PDF (Mac)
	if (strlen(ImageNameList(grfName, ";")))
		if (prefs.export[0] == 6)	//	Other DPI
			if (ParamIsDefault(size))
				SavePICT/E=-5/TRAN=1/RES=(prefs.export[1])/WIN=$grfName as "Clipboard"
			else
				SavePICT/E=-5/TRAN=1/RES=(prefs.export[1])/W=(0,0,size,size)/WIN=$grfName as "Clipboard"
			endif
		else
			Variable res = 72*round(0.2*prefs.export[0]^2+0.5*prefs.export[0]+0.2)	//	X1, X2, X4, X5, X8
			if (ParamIsDefault(size))
				SavePICT/E=-5/TRAN=1/B=(res)/WIN=$grfName as "Clipboard"
			else
				SavePICT/E=-5/TRAN=1/B=(res)/W=(0,0,size,size)/WIN=$grfName as "Clipboard"
			endif
		endif
	else
		SavePICT/E=-2/WIN=$grfName as "Clipboard"
	endif

	//	Revert the background colors
	ModifyGraph/W=$grfName wbRGB=(wbRGB.red, wbRGB.green, wbRGB.blue)
	ModifyGraph/W=$grfName gbRGB=(gbRGB.red, gbRGB.green, gbRGB.blue)
End
