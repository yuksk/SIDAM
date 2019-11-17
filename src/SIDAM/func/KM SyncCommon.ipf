#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = KMSyncCommon

#include "KM SyncCursor"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	KMSyncLayer, KMSyncAxisRange, KMSyncCursor で共通に使われる関数
//******************************************************************************
Static Function common(
	String key,	//	sync, syncaxisrange, synccursor
	String fn,	//	KMSyncLayerHook, KMSyncAxisRangeHook, KMSyncCursorHook
	String data	//	key:value& 形式のリスト、区切り文字は 「,」. valueとして ; 区切りのリストを含むため 
					//	key=listの場合は value はウインドウリスト
					//	key=modeの場合は value は synccursormode の mode
	)
	
	String syncWinList = StringByKey("list",data,":",",")
	int cursorsync = !CmpStr(key, "synccursor")			//	カーソル位置同期の場合に 1
	int cursormode = NumberByKey("mode", data, ":",",")	//	カーソル位置同期の場合に 0 or 1
	
	String win, str
	int i, n = ItemsInList(syncWinList)
	
	//	同期設定をするか、解除するかの判定
	int set = 0
	for (i = 0; i < n; i++)
		win = StringFromList(i, syncWinList)
		str = GetUserData(win,"",key)
		if (!strlen(str))	//	リストの中にまだ同期されていないウインドウが含まれていれば同期設定する
			set = 1
			break
		elseif (cursorsync && (NumberByKey("mode",str,":",",") != cursormode))	//	カーソル同期モードが異なる場合には同期設定する
			set = 1
			break
		endif
	endfor
	
	if (set)	//	同期設定する
		for (i = 0; i < n; i++)
			win = StringFromList(i, syncWinList)
			if (cursorsync)					//	カーソル位置同期のとき
				KMSyncCursor#putCursor(win)	//	カーソルがなければ表示する
			endif
			SetWindow $win, hook($key) = $fn
			SetWindow $win, userData($key) = data
		endfor
	else		//	同期解除する
		for (i = 0; i < n; i++)
			resetSync(StringFromList(i, syncWinList), key)
		endfor
	endif
End
//-------------------------------------------------------------
//	同期設定を解除する
//	引数の keyList	 は KMSyncCommon の同名引数と同じ形式・役割
//-------------------------------------------------------------
Static Function resetSync(String grfName, String key)
	//	自身を除いた新しい同期リストを得る
	String newList = getSyncList(grfName, key)
	
	//	設定削除前にフック関数名を取得しておく
	GetWindow $grfName, hook($key)
	String hookfnStr = S_Value
	
	//	自身が持つ同期に関する設定を削除する
	SetWindow $grfName, hook($key)=$""
	SetWindow $grfName, userData($key)=""
		
	if (ItemsInList(newList) > 1)	//	同期関係にあった他のウインドウに新しい同期リストを適用する
		applySyncList(newList,key)
	else						//	残されたウインドウについて同期設定を解除する
		SetWindow $StringFromList(0, newList), hook($key)=$""
		SetWindow $StringFromList(0, newList), userData($key)=""
	endif
End
//-------------------------------------------------------------
//	同期対象となるウインドウリストを返す
//-------------------------------------------------------------
Static Function/S getSyncList(String grfName, String key, [int all])
	//	自分自身を除いたリストを返すときは 0, 自分自身を含むすべてを返すときは 1
	all = ParamIsDefault(all) ? 0 : all
	
	String dataStr = GetUserData(grfName,"",key)
	String listStr = StringByKey("list",dataStr,":",",")
	
	//	userData がウインドウリストのみに使われていた古いバージョンへの対応
	if (strlen(dataStr) && !strlen(listStr))
		SetWindow $grfName userData($key)="list:"+dataStr
		listStr = dataStr
	endif
	
	//	renewSyncListから呼ばれているときにはrenewSyncListを実行しない(無限ループを避ける)
	if (!CmpStr(GetRTStackInfo(2),"renewSyncList"))
		renewSyncList(grfName, key)
	endif
	
	//	同期操作の対象となるウインドウリストの場合は、自分自身を除いたものが必要となる
	return SelectString(all,RemoveFromList(grfName, listStr),listStr)
End
//-------------------------------------------------------------
//	ウインドウの名前が変更されたときに、同期関係にある全てのウインドウにその変更を反映する
//	ウインドウの複製・消去に関する修正もここで扱う
//-------------------------------------------------------------
Static Function renewSyncList(String grfName, String key, [String oldName])
	String listStr = getSyncList(grfName,key,all=1)
	int i, changed = 0
	
	//	名前が変更された場合にはウインドウリストの中身を入れ替える
	if (!ParamIsDefault(oldName))
		listStr = ReplaceString(oldName, listStr, grfName)
		changed = 1
	endif
	
	//	複製されたウインドウである場合には、自分自身がリストに含まれていないので追加する
	if (WhichListItem(grfName, listStr) == -1)
		listStr += grfName + ";"
		changed = 1
	endif
	
	//	存在しない(閉じられた)ウインドウはリストからも削除する
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		if (!SIDAMWindowExists(StringFromList(i, listStr)))
			listStr = RemoveListItem(i, listStr)
			changed = 1
		endif
	endfor
	
	//	最新のリストを同期ウインドウで共有する
	if (changed)
		applySyncList(listStr,key)
	endif	
End
//-------------------------------------------------------------
//	listStrで与えられるウインドウにlistStrを設定する
//-------------------------------------------------------------
Static Function applySyncList(String listStr, String key)
	int i, n
	String grfName
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		grfName = StringFromList(i,listStr)
		SetWindow $grfName userData($key)=\
			ReplaceStringByKey("list",GetUserData(grfName,"",key),listStr,":",",")
	endfor
End
//-------------------------------------------------------------
//	循環動作を防ぐ関数群
//-------------------------------------------------------------
Static Function isBlocked(String grfName, String key)
	return NumberByKey("block",GetUserData(grfName,"",key),":",",")
End

Static Function releaseBlock(String grfName, String key)
	SetWindow $grfName userData($key)=\
		ReplaceStringByKey("block",GetUserData(grfName,"",key),"0",":",",")
End

Static Function setBlock(String grfName, String key)
	SetWindow $grfName userData($key)=\
		ReplaceStringByKey("block",GetUserData(grfName,"",key),"1",":",",")
End
//
//	以下は共通関数でパネルに関するもの
//
//-------------------------------------------------------------
//	パネル初期設定
//	引数の key は sync, syncaxisrange, synccursor のいずれか
//-------------------------------------------------------------
Static Function/S pnlInit(String pnlName, String key)
	DFREF dfrSav = GetDataFolderDFR()
	String grfName = StringFromList(0, pnlName, "#")
	String dfTmp = SIDAMNewDF(grfName, key+"#"+GetRTStackInfo(2))	//	GetRTStackInfo(2) のみだと第2引数は pnl になってしまう
	SetDataFolder $dfTmp
	
	//	同期設定用のリストボックスのための準備
	Make/N=0/T/O $KM_WAVE_LIST/WAVE=lw, $"list_graph"/WAVE=lgw
	Make/B/U/N=(0,1,3)/O $KM_WAVE_SELECTED/WAVE=sw
	SetDimLabel 2, 1, foreColors, sw
	SetDimLabel 2, 2, backColors, sw
	Make/W/U/N=1/O $KM_WAVE_COLOR = {{0,0,0}, {0,0,0}, {40000,40000,40000}, {65535,65535,65535}}		//	順に, (未使用), 表示用, 表示用2, 背景用
	MatrixTranspose $KM_WAVE_COLOR
	
	String win, list = pnlList(grfName, key)
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
		panelSelectionSet(StringFromList(i, list), pnlName, "KMSyncCommon#grfActivate")
	endfor
	
	SetDataFolder dfrSav
	
	return dfTmp
End
//-------------------------------------------------------------
//	テーブルに載せるウインドウのリストを返す
//	引数の key は sync, syncaxisrange, synccursor のいずれか
//-------------------------------------------------------------
Static Function/S pnlList(String grfName, String key)
	String listStr = WinList("*",";","WIN:1")
	int i
	
	//	synclayerの場合には、層数が異なる場合にはリストから削除する
	if (!CmpStr(key, "sync"))
		Wave srcw =  SIDAMImageWaveRef(grfName)
		for (i = ItemsInList(listStr)-1; i >= 0; i--)
			Wave/Z w = SIDAMImageWaveRef(StringFromList(i, listStr))
			if (WaveDims(w) != 3 || DimSize(srcw,2) != DimSize(w,2))
				listStr = RemoveListItem(i, listStr)
			endif
		endfor
	endif
	
	//	自身が同期されている場合には、他の同期グループに属するウインドウを除く
	//	自身が同期されていない場合には、全ての同期状態にあるウインドウを除く
	//	(非同期ウインドウはいずれの場合にも残す)
	String syncList = getSyncList(grfName, key, all=1)
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		String win = StringFromList(i, listStr)
		if (!ItemsInList(getSyncList(win, key, all=1)))	//	非同期ウインドウ
			continue
		endif
		int inOtherGroup = WhichListItem(win, syncList) == -1
		if ((ItemsInList(syncList) && inOtherGroup) || !ItemsInList(syncList))
			listStr = RemoveListItem(i, listStr)
		endif
	endfor
	
	return listStr
End
//----------------------------------------------------------------------
//	grfNameがactivateされたときに呼ばれる関数
//	grfNameに対応するチェックボックスの状態を変更する
//----------------------------------------------------------------------
Static Function grfActivate(String grfName, String pnlName)
	ControlInfo/W=$pnlName winL
	DFREF dfrTmp = $S_DataFolder
	Wave/Z/T/SDFR=dfrTmp lgw = list_graph
	Wave/Z/SDFR=dfrTmp sw = $KM_WAVE_SELECTED
	if (WaveExists(lgw) && WaveExists(sw))
		FindValue/TEXT=(grfName)/TXOP=2 lgw
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
			pnlButtonDoSync(s.win, key, fn)
			//	*** FALLTHROUGH ***
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
//	ボタンを押したときの同期設定
//-------------------------------------------------------------
Static Function pnlButtonDoSync(
	String pnlName,
	String key,		//	sync, syncaxisrange, synccursor
	String fnStr		//	KMSyncLayer, KMSyncAxisRange, KMSyncCursor
	)
	
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


//******************************************************************************
//	panelSelectionSet
//	panelSelectionReset
//		grfName をクリック(mouseup)したら callback(grfName, pnlName) を呼び出すようにする関数と、
//		それを解除する関数
//		callback は pnlName に保存される
//		grfName を閉じても callback を呼び出す発火点がなくなるだけであるが、
//		pnlName を閉じた場合には、pnlNameのcallbackを呼び出すことになっているgrfNameから
//		設定を削除する
//******************************************************************************
Static Function panelSelectionSet(String grfName, String pnlName, String callback)
	SetWindow $grfName userData(KMPanelSelection) = pnlName
	SetWindow $grfName hook(KMPanelSelection) = KMSyncCommon#panelSelectionHook
	SetWindow $pnlName userData(KMPanelSelection) = callback
	SetWindow $pnlName hook(KMPanelSelection) = KMSyncCommon#panelSelectionHook2
End

Static Function panelSelectionReset(String grfName)
	SetWindow $grfName userData(KMPanelSelection)=""
	SetWindow $grfName hook(KMPanelSelection)=$""
End

Static Function panelSelectionHook(STRUCT WMWinHookStruct &s)
	if (s.eventCode == 5) 	//	mouseup
		String pnlName = GetUserData(s.winName, "", "KMPanelSelection")
		FUNCREF KMPanelSelectionProto fn = $GetUserData(pnlName, "", "KMPanelSelection")
		fn(s.winName, pnlName)
	endif
	return 0
End

Static Function panelSelectionHook2(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 2 && s.eventCode != 17)	//	neither kill nor killvote
		return 0
	endif
	
	String grfName, list = WinList("*",";","WIN:1")
	int i, n
	
	for (i = 0, n = ItemsInList(list); i < n; i++)
		grfName = StringFromList(i,list)
		if (!CmpStr(GetUserData(grfName,"","KMPanelSelection"), s.winName))
			panelSelectionReset(grfName)
		endif
	endfor
	return 0
End

Function KMPanelSelectionProto(String grfName, String pnlName)
End
