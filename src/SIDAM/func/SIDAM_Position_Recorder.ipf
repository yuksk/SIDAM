#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMPositionRecorder

#include "SIDAM_Display"
#include "SIDAM_Utilities_Help"
#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Show a panel to record positions.
//
//	## Parameters
//	grfName : string, default `WinName(0,1,1)`
//		The name of window.
//
//	## Returns
//	variable
//		* 0: Normal exit
//		* !0 Error in input parameters
//@
Function SIDAMPositionRecorder(String grfName)
	grfName = SelectString(strlen(grfName),WinName(0,1,1),grfName)
	if (validateInputs(grfName))
		return 1
	endif

	pnl(grfName)
	return 0
End

Static Function validateInputs(String grfName)
	String errmsg
	sprintf errmsg, "%sSIDAMPositionRecorder gave error: ", PRESTR_CAUTION

	if (!strlen(grfName))
		printf "%sno window\r", errmsg
		return 1
	elseif (!ItemsInList(ImageNameList(grfName,";")))
		printf "%sno image\r", errmsg
		return 1
	endif

	return 0
End


//******************************************************************************
//	Display a panel
//******************************************************************************
Static Constant PNLWIDTH = 235
Static Constant PNLHEIGHT = 110
Static Constant PNLOFFSET = 140
Static StrConstant PNAME = "PositionRecorder"

Static Function pnl(String grfName)
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,PNLWIDTH,PNLHEIGHT)/N=$PNAME
	String pnlName = grfName + "#" + PNAME

	SetWindow $pnlName hook(self)=SIDAMPositionRecorder#pnlHook, activeChildFrame=0

	GroupBox posG title="position wave", pos={8,2}, size={220,75}, win=$pnlName
	CheckBox existingC title="existing:", pos={15,26}, value=1, win=$pnlName
	PopupMenu existingP pos={80,24}, mode=1, value= #"SIDAMPositionRecorder#popupStr()", win=$pnlName

	CheckBox newC pos={15,52}, title="new:", value=0, win=$pnlName
	PopupMenu newP pos={80,50}, value="_select a mode_;p and q;x and y", disable=1, win=$pnlName

	TitleBox pathT title="", pos={5,118}, frame=0, win=$pnlName
	Checkbox gridC pos={189,118}, title="grid", value=1, win=$pnlName

	Button startB pos={7,85}, size={60,20}, title="Start", disable=2, win=$pnlName
	Button finishB pos={75,85}, size={60,20}, title="Finish", disable=2, win=$pnlName
	Button helpB pos={141,85}, size={18,20}, title="?", win=$pnlName
	Button closeB pos={168,85}, size={60,20}, title="Close", win=$pnlName

	ModifyControlList "existingC;newC" mode=1, proc=SIDAMPositionRecorder#pnlCheck, win=$pnlName
	ModifyControlList "existingP;newP" title="", size={140,19}, bodyWidth=140, proc=SIDAMPositionRecorder#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*B") proc=SIDAMPositionRecorder#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	SetActiveSubwindow $grfName
End

Static Function/S popupStr()
	String candidates = WaveList("*",";","DIMS:2,MAXROWs:3,CMPLX:0,TEXT:0,WAVE:0,DF:0")

	//	Remove a wave from the list unless it has dimlabels of "p" and "q", or "x" and "y"
	int i
	for (i = ItemsInList(candidates)-1; i >= 0; i--)
		if (!getMode($StringFromList(i,candidates)))
			candidates = RemoveListItem(i,candidates)
		endif
	endfor

	return SelectString(ItemsInList(candidates), "_none_", "_select a wave_;"+candidates)
End

//-------------------------------------------------------------
//	Hook function for the panel
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			pnlHookClose(s)
			break
		case 11:	//	keyboard
			if (s.keycode == 27)	//	esc
				pnlHookClose(s)
				//	s.winName can be the parent panel or the child panel.
				String pnlName = StringFromList(0,s.winName,"#") + "#" + PNAME			
				KillWindow $pnlName
			endif
			break
		case 14:	//	subwindowkill
			//	s.winName here is pnlName+"T0"
			Wave w = $StringByKey("WAVE", TableInfo(s.winName,0))
			KillWindow $s.winName
			if (!numpnts(w))
				//	Kill the wave if it has no point and is not on the graph.
				//	If the finish button is pressed without adding a point to a new wave,
				//	the wave will be deleted because it satisfies the above condition.
				KillWaves/Z w
			endif
			break
	endswitch
	return 0
End

Static Function pnlHookClose(STRUCT WMWinHookStruct &s)
	String grfName = StringFromList(0, s.winName, "#")
	SetWindow $grfName hook(positionrecorder)=$""
End

//-------------------------------------------------------------
//	Hook function for the parent window
//	Add/Delete a point by clicking the window
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 5)	//	only mouse up
		return 0
	endif

	String pnlName = s.winName+"#"+PNAME

	STRUCT SIDAMMousePos ms
	ControlInfo/w=$pnlName gridC
	if (SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=V_Value))
		return 0
	endif

	ControlInfo/W=$pnlName existingC
	Wave w = $GetUserData(pnlName,SelectString(V_Value,"newP","existingP"),"wave")

	if (s.eventMod & 0x08)	//	if ctrl is pressed
		deleteNearestPoint(w, ms)
	else
		addPoint(w, ms, pnlName)
	endif

	return 0
End

Static Function deleteNearestPoint(Wave w, STRUCT SIDAMMousePos &ms)
	int n = DimSize(w,1)
	if (!n)
		return 1
	endif

	if (getMode(w) == 1)
		Make/D/N=(n)/FREE disw = (w[%p][p]-ms.p)^2 + (w[%q][p]-ms.q)^2
	else
		Make/D/N=(n)/FREE disw = (w[%x][p]-ms.x)^2 + (w[%y][p]-ms.y)^2
	endif
	WaveStats/Q/M=1 disw
	DeletePoints/M=1 V_minRowLoc, 1, w
	return 0
End

Static Function addPoint(Wave w, STRUCT SIDAMMousePos &ms, String pnlName)
	int n = DimSize(w,1), isPQ = str2num(GetUserData(pnlName,"","mode")) == 1
	String tableName = pnlName+"#T0"

	if (n)
		Redimension/N=(-1,n+1) w
	else
		Redimension/N=(2,n+1) w
		SetDimLabel 0, 0, $SelectString(isPQ,"x","p"), w
		SetDimLabel 0, 1, $SelectString(isPQ,"y","q"), w
		ModifyTable/W=$tableName elements=(-3,-2,0,0), horizontalIndex=2
		showWave(w, StringFromList(0,pnlName,"#"))
	endif

	if (isPQ)
		w[%p][n] = ms.p
		w[%q][n] = ms.q
	else
		w[%x][n] = ms.x
		w[%y][n] = ms.y
	endif

	String info = TableInfo(tableName,-2)
	int first = NumberByKey("FIRSTCELL", info), last = NumberByKey("LASTCELL", info)
	int top = n-last+first+1
	ModifyTable/W=$tableName selection=(n,0,n,1,n,0), topLeftCell=(limit(top,0,top),0)
End

Static Function showWave(Wave w, String grfName)
	CheckDisplayed/W=$grfName w
	if (V_flag || !numpnts(w))
		return 0
	endif
	SIDAMDisplay(w,traces=2)
	ModifyGraph/W=$grfName mode($NameOfWave(w))=3
End

Static Function getMode(Wave w)
	int hasPQ = FindDimLabel(w,0,"p")>=0 && FindDimLabel(w,0,"q")>=0
	int hasXY = FindDimLabel(w,0,"x")>=0 && FindDimLabel(w,0,"y")>=0
	if (hasPQ)
		return 1
	elseif (hasXY)
		return 2
	else
		return 0
	endif
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Checkbox
Static Function pnlCheck(STRUCT  WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "existingC":
			CheckBox newC value=0, win=$s.win
			break
		case "newC":
			CheckBox existingC value=0, win=$s.win
			break
	endswitch
	pnlUpdateCtrl(s.win)
	return 0
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif

	String grfName = StringFromList(0, s.win, "#")

	strswitch (s.ctrlName)
		case "startB":
			int mode
			ControlInfo/W=$s.win existingC
			if (V_Value)
				Wave/Z w = $GetUserData(s.win, "existingP", "wave")
				mode = getMode(w)
			else
				DFREF dfr = GetDataFolderDFR()
				SetDataFolder GetWavesDataFolderDFR(SIDAMImageWaveRef(grfName))
				Make/N=0 $UniqueName("pos",1,0)/WAVE=w
				SetDataFolder dfr
				PopupMenu newP userData(wave)=GetWavesDataFolder(w,2), win=$s.win
				ControlInfo/W=$s.win newP
				mode = V_Value - 1
			endif
			TitleBox pathT title=GetWavesDataFolder(w,2), win=$s.win
			//	numpnts can be 0 by ctrl+click and dimlabels can be lost.
			//	Therefore save mode in advance here.
			SetWindow $s.win userData(mode)=num2istr(mode)
			SetWindow $grfName hook(positionrecorder)=SIDAMPositionRecorder#pnlHookParent

			//	show a table in a subwindow
			GetWindow $grfName wsizeOuterDC
			MoveSubwindow/W=$s.win fnum=(0,0,PNLWIDTH,V_bottom)
			Edit/W=(0,PNLOFFSET,V_right,V_bottom)/HOST=$s.win w
			ModifyTable/W=$(s.win+"#T0") elements=(-3,-2,0,0), horizontalIndex=2
			ModifyTable/W=$(s.win+"#T0") width=90, width(Point)=30, format(Point)=1
			ModifyTable/W=$(s.win+"#T0") showParts=236		//	236 = from bit 2 to 7
			SetActiveSubwindow ##

			showWave(w, grfName)
			break

		case "finishB":
			SetWindow $grfName hook(positionrecorder)=$""
			KillWindow $(s.win+"#T0")
			MoveSubwindow/W=$s.win fnum=(0,0,PNLWIDTH,PNLHEIGHT)
			break

		case "helpB":
			SIDAMOpenHelpNote("positionrecorder", s.win, "Position Recorder")
			return 0

		case "closeB":
			KillWindow $s.win
			return 0

	endswitch
	pnlUpdateCtrl(s.win)
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "existingP":
			//	Save the path to the selected wave
			Wave/Z w = $s.popStr
			if (WaveExists(w))
				PopupMenu $s.ctrlName userData(wave)=GetWavesDataFolder(w,2), win=$s.win
			else		//	"_select a wave_" or "_none_"
				PopupMenu $s.ctrlName userData(wave)="", win=$s.win
			endif
			CheckBox existingC value=(s.popNum!=1), win=$s.win
			CheckBox newC value=(s.popNum==1), win=$s.win
			break

		case "newP":
			CheckBox existingC value=(s.popNum==1), win=$s.win
			CheckBox newC value=(s.popNum!=1), win=$s.win
			break
	endswitch

	pnlUpdateCtrl(s.win)
	return 0
End

//-------------------------------------------------------------
//	Update the controls of the panel
//-------------------------------------------------------------
Static Function pnlUpdateCtrl(String pnlName)
	Wave/Z posw = $GetUserData(pnlName,"existingP","wave")
	int isWaveSelected = WaveExists(posw)
	ControlInfo/W=$pnlName existingC
	int isExistingReady = V_Value==1 && isWaveSelected

	ControlInfo/W=$pnlName newP
	int isModeSelected = V_Value!=1
	ControlInfo/W=$pnlName newC
	int isNewReady = V_Value==1 && isModeSelected

	int hasTab = strlen(ChildWindowList(pnlName))

	Button startB disable=(!(isExistingReady || isNewReady) || hasTab)*2, win=$pnlName
	Button finishB disable=!hasTab*2, win=$pnlName
	ModifyControlList "posG;existingC;existingP;newC;newP" disable=hasTab*2, win=$pnlName
End
