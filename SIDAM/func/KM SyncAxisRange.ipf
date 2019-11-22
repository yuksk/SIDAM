#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMSyncAxisRange

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant ks_key = "syncaxisrange"

//******************************************************************************
//	軸範囲同期
//******************************************************************************
Function KMSyncAxisRange(
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
	
	String fn = "KMSyncAxisRange#hook"
	String data = "list:" + s.list
	KMSyncCommon#common(ks_key, fn, data)
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history)
		printf "%sKMSyncAxisRange(\"%s\")\r", PRESTR_CMD, s.list
	endif
	
	return 0
End
//-------------------------------------------------------------
//	チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMSyncAxisRange gave error: "
	
	int i, n = ItemsInList(s.list)
	for (i = 0; i < n; i++)
		String grfName = StringFromList(i, s.list)
		if (!SIDAMWindowExists(grfName))
			s.errMsg += "the window list contains a window not found."
			return 0
		endif
		String tName = StringFromList(0, ImageNameList(grfName, ";"))
		if (!strlen(tName))
			tName = StringFromList(0, TraceNameList(grfName, ";", 1))
		endif
		if (!strlen(tName))
			s.errMsg += "the window list contains an empty window."
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
			if (strlen(GetRTStackInfo(2)))	//	他のフック関数からの呼び出しでは動作しないようにする
				break
			elseif (KMSyncCommon#isBlocked(s.winName, ks_key))
				KMSyncCommon#releaseBlock(s.winName, ks_key)
				break
			endif
			STRUCT SIDAMAxisRange axis0 ;	SIDAMGetAxis(s.winName, topName(s.winName), axis0)
			STRUCT SIDAMAxisRange axis1
			String win, list = KMSyncCommon#getSyncList(s.winName, ks_key)
			int i, n = ItemsInList(list)
			for (i = 0; i < n; i++)
				win = StringFromList(i,list)
				SIDAMGetAxis(win, topName(win), axis1)
				KMSyncCommon#setBlock(win, ks_key)	//	循環動作を防ぐため
				SetAxis/W=$win $axis1.xaxis axis0.xmin, axis0.xmax
				KMSyncCommon#setBlock(win, ks_key)	//	循環動作を防ぐため
				SetAxis/W=$win $axis1.yaxis axis0.ymin, axis0.ymax
				DoUpdate/W=$win
			endfor
			break
			
		case 13:		//	renamed
			KMSyncCommon#renewSyncList(s.winName, ks_key, oldName=s.oldWinName)
			break
	endswitch
	return 0
End
//	0番イメージの名前、ない場合には0番トレースの名前
Static Function/S topName(String grfName)
	String name =  StringFromList(0, ImageNameList(grfName, ";"))
	if (strlen(name))
		return name
	else
		return StringFromList(0, TraceNameList(grfName, ";", 1))
	endif
End

//******************************************************************************
//	同期をとるグラフを選択するためのパネル
//******************************************************************************
Static Function pnl(String grfName)
	//	パネル表示
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,282,255) as "Syncronize Axis Range"
	RenameWindow $grfName#$S_name, syncaxisrange
	String pnlName = grfName + "#syncaxisrange"
	
	String dfTmp = KMSyncCommon#pnlInit(pnlName, ks_key)
	
	//	フック関数
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	//	各要素
	ListBox winL pos={5,12}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+KM_WAVE_LIST), selWave=$(dfTmp+KM_WAVE_SELECTED), colorWave=$(dfTmp+KM_WAVE_COLOR), win=$pnlName
	
	Button selectB title="Select / Deselect all", pos={10,172}, size={120,22}, proc=KMSyncCommon#pnlButton, win=$pnlName
	Titlebox selectT title="You can also select a window by clicking it.", pos={10,200}, frame=0, fColor=(21760,21760,21760), win=$pnlName
	Button doB title="Do It", pos={10,228}, size={70,22}, disable=(DimSize($(dfTmp+KM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=ks_key, userData(fn)="KMSyncAxisRange", proc=KMSyncCommon#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={201,228}, size={70,22}, proc=KMSyncCommon#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End
