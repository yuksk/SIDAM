#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMLine

#include "SIDAM_Color"
#include "SIDAM_Help"
#include "SIDAM_LineProfile"
#include "SIDAM_LineSpectra"
#include "SIDAM_Menus"
#include "SIDAM_Range"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Cursor"
#include "SIDAM_Utilities_DataFolder"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_misc"
#include "SIDAM_Utilities_Mouse"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant CTRLHEIGHT1D = 96
Static Constant CTRLHEIGHT2D = 70

//==============================================================================
//	Panel controls
//==============================================================================
//	Create the panel controls
Static Function pnlCtrls(String pnlName, String menuName)

	Wave w = $GetUserData(pnlName,"","src")
	int nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)

	//	Use a guide for a 2D image when line profiles of 2D waves are displayed
	//	because waterfall plot is not used
	Variable height = WaveDims(w)==2 ? CTRLHEIGHT2D : CTRLHEIGHT1D
	DefineGuide/W=$pnlName SIDAMFT={FT, height}

	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(GetUserData(pnlName,"","parent"),NameOfWave(w),s)

	int pmin = max(s.p.min.value, 0), pmax = min(s.p.max.value, DimSize(w,0)-1)
	int qmin = max(s.q.min.value, 0), qmax = min(s.q.max.value, DimSize(w,1)-1)
	int p1 = round(pmin*0.75 + pmax*0.25), q1 = round(qmin*0.75 + qmax*0.25)
	int p2 = round(pmin*0.25 + pmax*0.75), q2 = round(qmin*0.25 + qmax*0.75)
	Variable distance = sqrt((p1-p2)^2*dx^2+(q1-q2)^2*dy^2)
	Variable angle = atan2((q2-q1)*dy,(p2-p1)*dx)/pi*180

	SIDAMMenuCtrl(pnlName, menuName)

	CheckBox p1C title="start (1)", pos={31,5}, value=1, proc=SIDAMLine#pnlCheck, win=$pnlName
	SetVariable p1V title="p1:", pos={12,25}, value=_NUM:p1, limits={0,nx-1,1}, win=$pnlName
	SetVariable q1V title="q1:", pos={12,46}, value=_NUM:q1, limits={0,ny-1,1}, win=$pnlName
	
	CheckBox p2C title="end (2)", pos={119,5}, value=1, proc=SIDAMLine#pnlCheck, win=$pnlName
	SetVariable p2V title="p2:", pos={101,25}, value=_NUM:p2, limits={0,nx-1,1}, win=$pnlName
	SetVariable q2V title="q2:", pos={101,46}, value=_NUM:q2, limits={0,ny-1,1}, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" size={73,16}, bodyWidth=55, format="%d", win=$pnlName

	SetVariable distanceV title="\u2113:", pos={192,25}, size={89,18}, value=_NUM:distance, bodyWidth=70, win=$pnlName
	SetVariable distanceV help={"Distance between points 1 and 2."}
	SetVariable angleV title="\u03b8:", pos={197,46}, size={84,18}, value=_NUM:angle, bodyWidth=70, win=$pnlName

	pnlSetVarIncrement(pnlName)

	if (WaveDims(w) == 3)
		TitleBox waterT title="waterfall", pos={11,76}, frame=0, win=$pnlName
		SetVariable axlenV title="axlen:", pos={69,74}, size={90,18}, bodyWidth=55, win=$pnlName
		SetVariable axlenV value=_NUM:0.5, limits={0.1,0.9,0.01}, proc=SIDAMLine#pnlSetVarAxlen, win=$pnlName
		CheckBox hiddenC title="hidden", pos={173,75}, value=0, proc=SIDAMLine#pnlCheck, win=$pnlName
		drawCtrlBack(pnlName)
	endif

	Make/T/N=(2,16)/FREE helpw
	int n = 0
	helpw[][n++] = {"p1C", "Check to move the point #1."}
	helpw[][n++] = {"p1V", "Enter the row index of point #1."}
	helpw[][n++] = {"q1V", "Enter the column index of point #1."}
	helpw[][n++] = {"p2C", "Check to move point #2."}
	helpw[][n++] = {"p2V", "Enter the row index of point #2."}
	helpw[][n++] = {"q2V", "Enter the column index of point #2."}
	helpw[][n++] = {"distanceV", "Enter a distance between points #1 and #2."}					
	helpw[][n++] = {"angleV", "Enter an angle between positive x-axis and the path."}
	helpw[][n++] = {"axlenV", "Enter a relative length of y-axis, between 0.1 and 0.9."}
	helpw[][n++] = {"hiddenC", "Check to eliminate hidden lines."}			
	DeletePoints/M=1 n, DimSize(helpw,1)-n, helpw
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	SetWindow $pnlName activeChildFrame=0

	SIDAMDisableIgorMenuItems(count=2)	//	an deactivation event of the parent window will be called
End

//	Draw the gray background for the controls of waterfall
Static Function drawCtrlBack(String pnlName)
	SetDrawLayer/W=$pnlName ProgBack
	SetDrawEnv/W=$pnlName gname=ctrlback, gstart
	SetDrawEnv/W=$pnlName xcoord=rel, ycoord=abs, fillfgc=(58e3,58e3,58e3), linefgc=(58e3,58e3,58e3), linethick=1
	DrawRect/W=$pnlName 0,CTRLHEIGHT2D,1,CTRLHEIGHT1D
	SetDrawEnv/W=$pnlName gstop
	SetDrawLayer/W=$pnlName UserFront
End

//	Change line/image
Static Function pnlChangeDim(String pnlName, int dim)
	Wave w = $GetUserData(pnlName,"","src")
	SetWindow $pnlName userData(dim)=num2istr(dim)

	int hideLine = (WaveDims(w)==3 && dim==2) ? 1 : 0
	Variable height = hideLine ? CTRLHEIGHT2D : CTRLHEIGHT1D

	if (hideLine)
		DrawAction/L=ProgBack/W=$pnlName getgroup=ctrlback, delete
	else
		drawCtrlBack(pnlName)
	endif

	DefineGuide/W=$pnlName SIDAMFT={FT, height}
	SetWindow $pnlName#line hide=hideLine
	SetWindow $pnlname#image hide=!hideLine
	DoUpdate/W=$pnlname
	TitleBox waterT disable=hideLine, win=$pnlName
	SetVariable axlenV disable=hideLine, win=$pnlName
	CheckBox hiddenC disable=hideLine, win=$pnlName
End

//	Checkbox
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "p1C":
		case "p2C":
			ControlInfo/W=$s.win p1C;		int p1Checked = V_Value
			ControlInfo/W=$s.win p2C;		int p2Checked = V_Value

			SetVariable p1V disable=(!p1Checked)*2, win=$s.win
			SetVariable q1V disable=(!p1Checked)*2, win=$s.win
			SetVariable p2V disable=(!p2Checked)*2, win=$s.win
			SetVariable q2V disable=(!p2Checked)*2, win=$s.win
			SetVariable distanceV disable=!(p1Checked || p2Checked)*2, win=$s.win
			SetVariable angleV disable=!(p1Checked || p2Checked)*2, win=$s.win

			//	The widthV exist in the line profile
			ControlInfo/W=$s.win widthV
			if (V_Flag)
				SetVariable widthV disable=!(p1Checked || p2Checked)*2, win=$s.win
			endif

			//	Update the text marker
			strswitch (GetUserData(s.win, "", "key"))
				case "SIDAMLineSpectra":
					SIDAMLineSpectra#pnlUpdateTextmarker(s.win)
					break
				case "SIDAMLineProfile":
					SIDAMLineProfile#pnlUpdateTextmarker(s.win)
					break
			endswitch
			break

		case "hiddenC":
			ModifyWaterfall/W=$(s.win+"#line") hidden=s.checked
			break
	endswitch
End

//==============================================================================
//	Window hook functions
//==============================================================================
//-------------------------------------------------------------
//	Helper of the parent hook function, mouse
//-------------------------------------------------------------
Static Function pnlHookParentMouse(STRUCT WMWinHookStruct &s,	String pnlName)

	STRUCT SIDAMMousePos ms
	Wave cvw = SIDAMGetCtrlValues(pnlName,"p1C;p2C")
	int isp1Checked = cvw[0], isp2Checked = cvw[1]
	int isBothFixed = !isp1Checked && !isp2Checked
	int isGrid = str2num(GetUserData(pnlName,"","grid"))
	int isShiftPressed = s.eventMod & 2
	int isAltPressed = s.eventMod & 4
	int isRightClick = s.eventMod & 16
	int isMouseOut = SIDAMGetMousePos(ms,s.winName,s.mouseLoc,grid=isGrid)
	int isAfterClicked = strlen(GetUserData(pnlName,"","clicked"))

	switch (s.eventCode)
		case 3:	//	mousedown
			if (isAltPressed || isShiftPressed || isRightclick || isMouseOut || isBothFixed)
				break
			endif
			if (isAfterClicked)
				SetWindow $pnlName userData(clicked)=""
				break
			endif
			if (isp1Checked)
				SetVariable p1V value=_NUM:ms.p, win=$pnlName
				SetVariable q1V value=_NUM:ms.q, win=$pnlName
			endif
			if (isp2Checked)
				SetVariable p2V value=_NUM:ms.p, win=$pnlName
				SetVariable q2V value=_NUM:ms.q, win=$pnlName
			endif
			SetWindow $pnlName userData(clicked)="1"
			break

		case 4 :	//	mousemoved
			if (isShiftPressed || isMouseOut || !isAfterClicked)
				break
			elseif (isp2Checked)
				SetVariable p2V value=_NUM:ms.p, win=$pnlName
				SetVariable q2V value=_NUM:ms.q, win=$pnlName
			elseif (isp1Checked)
				SetVariable p1V value=_NUM:ms.p, win=$pnlName
				SetVariable q1V value=_NUM:ms.q, win=$pnlName
			endif
			break

	endswitch

	pnlSetDistanceAngle(pnlName)
End

//-------------------------------------------------------------
//	Helper of the parent hook function
//	Check the presence of children, and run the closing process
//	unless a child exists.
//-------------------------------------------------------------
Static Function pnlHookParentCheckChild(String grfName, String key,
	FUNCREF SIDAMLineCommonResetPrototype resetFn)

	String pnlList = GetUserData(grfName,"",key), pnlName
	DFREF dfrTmp
	int i, n

	for (i = 0, n = ItemsInList(pnlList); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		dfrTmp = $StringFromList(1,StringFromList(i,pnlList),"=")
		if (!SIDAMWindowExists(pnlName))
			resetFn(grfName, pnlName)
			SIDAMKillDataFolder(dfrTmp)
		endif
		if (!ItemsInList(GetUserData(grfName,"",key)))
			return 1
		endif
	endfor
	return 0
End

Function SIDAMLineCommonResetPrototype(String s0, String s1)
End

//-------------------------------------------------------------
//	Helper of the parent hook function, rename
//-------------------------------------------------------------
Static Function pnlHookParentRename(STRUCT WMWinHookStruct &s, String key)
	String pnlList = GetUserData(s.winName,"",KEY), pnlName
	int i, n

	for (i = 0, n = ItemsInList(pnlList); i < n; i += 1)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		String parentList = GetUserData(pnlName, "", "parent")
		SetWindow $pnlName userData(parent)=\
			AddListItem(s.winName,RemoveFromList(s.oldWinName,parentList))
	endfor
End

//-------------------------------------------------------------
//	Hook function of the panel, main
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 0: 	//	activate
			//	In case the parent window had been closed before compiling
			String parentList = GetUserData(s.winName,"","parent")
			int i, n
			for (i = 0, n = ItemsInList(parentList); i < n; i++)
				if (SIDAMWindowExists(StringFromList(i,parentList)))
					pnlSetVarIncrement(s.winName)
					SIDAMDisableIgorMenuItems()
					return 0
				endif
			endfor
			SIDAMKillDataFolder($GetUserData(s.winName,"","dfTmp"))
			KillWindow $s.winName
			SIDAMEnableIgorMenuItems()
			return 0

		case 1:	//	deactivate
			SIDAMEnableIgorMenuItems()
			return 0

		case 2:	//	kill
			SIDAMEnableIgorMenuItems()
			//	Removing the hook function of the parent window (the parent hook function)
			//	will be done by itself because it will detect this panel is closed.
			//	Similarly, SIDAMKillDataFolder below also can be done by the parent hook
			//	function. However, if SIDAMKillDataFolder below is removed, the trajectory
			//	trace will not be removed from the parent window immediately after the panel
			//	is close but will be removed when the mouse cursor is on the parent window
			//	and the parent hook function is called. This is why SIDAMKillDataFolder below
			//	is left here instead being moved to the parent hook function.
			SIDAMKillDataFolder($GetUserData(s.winName,"","dfTmp"))
			return 0

		case 11:	//	keyboard
			return pnlHookKeyboard(s)

		case 13:	//	rename
			pnlHookRename(s)
			return 0

		default:
			return 0
	endswitch
End

Static Function whoCalled(String pnlName)
	String dfTmp = GetUserData(pnlName,"","dfTmp")
	if (strsearch(dfTmp,"LineProfile",0) >= 0)
		return 0
	elseif (strsearch(dfTmp,"LineSpectra",0) >= 0)
		return 1
	else
		return -1
	endif
End

//-------------------------------------------------------------
//	Helper of the panel hook function, rename
//-------------------------------------------------------------
Static Function pnlHookRename(STRUCT WMWinHookStruct &s)
	String dfTmp = GetUserData(s.winName,"","dfTmp")
	if (strlen(dfTmp))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder $dfTmp
		RenameDataFolder $dfTmp, $s.winName
		dfTmp = GetDataFolder(1)	//	new path after renaming
		SetWindow $s.winName userData(dfTmp)=dfTmp
		SetDataFolder dfrSav
	endif

	//	update lists of children
	String parentList = GetUserData(s.winName, "", "parent")
	String key = GetUserData(s.winName,"","key")
	String parentName, oldList
	int i, n
	for (i = 0, n = ItemsInList(parentList); i < n; i++)
		parentName = StringFromList(i,parentList)
		oldList = GetUserData(parentName,"",key)
		SetWindow $parentName userData($key)=\
			AddListItem(s.winName+"="+dfTmp,RemoveByKey(s.oldWinName,oldList,"="))
	endfor
End

//-------------------------------------------------------------
//	Helper of the panel hook function, keyboard
//-------------------------------------------------------------
Static Function pnlHookKeyboard(STRUCT WMWinHookStruct &s)
	// Igor 8: s.winName is always "Graph0".
	// Igor 9: s.winName is either "Graph0", "Graph0#line", or "Graph0#image".
	String pnlName = StringFromList(0, s.winName, "#")

	switch (s.keycode)
		case 27:	//	esc
			SIDAMEnableIgorMenuItems()
			SIDAMKillDataFolder($GetUserData(pnlName,"","dfTmp"))
			KillWindow $pnlName
			return 0

		case 28:		//	left
		case 29:		//	right
		case 30:		//	up
		case 31:		//	down
			int ismoved = keyArrows(s)
			if (!ismoved)
				return 0
			endif
			switch (whoCalled(pnlName))
				case 0:
					SIDAMLineProfile#pnlHookArrows(pnlName)
					break
				case 1:
					SIDAMLineSpectra#pnlHookArrows(pnlName)
					break
			endswitch
			return 1

		case 32:	//	space
			keySpace(pnlName)
			return 1

		case 49:	//	1
		case 50:	//	2
			SIDAMClickCheckBox(pnlName,"p"+num2istr(s.keycode-48)+"C")
			return 1

		case 88:	//	X (shift + x)
			int isComplex = WaveType($GetUserData(pnlName,"","src")) & 0x01
			if (!isComplex)
				return 1
			endif
			int dim = str2num(GetUserData(pnlName,"","dim"))
			int cmplxMode = dim==2 \
				? NumberByKey("imCmplxMode",ImageInfo(pnlName+"#image", "", 0),"=")\
				: NumberByKey("cmplxMode(x)",TraceInfo(pnlName+"#line", "", 0),"=")
			changeComplex(pnlName, ++cmplxMode)
			return 1
	endswitch

	switch (s.specialKeyCode)
		case 4:	//	F4
			if (str2num(GetUserData(pnlName,"","dim"))==2)
				SIDAMRange(grfName=pnlName+"#image")
				return 1
			endif
			break

		case 5:	//	F5
			if (str2num(GetUserData(pnlName,"","dim"))==2)
				SIDAMColor(grfName=pnlName+"#image")
				return 1
			endif
			break
	endswitch

	return 0
End
//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, arrows
//-------------------------------------------------------------
Static Function keyArrows(STRUCT WMWinHookStruct &s)
	// Igor 8: s.winName is always "Graph0".
	// Igor 9: s.winName is either "Graph0", "Graph0#line", or "Graph0#image".
	#if IgorVersion() < 9
		GetWindow $s.winName, activeSW
		if (strlen(SIDAMActiveCursors(S_Value)))
			return 0
		endif
	#else
		if (strlen(SIDAMActiveCursors(s.winName)))
			return 0
		endif
	#endif
	
	//	The following needs to be done for "Graph0".
	String pnlName = StringFromList(0, s.winName, "#")
	Wave cvw = SIDAMGetCtrlValues(pnlName,"p1C;p1V;q1V;p2C;p2V;q2V")

	//	Do nothing if neither 1 nor 2 is checked
	if (!cvw[%p1C] && !cvw[%p2C])
		return 0
	endif

	int isLeft = s.keycode == 28, isRight = s.keycode == 29
	int isUp = s.keycode == 30, isDown = s.keycode == 31
	int step = (s.eventMod & 2) ? 10 : 1	//	if the shift key is pressed, move 10 times faster
	int direction = (isLeft || isDown) ? -1 : 1
	int pinc = getIncrement(pnlName, "p1V") * step * direction 
	int qinc = getIncrement(pnlName, "q1V") * step * direction 
	Wave w = $GetUserData(pnlName,"","src")
	int nx = DimSize(w,0), ny = DimSize(w,1)

	if (isLeft || isRight)
		SetVariable p1V value=_NUM:limit(cvw[%p1V]+pinc*cvw[%p1C], 0, nx-1), win=$pnlName
		SetVariable p2V value=_NUM:limit(cvw[%p2V]+pinc*cvw[%p2C], 0, nx-1), win=$pnlName
	elseif (isUp || isDown)
		SetVariable q1V value=_NUM:limit(cvw[%q1V]+qinc*cvw[%p1C], 0, ny-1), win=$pnlName
		SetVariable q2V value=_NUM:limit(cvw[%q2V]+qinc*cvw[%p2C], 0, ny-1), win=$pnlName
	endif

	pnlSetDistanceAngle(pnlName)
	
	return 1
End

Static Function getIncrement(String pnlName, String ctrlName)
	ControlInfo/W=$pnlName $ctrlName
	Variable num1 = strsearch(S_recreation,"limits={",0)+8
	Variable num2 = strsearch(S_recreation,"}",num1)-1
	return str2num(StringFromList(2,S_recreation[num1,num2],","))
End

//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, space
//-------------------------------------------------------------
Static Function keySpace(String pnlName)
	Variable dim = str2num(GetUserData(pnlName,"","dim"))		//	nan for 2D LineProfile
	if (dim == 1)
		pnlChangeDim(pnlName, 2)
	elseif (dim == 2)
		pnlChangeDim(pnlName, 1)
	endif
	return 0
End
//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, complex
//-------------------------------------------------------------
Static Function changeComplex(String pnlName, int mode)
	Variable dim = str2num(GetUserData(pnlName,"","dim"))
	if (numtype(dim))
		dim = 1
	endif

	//	Make mode 0 if it's too large.
	//	This can occur when this function is called by the keyboard shortcut.
	int numOfModes = ItemsInList(SelectString(dim, MENU_COMPLEX2D, MENU_COMPLEX1D))
	mode = mode < numOfModes ? mode : 0

	if (dim==1)
		ModifyGraph/W=$(pnlName+"#line") cmplxMode=mode
	elseif (dim==2)
		ModifyImage/W=$(pnlName+"#image") '' imCmplxMode=mode
	endif
End


//==============================================================================
//	Helper functions for controls
//==============================================================================
//	Set the values of controls based on changed controls.
//	When the value of distanceV or angleV is changed, set the value of
//	p1V, q1V, p2V, and q2V
//	When the value of p1V, q1V, p2V, or q2V is changed, set the value of
// distanceV and angleV.
Static Function pnlSetVarUpdateValues(STRUCT WMSetVariableAction &s)

	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif

	DFREF dfrTmp = $GetUserData(s.win,"","dfTmp")
	Wave w = $GetUserData(s.win,"","src")
	int grid = str2num(GetUserData(s.win,"","grid"))

	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable vx, vy

	strswitch (s.ctrlName)
		case "distanceV":
		case "angleV":
			Wave cvw = SIDAMGetCtrlValues(s.win,"p1C;p1V;q1V;p2C;p2V;q2V;distanceV;angleV")
			if (cvw[%p2C])
				vx = limit(ox+dx*cvw[1]+cvw[6]*cos(cvw[7]*pi/180), ox, ox+dx*(nx-1))
				vy = limit(oy+dy*cvw[2]+cvw[6]*sin(cvw[7]*pi/180), oy, oy+dy*(ny-1))
				SetVariable p2V value=_NUM:(grid ? round((vx-ox)/dx) : (vx-ox)/dx), win=$s.win
				SetVariable q2V value=_NUM:(grid ? round((vy-oy)/dy) : (vy-oy)/dy), win=$s.win
			elseif (cvw[%p1C])
				vx = limit(ox+dx*cvw[4]-cvw[6]*cos(cvw[7]*pi/180), ox, ox+dx*(nx-1))
				vy = limit(oy+dy*cvw[5]-cvw[6]*sin(cvw[7]*pi/180), oy, oy+dy*(ny-1))
				SetVariable p1V value=_NUM:(grid ? round((vx-ox)/dx) : (vx-ox)/dx), win=$s.win
				SetVariable q1V value=_NUM:(grid ? round((vy-oy)/dy) : (vy-oy)/dy), win=$s.win
			endif
			//	*** FALLTHROUGH ***
		case "p1V":
		case "p2V":
		case "q1V":
		case "q2V":
			if (strlen(s.ctrlName) == 3)	//	neither distanceV nor angleV
				SetVariable $s.ctrlName value=_NUM:(grid ? round(s.dval) : s.dval), win=$s.win
			endif
			pnlSetDistanceAngle(s.win)
			break
		default:
	endswitch
End

//	Set the value of distanceV and angleV based on the values
//	of p1V, q1V, p2V, and q2V
Static Function pnlSetDistanceAngle(String pnlName)
	Wave cvw = SIDAMGetCtrlValues(pnlName,"p1V;q1V;p2V;q2V")
	Wave w = $GetUserData(pnlName,"","src")
	Variable vx = (cvw[2]-cvw[0])*DimDelta(w,0), vy = (cvw[3]-cvw[1])*DimDelta(w,1)
	SetVariable distanceV value=_NUM:sqrt(vx^2+vy^2), win=$pnlName
	SetVariable angleV value=_NUM:atan2(vy,vx)/pi*180, win=$pnlName
End

//	Determine the step size of setvariable, used only for distanceV at present.
Static Function pnlSetVarIncrement(String pnlName)
	String grfName = StringFromList(0,GetUserData(pnlName,"","parent"))
	Wave w = SIDAMImageNameToWaveRef(grfName)
	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(grfName,NameOfWave(w),s)
	SetVariable distanceV limits={0,inf,sqrt((s.x.max.value-s.x.min.value)^2 \
		+ (s.y.max.value-s.y.min.value)^2)/128}, win=$pnlName
End

//	Waterfall
Static Function pnlSetVarAxlen(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	//	Newwaterfall wave0 vs {*, wavez}
	//	When the wavez is used (unevenly-spaced bias), even if the displayed image
	//	is deleted, the wavez is treated as if it was still shown. (Igor's bug?)
	//	Therefore close s.win+#line to avoid an error.
	if (SIDAMWindowExists(s.win+"#line"))
		ModifyWaterfall/W=$(s.win+"#line") axlen=s.dval
	endif
End

//==============================================================================
//	for menu
//==============================================================================
//	menu items
Static Function/S menu(int mode)
	String pnlName = WinName(0,64)
	if (!strlen(pnlName))
		return ""
	endif
	
	Variable dim = str2num(GetUserData(pnlName,"","dim"))	//	nan for 2D

	switch (mode)
		case 0:	//	positions
			String rtnStr = "origin && 0\u00B0;"
			rtnStr += "origin && 30\u00B0;"
			rtnStr += "origin && 45\u00B0;"
			rtnStr += "origin && 60\u00B0;"
			rtnStr += "origin && 90\u00B0;"
			rtnStr += "horizontal;vertical;-;exchange"
			return rtnStr

		case 1:	//	dim
			return SIDAMAddCheckmark(dim-1, "1D traces;2D image")	//	empty for nan

		case 2:	//	complex
			int isComplex = WaveType($GetUserData(pnlName,"","src")) & 0x01
			int cmplxMode
			if (!isComplex)
				return ""
			elseif (dim==2)
				cmplxMode = NumberByKey("imCmplxMode",ImageInfo(pnlName+"#image", "", 0),"=")
				return SIDAMAddCheckmark(cmplxMode, MENU_COMPLEX2D)
			else
				cmplxMode = NumberByKey("cmplxMode(x)",TraceInfo(pnlName+"#line", "", 0),"=")
				return SIDAMAddCheckmark(cmplxMode, MENU_COMPLEX1D)
			endif

		case 3:	//	Free
			int grid = str2num(GetUserData(pnlName,"","grid"))
			return SelectString(grid, "! ", "") + "Free"

		case 4:	//	Highlight
			Variable highlight = str2num(GetUserData(pnlName,"","highlight"))	//	nan ofr 2D
			return SelectString(dim==2, "","(") + SelectString(highlight, "Highlight", "! Highlight")				//	nan　に対しては空文字を返す

		case 7:	//	Range
			return SelectString(dim==2, "(","") + "Range..."

		case 8:	//	Color Table
			return SelectString(dim==2, "(","") + "Color Table..."
	endswitch
End

//	window list 
Static Function/S menuTarget()
	String pnlName = WinName(0,1)
	if (!strlen(pnlName))
		return ""
	endif

	strswitch (GetUserData(pnlName,"","key"))
		case "SIDAMLineSpectra":
			Wave/Z srcw = $GetUserData(pnlName, "", "src")
			break
		case "SIDAMSpectrumViewer":
			Wave/Z srcw = TraceNameToWaveRef(pnlName,StringFromList(0,TraceNameList(pnlName,";",1)))
			break
		default:
			return ""
	endswitch

	if (!WaveExists(srcw))
		return ""
	endif

	String allList = WinList("*",";","WIN:1,VISIBLE:1"), win
	String rtnList = ""	, grfList = ""
	int i, n

	for (i = 0, n = ItemsInList(allList); i < n; i += 1)
		win = StringFromList(i, allList)
		Wave/Z imgw = SIDAMImageNameToWaveRef(win)
		if (!WaveExists(imgw) || DimSize(srcw,0) != DimSize(imgw,0) \
			|| DimSize(srcw,1) != DimSize(imgw,1))
				continue
		elseif (WhichListItem(win, GetUserData(pnlName,"","parent")) != -1)
			rtnList += "\\M0:!" + num2char(18) + ":"+NameOfWave(imgw) + " (" + win + ");"
		else
			rtnList += "\\M0" + NameOfWave(imgw) + " (" + win + ");"
		endif
		grfList += win + ";"
	endfor
	SetWindow $pnlName userData(target)=grfList

	return rtnList
End

//	Set values of p1V, q1V, p2V, q2V, distanceV and angleV
//	by selecting a menu about positions.
Static Function menuPositions(String pnlName)
	Wave w = $GetUserData(pnlName,"","src")
	int grid = str2num(GetUserData(pnlName,"","grid"))

	int nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Variable p1, q1, p2, q2, v
	GetLastUserMenuInfo
	//	the origin for "origin & x"
	if (1 <= V_Value && V_Value <=5)		//	origin & x
		p1 = grid ? round(-DimOffset(w,0)/dx) : -DimOffset(w,0)/dx
		q1 = grid ? round(-DimOffset(w,1)/dy) : -DimOffset(w,1)/dy
	endif
	//	for dx != dy and origin & 30, 45, 60
	if (2 <= V_value && V_value <= 4)
		Make/D/N=3/FREE tw = {30,45,60}
		v = dy/dx/tan(tw[V_value-2]/180*pi)
	endif
	switch (V_value)
		case 1:	//	origin & 0
			p2 = nx-1;	q2 = q1
			break
		case 2:	//	origin & 30
		case 3:	//	origin & 45
		case 4:	//	origin & 60
			p2 = min(nx-1, p1+(grid ? round((ny-1-q1)*v) : (ny-1-q1)*v))
			q2 = min(ny-1, q1+(grid ? round((nx-1-p1)/v) : (nx-1-p1)/v))
			break
		case 5:	//	origin & 90
			p2 = p1;	q2 = ny-1
			break
		case 6:	//	horizontal
			p1 = 0;	p2 = nx-1;	q1 = Ceil(DimSize(w,1)/2)-1;	q2 = q1
			break
		case 7:	//	vertial
			q1 = 0; 	q2 = ny-1;	p1 = Ceil(DimSize(w,0)/2)-1;	p2 = p1;
			break
		case 9:	//	exchange
			Wave cw = SIDAMGetCtrlValues(pnlName, "p1V;q1V;p2V;q2V")
			p1 = cw[2];	q1 = cw[3];	p2 = cw[0];	q2 = cw[1]
			break
	endswitch
	SetVariable p1V value=_NUM:p1, win=$pnlName
	SetVariable q1V value=_NUM:q1, win=$pnlName
	SetVariable p2V value=_NUM:p2, win=$pnlName
	SetVariable q2V value=_NUM:q2, win=$pnlName

	pnlSetDistanceAngle(pnlName)
End

Static Function menuComplex(String pnlName)
	GetLastUserMenuInfo
	changeComplex(pnlName, V_value-1)
End

Static Function menuFree(String pnlName)
	int grid = str2num(GetUserData(pnlName,"","grid"))
	String ctrlList = "p1V;q1V;p2V;q2V"
	ModifyControlList ctrlList format=SelectString(grid,"%d","%.2f"), win=$pnlName
	Wave cvw = SIDAMGetCtrlValues(pnlName,ctrlList), w = $GetUserData(pnlName,"","src")
	if (!grid)
		SetVariable p1V value=_NUM:round(cvw[0]), win=$pnlName
		SetVariable q1V value=_NUM:round(cvw[1]), win=$pnlName
		SetVariable p2V value=_NUM:round(cvw[2]), win=$pnlName
		SetVariable q2V value=_NUM:round(cvw[3]), win=$pnlName
		pnlSetDistanceAngle(pnlName)
	endif
	SetWindow $pnlName userData(grid)=num2istr(!grid)
End
