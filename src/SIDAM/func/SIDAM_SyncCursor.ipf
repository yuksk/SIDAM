#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSyncCursor

#include "SIDAM_Help"
#include "SIDAM_Sync"
#include "SIDAM_Utilities_Cursor"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SYNCKEY = "synccursor"

//@
//	Synchronize the cursor position of windows.
//
//	## Parameters
//	syncWinList : string
//		The list of windows to be synchronized. If a window(s) that is
//		not synchronized, it is synchronized with the remaining windows.
//		If all the windows are synchronized, stop synchronization.
//	mode : int {0, 1}
//		0 to synchronize in p and q, 1 to synchronize in x and y.
//@
Function SIDAMSyncCursor(String syncWinList, [int mode])
	
	STRUCT paramStruct s
	s.mode = ParamIsDefault(mode) ? 0 : mode
	s.list = syncWinList
	
	if (validate(s))
		print s.errMsg
		return 1
	endif
	
	String fn = "SIDAMSyncCursor#hook"
	String data = "list:" + s.list + ",mode:" + num2str(mode)
	SIDAMSync#set(SYNCKEY, fn, data, call=$"SIDAMSyncCursor#putCursor")

	if (SIDAMSync#calledFromPnl())
		printf "%s%s(\"%s\"%s)\r", PRESTR_CMD, GetRTStackInfo(1), s.list, SelectString(mode, "", ", mode=1")
	endif
	
	return 0
End

Static Function validate(STRUCT paramStruct &s)
		
	s.errMsg = PRESTR_CAUTION + "SIDAMSyncCursor gave error: "
	
	if (s.mode != 0 && s.mode != 1)
		s.errMsg += "mode must be 0 or 1."
		return 1
	endif
	
	int i, n = ItemsInList(s.list)
	if (n < 2)
		s.errMsg += "syncWinList must contain two graphs or more."
		return 1
	endif
	
	for (i = 0; i < n; i++)
		if (!SIDAMWindowExists(StringFromList(i,s.list)))
			s.errMsg += "\"" + StringFromList(i,s.list) + "\" is not found."
			return 1
		endif
	endfor
	
	return 0
End

Static Structure paramStruct
	String	errMsg
	char	mode
	String	list
EndStructure

Static Function/S menuItem()
	STRUCT paramStruct s
	s.list = WinList("*",";","WIN:1")
	s.mode = 0
	return SelectString(validate(s),"","(") + "Sync Cursors..."
End

Static Function menuDo()
	pnl(WinName(0,1))
End


Static Function hook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 0: 	//	activate
			//	In case a window(s) in the list had been closed before compiling
			SIDAMSync#updateList(s.winName, SYNCKEY)
			break
			
		case 2:	//	kill
			SIDAMSync#reset(s.winName, SYNCKEY+";"+SYNCKEY+"mode")
			break
			
		case 7:	//	cursormoved
			int noCursor = !strlen(CsrInfo($s.cursorName, s.winName))
			if (noCursor)
				SIDAMSync#reset(s.winName, SYNCKEY)
				break
			endif
			//	In case a window(s) in the list had been closed before compiling
			SIDAMSync#updateList(s.winName, SYNCKEY)
			
			STRUCT SIDAMCursorPos pos
			SIDAMGetCursor(s.cursorName, s.winName, pos)
			String win, syncWinList = SIDAMSync#getList(s.winName, SYNCKEY), fnName
			int mode = NumberByKey("mode",GetUserData(s.winName,"",SYNCKEY),":",",")	//	0: p, q,	1: x, y
			int i, n = ItemsInList(syncWinList)
			for (i = 0; i < n; i++)
				win = StringFromList(i, syncWinList)
				fnName = SIDAMSync#pause(win, SYNCKEY)
				SIDAMMoveCursor(s.cursorName, win, mode, pos)
				SIDAMSync#resume(win, SYNCKEY, fnName)
			endfor
			break
			
		case 13:		//	renamed
			SIDAMSync#updateList(s.winName, SYNCKEY, oldName=s.oldWinName)
			break
	endswitch
	return 0
End

//	Show a cursor unless shown
Static Function putCursor(String grfName, String key)
	if (strlen(CsrInfo(A, grfName)))
		return 0
	endif
	
	int mode = NumberByKey("mode", GetUserData(grfName, "", key), ":", ",")
	String imgList = ImageNameList(grfName, ";")
	if (strlen(imgList) && mode)
		Cursor/P/F/I/W=$grfName A $StringFromList(0, imgList) 0.5, 0.5
	elseif (strlen(imgList) && !mode)
		Cursor/P/I/W=$grfName A $StringFromList(0, imgList) 0, 0
	else
		Cursor/P/F/W=$grfName A $StringFromList(0, TraceNameList(grfName, ";", 1)) 0.5, 0.5
	endif
	return 1
End


Static Function pnl(String grfName)
	String pnlName = grfName + "#synccursor"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,282,255)/N=synccursor as "Synchronize cursors"
	
	String dfTmp = SIDAMSync#pnlInit(pnlName, SYNCKEY)
	
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	Variable mode = str2num(GetUserData(grfName, "", SYNCKEY+"mode"))
	mode = numtype(mode) ? 0 : mode
	TitleBox modeT title="mode", pos={6,8}, frame=0, win=$pnlName
	CheckBox pC title="p", pos={50,8}, value=!mode, win=$pnlName
	CheckBox xC title="x", pos={85,8}, value=mode, win=$pnlName
	ModifyControlList "pC;xC", mode=1, proc=SIDAMSyncCursor#pnlCheck, win=$pnlName
	SIDAMAPPlyHelpStrings(pnlName, "pC", "Put cursors at the same [p,q] in all windows.")
	SIDAMAPPlyHelpStrings(pnlName, "xC", "Put cursors at the same (x,y) in all windows.")

	ListBox winL pos={5,32}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+SIDAM_WAVE_LIST), win=$pnlName
	ListBox winL selWave=$(dfTmp+SIDAM_WAVE_SELECTED), win=$pnlName
	ListBox winL colorWave=$(dfTmp+SIDAM_WAVE_COLOR), win=$pnlName
	SIDAMAPPlyHelpStrings(pnlName, "winL", "Select windows you want to "\
		+ "synchronize cursors. You can also select a window by clicking "\
		+ "an actual window.")
	
	Button selectB title="Select / Deselect all", size={130,18}, win=$pnlName
	Button selectB pos={10,192}, proc=SIDAMSync#pnlButton, win=$pnlName
	Button doB title="Do It", pos={10,223}, win=$pnlName
	Button doB disable=(DimSize($(dfTmp+SIDAM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=SYNCKEY, userData(fn)="SIDAMSyncCursor", win=$pnlName
	Button cancelB title="Cancel", pos={201,223}, win=$pnlName
	ModifyControlList "doB;cancelB", size={70,20}, proc=SIDAMSync#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	SetActiveSubwindow $grfName
End

Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "pC":
			Checkbox xC value=0, win=$s.win
			break
		case "xC":
			CheckBox pC value=0, win=$s.win
			break
	endswitch
End

