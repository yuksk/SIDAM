#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSyncLayer

#include "SIDAM_Help"
#include "SIDAM_Sync"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SYNCKEY = "sync"

//@
//	Synchronize the layer shown in windows.
//
//	## Parameters
//	syncWinList : string
//		The list of windows to be synchronized. If a window(s) that is
//		not synchronized, it is synchronized with the remaining windows.
//		If all the windows are synchronized, stop synchronization.
//@
Function SIDAMSyncLayer(String syncWinList)

	STRUCT paramStruct s
	s.list = syncWinList
	if (validate(s))
		print s.errMsg
		return 1
	endif

	String fn = "SIDAMSyncLayer#hook"
	String data = "list:" + s.list
	SIDAMSync#set(SYNCKEY, fn, data)
	doSync(StringFromList(ItemsInList(s.list)-1,s.list))

	if (SIDAMSync#calledFromPnl())
		printf "%s%s(\"%s\")\r", PRESTR_CMD, GetRTStackInfo(1), s.list
	endif

	return 0
End

Static Function validate(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "SIDAMSyncLayer gave error: "
	
	int i, n = ItemsInList(s.list)
	String grfName
	
	if (n < 2)
		GetWindow $StringFromList(0,s.list), hook($SYNCKEY)
		if(!strlen(S_Value))
			s.errMsg += "the window list must contain 2 windows or more."
			return 1
		endif
	endif
	
	for (i = 0; i < n; i++)
		grfName = StringFromList(i, s.list)
		if (!SIDAMWindowExists(grfName))
			s.errMsg += "the window list contains a window not found."
			return 1
		endif
		Wave/Z w = SIDAMImageNameToWaveRef(grfName)
		if (!WaveExists(w) || WaveDims(w)!=3)
			s.errMsg += "the window list must contain only LayerViewer."
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
	String win, list = SIDAMSync#getList(grfName, SYNCKEY), fnName

	int i, n = ItemsInList(list), plane = SIDAMGetLayerIndex(grfName)
	for (i = 0; i < n; i++)
		win = StringFromList(i, list)
		//	This is necessary to prevent a loop caused by mutual calling
		if (plane == SIDAMGetLayerIndex(win))
			continue
		endif
		fnName = SIDAMSync#pause(win, SYNCKEY)
		SIDAMSetLayerIndex(win, plane)
		SIDAMSync#resume(win, SYNCKEY, fnName)
	endfor
End

Static Function pnl(String LVName)
	String pnlName = LVName + "#synclayer"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif	
	NewPanel/HOST=$LVName/EXT=0/W=(0,0,282,235)/N=synclayer as "Syncronize Layers"
	
	String dfTmp = SIDAMSync#pnlInit(pnlName, SYNCKEY)
	
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	ListBox winL pos={5,12}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+SIDAM_WAVE_LIST), win=$pnlName
	ListBox winL selWave=$(dfTmp+SIDAM_WAVE_SELECTED), win=$pnlName
	ListBox winL colorWave=$(dfTmp+SIDAM_WAVE_COLOR), win=$pnlName
	SIDAMAPPlyHelpStrings(pnlName, "winL", "Select windows you want to "\
		+ "synchronize layers. You can also select a window by clicking "\
		+ "an actual window. 3D waves with the same number of layers are "\
		+ "listed here.")
	
	Button selectB title="Select / Deselect all", size={130,18}, win=$pnlName
	Button selectB pos={10,171}, proc=SIDAMSync#pnlButton, win=$pnlName
	Button doB title="Do It", pos={10,203}, win=$pnlName
	Button doB disable=(DimSize($(dfTmp+SIDAM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=SYNCKEY, userData(fn)="SIDAMSyncLayer", win=$pnlName
	Button cancelB title="Cancel", pos={205,203}, win=$pnlName
	ModifyControlList "doB;cancelB", size={70,20}, proc=SIDAMSync#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	SetActiveSubwindow $LVName
End
