#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = KMSyncLayer

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant ks_key = "sync"

//******************************************************************************
//	レイヤー同期
//******************************************************************************
Function KMSyncLayer(
	String syncWinList,	//	同期する/解除するウインドウのリスト
							//	1つでも現在は同期されていないウインドウがリストに含まれていたら、それを同期に含める
							//	リストに含まれる全てのウインドウが同期されていたら、リストのウインドウを同期から外す
	[
		int history
	])
	
	STRUCT paramStruct s
	s.list = syncWinList
	if (!isValidArguments(s))
		print s.errMsg
		return 1
	endif
	
	String fn = "KMSyncLayer#hook"
	String data = "list:" + s.list
	KMSyncCommon#common(ks_key, fn, data)
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history)
		printf "%sKMSyncLayer(\"%s\")\r", PRESTR_CMD, s.list
	endif
	
	return 0
End
//-------------------------------------------------------------
//	チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMSyncLayer gave error: "
	
	int i, n = ItemsInList(s.list)
	String grfName
	
	if (n < 2)
		GetWindow $StringFromList(0,s.list), hook($ks_key)
		if(!strlen(S_Value))
			s.errMsg += "the window list must contain 2 windows or more."
			return 0
		endif
	endif
	
	for (i = 0; i < n; i++)
		grfName = StringFromList(i, s.list)
		if (!SIDAMWindowExists(grfName))
			s.errMsg += "the window list contains a window not found."
			return 0
		endif
		Wave/Z w = SIDAMImageWaveRef(grfName)
		if (!WaveExists(w) || WaveDims(w)!=3)
			s.errMsg += "the window list must contain only LayerViewer."
			return 0
		endif
	endfor
	
	return 1
End

Static Structure paramStruct
	String list
	String errMsg
EndStructure

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
		case 2:		//	kill:
			KMSyncCommon#resetSync(s.winName, ks_key)
			break
			
		case 8:		//	modified
			if (strlen(GetRTStackInfo(2)))	//	他のフック関数からの呼び出し(AxisやRangeなど)では動作しないようにする
				break
			elseif (KMSyncCommon#isBlocked(s.winName, ks_key))
				KMSyncCommon#releaseBlock(s.winName, ks_key)
				break
			endif
			String win, list = KMSyncCommon#getSyncList(s.winName, ks_key)
			int i, n = ItemsInList(list), plane = KMLayerViewerDo(s.winName)
			for (i = 0; i < n; i++)
				win = StringFromList(i, list)
				KMSyncCommon#setBlock(win, ks_key)	//	循環動作を防ぐため
				KMLayerViewerDo(win, index=plane)
				DoUpdate/W=$win
			endfor
			break
			
		case 13:		//	renamed
			KMSyncCommon#renewSyncList(s.winName, ks_key, oldName=s.oldWinName)
			break
	endswitch
	return 0
End

//******************************************************************************
//	同期をとるグラフを選択するためのパネル
//******************************************************************************
Static Function pnl(String LVName)
	
	//	パネル表示
	NewPanel/HOST=$LVName/EXT=0/W=(0,0,282,255) as "Syncronize Layers"
	RenameWindow $LVName#$S_name, synclayer
	String pnlName = LVName + "#synclayer"
	
	String dfTmp = KMSyncCommon#pnlInit(pnlName, ks_key)
	
	//	フック関数
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	//	各要素
	ListBox winL pos={5,12}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+KM_WAVE_LIST), selWave=$(dfTmp+KM_WAVE_SELECTED), colorWave=$(dfTmp+KM_WAVE_COLOR), win=$pnlName
	
	Button selectB title="Select / Deselect all", pos={10,172}, size={130,22}, proc=KMSyncCommon#pnlButton, win=$pnlName
	Titlebox selectT title="You can also select a window by clicking it.", pos={10,200}, frame=0, fColor=(21760,21760,21760), win=$pnlName
	Button doB title="Do It", pos={10,228}, disable=(DimSize($(dfTmp+KM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=ks_key, userData(fn)="KMSyncLayer", win=$pnlName
	Button cancelB title="Cancel", pos={201,228}, win=$pnlName
	ModifyControlList "doB;cancelB", size={70,22}, proc=KMSyncCommon#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	後方互換性
Function KMSyncLayerMasterHook(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName hook(sync)=KMSyncLayer#hook
End
Function KMSyncLayerSlaveHook(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName userData(sync)=GetUserData(GetUserData(s.winName, "", "sync"), "", "sync")
	SetWindow $s.winName hook(sync)=KMSyncLayer#hook
End
