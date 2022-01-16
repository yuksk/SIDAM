#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSync

#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif


Static Function set(
	String key,	//	sync, syncaxisrange, synccursor
	String fn,	//	name of hook function
	String data,	//	key1:value1,key2:value2,...
					//	"," is used as the separator string because the value can
					//	contain ";".
					//	When the key is "list", the value is a window list.
					//	When the key is "mode", the value is the mode of synccursormode
	[FUNCREF SIDAMSyncproto call]		//	This is used to put a cursor, at present.
	)
	
	String syncWinList = StringByKey("list",data,":",",")
	int cursorsync = !CmpStr(key, "synccursor")
	int cursormode = NumberByKey("mode", data, ":",",")
	
	String win, str
	int i, n = ItemsInList(syncWinList)
	
	//	Set or reset synchronization
	int set = 0
	for (i = 0; i < n; i++)
		win = StringFromList(i, syncWinList)
		str = GetUserData(win,"",key)
		//	Do synchronise if the window list contains a window that is
		//	not yet synchronized,	
		if (!strlen(str))
			set = 1
			break
		endif
		//	Do synchronise if the mode of cursor sync is different
		if (cursorsync && (NumberByKey("mode",str,":",",") != cursormode))
			set = 1
			break
		endif
	endfor
	
	if (set)
		for (i = 0; i < n; i++)
			win = StringFromList(i, syncWinList)
			SetWindow $win, hook($key) = $fn
			SetWindow $win, userData($key) = data
			if (!paramIsDefault(call))
				call(win,key)
			endif
		endfor
	else
		for (i = 0; i < n; i++)
			reset(StringFromList(i, syncWinList), key)
		endfor
	endif
End

Function SIDAMSyncproto(String win, String key)
End

Static Function reset(String grfName, String key)
	//	new list not including the grfName
	String newList = getList(grfName, key)
	
	SetWindow $grfName, hook($key)=$""
	SetWindow $grfName, userData($key)=""
		
	if (ItemsInList(newList) > 1)	
		//	Update the list of the remaining windows
		setList(newList,key)
	else
		SetWindow $StringFromList(0, newList), hook($key)=$""
		SetWindow $StringFromList(0, newList), userData($key)=""
	endif
End

Static Function/S getList(String grfName, String key, [int all])
	//	Set !0 to all to include all windows including the grfName
	all = ParamIsDefault(all) ? 0 : all
	
	String dataStr = GetUserData(grfName,"",key)
	String listStr = StringByKey("list",dataStr,":",",")
	
	return SelectString(all,RemoveFromList(grfName, listStr),listStr)
End

Static Function updateList(String grfName, String key, [String oldName])
	String listStr = getList(grfName,key,all=1)
	int i, changed = 0
	
	//	Update the list when the name of window is changed
	if (!ParamIsDefault(oldName))
		listStr = ReplaceString(oldName, listStr, grfName)
		changed = 1
	endif
	
	//	Add the window to the list when the window is duplicate
	//	because it is not included in the list
	if (WhichListItem(grfName, listStr) == -1)
		listStr += grfName + ";"
		changed = 1
	endif
	
	//	Remove closed windows from the list
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		if (!SIDAMWindowExists(StringFromList(i, listStr)))
			listStr = RemoveListItem(i, listStr)
			changed = 1
		endif
	endfor
	
	if (changed)
		setList(listStr,key)
	endif	
End

Static Function setList(String listStr, String key)
	int i, n
	String grfName
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		grfName = StringFromList(i,listStr)
		SetWindow $grfName userData($key)=\
			ReplaceStringByKey("list",GetUserData(grfName,"",key),listStr,":",",")
	endfor
End

Static Function/S pause(String win, String key)
	GetWindow $win, hook($key)
	String fnName = S_Value
	SetWindow $win hook($key)=$""
	DoUpdate/W=$win
	return fnName
End

Static Function resume(String win, String key, String fnName)
	SetWindow $win hook($key)=$fnName
	DoUpdate/W=$win
End

//-------------------------------------------------------------
//	for panels
//-------------------------------------------------------------
//	The common part of panel
//	The key is either of sync, syncaxisrange, synccursor
Static Function/S pnlInit(String pnlName, String key)
	DFREF dfrSav = GetDataFolderDFR()
	String grfName = StringFromList(0, pnlName, "#")
	String dfTmp = SIDAMNewDF(grfName, key+"#"+GetRTStackInfo(2))
	SetDataFolder $dfTmp
	
	Make/N=0/T/O $SIDAM_WAVE_LIST/WAVE=lw, $"list_graph"/WAVE=lgw
	Make/B/U/N=(0,1,3)/O $SIDAM_WAVE_SELECTED/WAVE=sw
	SetDimLabel 2, 1, foreColors, sw
	SetDimLabel 2, 2, backColors, sw
	//	The colors are for (unused), foreground1, foreground2, background
	Make/W/U/N=1/O $SIDAM_WAVE_COLOR = {{0,0,0}, {0,0,0}, {40000,40000,40000}, {65535,65535,65535}}
	MatrixTranspose $SIDAM_WAVE_COLOR
	
	String win, list = pnlList(grfName, key)
	int i, n
	
	//	Constract the list box
	for (i = 0; i < ItemsInList(list); i++)
		win = StringFromList(i, list)
		n = DimSize(lw,0)
		Redimension/N=(n+1) lw, lgw
		Redimension/N=(n+1,1,3) sw
		GetWindow $win wtitle
		lw[n] = S_value+" ("+win+")"
		lgw[n] = win
		sw[n][0][0] = (strlen(GetUserData(win, "", key))) ? 0x30 : 0x20	//	checked or unchecked
	endfor
	//	colors
	sw[][][1] = n ? 1 : 2
	sw[][][2] = 3
	
	//	Select a window by activating it
	for (i = 0, n = ItemsInList(list); i < n; i += 1)
		pnlSelectionSet(StringFromList(i, list), pnlName, "SIDAMSync#grfActivate")
	endfor
	
	SetDataFolder dfrSav
	
	return dfTmp
End

//	Return a list of window
//	The key is either of sync, syncaxisrange, synccursor
Static Function/S pnlList(String grfName, String key)
	String listStr = WinList("*",";","WIN:1")
	int i
	
	//	Remove a window if the number of layers is different
	//	in the case of synclayer
	if (!CmpStr(key, "sync"))
		Wave srcw =  SIDAMImageWaveRef(grfName)
		for (i = ItemsInList(listStr)-1; i >= 0; i--)
			Wave/Z w = SIDAMImageWaveRef(StringFromList(i, listStr))
			if (WaveDims(w) != 3 || DimSize(srcw,2) != DimSize(w,2))
				listStr = RemoveListItem(i, listStr)
			endif
		endfor
	endif
	
	//	If the grfName is included in a group of sync, remove
	//	windows that are included in another group of sync.
	//	If the grfName is not included in a group of sync,
	//	remove windows that re included in a group of sync.
	//	In both cases, windows not included in any group of
	//	sync are listed.
	String syncList = getList(grfName, key, all=1)
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		String win = StringFromList(i, listStr)
		if (!ItemsInList(getList(win, key, all=1)))
			continue
		endif
		int inOtherGroup = WhichListItem(win, syncList) == -1
		if ((ItemsInList(syncList) && inOtherGroup) || !ItemsInList(syncList))
			listStr = RemoveListItem(i, listStr)
		endif
	endfor
	
	return listStr
End

//	Called when the grfName is activated
Static Function grfActivate(String grfName, String pnlName)
	ControlInfo/W=$pnlName winL
	DFREF dfrTmp = $S_DataFolder
	Wave/Z/T/SDFR=dfrTmp lgw = list_graph
	Wave/Z/SDFR=dfrTmp sw = $SIDAM_WAVE_SELECTED
	if (WaveExists(lgw) && WaveExists(sw))
		FindValue/TEXT=(grfName)/TXOP=2 lgw
		if (V_Value != -1)
			sw[V_Value][0][0] = (sw[V_Value][0][0] & 0x10) ? 0x20 : 0x30
		endif
	endif
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			String key = GetUserData(s.win, s.ctrlName, "key")
			String fn = GetUserData(s.win, s.ctrlName, "fn")
			pnlButtonDoSync(s.win, key, fn)
			//	*** FALLTHROUGH ***
		case "cancelB":
			KillWindow $s.win
			break
		case "selectB":
			ControlInfo/W=$s.win winL
			Wave/SDFR=$S_DataFolder sw = $SIDAM_WAVE_SELECTED
			Make/B/N=(DimSize(sw,0))/FREE tw = (sw[p][0][0]&(2^4)) / 2^4
			if (sum(tw))	//	at least one checkbox is selected
				sw[][0][0] = 2^5
			else
				sw[][0][0] = 2^5 + 2^4
			endif
			break
	endswitch
End

Static Function pnlButtonDoSync(
	String pnlName,
	String key,		//	sync, syncaxisrange, synccursor
	String fnStr		//	SIDAMSyncLayer, SIDAMSyncAxisRange, SIDAMSyncCursor
	)
	
	String win
	int i, n
	
	Variable cursorsync
	strswitch (fnStr)
		case "SIDAMSyncLayer":
		case "SIDAMSyncAxisRange":
			FUNCREF SIDAMSyncLayer fn0 = $fnStr
			cursorsync = 0
			break
		case "SIDAMSyncCursor":
			FUNCREF SIDAMSyncCursor fn1 = $fnStr
			cursorsync = 1
			ControlInfo/W=$pnlName xC
			Variable mode = V_Value
			break
	endswitch
	
	//	Make window lists
	ControlInfo/W=$pnlName winL
	Wave/SDFR=$S_DataFolder sw = $SIDAM_WAVE_SELECTED
	Wave/SDFR=$S_DataFolder/T lgw = list_graph
	String checkedList = "", resetList = ""
	for (i = 0, n = DimSize(sw,0); i < n; i++)
		if (sw[i][0][0] & 16)
			checkedList = AddListItem(lgw[i], checkedList)
		else
			resetList = AddListItem(lgw[i], resetList)
		endif
	endfor
	
	//	If a window not checked in the list has a sync list,
	//	remove the window from the synchronization.
	for (i = ItemsInList(resetList)-1; i >= 0; i--)
		win = StringFromList(i, resetList)
		if (!strlen(GetUserData(win, "", key)))
			resetList = RemoveListItem(i, resetList)
		endif
	endfor
	if (ItemsInList(resetList))
		if (cursorsync)
			fn1(resetList)
		else
			fn0(resetList)
		endif
	endif
	
	if (ItemsInList(checkedList) < 2)
		return 0
	endif
	
	//	If a checked window does not have a sync list, do synchronization.
	Variable doSync = 0
	for (i = 0, n = ItemsInList(checkedList); i < n; i++)
		win = StringFromList(i,checkedList)
		if (!strlen(GetUserData(win, "", key)))
			doSync = 1
			break
		elseif (cursorsync && mode != str2num(GetUserData(win, "", key+"mode")))
			//	change the cursor mode
			doSync = 1
			break
		endif
	endfor
	if (doSync)
		if (cursorsync)
			fn1(checkedList, mode=mode)
		else
			fn0(checkedList)
		endif
	endif
End

Static Function calledFromPnl()
	return WhichListItem("pnlButtonDoSync", GetRTStackInfo(0)) >= 0
End

//-------------------------------------------------------------
//	for selecting windows by click
//-------------------------------------------------------------
Static Function pnlSelectionSet(String grfName, String pnlName, String callback)
	//	Set a hook function to run callback(grfName, pnlName)
	//	by clicking the grfName
	SetWindow $grfName userData(SIDAMSyncPnlSelection) = pnlName
	SetWindow $grfName hook(SIDAMSyncPnlSelection) = SIDAMSync#pnlSelectionHookGrf
	SetWindow $pnlName userData(SIDAMSyncPnlSelection) = callback
	SetWindow $pnlName hook(SIDAMSyncPnlSelection) = SIDAMSync#pnlSelectionHookPnl
End

Static Function pnlSelectionReset(String grfName)
	SetWindow $grfName userData(SIDAMSyncPnlSelection)=""
	SetWindow $grfName hook(SIDAMSyncPnlSelection)=$""
End

Static Function pnlSelectionHookGrf(STRUCT WMWinHookStruct &s)
	if (s.eventCode == 5) 	//	mouseup
		String pnlName = GetUserData(s.winName, "", "SIDAMSyncPnlSelection")
		FUNCREF SIDAMSyncPnlSelectionProto fn = $GetUserData(pnlName, "", "SIDAMSyncPnlSelection")
		fn(s.winName, pnlName)
	endif
	return 0
End

Static Function pnlSelectionHookPnl(STRUCT WMWinHookStruct &s)
	int isKill = s.eventCode == 2
	int isKillVote = s.eventCode == 17
	int isEscPressed = s.eventCode == 11 && s.keycode == 27
	if (!isKill && !isKillVote && isEscPressed)	
		return 0
	endif
	
	String grfName, list = WinList("*",";","WIN:1")
	int i, n
	
	for (i = 0, n = ItemsInList(list); i < n; i++)
		grfName = StringFromList(i,list)
		if (!CmpStr(GetUserData(grfName,"","SIDAMSyncPnlSelection"), s.winName))
			pnlSelectionReset(grfName)
		endif
	endfor
	return 0
End

Function SIDAMSyncPnlSelectionProto(String grfName, String pnlName)
End
