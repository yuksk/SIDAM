#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMSyncCommon

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	KMSyncLayer, KMSyncAxisRange, KMSyncCursor で共通に使われる関数
//******************************************************************************
Function KMSyncCommon(syncWinList, keyList, fn, data)
	String syncWinList	//	同期されるウインドウのリスト
	String keyList	//	key0;key1;...
						//	key0 は sync, syncaxisrange, synccursor
						//	synccursor の際には key1 = synccursormode が使用される
	String fn		//	key:value 形式のリスト
					//	key は sync, syncaxisrange, synccursor
					//	value は　KMSyncLayerHook, KMSyncAxisRangeHook, KMSyncCursorHook
	String data	//	key:value& 形式のリスト、区切り文字は &. valueとして ; 区切りのリストを含むため 
					//	key は sync, syncaxisrange, synccursor. value はウインドウリスト
					//	key が synccursormode の際は value は mode 
	
	String key0 = StringFromList(0, keyList)				//	sync, syncaxisrange, synccursor
	String key1 = StringFromList(1, keyList)				//	カーソル位置同期の場合にのみ synccursormode が入る
	String win
	Variable cursorsync = !CmpStr(key0, "synccursor")		//	カーソル位置同期の場合に 1
	Variable cursormode = NumberByKey(key1, data, ":","&")	//	カーソル位置同期の場合に 0 or 1
	Variable i, n = ItemsInList(syncWinList)
	
	//	同期設定をするか、解除するかの判定
	Variable set = 0
	for (i = 0; i < n; i += 1)
		win = StringFromList(i, syncWinList)
		if (!strlen(GetUserData(win, "", key0)))	//	リストの中にまだ同期されていないウインドウが含まれていれば同期設定する
			set = 1
			break
		elseif (cursorsync && (str2num(GetUserData(win, "", key1)) != cursormode))	//	カーソル同期モードが異なる場合には同期設定する
			set = 1
			break
		endif
	endfor
	
	if (set)	//	同期設定する
		for (i = 0; i < n; i += 1)
			win = StringFromList(i, syncWinList)
			if (cursorsync)					//	カーソル位置同期のとき
				KMSyncCursor#putCursor(win)	//	カーソルがなければ表示する
			endif
			KMSyncCommonSet(win, fn, data)
		endfor
	else		//	同期解除する
		for (i = 0; i < n; i += 1)
			KMSyncCommonCancel(StringFromList(i, syncWinList), keyList)
		endfor
	endif
End
//-------------------------------------------------------------
//	KMSyncCommonSet
//		同期を設定する共通関数, 実際の動作は各フック関数で記述する
//-------------------------------------------------------------
Function KMSyncCommonSet(win, fn, data)
	String win
	String fn, data	//	KMSyncCommon の同名引数と同じ形式・役割
	
	SetWindow $win, hook($StringFromList(0,fn,":")) = $StringFromList(1,fn,":")
	
	String str
	Variable i, n
	for (i = 0, n = ItemsInList(data, "&"); i < n; i += 1)
		str = StringFromList(i, data, "&")
		SetWindow $win, userData($StringFromList(0,str,":")) = StringFromList(1,str,":")
	endfor
End
//-------------------------------------------------------------
//	KMSyncCommonCancel:	同期設定を解除する
//-------------------------------------------------------------
Function KMSyncCommonCancel(win, keyList)
	String win
	String keyList	//	KMSyncCommon の同名引数と同じ形式・役割
	
	String key0 = StringFromList(0, keyList)
	Variable i, n
	
	//	自身を除いた新しい同期リストを得る
	String newList = RemoveFromList(win, GetUserData(win, "", key0))
	
	//	設定削除前にフック関数名を取得しておく
	GetWindow $win, hook($key0)
	String hookfnStr = S_Value
	
	//	自身が持つ同期に関する設定を削除する
	SetWindow $win, hook($key0)=$""
	for (i = 0, n = ItemsInList(keyList); i < n; i += 1)
		SetWindow $win, userData($StringFromList(i, keyList))=""
	endfor
		
	if (ItemsInList(newList) > 1)	//	同期関係にあった他のウインドウに新しい同期リストを適用する
		for (i = 0, n = ItemsInList(newList); i < n; i += 1)
			SetWindow $StringFromList(i, newList) userData($key0) = newList
			SetWindow $StringFromList(i, newList) hook($key0) = $hookfnStr	//	フック関数のdeactivateで外されている場合に備えて
		endfor
	else						//	残されたウインドウについて同期設定を解除する
		SetWindow $StringFromList(0, newList), hook($StringFromList(0, keyList))=$""
		for (i = 0, n = ItemsInList(keyList); i < n; i += 1)
			SetWindow $StringFromList(0, newList), userData($StringFromList(i, keyList))=""
		endfor
	endif
End
//-------------------------------------------------------------
//	KMSyncCommonGetSyncList:
//		同期対象となるウインドウリストを返す
//		ウインドウの複製・消去に関する修正もここで扱う
//-------------------------------------------------------------
Function/S KMSyncCommonGetSyncList(STRUCT WMWinHookStruct &s, String key)
	String list = GetUserData(s.winName,"", key)
	int changed = 0, i, n
	
	//	複製されたウインドウである場合には、自分自身がリストに含まれていないので追加する
	if (WhichListItem(s.winName, list) == -1)
		list += s.winName + ";"
		changed = 1
	endif
	
	//	存在しない(閉じられた)ウインドウはリストからも削除する
	for (i = ItemsInList(list)-1; i >= 0; i--)
		DoWindow $StringFromList(i, list)
		if (!V_flag)
			list = RemoveListItem(i, list)
			changed = 1
		endif
	endfor
	
	//	最新のリストを同期ウインドウで共有する
	if (changed)
		for (i = 0, n = ItemsInList(list); i < n; i++)
			SetWindow $StringFromList(i, list) userData($key)=list
		endfor
	endif
	
	//	同期操作の対象は自分自身以外なので、自分自身を除いたリスト文字列を返す
	return RemoveFromList(s.winName, list)
End
//-------------------------------------------------------------
//	KMSyncCommonHookRenamed
//		ウインドウの名前が変更されたときに、同期関係にある全てのウインドウにその変更を反映する
//-------------------------------------------------------------
Function KMSyncCommonHookRenamed(STRUCT WMWinHookStruct &s, String key)
	String newList = ReplaceString(s.oldWinName, GetUserData(s.winName, "", key), s.winName)
	int i, n = ItemsInList(newList)
	for (i = 0; i < n; i++)
		SetWindow $StringFromList(i, newList) userData($key)=newList
	endfor
End
//
//	以下は共通関数でパネルに関するもの
//
//-------------------------------------------------------------
//	KMSyncCommonPnlInit :	パネル初期設定
//-------------------------------------------------------------
Function/S KMSyncCommonPnlInit(pnlName, key)
	String pnlName
	String key 		//	sync, syncaxisrange, synccursor
	
	String grfName = StringFromList(0, pnlName, "#")
	String dfSav = KMNewTmpDf(grfName, key+"#"+GetRTStackInfo(2))	//	GetRTStackInfo(2) のみだと第2引数は pnl になってしまう
	String dfTmp = GetDataFolder(1)
	
	//	同期設定用のリストボックスのための準備
	Make/N=0/T/O $KM_WAVE_LIST/WAVE=lw, $"list_graph"/WAVE=lgw
	Make/B/U/N=(0,1,3)/O $KM_WAVE_SELECTED/WAVE=sw
	SetDimLabel 2, 1, foreColors, sw
	SetDimLabel 2, 2, backColors, sw
	Make/W/U/N=1/O $KM_WAVE_COLOR = {{0,0,0}, {0,0,0}, {40000,40000,40000}, {65535,65535,65535}}		//	順に, (未使用), 表示用, 表示用2, 背景用
	MatrixTranspose $KM_WAVE_COLOR
	
	String win, list = KMSyncCommonPnlList(grfName, key)
	int i, n
	
	//	リストボックスの内容
	for (i = 0; i < ItemsInList(list); i++)
		win = StringFromList(i, list)
		n = DimSize(lw,0)
		Redimension/N=(n+1) lw, lgw
		Redimension/N=(n+1,1,3) sw
		GetWindow $win wtitle
		lw[n] = S_value+" ("+win+")"
		lgw[n] = win
		sw[n][0][0] = (strlen(GetUserData(win, "", key))) ? 0x30 : 0x20	//	チェックされたチェックボックス/されてないチェックボックス
	endfor
	//	リストボックスの色
	sw[][][1] = n ? 1 : 2
	sw[][][2] = 3
	
	//	グラフをactivateしたら選択されるようにする
	for (i = 0, n = ItemsInList(list); i < n; i += 1)
		KMPanelSelectionSet(StringFromList(i, list), pnlName, "KMSyncCommonPnlActivate")
	endfor
	
	SetDataFolder $dfSav
	
	return dfTmp
End
//-------------------------------------------------------------
//	KMSyncCommonPnlList :	テーブルに載せるウインドウのリストを返す
//-------------------------------------------------------------
Static Function/S KMSyncCommonPnlList(grfName, key)
	String grfName
	String key 		//	sync, syncaxisrange, synccursor
	
	String listStr = WinList("*",";","WIN:1")
	Variable i
	
	//	synclayerの場合には、層数が異なる場合にはリストから削除する
	if (!CmpStr(key, "sync"))
		Wave srcw =  KMGetImageWaveRef(grfName)
		for (i = ItemsInList(listStr)-1; i >= 0; i -= 1)
			Wave/Z w = KMGetImageWaveRef(StringFromList(i, listStr))
			if (WaveDims(w) != 3 || DimSize(srcw,2) != DimSize(w,2))
				listStr = RemoveListItem(i, listStr)
			endif
		endfor
	endif
	
	//	自身が同期されている場合には、他の同期グループに属するウインドウを除く
	//	自身が同期されていない場合には、全ての同期状態にあるウインドウを除く
	//	(非同期ウインドウはいずれの場合にも残す)
	String syncList = GetUserData(grfName, "", key)
	for (i = ItemsInList(listStr)-1; i >= 0; i -= 1)
		String win = StringFromList(i, listStr)
		if (!strlen(GetUserData(win, "", key)))	//	非同期ウインドウ
			continue
		endif
		Variable inOtherGroup = WhichListItem(win, syncList) == -1
		if ((strlen(syncList) && inOtherGroup) || !strlen(syncList))
			listStr = RemoveListItem(i, listStr)
		endif
	endfor
	
	return listStr
End
//----------------------------------------------------------------------
//	KMSyncCommonPnlActivate
//		grfNameがactivateされたときに呼ばれる関数
//		grfNameに対応するチェックボックスの状態を変更する
//----------------------------------------------------------------------
Function KMSyncCommonPnlActivate(grfName, pnlName)
	String grfName, pnlName
	
	ControlInfo/W=$pnlName winL
	DFREF dfrTmp = $S_DataFolder
	Wave/Z/T/SDFR=dfrTmp lgw = list_graph
	Wave/Z/SDFR=dfrTmp sw = $KM_WAVE_SELECTED
	if (WaveExists(lgw) && WaveExists(sw))
		FindValue/TEXT=(grfName) lgw
		if (V_Value != -1)
			sw[V_Value][0][0] = (sw[V_Value][0][0] & 0x10) ? 0x20 : 0x30
		endif
	endif
End
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			String key = GetUserData(s.win, s.ctrlName, "key")
			String fn = GetUserData(s.win, s.ctrlName, "fn")
			KMSyncCommonPnlButtonDoSync(s.win, key, fn)
			//	** THROUGH **
		case "cancelB":
			KillWindow $s.win
			break
		case "selectB":
			ControlInfo/W=$s.win winL
			Wave/SDFR=$S_DataFolder sw = $KM_WAVE_SELECTED
			Make/B/N=(DimSize(sw,0))/FREE tw = (sw[p][0][0]&(2^4)) / 2^4
			if (sum(tw))		//	選択されているチェックボックスの数が0でなければ
				sw[][0][0] = 2^5
			else
				sw[][0][0] = 2^5 + 2^4
			endif
			break
	endswitch
End
//-------------------------------------------------------------
//	KMSyncCommonPnlButtonDoSync :	ボタンを押したときの同期設定
//-------------------------------------------------------------
Static Function KMSyncCommonPnlButtonDoSync(pnlName, key, fnStr)
	String pnlName
	String key		//	sync, syncaxisrange, synccursor
	String fnStr		//	KMSyncLayer, KMSyncAxisRange, KMSyncCursor
	
	String win
	int i, n
	
	//	カーソル位置同期かどうかで分かれる処理の準備
	Variable cursorsync
	strswitch (fnStr)
		case "KMSyncLayer":
		case "KMSyncAxisRange":
			FUNCREF KMSyncLayer fn0 = $fnStr
			cursorsync = 0
			break
		case "KMSyncCursor":
			FUNCREF KMSyncCursor fn1 = $fnStr
			cursorsync = 1
			ControlInfo/W=$pnlName xC
			Variable mode = V_Value
			break
	endswitch
	
	//	ウインドウリストのチェック状況を調べる	
	ControlInfo/W=$pnlName winL
	Wave/SDFR=$S_DataFolder sw = $KM_WAVE_SELECTED
	Wave/SDFR=$S_DataFolder/T lgw = list_graph
	String checkedList = ""	//	チェックされたウインドウのリスト
	String resetList = ""		//	同期設定解除されるウインドウのリスト
	for (i = 0, n = DimSize(sw,0); i < n; i++)
		if (sw[i][0][0] & 16)
			checkedList = AddListItem(lgw[i], checkedList)
		else
			resetList = AddListItem(lgw[i], resetList)
		endif
	endfor
	
	//	チェックがついていないウインドウの中で、同期リストを持つものは同期解除
	for (i = ItemsInList(resetList)-1; i >= 0; i--)
		win = StringFromList(i, resetList)
		if (!strlen(GetUserData(win, "", key)))
			resetList = RemoveListItem(i, resetList)
		endif
	endfor
	if (ItemsInList(resetList))
		if (cursorsync)
			fn1(resetList, history=1)
		else
			fn0(resetList, history=1)
		endif
	endif
	
	//	チェックがついているウインドウの数が1つの場合にはここで終了
	if (ItemsInList(checkedList) < 2)
		return 0
	endif
	
	//	チェックがついている、かつ、ついているウインドウの中に同期リストを持たないものがある場合には、同期設定
	//	(同期リストを持つものだけだと、解除されてしまう)
	Variable doSync = 0
	for (i = 0, n = ItemsInList(checkedList); i < n; i++)
		win = StringFromList(i,checkedList)
		if (!strlen(GetUserData(win, "", key)))
			doSync = 1
			break
		elseif (cursorsync && mode != str2num(GetUserData(win, "", key+"mode")))	//	カーソル位置同期でモードの変更を伴う場合
			doSync = 1
			break
		endif
	endfor
	if (doSync)
		if (cursorsync)
			fn1(checkedList, mode=mode, history=1)
		else
			fn0(checkedList, history=1)
		endif
	endif
End