#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= SIDAMInfoBar

#include "SIDAM_Bias"
#include "SIDAM_Color"
#include "SIDAM_FFT"
#include "SIDAM_Help"
#include "SIDAM_KeyboardShortcuts"
#include "SIDAM_LayerAnnotation"
#include "SIDAM_Menus"
#include "SIDAM_Range"
#include "SIDAM_ScaleBar"
#include "SIDAM_Subtraction"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Mouse"
#include "SIDAM_Utilities_Window"
#include "SIDAM_Utilities_Wave"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant COORDINATESMENU = "x and y (Cartesian);r and θ (Polar);1/r and θ (Polar, inverse magnitude)"


//@
//	Show the information bar.
//
//	## Parameters
//	grfName : string
//		The name of window to show the information bar.
//@
Function SIDAMInfoBar(String grfName)
	
	if (!strlen(grfName))
		grfName = WinName(0,1,1)
	endif
	
	if (isAlreadyShown(grfName))
		closeInfoBar(grfName)
		return 1
	endif
	
	SetWindow $grfName hook(self)=SIDAMInfoBar#hook
	SetWindow $grfName tooltipHook(self)=SIDAMTooltipHook
	
	//	0: x,y;  1: r,θ,   2: r^-1,θ
	SetWindow $grfName userData(mode)="0"
	
	Wave/Z w = SIDAMImageNameToWaveRef(grfName)
	int isNoimage = !WaveExists(w)
	int is2D = WaveExists(w) && WaveDims(w)==2
	int is3D = WaveExists(w) && WaveDims(w)==3

	int isTrace2D = 0
	if (isNoimage)
		Wave w = topTraceWaveRef(grfName)
		//	True if a 2D wave is shown as only one trace
		isTrace2D = WaveDims(w)==2 && ItemsInList(TraceNameList(grfName,";",1))==1
	endif

	int ctrlHeight = is3D || isTrace2D ? 48 : 25
	ControlBar/W=$grfName ctrlHeight

	//	If the current datafolder is a free datafolder, TitleBox in
	//	the following will give an error.
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(w)

	SIDAMMenuCtrl(grfName,SelectString(is2D||is3D, "SIDAMInfobarMenu1D", "SIDAMInfobarMenu2D3D"))
	
	if (isNoimage)
		TitleBox xyT pos={isTrace2D?4:23,ctrlHeight-18}, frame=0, win=$grfName
	else
		TitleBox pqT pos={is3D?4:23,5}, frame=0, win=$grfName
		TitleBox xyT frame=0, win=$grfName
		TitleBox zT frame=0, win=$grfName
	endif

	if (is3D)
		int layer = SIDAMGetLayerIndex(grfName)
		SetVariable indexV title="index:", pos={23,5}, size={96,18}, win=$grfName
		SetVariable indexV value=_NUM:layer, format="%d", win=$grfName
		SetVariable energyV title="value:", value=_NUM:SIDAMIndexToScale(w,layer,2), win=$grfName
		ModifyControlList "indexV;energyV" bodyWidth=60, focusRing=0, win=$grfName
		ModifyControlList "indexV;energyV" proc=SIDAMInfoBar#pnlSetvalue, win=$grfName
		setLimits(grfName, "indexV", "energyV")
		ControlUpdate/W=$grfName indexV
	endif

	if (isTrace2D)
		int pq = tracepq(grfName)
		int index = getTraceIndex(grfName)
		SetVariable pqV title=SelectString(pq,"p:","q:"), win=$grfName
		SetVariable pqV pos={23,5}, size={74,18}, value=_NUM:index, format="%d", win=$grfName
		SetVariable xyV title=SelectString(pq,"x:","y:"), win=$grfName
		SetVariable xyV value=_NUM:IndexToScale(w,index,pq), win=$grfName
		ModifyControlList "pqV;xyV" bodyWidth=60, focusRing=0, win=$grfName
		ModifyControlList "pqV;xyV" proc=SIDAMInfoBar#pnlSetvalue, win=$grfName
		setLimits(grfName, "pqV", "xyV")
		ControlUpdate/W=$grfName pqV
	endif
	
	SIDAMApplyHelp(grfName, "[SIDAM_InfoBar]")
	adjustCtrlPos(grfName)

	SetDataFolder dfrSav
End

//	Return 1 if the infobar can be shown
Static Function canInfoBarShown(String grfName)
	
	if (!strlen(grfName) || WinType(grfName) != 1)
		return 0
	endif
	
	//	If a horizongal guide is used, it means Line Profile or Line Spectra.
	if (strlen(GuideNameList(grfName,"TYPE:User,HORIZONTAL:1")))
		return 0
	endif
	
	return !isAlreadyShown(grfName)
End

Static Function isAlreadyShown(String grfName)
	ControlInfo/W=$grfName kwControlBar
	return V_Height ? 1 : 0
End

Static Function setLimits(String pnlName, String indexCtrl, String valueCtrl)
	
	int dim
	if (!CmpStr(indexCtrl, "indexV"))
		Wave w = SIDAMImageNameToWaveRef(pnlName)
		dim = 2
	else
		Wave w = topTraceWaveRef(pnlName)
		dim = tracepq(pnlName)
	endif
	Variable offset = DimOffset(w,dim), num = DimSize(w,dim), delta = DimDelta(w,dim)

	SetVariable $indexCtrl limits={0,num-1,1}, win=$pnlName
	
	if (SIDAMisUnevenlySpacedBias(w))
		Make/D/N=(num)/FREE ew = str2num(GetDimLabel(w,2,p))
		Make/D/N=3/FREE limits = {WaveMin(ew),WaveMax(ew),(WaveMax(ew)-WaveMin(ew))/num}
	else
		Make/D/N=3/FREE limits = {min(offset, offset+(num-1)*delta), \
			max(offset, offset+(num-1)*delta), abs(delta)}
	endif
	SetVariable $valueCtrl limits={limits[0],limits[1],limits[2]}, win=$pnlName
End
	
Static Function closeInfoBar(String pnlName)

	int i, n
	
	//	pnlName may be a subwindow. This occurs if (1) a subwindow is opened, (2) it
	//	is activated (clicked), and (3) then the title bar of the parent window is
	//	clicked without clicking the inside of parent window. In this case, make
	//	pnlName the parent window.
	n = strsearch(pnlName, "#", 0)
	if (n != -1)
		pnlName = pnlName[0, n-1]
	endif

	SetWindow $pnlName hook(self)=$""
	SetWindow $pnlName tooltipHook(self)=$""
	
	String listStr = ControlNameList(pnlName)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		KillControl/W=$pnlName $StringFromList(i,listStr)
	endfor
	ControlBar/W=$pnlName 0

	DoUpdate/W=$pnlName	
	SetWindow $pnlName userData(mode)=""
End

//-------------------------------------------------------------
//	Menu
//-------------------------------------------------------------
Static Function/S mainMenuItem()
	return SelectString(canInfoBarShown(WinName(0,1,1)), "(", "")+"Information Bar"
End

Static Function/S menuItem(int menuitem)
	
	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return ""
	endif
	
	int mode
	
	switch (menuitem)
		case 0:	//	coordinates
			
			mode = str2num(GetUserData(grfName,"","mode"))
			String menuStr = SIDAMAddCheckmark(mode, COORDINATESMENU)
			
			Wave/Z w = SIDAMImageNameToWaveRef(grfName)
			if (!WaveExists(w))		//	1D for example
				return menuStr
			endif
			
			Variable isFree = str2num(GetUserData(grfName,"","free"))
			menuStr += "-;" + SIDAMAddCheckmark(isFree, "free (allows selecting 'between' pixels);")
			
			return menuStr
		
		case 2:	//	label
			return SelectString(getTick(grfName)==3,"Hide","Show") + " Label"
			
		case 3:	//	complex (2D/3D)
			if (SIDAMcontainsComplexWave(grfName,2))
				mode = NumberByKey("imCmplxMode",ImageInfo(grfName, "", 0),"=")
				return SIDAMAddCheckmark(mode, MENU_COMPLEX2D)
			else
				return ""
			endif
					
		case 4:	//	complex (1D)
			if (SIDAMcontainsComplexWave(grfName,1))
				mode = NumberByKey("cmplxMode(x)",TraceInfo(grfName, "", 0),"=")
				return SIDAMAddCheckmark(mode, MENU_COMPLEX1D)
			else
				return ""
			endif
			
	endswitch
End

Static Function getTick(String grfName)
	STRUCT SIDAMWindowInfo s
	SIDAMGetWindow(grfName, s)
	return s.tick
End

Static Function/S menuDo(int mode)
	GetLastUserMenuInfo
	switch (mode)
		case 0:	//	coordinates
			changeCoordinateSetting(WhichListItem(S_value, COORDINATESMENU))			
			break
			
		case 2:	//	axis
			toggleLabel(WinName(0,1))
			break
			
		case 3:	//	complex 2D/3D
		case 4:	//	complex 1D
			SIDAMChangeComplexMode(V_value-1, mode-3)
			break
			
	endswitch
End

//-------------------------------------------------------------
//	Hook function
//-------------------------------------------------------------
Static Function hook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 3:	//	mousedown
		case 4:	//	mouse move
		case 8:	//	modified
		case 11:	//	keyboard
		case 22:	//	mouseWheel
			break
		default:
			return 0
	endswitch
	
	Wave/Z w = SIDAMImageNameToWaveRef(s.winName)
	int is1D = !WaveExists(w) && strlen(TraceNameList(s.winName,";",1))
	int is2D = WaveExists(w) && WaveDims(w)==2 
	int is3D = WaveExists(w) && WaveDims(w)==3

	int isTrace2D = 0
	if (!WaveExists(w))
		ControlInfo/W=$s.winName pqV
		Variable existpq = V_flag
		ControlInfo/W=$s.winName xyV
		Variable existxy = V_flag
		isTrace2D = existpq && existxy
		if (isTrace2D)
			Wave w = TraceNameToWaveRef(\
				s.winName,StringFromList(0,TraceNameList(s.winName,";",1)))
		endif
	endif

	int plane

	switch (s.eventCode)
			
		case 4:	//	mouse move
			if (!(s.eventMod&0x02))	//	unless the shift key is pressed
				SIDAMInfobarUpdatePos(s)
			endif
			return 0
			
		case 8:	//	modified
			if (is3D)
				//	When the displayed layer has been changed (by mouse wheel, from
				//	the panel of ModifyImage), the indexV and the energyV must be changed.
				plane = SIDAMGetLayerIndex(s.winName)	//	the present layer
				ControlInfo/W=$s.winname indexV
				if (V_Value != plane)
					SetVariable indexV value=_NUM:plane, win=$s.winName
					SetVariable energyV value=_NUM:SIDAMIndexToScale(w,plane,2), win=$s.winName
				endif
			elseif (istrace2D)
				int index = getTraceIndex(s.winName)
				ControlInfo/W=$s.winname pqV
				if (V_Value != index)
					SetVariable pqV value=_NUM:index, win=$s.winName
					SetVariable xyV value=_NUM:IndexToScale(w,index,tracepq(s.winName)), win=$s.winName					
				endif
			endif
			return 0
			
		case 11:	//	keyboard
			return keyboardShortcuts(s)
			
		case 22:	//	mouseWheel
			if (s.eventMod & 8)		//	if the ctrl key is pressed
				magnify(s)
				return 0
			endif
			
			int direction = (s.wheelDy > 0) ? 1 : -1
			if (is3D)
				STRUCT SIDAMMousePos ms
				SIDAMGetMousePos(ms, s.winName, s.mouseLoc)
				plane = SIDAMGetLayerIndex(s.winName, w=ms.w)
				SIDAMSetLayerIndex(s.winName, plane+direction, w=ms.w)
			elseif (istrace2D)
				setTraceIndex(s.winName, getTraceIndex(s.winName)+direction)
			endif
			return 0
	endswitch
End

//-------------------------------------------------------------
//	Helper functions of the hook function
//-------------------------------------------------------------
//	Update the coordinates of the mouse cursor
//	This is used in the external files (Fourier filter)
Function SIDAMInfobarUpdatePos(STRUCT WMWinHookStruct &s, [String win])
	
	//	If a window to get the location of the mouse cursor is different from
	//	a window to display the coordinates (e.g., the former is a subwindow),
	//	the latter window has to be explicitly given.
	win = SelectString(ParamIsDefault(win),win,s.winName)
	
	//	If the current datafolder is a free datafolder, force to move to root:
	//	to avoid errors returned by TitleBox and CheckBox
	DFREF dfr = GetDataFolderDFR()
	int isInFreeDataFolder = DataFolderRefStatus(dfr)==3
	if (isInFreeDataFolder)
		SetDataFolder root:
	endif
	
	STRUCT SIDAMMousePos ms
	int grid = str2num(GetUserData(s.winName,"","free")) != 1
	SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=grid)
	
	String pqs, xys, zs

	int isPQZdisplayed = 1
	ControlInfo/W=$win pqT	; isPQZdisplayed *= V_flag
	ControlInfo/W=$win zT	; isPQZdisplayed *= V_flag
	if (isPQZdisplayed)
		setpqzStr(pqs, zs, ms, grid, s.winName)
		TitleBox pqT title=pqs, win=$win
		TitleBox zT title=zs, win=$win
	endif

	setxyStr(xys, ms, s.winName)
	TitleBox xyT title=xys, win=$win

	adjustCtrlPos(win)
End

Static Function setpqzStr(String &pqs, String &zs, 
	STRUCT SIDAMMousePos &ms, int grid, String grfName)
	
	if (!WaveExists(ms.w))		//	the mouse cursor is not on any image
		pqs = "[p:-, q:-]"
		zs = "z:-"
		return 0
	elseif (WaveDims(ms.w) == 1)
		return 0
	endif
	
	String formatStr = SelectString(grid, "[p:%.1f, q:%.1f]", "[p:%d, q:%d]")
	Sprintf pqs, formatStr, ms.p, ms.q
	
	formatStr = "z:"+SIDAM_WINDOW_FORMAT_Z
	if (SIDAM_WINDOW_FORMAT_SHOWUNIT & 2)
		formatStr += StringByKey("DUNITS",WaveInfo(ms.w,0))
	endif
	if (WaveType(ms.w)&0x01)
		Variable mode = NumberByKey("imCmplxMode",ImageInfo(grfName,NameOfWave(ms.w),0),"=")
		switch (mode)
			case 0:		//	magnitude
				Sprintf zs, formatStr, real(r2polar(ms.z))
				break
			case 1:		//	real
				Sprintf zs, formatStr, real(ms.z)
				break
			case 2:		//	imaginary
				Sprintf zs, formatStr, imag(ms.z)
				break
			case 3:		//	phase (in radian)
				Sprintf zs, "z: %.4fpi", imag(r2polar(ms.z))/pi
				break
		endswitch
	else
		Sprintf zs, formatStr, real(ms.z)
	endif
	return 1
End

Static Function setxyStr(String &xys, STRUCT SIDAMMousePos &ms, String grfName)
	//	The mode is NaN if GetUserData returns "". e.g., Fourier filter
	int mode = str2num(GetUserData(grfName,"","mode"))
	String formatStr = constructFormatStr(mode, SIDAM_WINDOW_FORMAT_SHOWUNIT, ms.w)
	Variable mag

	switch (mode)
		default:		//	*** FALLTHROUGH ***
		case 0:		//	x, y	(also for traces)
			if (!WaveExists(ms.w))
				xys = "(x:-, y:-)"
			elseif (stringmatch(WaveUnits(ms.w,0),"dat"))
				Sprintf xys, formatStr, Secs2Date(ms.x,-2), Secs2Time(ms.x,3), ms.y
			elseif (stringmatch(WaveUnits(ms.w,1),"dat"))
				Sprintf xys, formatStr, ms.x, Secs2Date(ms.y,-2), Secs2Time(ms.y,3)
			else
				Sprintf xys, formatStr, ms.x, ms.y
			endif
			break
		case 1: 	//	r, θ
			mag = sqrt(ms.x^2+ms.y^2)
			if (numtype(mag))
				xys = "(r:-, θ:-)"
			else
				Sprintf xys, formatStr, mag, acos(ms.x/mag)*180/pi*sign(ms.y)
			endif
			break
		case 2: 	//	1/r, θ
			mag = sqrt(ms.x^2+ms.y^2)
			if (numtype(mag))
				xys = "(1/r:-, θ:-)"
			else
				Sprintf xys, formatStr, 1/mag, acos(ms.x/mag)*180/pi*sign(ms.y)
			endif
			break
	endswitch
End

Static Function/S constructFormatStr(int mode, int showunit, Wave/Z w)
	if (!WaveExists(w))
		return ""
	elseif (mode < 0 || mode > 2)		//	e.g., NaN for Fourier filter
		mode = 0
	endif

	String str = ""

	if (mode == 0)	//	x, y
		if (stringmatch(WaveUnits(w,0),"dat"))
			str = "(x: %s %s, y:" + SIDAM_WINDOW_FORMAT_XY \
				+ SelectString(showUnit & 1, "", WaveUnits(w,1))
		elseif (stringmatch(WaveUnits(w,1),"dat"))
			str = "(x:" + SIDAM_WINDOW_FORMAT_XY \
				+ SelectString(showUnit & 1, "", WaveUnits(w,0)) + ", y:%s %s)"
		else
			str = "(x:"+SIDAM_WINDOW_FORMAT_XY \
				+ SelectString(showUnit & 1, "", WaveUnits(w,0)) \
				+ ", y:"+SIDAM_WINDOW_FORMAT_XY \
				+ SelectString(showUnit & 1, "", WaveUnits(w,1)) + ")"		
		endif
		return str
	endif
	
	String xUnit = WaveUnits(w,0)
	int isSameUnit = !CmpStr(xUnit, WaveUnits(w,1))
	int isInverseUnit = !CmpStr(xUnit[strlen(xUnit)-3,strlen(xUnit)-1], "^-1")
	if (!strlen(xUnit))
		showunit = 0
	endif

	if (mode == 1)	//	r, θ
		str = "(r:"+SIDAM_WINDOW_FORMAT_XY \
			+ SelectString((showUnit & 1) && isSameUnit, "", WaveUnits(w,0)) \
			+ ", θ:"+SIDAM_WINDOW_FORMAT_THETA \
			+ SelectString(showUnit & 4, ")", "\u00b0)")
	elseif (mode == 2)	//	1/r, θ
		xUnit = SelectString(isInverseUnit, xUnit+"^-1", xUnit[0,strlen(xUnit)-4])
		str = "(1/r:"+SIDAM_WINDOW_FORMAT_XY \
			+ SelectString((showUnit & 1) && isSameUnit, "", xUnit) \
			+ ", θ:"+SIDAM_WINDOW_FORMAT_THETA \
			+ SelectString(showUnit & 4, ")", "\u00b0)")
	endif

	return str
End

//	Adjust the positions of controls
Static Function adjustCtrlPos(String win)
	
	ControlInfo/W=$win kwControlBar
	Variable ctrlBarHeight = V_Height
	
	//	Obtain the height of text from the xyT because it's always
	//	shown even in the case of 1D traces.
	ControlInfo/W=$win xyT
	Variable textHeight = V_Height, xyTLeft = V_left
	Variable textTop	 = V_top

	//	Controls to be adjusted	
	String setVarList = ""
	ControlInfo/W=$win indexV		//	Layer Viewer
	if (V_flag)
		setVarList = "indexV;energyV;"
	endif
	ControlInfo/W=$win pV			//	Spectrum Viewer
	if (V_flag)
		setVarList = "pV;qV;"
	endif
	ControlInfo/W=$win pqV			//	Trace Viewer
	if (V_flag)
		SetVarList = "pqV;xyV"
	endif
	
	if (strlen(setVarList))
		ControlInfo/W=$win $StringFromList(0,setVarList)
		Variable setVarHeight = V_Height, setVarTop = (ctrlBarHeight-setVarHeight-textHeight)/3
		Variable setVar0Width = V_Width, setVar0Left = V_Left
		SetVariable $StringFromList(0,setVarList) pos={setVar0Left, setVarTop}, win=$win
		SetVariable $StringFromList(1,setVarList) pos={setVar0Left+setVar0Width+10, setVarTop}, win=$win
	endif
	
	//	When the control bar is shown (2D, Layer Viewer), the vertical position
	//	of the xyT, pqT, and zT has to be determined depending on the setVarList.
	//	When the control bar is not shown (Fourier fileter), nothing is necessary.
	if (strlen(setVarList))
		textTop = setVarTop + setVarHeight + (ctrlBarHeight-setVarHeight-textHeight)/3
	elseif (ctrlBarHeight > 0)
		textTop = (ctrlBarHeight-textHeight)/2
	endif
	
	//	The window contains an image when the pqT is shown.
	ControlInfo/W=$win pqT
	int containsImage = V_flag
	
	if (containsImage)

		//	Note that V_left here is obtained at the above ControlInfo/W=$win pqT		
		TitleBox pqT pos={V_left, textTop}, win=$win	
		ControlUpdate/W=$win pqT
		
		ControlInfo/W=$win pqT
		TitleBox xyT pos={V_left+V_width+10, textTop}, win=$win
		ControlUpdate/W=$win xyT
		
		ControlInfo/W=$win xyT
		TitleBox zT pos={V_left+V_width+10, textTop}, win=$win
		ControlUpdate/W=$win zT
		
	else
		
		TitleBox xyT pos={xyTLeft, textTop}, win=$win
		ControlUpdate/W=$win xyT
		
	endif

End

//	Expand or shrink the displayed area of an image by the mouse wheel
Static Function magnify(STRUCT WMWinHookStruct &s)
	STRUCT SIDAMMousePos ms
	SIDAMGetMousePos(ms, s.winName, s.mouseLoc)
	if (!WaveExists(ms.w))
		return 1
	endif
	//	upward -> expand
	//	downward -> shrink
	Variable coef = 1 - 0.1*sign(s.wheelDy)
	GetAxis/Q/W=$s.winName $ms.xaxis
	SetAxis/W=$s.winName $ms.xaxis  ms.x+(V_min-ms.x)*coef, ms.x+(V_max-ms.x)*coef
	GetAxis/Q/W=$s.winName $ms.yaxis
	SetAxis/W=$s.winName $ms.yaxis  ms.y+(V_min-ms.y)*coef, ms.y+(V_max-ms.y)*coef
End

Static Function keyboardShortcuts(STRUCT WMWinHookStruct &s)
	Wave/Z w = SIDAMImageNameToWaveRef(s.winName)
	int is2D = WaveExists(w) && WaveDims(w)==2
	int is3D = WaveExists(w) && WaveDims(w)==3
	
	if (s.specialKeyCode && (is2D || is3D))
		switch (s.specialKeyCode)
			case 4:		//	F4
				SIDAMRange()
				return 1
			case 5:		//	F5
				SIDAMColor()
				return 1
			case 6:		//	F6
				SIDAMSubtraction#menuDo()
				return 1
			case 7:		//	F7
				SIDAMFFT#menuDo()
				return 1
		endswitch
	endif
	
	int mode
	switch (s.keycode)
		case 11:		//	PageUp
		case 12:		//	PageDown
			if (is3D)	//	Change the displayed layer of a 3D wave
				int direction = (s.keyCode == 11) ? 1 : -1
				SIDAMSetLayerIndex(s.winName, SIDAMGetLayerIndex(s.winName)+direction)
			endif
			return 1
		case 27:		//	esc
			closeInfoBar(s.winName)
			return 1
		case 28:		//	arrow left
		case 29:		//	arrow right
		case 30:		//	arrow up
		case 31:		//	arrow down
			return 0		//	allow moving cursors
		case 49:		//	1
		case 50:		//	2
		case 51:		//	3
			ModifyGraph/W=$s.winName expand=s.keycode-48
			return 1
		case 65:		//	A (shift + a)
			if (is3D)
				SIDAMLayerAnnotation#menuDo()
			endif
			return 1
		case 66:		//	B (shift + b)
			if (is2D || is3D)
				SIDAMScaleBar#menuDo()
			endif
			return 1
		case 67:		//	C (shift + c)
			mode = str2num(GetUserData(s.winName,"","mode"))
			changeCoordinateSetting(mode+1)
			SIDAMInfobarUpdatePos(s)
			return 1
		case 76:		//	L (shift + l)
			toggleLabel(s.winName)
			return 1
		default:
			if (s.keycode == 88 || s.keycode >= 97) //	X or a,b,c,...
				return SIDAMKeyboardShortcuts(s)
			else
				return 1		//	prevent command input
			endif
	endswitch

	return 0
End

//	Change the coordinate setting. The userdata set here is refered
//	when the mouse coordinates are shown in the control bar.
Static Function changeCoordinateSetting(int mode)
	
	//	When this is called from the keyboard shortcut, the mode can
	//	be larger than the maximum. If so, make it zero.
	Variable maxMode = ItemsInList(COORDINATESMENU) - 1
	if (mode > maxMode)
		mode = 0
	endif
	
	String grfName = WinName(0,1)
	switch (mode)
		case 0:
		case 1:
		case 2:
		case 3:
			SetWindow $grfName userData(mode)=num2str(mode)
			break
		case -1:
			Variable isFree = str2num(GetUserData(grfName,"","free"))
			//	1 for isFree=0 or NaN
			SetWindow $grfName userData(free)=num2str(isFree != 1)
			break
	endswitch
End

//	Show or hide the axis labels
Static Function toggleLabel(String grfName)
	if (getTick(grfName)==3)	//	show
		ModifyGraph/W=$grfName margin(left)=44, margin(bottom)=36, margin(top)=8, margin(right)=8
		ModifyGraph/W=$grfName tick=0, noLabel=0, axThick=1
	else	//	hide
		ModifyGraph/W=$grfName margin=1, tick=3, noLabel=2, axThick=SIDAM_WINDOW_AXTHICK
	endif
End

//-------------------------------------------------------------
//	Controls
//-------------------------------------------------------------
//	SetVariable
Static Function pnlSetvalue(STRUCT WMSetVariableAction &s)
	
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	String names
	int dim
	strswitch (s.ctrlName)
		case "indexV":
		case "energyV":
			Wave w = SIDAMImageNameToWaveRef(s.win)
			names = "indexV;energyV"
			dim = 2
			break
		case "pqV":
		case "xyV":
			Wave w = topTraceWaveRef(s.win)
			names = "pqV;xyV"
			dim = tracepq(s.win)
	endswitch
	
	//	Get a value of indexV even when energyV is changed.
	//	Then change values of indexV and energyV.
	int index
	Variable value
	strswitch (s.ctrlName)
		case "indexV":
		case "pqV":
			index = round(s.dval)
			break
		case "energyV":
		case "xyV":
			index = SIDAMScaleToIndex(w, s.dval, dim)
			break
	endswitch

	SetVariable $StringFromList(0, names) value=_NUM:index, win=$s.win
	SetVariable $StringFromList(1, names) value=_NUM:SIDAMIndexToScale(w,index,dim), win=$s.win

	switch (dim)
		case 0:
		case 1:
			setTraceIndex(s.win, index)
			break
		case 2:
			SIDAMSetLayerIndex(s.win, index, w=w)
			break
	endswitch
End

//-------------------------------------------------------------
//	Trace utilities
//-------------------------------------------------------------
Static Function/WAVE topTraceWaveRef(String grfName)
	String trcName = StringFromList(0, TraceNameList(grfName,";",1))
	return TraceNameToWaveRef(grfName, trcName)
End

//	Return 0 if w[%d][*] is plotted, 1 if w[*][%d] is plotted.
Static Function tracepq(String grfName)
	String yrange = getYrangeStr(grfName)
	//	true for "[*][1]", "[0,][1]", "[0,1][1]", "[,1][1]", for example.
	int isP = GrepString(yrange,"\[\d+\]\[.*?(,|\*).*?\]")
	//	true for "[1][*]", "[1][0,]", "[1][0,1]", "[1][,1]", for example.
	int isQ = GrepString(yrange,"\[.*?(,|\*).*?\]\[\d+\]")
	return (isP %^ isQ) ? isQ : NaN
End

//	Return the index (%d of w[%d][*] or w[*][%d]) of the top trace.
Static Function getTraceIndex(String grfName)
	String str = getYrangeStr(grfName)
	int dim = tracepq(grfName)
	int start = dim ? strlen(str)-1 : 0
	int p0 = strsearch(str, "[", start, dim), p1 = strsearch(str, "]", start, dim)
	return str2num(str[p0+1,p1-1])
End

Static Function/WAVE getTraceRange(String grfName)
	String str = getYrangeStr(grfName)
	int dim = tracepq(grfName)
	int start = dim ? 0 : strlen(str)-1
	int p0 = strsearch(str, "[", start, !dim), p1 = strsearch(str, "]", start, !dim)
	//	one of "\*", "\d+,\*", "\d+,\d+"
	str = str[p0+1,p1-1]
	if (strlen(str) == 1) 	//	"\*"
		Make/N=0/FREE rtnw
	elseif (strsearch(str, "*", 0) > 0) //	"\d+,\*"
		sscanf str, "%d,*", p0
		Make/N=1/FREE rtnw = p0
	else	//	"\d+,\d+"
		sscanf str, "%d,%d", p0, p1
		Make/N=2/FREE rtnw = {p0, p1}
	endif
	return rtnw
End

//	Set the index (%d of w[%d][*] or w[*][%d]) of the top trace.
Static Function setTraceIndex(String grfName, int index)
	Wave w = topTraceWaveRef(grfName)
	Wave rw = getTraceRange(grfName)
	if (tracepq(grfName))
		if (numpnts(rw)==0)
			ReplaceWave/W=$grfName trace=$NameOfWave(w), w[][limit(index,0,DimSize(w,1)-1)]
		elseif (numpnts(rw)==1)
			ReplaceWave/W=$grfName trace=$NameOfWave(w), w[rw[0],*][limit(index,0,DimSize(w,1)-1)]
		else
			ReplaceWave/W=$grfName trace=$NameOfWave(w), w[rw[0],rw[1]][limit(index,0,DimSize(w,1)-1)]
		endif
	else
		if (numpnts(rw)==0)
			ReplaceWave/W=$grfName trace=$NameOfWave(w), w[limit(index,0,DimSize(w,0)-1)][]
		elseif (numpnts(rw)==1)
			ReplaceWave/W=$grfName trace=$NameOfWave(w), w[limit(index,0,DimSize(w,0)-1)][rw[0],*]
		else
			ReplaceWave/W=$grfName trace=$NameOfWave(w), w[limit(index,0,DimSize(w,0)-1)][rw[0],rw[1]]
		endif
	endif
End

//	Return the yrange string ([*], [%d][*], or [*][%d]) of the top trace in grfName
Static Function/S getYrangeStr(String grfName)
	String trcName = StringFromList(0, TraceNameList(grfName,";",1))
	String str = StringByKey("YRANGE", TraceInfo(grfName, trcName, 0))
	//	w[*] is equivalent to w[*][0]
	return str + SelectString(CmpStr(str, "[*]"), "[0]", "")
End
