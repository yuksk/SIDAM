#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>
#include <Graph Utility Procs>		//	WMGetRECREATIONInfoByKey を使用するため
											//	いずれにせよ WMImageInfo から呼び出されることにはなる

//  Extension of WMImageInfo

//******************************************************************************
///Extension of WM_ColorTableForImage
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@return	Name of a color table or absolute path to a color table wave
///				Empty When the image is not found
//******************************************************************************
Function/S SIDAM_ColorTableForImage(String grfName, String imgName)	//	tested
	String str = WM_ColorTableForImage(grfName,imgName)
	if (GetRTError(1) || !strlen(str))
		return ""
	elseif (WhichListItem(str,CTabList()) >= 0)	//	color table
		return str
	else
		return GetWavesDataFolder($str,2)
	endif
End

//******************************************************************************
//  KM_GetColorTableMinMax
//    WM_GetColorTableMinMaxの拡張
//    インデックスウエーブが使用されている場合を含めて、カラーテーブルの最大値、最小値を持つフリーウエーブを返す
//******************************************************************************
Function/WAVE KM_GetColorTableMinMax(grfName,imgName)
	String grfName,imgName

	Variable zmin = NaN, zmax = NaN

	if (strlen(WM_ImageColorTabInfo(grfName,imgName)))
	  	WM_GetColorTableMinMax(grfName,imgName,zmin,zmax)
	elseif (strlen(WM_ImageColorIndexWave(grfName,imgName)))
		Wave cw = $WM_ImageColorIndexWave(grfName,imgName)
		zmin = DimOffset(cw,0)
		zmax = zmin + DimDelta(cw,0)*(DimSize(cw,0)-1)
	endif

	Make/D/FREE/N=2 rw = {zmin, zmax}
	return rw
End

//******************************************************************************
///Returns if a logarithmically-spaced color is set.
///	(log version of WM_ColorTableReversed)
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@return	0: a linearly-spaced color
///				1: a logarithmically-spaced color
///				-1: any error
//******************************************************************************
Function SIDAM_ColorTableLog(String grfName, String imgName)	//	tested
	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return -1
	endif
	return str2num(TrimString(WMGetRECREATIONInfoByKey("log",info)))
End

//******************************************************************************
///	Returns mode of minRGB/maxRGB
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@param key		"minRGB" or "maxRGB"
///	@return	0: use first/last color
///				1: (r,g,b)
///				2: transparent
///				-1: any error
//******************************************************************************
Function SIDAM_ImageColorRGBMode(String grfName, String imgName, String key) //	tested
	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return -1
	endif
	
	if (CmpStr(key,"minRGB") && CmpStr(key,"maxRGB"))
		return -1
	endif
	
	String str = WMGetRECREATIONInfoByKey(key,info)
	if (!CmpStr(str,"0"))	//	use first/last color
		return 0
	elseif (GrepString(str,"\([0-9]+,[0-9]+,[0-9]+\)"))	//	(r,g,b)
		return 1
	elseif (!CmpStr(LowerStr(str),"nan"))	//	transparent
		return 2
	else
		return -1
	endif
End

//******************************************************************************
///	Returns values of minRGB/maxRGB
///	@param grfName	Name of a window.
///	@param imgName	Name of an image.
///	@param key		"minRGB" or "maxRGB"
///	@param[out] s	rgb color
///	@return	0: no error
///				!0: any error
//******************************************************************************
Function SIDAM_ImageColorRGBValues(String grfName, String imgName, String key,
	STRUCT RGBColor &s) //	tested

	String info = ImageInfo(grfName, imgName, 0)
	if (GetRTError(1))
		return 1
	elseif (!strlen(info))
		return 2
	endif
	
	String str = WMGetRECREATIONInfoByKey(key,info)
	if (!GrepString(str,"\([0-9]+,[0-9]+,[0-9]+\)"))
		return 3
	endif
	
	str = str[1,strlen(str)-2]
	s.red = str2num(StringFromList(0,str,","))
	s.green = str2num(StringFromList(1,str,","))
	s.blue = str2num(StringFromList(2,str,","))

	return 0
End


//******************************************************************************
//	表示されているイメージのZ範囲がautoであるかどうかを返す
//******************************************************************************
//	first Z
Function isFirstZAuto(String grfName, String imgName)
	String ctabInfo = WM_ImageColorTabInfo(grfName,imgName)
	return strlen(ctabInfo) ? Stringmatch("*", StringFromList(0,ctabInfo,",")) : 0
End
//	last Z
Function isLastZAuto(String grfName, String imgName)
	String ctabInfo = WM_ImageColorTabInfo(grfName,imgName)
	return strlen(ctabInfo) ? Stringmatch("*", StringFromList(1,ctabInfo,",")) : 0
End


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
	Variable mousex, mousey, axmin, axmax, aymin, aymax, wxmin, wxmax, wymin, wymax
	Variable isInRange	//	isInRange has to be variable (not int)
	int swap = strsearch(WinRecreation(grfName,1), "swapXY", 4) != -1
	int i, isImg

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
		axmin = min(as.xmin, as.xmax)
		axmax = max(as.xmin, as.xmax)
		aymin = min(as.ymin, as.ymax)
		aymax = max(as.ymin, as.ymax)

		mousex = AxisValFromPixel(grfName, as.xaxis, (swap ? ps.v : ps.h))
		mousey = AxisValFromPixel(grfName, as.yaxis, (swap ? ps.h : ps.v))

		Wave/Z w = ImageNameToWaveRef(grfName,itemName)
		isImg = WaveExists(w)

		//	As for traces, the followings are chosen so that isInRange is always 1
		wxmin = isImg ? DimOffset(w,0)-0.5*DimDelta(w,0) : as.xmin
		wxmax = isImg ? DimOffset(w,0)+DimDelta(w,0)*(DimSize(w,0)-0.5) : as.xmax
		wymin = isImg ? DimOffset(w,1)-0.5*DimDelta(w,1) : as.ymin
		wymax = isImg ? DimOffset(w,1)+DimDelta(w,1)*(DimSize(w,1)-0.5) : as.ymax

		//	isInRange is always 1 for traces
		isInRange = (mousex >= max(axmin, wxmin)) & (mousex <= min(axmax, wxmax)) & \
			(mousey >= max(aymin, wymin)) & (mousey <= min(aymax, wymax))
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
//	KMGetCursorState
//		カーソルが表示されていてアクティブなら0, 非アクティブなら2, 表示されていないなら1 を返す
//		bit 0: 表示されている(1)、いない(0)
//		bit 1: アクティブである(1)、ない(0)
//		bit 2: フリーである(1)、ない(0)
//******************************************************************************
Function KMGetCursorState(csrName, grfName)
	String csrName, grfName

	String infoStr = CsrInfo($csrName, grfName)
	Variable rtn = 0

	//	bit 0
	rtn += strlen(infoStr) ? 2^0 : 0
	//	bit 1
	rtn += (strsearch(StringByKey("RECREATION", infoStr), "/A=0",0) != -1) ? 0 : 2^1
	//	bit 2
	rtn += NumberByKey("ISFREE", infoStr) * 2^2

	return rtn
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
//	KMGetMarquee
//		マーキーの位置を、座標(mode=1)もしくはウエーブインデックス(mode=0)で返す
//******************************************************************************
Function/WAVE KMGetMarquee(mode)
	Variable mode

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
//	背景を透明にして画像をクリップボードにコピーする
//******************************************************************************
Function KMExportGraphicsTransparent([String grfName, Variable size])

	if (ParamIsDefault(grfName))
		grfName = WinName(0,1)
	elseif (!SIDAMWindowExists(grfName))
		return 0
	endif

	//	表示色を取得する
	STRUCT RGBColor wbRGB
	GetWindow $grfName, wbRGB
	wbRGB.red = V_Red ;	wbRGB.green = V_Green ;	wbRGB.blue = V_Blue
	STRUCT RGBColor gbRGB
	GetWindow $grfName, gbRGB
	gbRGB.red = V_Red ;	gbRGB.green = V_Green ;	gbRGB.blue = V_Blue

	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)

	//	透明にするために一度背景を白にする
	if (prefs.export[2] != 0)		//	1 or 2, Window or Both
		ModifyGraph/W=$grfName wbRGB=(65535,65535,65535)
	endif
	if (prefs.export[2] != 1)		//	0 or 2, Graph or Both
		ModifyGraph/W=$grfName gbRGB=(65535,65535,65535)
	endif

	//	クリップボードにコピー
	//	イメージが含まれていたらPNG, トレースだけなら EMF (Win) or Quartz PDF (Mac)
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

	//	白にした背景を元に戻す
	ModifyGraph/W=$grfName wbRGB=(wbRGB.red, wbRGB.green, wbRGB.blue)
	ModifyGraph/W=$grfName gbRGB=(gbRGB.red, gbRGB.green, gbRGB.blue)
End
