#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= SIDAMSyncAxisRange

#include "SIDAM_Help"
#include "SIDAM_Sync"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SYNCKEY = "syncaxisrange"

//@
//	Synchronize the axis range of windows.
//
//	## Parameters
//	syncWinList : string
//		The list of windows to be synchronized. If a window(s) that is
//		not synchronized, it is synchronized with the remaining windows.
//		If all the windows are synchronized, stop synchronization.
//@
Function SIDAMSyncAxisRange(String syncWinList)

	STRUCT paramStruct s
	s.list = syncWinList
	if (validate(s))
		print s.errMsg
		return 1
	endif

	String fn = "SIDAMSyncAxisRange#hook"
	String data = "list:" + s.list
	SIDAMSync#set(SYNCKEY, fn, data)
	doSync(StringFromList(ItemsInList(s.list)-1, s.list))

	if (SIDAMSync#calledFromPnl())
		printf "%s%s(\"%s\")\r", PRESTR_CMD, GetRTStackInfo(1), s.list
	endif

	return 0
End

Static Function validate(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "SIDAMSyncAxisRange gave error: "
	
	int i, n = ItemsInList(s.list)
	for (i = 0; i < n; i++)
		String grfName = StringFromList(i, s.list)
		if (!SIDAMWindowExists(grfName))
			s.errMsg += "the window list contains a window not found."
			return 1
		endif
		String tName = StringFromList(0, ImageNameList(grfName, ";"))
		if (!strlen(tName))
			tName = StringFromList(0, TraceNameList(grfName, ";", 1))
		endif
		if (!strlen(tName))
			s.errMsg += "the window list contains an empty window."
			return 1
		endif
	endfor
	
	return 0
End

Static Structure paramStruct
	String list
	String errMsg
EndStructure

Static Function menuDo()
	pnl(WinName(0,1))
End


Static Function hook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 0: 	//	activate
			//	In case a window(s) in the list had been closed before compiling
			SIDAMSync#updateList(s.winName, SYNCKEY)
			break
			
		case 2:		//	kill:
			SIDAMSync#reset(s.winName, SYNCKEY)
			break
			
		case 8:		//	modified
			//	In case a window(s) in the list had been closed before compiling
			SIDAMSync#updateList(s.winName, SYNCKEY)
			doSync(s.winName)
			break
			
		case 13:		//	renamed
			SIDAMSync#updateList(s.winName, SYNCKEY, oldName=s.oldWinName)
			break
	endswitch
	return 0
End

Static Function doSync(String grfName)
	STRUCT SIDAMAxisRange axis0
	SIDAMGetAxis(grfName, topName(grfName), axis0)

	STRUCT SIDAMAxisRange axis1
	String win, list = SIDAMSync#getList(grfName, SYNCKEY), fnName

	int i, n = ItemsInList(list)
	for (i = 0; i < n; i++)
		win = StringFromList(i,list)
		SIDAMGetAxis(win, topName(win), axis1)
		//	This is necessary to prevent a loop caused by mutual calling
		if (axis0.x.min.value == axis1.x.min.value && axis0.x.max.value == axis1.x.max.value \
			&& axis0.y.min.value == axis1.y.min.value && axis0.y.max.value == axis1.y.max.value)
				continue
		endif
		fnName = SIDAMSync#pause(win, SYNCKEY)
		SetAxis/W=$win $axis1.xaxis axis0.x.min.value, axis0.x.max.value
		SetAxis/W=$win $axis1.yaxis axis0.y.min.value, axis0.y.max.value
		SIDAMSync#resume(win, SYNCKEY, fnName)
	endfor
End

//	Return the name of top image, or top trace
Static Function/S topName(String grfName)
	String name =  StringFromList(0, ImageNameList(grfName, ";"))
	if (strlen(name))
		return name
	else
		return StringFromList(0, TraceNameList(grfName, ";", 1))
	endif
End

Static Function pnl(String grfName)
	String pnlName = grfName + "#syncaxisrange"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,282,235)/N=syncaxisrange as "Syncronize Axis Range"
	
	String dfTmp = SIDAMSync#pnlInit(pnlName, SYNCKEY)
	
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	ListBox winL pos={5,12}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+SIDAM_WAVE_LIST), win=$pnlName 
	ListBox winL selWave=$(dfTmp+SIDAM_WAVE_SELECTED), win=$pnlName
	ListBox winL colorWave=$(dfTmp+SIDAM_WAVE_COLOR), win=$pnlName
			
	Button selectB title="Select / Deselect all", size={130,18}, win=$pnlName
	Button selectB pos={10,171}, proc=SIDAMSync#pnlButton, win=$pnlName
	Button doB title="Do It", pos={10,203}, win=$pnlName
	Button doB disable=(DimSize($(dfTmp+SIDAM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=SYNCKEY, userData(fn)="SIDAMSyncAxisRange", win=$pnlName
	Button cancelB title="Cancel", pos={205,203}, win=$pnlName
	ModifyControlList "doB;cancelB", size={70,20}, proc=SIDAMSync#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	SIDAMApplyHelp(pnlName, "[SIDAM_SyncAxisRange]")

	SetActiveSubwindow $grfName
End
