#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Preference"
#include "SIDAM_Utilities_Panel"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
///	SIDAMGetWindow
///	@param grfName
///		Name of a window.
///	@param s
///		Information about grfName is returned.
//******************************************************************************
Structure SIDAMWindowInfo
	float width
	String widthStr
	float height
	String heightStr
	float axThick
	float expand
	STRUCT RectF margin
	String labelLeft
	String labelBottom
EndStructure

Function SIDAMGetWindow(String grfName, STRUCT SIDAMWindowInfo &s)
	String recStr = getRecStr(grfName)

	s.axThick = getValueFromRecStr(recStr, "axThick", 1)

	GetWindow $grfName psize
	s.width = V_right - V_left
	s.height = V_bottom - V_top
	s.widthStr = getStrFromRecStr(recStr, "width", "0")
	s.heightStr = getStrFromRecStr(recStr, "height", "0")

	s.expand = abs(getValueFromRecStr(recStr, "expand", 1))

	s.margin.left = getValueFromRecStr(recStr, "margin(left)",0)
	s.margin.right = getValueFromRecStr(recStr, "margin(right)",0)
	s.margin.top = getValueFromRecStr(recStr, "margin(top)",0)
	s.margin.bottom = getValueFromRecStr(recStr, "margin(bottom)",0)

	//	label
	int n0 = strsearch(recStr, "Label/Z left", 0), n1
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

//	Get the necessary part of the string returned by WinRecreation.
//	Works also for a subwindow.
Static Function/S getRecStr(String grfName)
	int type = WinType(grfName)
	if (type != 1)
		return ""
	endif

	int isSubWindow = strsearch(grfName, "#", 0) >= 0
	String recStr = WinRecreation(StringFromList(0, grfName, "#"), !isSubWindow+4)
	int v0, v1

	if (!isSubWindow)
		//	Even if grfName is not a subwindow, if it contains a subwindow, a recreation
		//	macro for the subwindow is included. The following is necessary to remove
		//	the recreation macro.
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

Static Function getValueFromRecStr(String recStr, String key, Variable defaultValue)
	int n0 = strsearch(recStr, key, 0)
	if (n0 == -1)
		return defaultValue
	endif
	int n1 = strsearch(recStr, "\r", n0), n2 = strsearch(recStr, ",", n0)
	n1 = (n1 == -1) ? inf : n1
	n2 = (n2 == -1) ? inf : n2
	return str2num(recStr[n0+strlen(key)+1, min(n1, n2)-1])	// +1 is for "="
End

Static Function/S getStrFromRecStr(String recStr, String key, String defaultStr)
	int n0 = strsearch(recStr, key, 0)
	if (n0 == -1)
		return defaultStr
	endif

	int n1, n2

	if (!numtype(str2num(recStr[n0+strlen(key)+1])))
		n1 = strsearch(recStr, "\r", n0)
		n2 = strsearch(recStr, ",", n0)
		n1 = (n1 == -1) ? inf : n1
		n2 = (n2 == -1) ? inf : n2
		return recStr[n0+strlen(key)+1, min(n1, n2)-1]	// +1 is for "="
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


//******************************************************************************
///	SIDAMImageWaveRef
///	@param grfName
///		Name of a window.
///	@param imgName [optional]
///		Name of an image. The default is the top image of grfName.
///		If this is given, SIDAMImageWaveRef works as ImageNameToWaveRef 
///	@param displayed
///		0 or !0. Set !0 to return a 2D free wave corresponding to the displayed
///		state (region, plane, imCmplxMode). 
///	@return
///		A wave displayed as the top image of grfName, or a free wave which is
///		a part of a wave displayed as the top image of grfName
//******************************************************************************
Function/WAVE SIDAMImageWaveRef(String grfName, [String imgName, Variable displayed])

	if (ParamIsDefault(imgName))
		imgName = StringFromList(0, ImageNameList(grfName, ";"))
	endif

	if (!strlen(imgName))
		return $""
	endif

	Wave/Z w = ImageNameToWaveRef(grfName, imgName)
	if (!WaveExists(w))
		return $""
	elseif (ParamIsDefault(displayed) || !displayed)
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
	elseif (WaveExists(ImageNameToWaveRef(grfName,PossiblyQuoteName(NameOfWave(s.w)))))
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
		s.z = s.w(tx)(ty)[limit(layer,0,DimSize(s.w,2)-1)]
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
///	SIDAMGetCursor 
///	@param csrName
///		Name of a cursor.
///	@param grfName
///		Name of a window.
///	@param pos
///		A new position where a cursor is moved.
//******************************************************************************
Structure SIDAMCursorPos
	uchar	isImg
	uint32	p
	uint32	q
	double	x
	double	y
EndStructure

Function SIDAMGetCursor(String csrName, String grfName,
	STRUCT SIDAMCursorPos &pos)

	String infoStr = CsrInfo($csrName, grfName)
	if (!strlen(infoStr))			//	the cursor is not shown
		return 1
	endif

	String tName = StringByKey("TNAME", infoStr)
	Variable posx = NumberByKey("POINT", infoStr)
	Variable posy = NumberByKey("YPOINT", infoStr)

	pos.isImg = (strsearch(StringByKey("RECREATION",infoStr),"/I",0) != -1)
	if (pos.isImg)
		Wave w = ImageNameToWaveRef(grfName, tName)
	else
		Wave w = TraceNameToWaveRef(grfName, tName)
	endif

	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	if (NumberByKey("ISFREE", infoStr))
		//	When the cursor position is "free", posx and posy are between 0 and 1.
		//	Calculate (x,y) from these, then [p,q] from (x,y)
		STRUCT SIDAMAxisRange axis
		SIDAMGetAxis(grfName,tName,axis)
		pos.x = axis.xmin + (axis.xmax - axis.xmin) * posx
		pos.y = axis.ymin + (axis.ymax - axis.ymin) * (1 - posy)
		pos.p = pos.isImg ? round((pos.x-ox)/dy) : NaN
		pos.q = pos.isImg ? round((pos.y-oy)/dy) : NaN
	else
		//	When the cursor position is not "free", posx and posy are p and q,
		//	respectively
		pos.p = posx
		pos.q = posy		//	NaN if a 1D wave is displayed
		pos.x = pos.isImg ? ox+dy*posx : leftx(w)+deltax(w)*posx
		pos.y = pos.isImg ? oy+dy*posy : w[posx]
	endif

	return 0
End

//******************************************************************************
///	SIDAMMoveCursor 
///	@param csrName
///		Name of a cursor.
///	@param grfName
///		Name of a window.
///	@param mode
///		0 or 1. Set 0 to give a new position by p & q, 1 by x & y.
///	@param pos
///		A new position where a cursor is moved.
//******************************************************************************
Function SIDAMMoveCursor(String csrName, String grfName, int mode,
	STRUCT SIDAMCursorPos &pos)

	String infoStr = CsrInfo($csrName, grfName)
	if (!strlen(infoStr))			//	the cursor is not shown
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
	//	Otherwise copy as SVG
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
		SavePICT/E=-9/WIN=$grfName as "Clipboard"
	endif

	//	Revert the background colors
	ModifyGraph/W=$grfName wbRGB=(wbRGB.red, wbRGB.green, wbRGB.blue)
	ModifyGraph/W=$grfName gbRGB=(gbRGB.red, gbRGB.green, gbRGB.blue)
End


//@
//	Get the index of a 3D wave shown in a window
//
//	Parameters
//	----------
//	grfName : string
//		The name of window
//	w : wave, default wave of the top image
//		The 3D wave to get the index.
//
//	Returns
//	-------
//	variable
//		The index of displayed layer. If no 3D wave is shown,
//		nan is returned.
//@
Function SIDAMGetLayerIndex(String grfName, [Wave/Z w])
	if (ParamIsDefault(w))
		Wave/Z w =  SIDAMImageWaveRef(grfName)
	endif
	if (!WaveExists(w) || WaveDims(w) != 3)
		return NaN
	endif
	
	return NumberByKey("plane", ImageInfo(grfName, NameOfWave(w), 0), "=")
End

//@
//	Set the index of a 3D wave shown in a window
//
//	Parameters
//	----------
//	grfName : string
//		The name of window
//	index : int
//		The index of layer
//	w : wave, default wave of the top image
//		The 3D wave to set the index.
//
//	Returns
//	-------
//	variable
//		0 if the index is correctly set. 1 if no 3D wave is shown.
//@
Function SIDAMSetLayerIndex(String grfName, int index, [Wave/Z w])
	if (ParamIsDefault(w))
		Wave/Z w =  SIDAMImageWaveRef(grfName)
	endif
	if (!WaveExists(w) || WaveDims(w) != 3)
		return 1
	endif
	
	ModifyImage/W=$grfName $NameOfWave(w) plane=limit(round(index), 0, DimSize(w,2)-1)
	return 0
End