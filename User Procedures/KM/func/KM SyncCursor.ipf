#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMSyncCursor

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Static StrConstant ks_key = "synccursor"

//******************************************************************************
//	KMSyncCursor
//		カーソル位置同期
//******************************************************************************
Function KMSyncCursor(syncWinList, [mode, history])
	String syncWinList	//	同期する/解除するウインドウのリスト
							//	1つでも現在は同期されていないウインドウがリストに含まれていたら、それを同期に含める
							//	リストに含まれる全てのウインドウが同期されていたら、リストのウインドウを同期から外す
	Variable mode		//	0: p, q,	1: x, y
	Variable history
	
	STRUCT paramStruct s
	s.mode = ParamIsDefault(mode) ? 0 : mode
	s.list = syncWinList
	
	if (!isValidArguments(s))
		print s.errMsg
		return 1
	endif
	
	String keyList = ks_key + ";" + ks_key + "mode"	
	String fn = ks_key + ":KMSyncCursor#hook"
	String data = ks_key + ":" + s.list + "&" + ks_key + "mode:" + num2str(mode)
	KMSyncCommon(s.list, keyList, fn, data)
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history)
		printf "%sKMSyncCursor(\"%s\"%s)\r", PRESTR_CMD, s.list, SelectString(mode, "", ", mode=1")
	endif
	
	return 0
End
//-------------------------------------------------------------
//	isValidArguments: 		チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
		
	s.errMsg = PRESTR_CAUTION + "KMSyncCursor gave error: "
	
	if (s.mode != 0 && s.mode != 1)
		s.errMsg += "mode must be 0 or 1."
		return 0
	endif
	
	int i, n = ItemsInList(s.list)
	if (n < 2)
		s.errMsg += "syncWinList must contain two graphs or more."
		return 0
	endif
	
	for (i = 0; i < n; i++)
		DoWindow $StringFromList(i,s.list)
		if (!V_Flag)
			s.errMsg += "\"" + StringFromList(i,s.list) + "\" is not found."
			return 0
		endif
	endfor
	
	return 1
End

Static Structure paramStruct
	String	errMsg
	char	mode
	String	list
EndStructure

//-------------------------------------------------------------
//	右クリックメニュー表示用
//-------------------------------------------------------------
Static Function/S rightclickMenu()
	STRUCT paramStruct s
	s.list = WinList("*",";","WIN:1")
	s.mode = 0
	return SelectString(isValidArguments(s),"(","") + "Sync Cursors..."
End

//-------------------------------------------------------------
//	右クリックメニューから実行される関数
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(WinName(0,1))
End

//-------------------------------------------------------------
//	同期を行うフック関数
//-------------------------------------------------------------
Static Function hook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			KMSyncCommonCancel(s.winName, ks_key+";"+ks_key+"mode")
			break
			
		case 7:	//	cursormoved
			if (!strlen(CsrInfo($s.cursorName, s.winName)))	//	カーソルがはずされた場合
				KMSyncCommonCancel(s.winName, ks_key+";"+ks_key+"mode")
				break
			endif
			
			STRUCT KMCursorPos pos ;	KMGetCursor(s.cursorName, s.winName, pos)
			String win, syncWinList = KMSyncCommonGetSyncList(s, ks_key)
			int i, n = ItemsInList(syncWinList)
			int syncMode = str2num(GetUserData(s.winName, "", ks_key+"mode"))	//	0: p, q,	1: x, y
			for (i = 0; i < n; i++)
				win = StringFromList(i, syncWinList)
				SetWindow $win hook($ks_key)=$""	//	循環動作を防ぐために、他のウインドウのフック関数を一度外す
				KMSetCursor(s.cursorName, win, syncMode, pos)
				SetWindow $win hook($ks_key)=KMSyncCursor#hook	//	外したフック関数を元に戻す
				DoUpdate/W=$win
			endfor
			break
			
		case 13:		//	renamed
			KMSyncCommonHookRenamed(s, ks_key)
			break
	endswitch
	return 0
End

//-------------------------------------------------------------
//	カーソルが表示されていなければ表示する. KMSyncCommonから呼ばれる
//-------------------------------------------------------------
Static Function putCursor(grfName)
	String grfName
	
	if (strlen(CsrInfo(A, grfName)))
		return 0
	elseif (strlen(ImageNameList(grfName, ";")))
		Cursor/P/F/I/W=$grfName A $StringFromList(0, ImageNameList(grfName, ";")) 0.5, 0.5
	else
		Cursor/P/F/W=$grfName A $StringFromList(0, TraceNameList(grfName, ";", 1)) 0.5, 0.5
	endif
	return 1
End

//******************************************************************************
//	pnl:	同期をとるグラフを選択するためのパネル
//******************************************************************************
Static Function pnl(String grfName)
	
	//	パネル表示
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,282,290) as "Synchronize cursors"
	RenameWindow $grfName#$S_name, synccursor
	String pnlName = grfName + "#synccursor"
	
	String dfTmp = KMSyncCommonPnlInit(pnlName, ks_key)
	
	//	フック関数
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	//	各要素
	Variable mode = str2num(GetUserData(grfName, "", ks_key+"mode"))
	mode = numtype(mode) ? 0 : mode
	DrawText 10,31,"mode"
	CheckBox pC title="p: put all cursors at [p,q]", pos={49,9}, mode=1, value=!mode, proc=KMSyncCursor#pnlCheck, win=$pnlName
	CheckBox xC title="x: put all cursors at (x,y)", pos={49,29}, mode=1, value=mode, proc=KMSyncCursor#pnlCheck, win=$pnlName
	
	ListBox winL pos={5,52}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+KM_WAVE_LIST), selWave=$(dfTmp+KM_WAVE_SELECTED), colorWave=$(dfTmp+KM_WAVE_COLOR), win=$pnlName
	
	Button selectB title="Select / Deselect all", pos={10,210}, size={120,20}, proc=KMSyncCommon#pnlButton, win=$pnlName
	Titlebox selectT title="You can also select a window by clicking it.", pos={10,240}, frame=0, fColor=(21760,21760,21760), win=$pnlName
	Button doB title="Do It", pos={10,263}, size={70,20}, disable=(DimSize($(dfTmp+KM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=ks_key, userData(fn)="KMSyncCursor", proc=KMSyncCommon#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={201,263}, size={70,20}, proc=KMSyncCommon#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
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


//******************************************************************************
//	後方互換性
Function KMSyncCursorMasterHook(STRUCT WMWinHookStruct &s)
	KMSyncCursorHookBwdComp(s)
End
Function KMSyncCursorSlaveHook(STRUCT WMWinHookStruct &s)
	KMSyncCursorHookBwdComp(s)
End
Static Function KMSyncCursorHookBwdComp(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName userData($ks_key) = GetUserData(s.winName, "", "csrsync")
	SetWindow $s.winName userData(csrsync)=""
	SetWindow $s.winName userData($(ks_key+"mode")) = GetUserData(s.winName, "", "csrsyncmode")
	SetWindow $s.winName userData(csrsyncmode)=""
	SetWindow $s.winName hook($ks_key)=KMSyncCursorHook
	SetWindow $s.winName hook(csrsync)=$""
End