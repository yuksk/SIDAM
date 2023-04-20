#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSpectrumViewer

#include "SIDAM_Bias"
#include "SIDAM_Help"
#include "SIDAM_InfoBar"
#include "SIDAM_KeyboardShortcuts"
#include "SIDAM_Line"
#include "SIDAM_Menus"
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

Static StrConstant KEY = "SIDAMSpectrumViewer"

Static Function menuDo()
	pnl(WinName(0,1))
End

Static Function pnl(String LVName)

	//	If there is a grpah showing a spectrum, focus it and quit
	if (isDisplayed(LVName))
		return 0
	endif

	String pnlName = UniqueName("Graph",6,0)
	Wave srcw =  SIDAMImageNameToWaveRef(LVName)

	//	Prepare a wave for horizontal axis in a temporary folder
	//	if the 3D wave is in Nanonis MLS mode
	int isMLS = SIDAMisUnevenlySpacedBias(srcw)
	if (isMLS)
		String dfTmp
		Wave xw = pnlInit(srcw, pnlName, dfTmp)
	endif

	//  Show a graph
	if (isMLS)
		Display/K=1 srcw[0][0][] vs xw
	else
		Display/K=1 srcw[0][0][]
	endif
	AutoPositionWindow/E/M=0/R=$LVName $pnlName

	ModifyGraph/W=$pnlName width=180*96/screenresolution, height=180*96/screenresolution, gfSize=10
	ModifyGraph/W=$pnlName margin(top)=8,margin(right)=12,margin(bottom)=36,margin(left)=44
	ModifyGraph/W=$pnlName tick=0,btlen=5,mirror=0,lblMargin=2
	ModifyGraph/W=$pnlName rgb=(SIDAM_WINDOW_LINE_R, SIDAM_WINDOW_LINE_G, SIDAM_WINDOW_LINE_B)

	ControlBar 48
	SIDAMMenuCtrl(pnlName, "SIDAMSpectrumViewerMenu")
				
	SetVariable pV title="p:", pos={25,6}, value=_NUM:0, win=$pnlName
	SetVariable qV title="q:", pos={105,6}, value=_NUM:0, win=$pnlName
	TitleBox xyT pos={4,30}, frame=0, win=$pnlName

	ModifyControlList "pV;qV" size={72,15}, proc=SIDAMSpectrumViewer#pnlSetVar, win=$pnlName
	ModifyControlList "pV;qV" bodyWidth=60, limits={0,DimSize(srcw,0)-1,1}, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	SIDAMApplyHelp(pnlName, "[SIDAM_SpectrumViewer]")

	SetWindow $pnlName userData(live)="0"
	SetWindow $pnlName userData(key)=KEY
	if (isMLS)
		SetWindow $pnlName userData(dfTmp)=dfTmp
	endif

	//	Make the LVname a target window of the pnlName
	pnlSetRelation(LVname, pnlName)

	DoUpdate/W=$pnlName
	ModifyGraph/W=$pnlName width=0, height=0
End

Static Function isDisplayed(String LVName)
	String listStr = GetUserData(LVName,"",KEY), pnlName, trcName
	int i, n

	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,listStr,";"),"=")
		if (!SIDAMWindowExists(pnlName))
			continue
		endif
		trcName = StringFromList(0,TraceNameList(pnlName,";",1))
		Wave tracew = TraceNameToWaveRef(pnlName,trcName)
		Wave imgw = SIDAMImageNameToWaveRef(LVName)
		if (WaveRefsEqual(tracew,imgw))
			DoWindow/F $pnlName
			return 1
		endif
	endfor
	return 0
End

Static Function/WAVE pnlInit(Wave srcw, String pnlName, String &dfTmp)
	dfTmp = SIDAMNewDF(pnlName,KEY)
	Duplicate/O SIDAMGetBias(srcw, 1) $(dfTmp+NameOfWave(srcw)+"_b")/WAVE=tw
	return tw
End

//	Make the mouseWin a target window of the specWin
Static Function pnlSetRelation(String mouseWin, String specWin)
	String list = GetUserData(mouseWin, "", KEY)
	SetWindow $mouseWin userData($KEY)=AddListItem(specWin+"="+GetUserData(specWin,"","dfTmp"), list)
	SetWindow $mouseWin hook($KEY)=SIDAMSpectrumViewer#pnlHookParent

	list = GetUserData(specWin, "", "parent")
	SetWindow $specWin userData(parent)=AddListItem(mouseWin, list)
	SetWindow $specWin hook(self)=SIDAMSpectrumViewer#pnlHook
End

//	Make the mouseWin NOT a target window of the specWin
Static Function pnlResetRelation(String mouseWin, String specWin)
	//	For the mouseWin
	//	Remove the specWin from the list
	String newList = RemoveByKey(specWin, GetUserData(mouseWin,"",KEY),"=")
	SetWindow $mouseWin userData($KEY)=newList
	if (!ItemsInlist(newList))
		//	If the list becomes empty, the mouseWin is no longer a target
		//	of any window and the hook function can be removed.
		SetWindow $mouseWin hook($KEY)=$""
	endif

	//	For the specWin
	//	Remove the mouseWin from the list
	//	This function is also called in the case that the specWin was
	//	closed during SIDAM was not working (before compile).
	//	The following if clause is for that case.
	if (SIDAMWindowExists(specWin))
		//	Unlike the specWin, the hook function must be kept even if
		//	the list becomes empty to show the menu and the coordinates.
		SetWindow $specWin userData(parent)=RemoveFromList(mouseWin,GetUserData(specWin,"","parent"))
	endif
End


//******************************************************************************
//	Hook functions
//******************************************************************************
//	For the graph showing a spectrum
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
			return 0

		case 4:	//	mouse move
			int isShiftPressed = s.eventMod & 0x02
			if (!isShiftPressed)
				SIDAMInfobarUpdatePos(s)
			endif
			return 0

		case 11: 	//	keyboard
			if (s.keycode == 27)		//	esc
				SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
				KillWindow $s.winName
			elseif (s.keycode >= 28 && s.keycode <= 31)	//	arrows
				if (strlen(SIDAMActiveCursors(s.winName)))
					return 0
				endif
				pnlHookArrows(s)
			elseif (s.keycode==88 || s.keycode >= 97)
				SIDAMKeyboardShortcuts(s)
			endif
			return 1

		case 13: //	renamed
			SIDAMLine#pnlHookRename(s)
			return 0

		default:
			return 0
	endswitch
End

//	For the parent window
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	String pnlList, pnlName
	int i, n

	if (SIDAMLine#pnlHookParentCheckChild(s.winName,KEY,pnlResetRelation))
		return 0
	endif

	switch (s.eventCode)
		case 2:	//	kill
			pnlList = GetUserData(s.winName,"",KEY)
			for (i = 0, n = ItemsInList(pnlList); i < n; i += 1)
				pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
				pnlResetRelation(s.winName, pnlName)
			endfor
			return 0

		case 3:	//	mouse down
			SetWindow $s.winName userData(mousePressed)="1"
			return 0

		case 4:	//	mouse moved
			int isShiftPressed = s.eventMod & 0x02
			if (!isShiftPressed)
				pnlHookMouseMov(s)
			endif
			return 0

		case 5:	//	mouse up
			GetWindow $s.winName, wsizeDC
			int isOutOfWindow = s.mouseLoc.h < V_left || s.mouseLoc.h > V_right \
				|| s.mouseLoc.v > V_bottom || s.mouseLoc.v < V_top
			int isDragged = !strlen(GetUserData(s.winName,"","mousePressed"))
			if (isOutOfWindow)
				return 0
			elseif (isDragged)
				return 0
			endif
			SetWindow $s.winName userData(mousePressed)=""
			return 0

		case 7:	//	cursor moved
			pnlHookCsrMov(s)
			SetWindow $s.winName userData(mousePressed)=""
			return 0

		case 13:	//	renamed
			SIDAMLine#pnlHookParentRename(s,KEY)
			return 0

		default:
			return 0
	endswitch
End

//-------------------------------------------------------------
//	Helper functions of hook functions
//-------------------------------------------------------------
//	When the mouse cursor is moved on the parent window
Static Function pnlHookMouseMov(STRUCT WMWinHookStruct &s)
	STRUCT SIDAMMousePos ms
	if (SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=1))
		return 0
	endif

	String pnlList = GetUserData(s.winName,"",KEY), pnlName
	int i, n
	for (i = 0, n = ItemsInList(pnlList); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		if (str2num(GetUserData(pnlName, "", "live")) == 0)
			pnlUpdateSpec(pnlName, ms.p, ms.q)
		endif
	endfor
End

//	When the cursor A in the pararent window is moved
Static Function pnlHookCsrMov(STRUCT WMWinHookStruct &ws)
	//	Do nothing unless the cursor A is displayed
	STRUCT SIDAMCursorPos s
	if (SIDAMGetCursor("A", ws.winName, s))
		return 0
	endif

	String pnlList = GetUserData(ws.winName,"",KEY), pnlName
	int i, n
	for (i = 0, n = ItemsInList(pnlList); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		if (str2num(GetUserData(pnlName, "", "live")) == 1)
			pnlUpdateSpec(pnlName, s.p, s.q)
		endif
	endfor
End

//	When an arrow key is pressed on the spectrum window
Static Function pnlHookArrows(STRUCT WMWinHookStruct &s)
	String mouseWinList = GetUserData(s.winName,"","parent")
	int i, n = ItemsInList(mouseWinList)

	for (i = 0; i < n; i++)
		int isCtrlPressed = s.eventMod & 2
		int step = isCtrlPressed ? 10 : 1
		ControlInfo/W=$s.winName pV ;	Variable posp = V_Value
		ControlInfo/W=$s.winName qV ;	Variable posq = V_Value
		switch (s.keycode)
			case 28:		//	left
				posp = posp-step
				break
			case 29:		//	right
				posp = posp+step
				break
			case 30:		//	up
				posq = posq+step
				break
			case 31:		//	down
				posq = posq-step
				break
		endswitch
		pnlUpdateSpec(s.winName, posp, posq)
	endfor
End


//******************************************************************************
//	Controls
//******************************************************************************
//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	Wave cvw = SIDAMGetCtrlValues(s.win,"pV;qV")
	pnlUpdateSpec(s.win, cvw[%pV], cvw[%qV])
End


//******************************************************************************
//	Helper functions
//******************************************************************************
//	Update the spectrum in the spectrum window
Static Function pnlUpdateSpec(String pnlName, Variable posp, Variable posq)
	//	function stack calling this function
	String callingStack = RemoveListItem(ItemsInList(GetRTStackInfo(0))-1, GetRTStackInfo(0))
	//	true if this function is included in the stack
	Variable recursive = WhichListItem(GetRTStackInfo(1), callingStack) != -1
	if (recursive)
		return 0
	endif

	int i, n
	String trcList = TraceNameList(pnlName,";",1), trcName

	//	Update the spectrum
	for (i = 0, n = ItemsInList(trcList); i < n; i++)
		trcName = StringFromList(i,trcList)
		Wave srcw = TraceNameToWaveRef(pnlName,trcName)
		posp = limit(posp, 0, DimSize(srcw,0)-1)
		posq = limit(posq, 0, DimSize(srcw,1)-1)
		ReplaceWave/W=$pnlName trace=$NameOfWave(srcw), srcw[posp][posq][]
	endfor

	//	Update the controls
	SetVariable pV value=_NUM:posp, win=$pnlName
	SetVariable qV value=_NUM:posq, win=$pnlName
	DoUpdate/W=$pnlName

	//	Move cursor A in the parent window if necessary.
	int isCursorAUsed = str2num(GetUserData(pnlName,"","live")) == 1
	int isNOTCalledFrompnlHookCsrMov = CmpStr(GetRTStackInfo(2), "pnlHookCsrMov")
	if (isCursorAUsed && isNOTCalledFrompnlHookCsrMov)
		STRUCT SIDAMCursorPos s
		s.isImg = 1
		s.p = posp
		s.q = posq
		String win, mouseWinList = GetUserData(pnlName,"","parent")
		for (i = 0, n = ItemsInList(mouseWinList); i < n; i++)
			win = StringFromList(i, mouseWinList)
			SIDAMMoveCursor("A", win, 0, s)
		endfor
	endif
End

//-------------------------------------------------------------
//	Menu
//-------------------------------------------------------------
Menu "SIDAMSpectrumViewerMenu", dynamic, contextualmenu
	SubMenu "Live Update"
		SIDAMSpectrumViewer#changeLiveMenu(), SIDAMSpectrumViewer#changeLive()
	End
	SubMenu "Target window"
		SIDAMLine#menuTarget(), SIDAMSpectrumViewer#changeTarget()
	End
	SubMenu "Complex"
		SIDAMSpectrumViewer#changeComplexMenu(), SIDAMSpectrumViewer#changeComplex()
	End
	"Save", SIDAMSpectrumViewer#saveSpectrum(WinName(0,1))
End

Static Function changeComplex()
	GetLastUserMenuInfo
	ModifyGraph/W=$WinName(0,1) cmplxMode=V_Value
End

Static Function/S changeComplexMenu()
	String win = WinName(0,1)
	String trcList = TraceNameList(win,";",1), trcName
	int i, isComplexIncluded = 0

	for (i = 0; i < ItemsInList(trcList); i++)
		trcName = StringFromList(i,trcList)
		if (WaveType(TraceNameToWaveRef(win,trcName)) & 0x01)
			int mode = NumberByKey("cmplxMode(x)",TraceInfo(win, trcName, 0),"=")
			return SIDAMAddCheckmark(mode-1, "real only;imaginary only;magnitude;phase in radian")
		endif
	endfor
	return ""
End

Static Function changeLive()
	GetLastUserMenuInfo
	SetWindow $WinName(0,1) userData(live)=num2str(V_Value-1)
End

Static Function/S changeLiveMenu()
	String win = WinName(0,1)
	int num = strlen(win) ? str2num(GetUserData(win,"","live")) : 0
	return SIDAMAddCheckmark(num, "Mouse;Cursor A;None;")
End

Static Function changeTarget()
	String specWin = WinName(0,1)
	GetLastUserMenuInfo
	String mouseWin = StringFromList(V_value-1,GetUserData(specWin,"","target"))
	if (WhichListItem(mouseWin, GetUserData(specWin, "", "parent")) == -1)
		pnlSetRelation(mouseWin, specWin)
	else
		pnlResetRelation(mouseWin, specWin)
	endif
End

Static Function saveSpectrum(String pnlName)
	Wave cvw = SIDAMGetCtrlValues(pnlName,"pV;qV")
	String trcList = TraceNameList(pnlName,";",1), trcName, result
	DFREF dfrSav = GetDataFolderDFR()
	int i

	for (i = 0; i < ItemsInList(trcList); i++)
		trcName = StringFromList(i,trcList)
		if (strsearch(trcName,"#",0)>=0)
			continue
		endif

		Wave srcw = TraceNameToWaveRef(pnlName,trcName)
		if (WaveDims(srcw)!=3)
			continue
		endif

		sprintf result, "%s_p%dq%d", NameOfWave(srcw), cvw[%pV], cvw[%qV]
		result = CleanupName(result,1)
		
		DFREF dfr = GetWavesDataFolderDFR(srcw)
		Duplicate/O/R=[cvw[%pV]][cvw[%qV]][] srcw, dfr:$result/WAVE=extw
		Redimension/N=(numpnts(extw)) extw

		if (SIDAMisUnevenlySpacedBias(srcw))
			Duplicate/O SIDAMGetBias(srcw, 1) dfr:$(NameOfWave(srcw)+"_b")
		else
			SetScale/P x DimOffset(srcw,2), DimDelta(srcw,2), WaveUnits(srcw,2), extw
		endif
		SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(srcw,0)), extw
		DoAlert 0, "A wave saved at " + GetWavesDataFolder(extw,2)
	endfor
End
