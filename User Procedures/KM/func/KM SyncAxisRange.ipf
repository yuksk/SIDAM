#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMSyncAxisRange

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Static StrConstant ks_key = "syncaxisrange"

//******************************************************************************
//	KMSyncAxisRange
//		軸範囲同期
//******************************************************************************
Function KMSyncAxisRange(syncWinList,[history])
	String syncWinList	//	同期する/解除するウインドウのリスト
							//	1つでも現在は同期されていないウインドウがリストに含まれていたら、それを同期に含める
							//	リストに含まれる全てのウインドウが同期されていたら、リストのウインドウを同期から外す
	Variable history
	
	STRUCT paramStruct s
	s.list = syncWinList
	if (!isValidArguments(s))
		print s.errMsg
		return 1
	endif
	
	String fn = ks_key + ":KMSyncAxisRange#hook"
	String data = ks_key + ":" + s.list
	KMSyncCommon(s.list, ks_key, fn, data)
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history)
		printf "%sKMSyncAxisRange(\"%s\")\r", PRESTR_CMD, s.list
	endif
	
	return 0
End
//-------------------------------------------------------------
//	isValidArguments: 		チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMSyncAxisRange gave error: "
	
	int i, n = ItemsInList(s.list)
	for (i = 0; i < n; i++)
		String grfName = StringFromList(i, s.list)
		DoWindow $grfName
		if (!V_Flag)
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
//	hook:	同期を行うフック関数
//-------------------------------------------------------------
Static Function hook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:		//	kill:
			KMSyncCommonCancel(s.winName, ks_key)
			break
			
		case 8:		//	modified
			if (strlen(GetRTStackInfo(2)))	//	他のフック関数からの呼び出しでは動作しないようにする
				break
			endif
			STRUCT KMAxisRange axis0 ;	KMGetAxis(s.winName, topName(s.winName), axis0)
			STRUCT KMAxisRange axis1
			String win, list = KMSyncCommonGetSyncList(s, ks_key)
			int i, n = ItemsInList(list)
			for (i = 0; i < n; i++)
				win = StringFromList(i,list)
				SetWindow $win hook($ks_key)=$""	//	循環動作を防ぐために、他のウインドウのフック関数を一度外す
				KMGetAxis(win, topName(win), axis1)
				SetAxis/W=$win $axis1.xaxis axis0.xmin, axis0.xmax
				SetAxis/W=$win $axis1.yaxis axis0.ymin, axis0.ymax
				SetWindow $win hook($ks_key)=KMSyncAxisRange#hook	//	外したフック関数を元に戻す
				DoUpdate/W=$win
			endfor
			break
			
		case 13:		//	renamed
			KMSyncCommonHookRenamed(s, ks_key)
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
//	pnl:	同期をとるグラフを選択するためのパネル
//******************************************************************************
Static Function pnl(String grfName)
	
	//	パネル表示
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,282,250) as "Syncronize Axis Range"
	RenameWindow $grfName#$S_name, syncaxisrange
	String pnlName = grfName + "#syncaxisrange"
	
	String dfTmp = KMSyncCommonPnlInit(pnlName, ks_key)
	
	//	フック関数
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	//	各要素
	ListBox winL pos={5,12}, size={270,150}, frame=2, mode=4, win=$pnlName
	ListBox winL listWave=$(dfTmp+KM_WAVE_LIST), selWave=$(dfTmp+KM_WAVE_SELECTED), colorWave=$(dfTmp+KM_WAVE_COLOR), win=$pnlName

	Button selectB title="Select / Deselect all", pos={10,170}, size={120,20}, proc=KMSyncCommon#pnlButton, win=$pnlName
	Titlebox selectT title="You can also select a window by clicking it.", pos={10,200}, frame=0, fColor=(21760,21760,21760), win=$pnlName
	Button doB title="Do It", pos={10,223}, size={70,20}, disable=(DimSize($(dfTmp+KM_WAVE_SELECTED),0)==1)*2, win=$pnlName
	Button doB userData(key)=ks_key, userData(fn)="KMSyncAxisRange", proc=KMSyncCommon#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={201,223}, size={70,20}, proc=KMSyncCommon#pnlButton, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End
