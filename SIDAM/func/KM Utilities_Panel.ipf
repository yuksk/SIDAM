#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	KMNewPanel
//		自動位置調節機能つきパネル表示
//******************************************************************************
Function/S KMNewPanel(title,width,height,[float,nofixed,kill])
	String title
	Variable width, height
	Variable float, nofixed, kill
	
	float = (ParamIsDefault(float) || !float) ? 0 : 1
	nofixed = (ParamIsDefault(nofixed) || !nofixed) ? 0 : 1
	kill = ParamIsDefault(kill) ? 1 : kill
	
	String screenStr = StringFromList(2,StringByKey("SCREEN1",IgorInfo(0)),"=")
	Variable screenL = str2num(StringFromList(0,screenStr,","))	//  画面の位置; 左
	Variable screenT = str2num(StringFromList(1,screenStr,","))	//  画面の位置; 上
	Variable screenR = str2num(StringFromList(2,screenStr,","))	//  画面の位置; 右
	Variable screenB = str2num(StringFromList(3,screenStr,","))	//  画面の位置; 下
	
	Variable panelL = (screenR-screenL)/2-width/2		//  パネルの位置; 左
	Variable panelT = (screenB-screenT)/2-height		//  パネルの位置; 上
	Variable panelR = panelL+width						//  パネルの位置; 右
	Variable panelB = panelT+height						//  パネルの位置; 下
	
	NewPanel/FLT=(float)/K=(kill)/W=(panelL, panelT, panelR, panelB) as title
	String pnlName = S_name
	if (float)
		SetActiveSubwindow _endfloat_
	endif
	if (!nofixed)
		ModifyPanel/W=$pnlName fixedSize=1
	endif
	
	KillStrings/Z S_name
	return pnlName
End


//******************************************************************************
//	KMWindowExists
//		pnlNameが存在するかどうかを確認する。DoWindowがサブパネルには使えないので拡張した。
//******************************************************************************
Function KMWindowExists(String pnlName)
	
	//	childwindow でなければ単純に DoWindow を実行して終わり
	if (strsearch(pnlName, "#", 0) == -1)
		DoWindow $pnlName	//	# を含む場合にはここでエラーが出るので上記の場合分けが必要
		return V_flag
	else
		String hostName = RemoveEnding(ParseFilePath(1,pnlName,"#",1,0),"#")		//	最後についている # を除く
		String subName = ParseFilePath(0,pnlName,"#",1,0)
		String listStr = ChildWindowList(hostName)
		if (ItemsInList(listStr))
			return WhichListItem(subName, listStr) != -1
		else
			return 0
		endif
	endif
	
End


//******************************************************************************
//	KMRemoveAll
//		グラフ名grfName(graph/panel)から全てのトレース・イメージを削除します。
//		KMKillTmpDfの前に実行することが必要になることがあります。
//		df を指定した場合には、トレース・イメージの元ウエーブがデータフォルダ df 内にある場合だけ
//		トレース・イメージを削除する
//******************************************************************************
Function KMRemoveAll(String grfName,[String df])
	
	if (ParamIsDefault(df) || !strlen(df))
		df = ""
	elseif (!DataFolderExists(df))
		print PRESTR_CAUTION + "KMRemoveAll gave error: datafolder is not found."
		return 1
	endif
	
	int i, n
	
	String cwList = ChildWindowList(grfName)
	if (strlen(cwList))	//	childwindowを持っているならば
		for (i = 0, n = ItemsInList(cwList); i < n; i++)
			KMRemoveAll(grfName+"#"+StringFromList(i,cwList),df=df)	//	再帰的に実行
		endfor
	elseif (WinType(grfName) != 1)	//	childwindowを持っておらず、graphでもなければ
		return 1
	endif
	
	//  トレース除去
	String listStr = TraceNameList(grfName,";",1)
	Variable NumOfItems = ItemsInList(listStr)
	if (NumOfItems)
		for (i = NumOfItems-1; i >= 0; i--)
			if (strlen(df) && !stringmatch(GetWavesDataFolder(TraceNameToWaveRef(grfName,StringFromList(i,listStr)),1),df))
				continue
			endif
			RemoveFromGraph/W=$grfName $StringFromList(i,listStr)
		endfor
	endif
	
	//  イメージ除去
	listStr = ImageNameList(grfName,";")
	NumOfItems = ItemsInList(listStr)
	if (NumOfItems)
		for (i = NumOfItems-1; i >= 0; i--)
			if (strlen(df) && !stringmatch(GetWavesDataFolder(ImageNameToWaveRef(grfName,StringFromList(i,listStr)),1),df))
				continue
			endif
			RemoveImage/W=$grfName $StringFromList(i,listStr)
		endfor
	endif
	
	return 0
End


//******************************************************************************
//	KMonClosePnl
//		パネルを閉じる際の処理
//******************************************************************************
Function KMonClosePnl(String pnlName, [String df])
	
	//	トレース・イメージの削除
	if (ParamIsDefault(df))
		KMRemoveAll(pnlName)
	else
		KMRemoveAll(pnlName, df=df)
	endif
	
	//	一時データフォルダの削除
	KMonClosePnlKillDF($GetUserData(pnlName, "", "dfTmp"))
End
//-------------------------------------------------------------
//	KMonClosePnlKillDF
//		一時データフォルダの削除
//		KMLayerViewerPnlHookBackCompでも使用されているのStatic解除
//-------------------------------------------------------------
Function KMonClosePnlKillDF(DFREF dfr)
	//	dfr が無効
	//	dfr は子フォルダを含む
	//	dfr は root である
	if (!DataFolderRefStatus(dfr) || CountObjectsDFR(dfr,4) || DataFolderRefsEqual(dfr, root:))
		return 1
	endif
	
	//	dfr を削除した後で、dfr の親フォルダに対して再帰的に実行する
	KMonClosePnlKillDependence(dfr)
	DFREF pdfr = $ParseFilePath(1, GetDataFolder(1,dfr), ":", 1, 0)
	KillDataFolder dfr
	KMonClosePnlKillDF(pdfr)
End
//-------------------------------------------------------------
//	KMonClosePnlKillDependence
//		データフォルダdf内にあるウエーブ・変数についての従属関係を消去する
//-------------------------------------------------------------
Static Function KMonClosePnlKillDependence(DFREF dfr)
	int type, i, n
	for (type = 1; type <= 3; type++)
		for (i = 0, n = CountObjectsDFR(dfr, type); i < n; i++)
			SetFormula dfr:$GetIndexedObjNameDFR(dfr, type, i), ""
		endfor
	endfor
End
//******************************************************************************
//	KMClosePnl:	多いパターンのショートカット
//******************************************************************************
Function KMClosePnl(STRUCT WMWinHookStruct &s)
	if (s.eventCode == 17)	//	killVote
		KMonClosePnl(s.winName)
	elseif ((s.eventCode == 11 && s.keycode == 27))	//	esc
		KMonClosePnl(s.winName)
		KillWindow $s.winName
	endif
	return 0
End


//******************************************************************************
//	KMWaveSelector:	シンプルなウエーブ選択パネルを表示する
//******************************************************************************
Function KMWaveSelector(String title, String listStr, [String grfName])
	
	int doButtonDisable = 0
	if (!strlen(listStr))
		listStr = "_none_"
		doButtonDisable = 2
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	Variable/G popNum = 0	//	パネルからの入力を受け取るための変数
	
	String pnlName = KMNewPanel(title, 350, 74)
	PopupMenu waveP title="Select a wave:", pos={9,11}, size={329,20}, bodyWidth=250, value=#("\""+listStr+"\""), mode=1, win=$pnlName
	Button doB title="Do It", pos={13,44}, size={70,20}, disable=doButtonDisable, proc=KMWaveSelectorButton, win=$pnlName
	Button cancelB title="Cancel", pos={266,44}, size={70,20}, proc=KMWaveSelectorButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName) focusRing=0, win=$pnlName
	
	if (!ParamIsDefault(grfName))
		AutoPositionWindow/E/M=0/R=$grfName $pnlName
	endif
	
	PauseForUser $pnlName	//	ユーザーからの入力を待つ
	
	Variable rtn = popNum	//	フリーデータフォルダを出る前に入力内容を受け渡す
	SetDataFolder dfrSav
	
	return rtn
End

Function KMWaveSelectorButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			NVAR/Z popNum
			ControlInfo/W=$s.win waveP
			popNum = V_Value
			//*** THROUGH ***
		case "cancelB":
			KillWindow $s.win
			break
	endswitch
End


//******************************************************************************
//	KMPanelSelectionSet
//	KMPanelSelectionReset
//		grfName をクリック(mouseup)したら callback(grfName, pnlName) を呼び出すようにする関数と、それを解除する関数
//		KMSyncLayerなどで使用される
//		callback は pnlName に保存される
//		grfName を閉じても callback を呼び出す発火点がなくなるだけであるが、
//		pnlName を閉じた場合には、pnlNameのcallbackを呼び出すことになっているgrfNameから
//		設定を削除する
//******************************************************************************
Function KMPanelSelectionSet(String grfName, String pnlName, String callback)
	SetWindow $grfName userData(KMPanelSelection) = pnlName
	SetWindow $grfName hook(KMPanelSelection) = KMPanelSelectionHook
	SetWindow $pnlName userData(KMPanelSelection) = callback
	SetWindow $pnlName hook(KMPanelSelection) = KMPanelSelectionHook2
End

Function KMPanelSelectionReset(String grfName)
	SetWindow $grfName userData(KMPanelSelection)=""
	SetWindow $grfName hook(KMPanelSelection)=$""
End

Function KMPanelSelectionHook(STRUCT WMWinHookStruct &s)
	if (s.eventCode == 5) 	//	mouseup
		String pnlName = GetUserData(s.winName, "", "KMPanelSelection")
		FUNCREF KMPanelSelectionProto fn = $GetUserData(pnlName, "", "KMPanelSelection")
		fn(s.winName, pnlName)
	endif
	return 0
End

Function KMPanelSelectionHook2(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 2 && s.eventCode != 17)	//	neither kill nor killvote
		return 0
	endif
	
	String grfName, list = WinList("*",";","WIN:1")
	int i, n
	
	for (i = 0, n = ItemsInList(list); i < n; i++)
		grfName = StringFromList(i,list)
		if (!CmpStr(GetUserData(grfName,"","KMPanelSelection"), s.winName))
			KMPanelSelectionReset(grfName)
		endif
	endfor
	return 0
End

Function KMPanelSelectionProto(String grfName, String pnlName)
End