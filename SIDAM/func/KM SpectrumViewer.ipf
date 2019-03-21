#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMSpectrumViewer

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant KEY = "SIDAMSpectrumViewer"

//******************************************************************************
//	レイヤーデータから1本のスペクトルを抜き出して表示するためのパネルを表示
//******************************************************************************
//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(WinName(0,1))
End

Static Function pnl(String LVName)

	//	既に表示されているパネルがあればそれをフォーカスして終了
	String pnlName = StringFromList(0,GetUserData(LVName,"",KEY),"=")
	if (SIDAMWindowExists(pnlName))
		DoWindow/F $pnlName
		return 0
	endif
	pnlName = UniqueName("Graph",6,0)

	Wave srcw =  KMGetImageWaveRef(LVName)
	int isMLS = SIDAMisUnevenlySpacedBias(srcw)
	if (isMLS)		//	Nanonis MLSモードでのデータの場合は、横軸用ウエーブを一時データフォルダ内に用意する
		String dfTmp
		Wave xw = pnlInit(srcw, pnlName, dfTmp)
	endif

	//  パネル表示
	if (isMLS)
		Display/K=1 srcw[0][0][] vs xw
	else
		Display/K=1 srcw[0][0][]
	endif
	AutoPositionWindow/E/M=0/R=$LVName $pnlName

	//  グラフ詳細
	ModifyGraph/W=$pnlName width=180*96/screenresolution, height=180*96/screenresolution, gfSize=10
	ModifyGraph/W=$pnlName margin(top)=8,margin(right)=12,margin(bottom)=36,margin(left)=44
	ModifyGraph/W=$pnlName tick=0,btlen=5,mirror=0,lblMargin=2
	if (isMLS)
		ModifyGraph/W=$pnlName rgb=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B)
		ModifyGraph/W=$pnlName axRGB=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B)
		ModifyGraph/W=$pnlName tlblRGB=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B)
		ModifyGraph/W=$pnlName alblRGB=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B)
		ModifyGraph/W=$pnlName gbRGB=(SIDAM_CLR_BG_R, SIDAM_CLR_BG_G, SIDAM_CLR_BG_B)
		ModifyGraph/W=$pnlName wbRGB=(SIDAM_CLR_BG_R, SIDAM_CLR_BG_G, SIDAM_CLR_BG_B)
	endif

	//	コントロールバー
	ControlBar 48
	SetVariable pV title="p:", pos={5,6}, size={72,15}, proc=SIDAMSpectrumViewer#pnlSetVar, win=$pnlName
	SetVariable pV bodyWidth=60, value=_NUM:0, limits={0,DimSize(srcw,0)-1,1}, win=$pnlName
	SetVariable qV title="q:", pos={85,6}, size={72,15}, proc=SIDAMSpectrumViewer#pnlSetVar, win=$pnlName
	SetVariable qV bodyWidth=60, value=_NUM:0, limits={0,DimSize(srcw,1)-1,1}, win=$pnlName
	TitleBox xyT pos={4,30}, frame=0, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	SetWindow $pnlName userData(live)="0"
	SetWindow $pnlName userData(key)=KEY
	if (isMLS)
		SetWindow $pnlName userData(dfTmp)=dfTmp
	endif

	//  マウス位置取得ウインドウの設定
	pnlSetRelation(LVname, pnlName)

	DoUpdate/W=$pnlName
	ModifyGraph/W=$pnlName width=0, height=0
End
//-------------------------------------------------------------
//	パネル初期設定
//-------------------------------------------------------------
Static Function/WAVE pnlInit(Wave srcw, String pnlName, String &dfTmp)
	dfTmp = SIDAMNewDF(pnlName,KEY)
	Duplicate/O SIDAMGetBias(srcw, 1) $(dfTmp+NameOfWave(srcw)+"_b")/WAVE=tw	//	MLS対応横軸ウエーブ
	return tw
End
//-------------------------------------------------------------
//	指定されたウインドウについて、マウス位置取得ウインドウとスペクトル表示
//	ウインドウとしての関係を設定する
//-------------------------------------------------------------
Static Function pnlSetRelation(String mouseWin, String specWin)
	String list = GetUserData(mouseWin, "", KEY)
	SetWindow $mouseWin userData($KEY)=AddListItem(specWin+"="+GetUserData(specWin,"","dfTmp"), list)
	SetWindow $mouseWin hook($KEY)=SIDAMSpectrumViewer#pnlHookParent

	list = GetUserData(specWin, "", "parent")
	SetWindow $specWin userData(parent)=AddListItem(mouseWin, list)
	SetWindow $specWin hook(self)=SIDAMSpectrumViewer#pnlHook
End
//-------------------------------------------------------------
//	指定されたウインドウについて、マウス位置取得ウインドウとスペクトル表示
//	ウインドウとしての関係を解除する
//-------------------------------------------------------------
Static Function pnlResetRelation(String mouseWin, String specWin)
	//	マウス位置取得ウインドウについての処理
	//	指定されたスペクトル表示ウインドウをリストから削除する
	String newList = RemoveByKey(specWin, GetUserData(mouseWin,"",KEY),"=")
	SetWindow $mouseWin userData($KEY)=newList
	if (!ItemsInlist(newList))
		//	リストからスペクトル表示ウインドウを削除した結果としてリストが空になったら
		//	マウス位置取得ウインドウの役割を解除して良い
		SetWindow $mouseWin hook($KEY)=$""
	endif

	//	スペクトル表示ウインドウについての処理
	//	指定されたマウス位置取得ウインドウをリストから削除する
	//	リストが空になってもスペクトル表示ウインドウのフック関数は解除しない(メニュー等の表示が必要)
	if (SIDAMWindowExists(specWin))	//	SIDAM非動作中にウインドウが閉じられた場合の処理からもこの関数が呼ばれることに備えて
		SetWindow $specWin userData(parent)=RemoveFromList(mouseWin,GetUserData(specWin,"","parent"))
	endif
End


//******************************************************************************
//	フック関数
//******************************************************************************
//-------------------------------------------------------------
//	スペクトル表示用グラフのフック関数
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
			return 0

		case 3:	//	mousedown
			GetWindow $s.winName, wsizeDC
			if (s.mouseLoc.v > V_top)	//	コントロールバー外なら
				return 0
			elseif (s.eventMod & 16)	//	右クリック
				PopupContextualMenu/N "KMSpectrumViewerMenu"
			endif
			return 1

		case 4:	//	mouse move
			if (!(s.eventMod&0x02))	//	shiftキーが押されていなければ
				KMDisplayCtrlBarUpdatePos(s)		//	マウス位置座標表示
			endif
			return 0

		case 11: 	//	keyboard
			if (s.keycode == 27)		//	esc
				SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
				KillWindow $s.winName
			elseif (s.keycode >= 28 && s.keycode <= 31)	//	arrows
				pnlHookArrows(s)
			elseif (s.keycode >= 97)
				KMInfobar#keyboardShortcuts(s)
			endif
			return 1

		case 13: //	renamed
			SIDAMLineCommon#pnlHookRename(s)
			return 0

		default:
			return 0
	endswitch
End
//-------------------------------------------------------------
//	Hook function for the parent window
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	String pnlList, pnlName
	int i, n

	if (SIDAMLineCommon#pnlHookParentCheckChild(s.winName,KEY,pnlResetRelation))
		return 0
	endif

	switch (s.eventCode)
		case 2:	//	kill
			pnlList = GetUserData(s.winName,"",KEY)
			for (i = 0, n = ItemsInList(pnlList); i < n; i += 1)
				pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
				pnlResetRelation(s.winName, pnlName)
			endfor
			return 0

		case 3:	//	mouse down
			SetWindow $s.winName userData(mousePressed)="1"
			return 0

		case 4:	//	mouse moved
			if (!(s.eventMod&2^1))		//	unless the shift key is pressed
				pnlHookMouseMov(s)
			endif
			return 0

		case 5:	//	mouse up
			GetWindow $s.winName, wsizeDC
			if (s.mouseLoc.h < V_left || s.mouseLoc.h > V_right || s.mouseLoc.v > V_bottom || s.mouseLoc.v < V_top)
				return 0
			elseif (!strlen(GetUserData(s.winName,"","mousePressed")))	//	when the cursor is dragged
				return 0
			elseif (s.eventMod&2^3)	// if the ctrl key is pressed
				pnlHookClick(s)
			endif
			SetWindow $s.winName userData(mousePressed)=""
			return 0

		case 7:	//	cursor moved
			pnlHookCsrMov(s)
			SetWindow $s.winName userData(mousePressed)=""
			return 0

		case 13:	//	renamed
			SIDAMLineCommon#pnlHookParentRename(s,KEY)
			return 0

		default:
			return 0
	endswitch
End
//-------------------------------------------------------------
//	マウス動作時の表示動作
//	マウス位置を取得してスペクトル表示を更新する
//-------------------------------------------------------------
Static Function pnlHookMouseMov(STRUCT WMWinHookStruct &s)
	STRUCT SIDAMMousePos ms
	if (SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=1))
		return 0
	endif

	String pnlList = GetUserData(s.winName,"",KEY), pnlName
	int i, n
	for (i = 0, n = ItemsInList(pnlList); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		if (str2num(GetUserData(pnlName, "", "live")) == 0)
			pnlUpdateSpec(pnlName, ms.p, ms.q)	//	表示更新
		endif
	endfor
End
//-------------------------------------------------------------
//	カーソル動作時の表示動作
//	カーソル位置を取得してスペクトル表示を更新する
//-------------------------------------------------------------
Static Function pnlHookCsrMov(STRUCT WMWinHookStruct &ws)
	//	カーソルAが表示されていない場合には何もしない
	STRUCT KMCursorPos s
	if (KMGetCursor("A", ws.winName, s))
		return 0
	endif

	String pnlList = GetUserData(ws.winName,"",KEY)	//	更新対象となるウインドウのリスト
	int i, n = ItemsInList(pnlList)
	for (i = 0; i < n; i++)
		String pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		if (str2num(GetUserData(pnlName, "", "live")) == 1)
			pnlUpdateSpec(pnlName, s.p, s.q)	//	表示更新
		endif
	endfor
End
//-------------------------------------------------------------
//	矢印キーが押された場合の動作
//	押された方向にスペクトル表示位置を動かす(ctrlが押されていたら10倍)
//-------------------------------------------------------------
Static Function pnlHookArrows(STRUCT WMWinHookStruct &s)
	String mouseWinList = GetUserData(s.winName,"","parent")
	int i, n = ItemsInList(mouseWinList)
	Make/N=10/FREE tw

	for (i = 0; i < n; i++)
		int step = (s.eventMod & 2) ? 10 : 1
		ControlInfo/W=$s.winName pV ;	Variable posp = V_Value
		ControlInfo/W=$s.winName qV ;	Variable posq = V_Value
		switch (s.keycode)
			case 28:		//	左
				posp = posp-step
				break
			case 29:		//	右
				posp = posp+step
				break
			case 30:		//	上
				posq = posq+step
				break
			case 31:		//	下
				posq = posq-step
				break
		endswitch
		pnlUpdateSpec(s.winName, posp, posq)	//	表示更新
	endfor
End
//-------------------------------------------------------------
//	クリックの場合の動作
//	クリック位置でのスペクトル表示を追加する
//-------------------------------------------------------------
Static Function pnlHookClick(STRUCT WMWinHookStruct &s)
	//	複数のspectrum viewerのターゲットになっている可能性があり、それらのリストが入る
	String specWinList = GetUserData(s.winName, "", KEY)

	String specWin, trcList, trcName
	STRUCT RGBColor clr
	int i, j

	for (i = 0; i < ItemsInList(specWinList); i++)
		specWin = StringFromList(0,StringFromList(i,specWinList),"=")
		trcList = TraceNameList(specWin,";",1)
		Wave cw = KMGetCtrlValues(specWin,"pV;qV")

		for (j = 0; j < ItemsInList(trcList); j++)
			trcName = StringFromList(j,trcList)
			//	追加表示されたトレースであれば削除する
			if (strsearch(trcName,"#",0)>=0)
				RemoveFromGraph/W=$specWin $trcName
				continue
			endif
			Wave srcw = TraceNameToWaveRef(specWin,trcName)
			Wave/Z xw = XWaveRefFromTrace(specWin,trcName)
			if (WaveExists(xw))	//	MLS
				AppendToGraph/W=$specWin srcw[cw[0]][cw[1]][]/TN=$trcName vs xw
				clr.red = SIDAM_CLR_LINE2_R
				clr.green = SIDAM_CLR_LINE2_G
				clr.blue = SIDAM_CLR_LINE2_B
			else
				AppendToGraph/W=$specWin srcw[cw[0]][cw[1]][]/TN=$trcName
				getInvertedColor(specWin,NameOfWave(srcw),clr)
			endif
			ModifyGraph/W=$specWin rgb($trcName)=(clr.red, clr.green, clr.blue)
		endfor
	endfor
End

Static Function getInvertedColor(String grfName, String trcName, STRUCT RGBColor &s)
	Variable red, green, blue
	sscanf StringByKey("rgb(x)", TraceInfo(grfName, trcName, 0), "="),"(%d,%d,%d)", red, green, blue
	s.red = 65535 - red
	s.green = 65535 - green
	s.blue = 65535 - blue
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == -1)
		return 1
	endif
	ControlInfo/W=$s.win pV ;	Variable posp = V_Value
	ControlInfo/W=$s.win qV ;	Variable posq = V_Value
	pnlUpdateSpec(s.win, posp, posq)	//	表示更新
End


//******************************************************************************
//	補助関数
//******************************************************************************
//-------------------------------------------------------------
//	スペクトル等表示更新
//-------------------------------------------------------------
Static Function pnlUpdateSpec(String pnlName, Variable posp, Variable posq)
	//	この関数を呼び出した関数のスタック
	String callingStack = RemoveListItem(ItemsInList(GetRTStackInfo(0))-1, GetRTStackInfo(0))
	//	そのスタックに自分自身が含まれている場合には true
	Variable recursive = WhichListItem(GetRTStackInfo(1), callingStack) != -1
	if (recursive)
		return 0
	endif

	int i, n
	String trcList = TraceNameList(pnlName,";",1), trcName

	//	スペクトル表示の更新
	for (i = 0, n = ItemsInList(trcList); i < n; i++)
		trcName = StringFromList(i,trcList)
		//	追加表示されたトレースは更新しない
		if (strsearch(trcName,"#",0)>=0)
			continue
		endif
		Wave srcw = TraceNameToWaveRef(pnlName,trcName)
		posp = limit(posp, 0, DimSize(srcw,0)-1)
		posq = limit(posq, 0, DimSize(srcw,1)-1)
		ReplaceWave/W=$pnlName trace=$NameOfWave(srcw), srcw[posp][posq][]
	endfor

	//	パネル表示の更新
	SetVariable pV value=_NUM:posp, win=$pnlName
	SetVariable qV value=_NUM:posq, win=$pnlName
	DoUpdate/W=$pnlName

	//	カーソル位置を使用している場合、かつ、カーソル位置変化に伴う呼び出しでない場合
	//	(SetVariableの値変化やスペクトル表示ウインドウでの矢印キー)には、カーソルを移動する
	if (str2num(GetUserData(pnlName,"","live"))==1 && CmpStr(GetRTStackInfo(2), "pnlHookCsrMov"))
		STRUCT KMCursorPos s ;	s.isImg = 1;	s.p = posp ;	s.q = posq
		String win, mouseWinList = GetUserData(pnlName,"","parent")
		for (i = 0, n = ItemsInList(mouseWinList); i < n; i++)
			win = StringFromList(i, mouseWinList)
			KMSetCursor("A", win, 0, s)
		endfor
	endif
End
//-------------------------------------------------------------
//	SpectrumViewerの右クリックメニュー
//-------------------------------------------------------------
Menu "KMSpectrumViewerMenu", dynamic, contextualmenu
	SubMenu "Live Update"
		SIDAMSpectrumViewer#rightclickMenuLive(), SIDAMSpectrumViewer#rightclickDoLive()
	End
	SubMenu "Target window"
		SIDAMLineCommon#rightclickMenuTarget(), SIDAMSpectrumViewer#rightclickDoTarget()
	End
	SubMenu "Complex"
		SIDAMSpectrumViewer#rightclickMenuComplex(), SIDAMSpectrumViewer#rightclickDoComplex()
	End
	"Save", SIDAMSpectrumViewer#saveSpectrum(WinName(0,1))
	"-"
	"Help", SIDAMOpenHelpNote("spectrumviewer",WinName(0,1),"Spectrum Viewer")
End
//-------------------------------------------------------------
//	複素数表示を変更する
//-------------------------------------------------------------
Static Function rightclickDoComplex()
	GetLastUserMenuInfo
	ModifyGraph/W=$WinName(0,1) cmplxMode=V_Value
End

Static Function/S rightclickMenuComplex()
	String win = WinName(0,1)
	String trcList = TraceNameList(win,";",1), trcName
	int i, isComplexIncluded = 0

	for (i = 0; i < ItemsInList(trcList); i++)
		trcName = StringFromList(i,trcList)
		if (WaveType(TraceNameToWaveRef(win,trcName)) & 0x01)
			int mode = NumberByKey("cmplxMode(x)",TraceInfo(win, trcName, 0),"=")
			return SIDAMAddCheckmark(mode-1, "real only;imaginary only;magnitude;phase in radian")
		endif
	endfor
	return ""
End
//-------------------------------------------------------------
//	座標取得元を変更する
//-------------------------------------------------------------
Static Function rightclickDoLive()
	GetLastUserMenuInfo
	SetWindow $WinName(0,1) userData(live)=num2str(V_Value-1)
End

Static Function/S rightclickMenuLive()
	String win = WinName(0,1)
	int num = strlen(win) ? str2num(GetUserData(win,"","live")) : 0
	return SIDAMAddCheckmark(num, "Mouse;Cursor A;None;")
End
//-------------------------------------------------------------
//	マウス座標を取得するウインドウを変更する
//-------------------------------------------------------------
Static Function rightclickDoTarget()
	String specWin = WinName(0,1)
	GetLastUserMenuInfo
	String mouseWin = StringFromList(V_value-1,GetUserData(specWin,"","target"))
	if (WhichListItem(mouseWin, GetUserData(specWin, "", "parent")) == -1)
		pnlSetRelation(mouseWin, specWin)
	else
		pnlResetRelation(mouseWin, specWin)
	endif
End
//-------------------------------------------------------------
//	指定点におけるウエーブを抜き出す
//-------------------------------------------------------------
Static Function saveSpectrum(String pnlName)
	ControlInfo/W=$pnlName pV ;	Variable posp = V_Value
	ControlInfo/W=$pnlName qV ;	Variable posq = V_Value
	String trcList = TraceNameList(pnlName,";",1), trcName, result
	DFREF dfrSav = GetDataFolderDFR()
	int i

	for (i = 0; i < ItemsInList(trcList); i++)
		trcName = StringFromList(i,trcList)
		if (strsearch(trcName,"#",0)>=0)
			continue
		endif

		Wave srcw = TraceNameToWaveRef(pnlName,trcName)
		if (WaveDims(srcw)!=3)
			continue
		endif

		sprintf result, "%s_p%dq%d", NameOfWave(srcw), posp, posq
		result = CleanupName(result,1)

		SetDataFolder GetWavesDataFolderDFR(srcw)
		MatrixOP/O $result/WAVE=extw = beam(srcw, posp, posq)
		if (SIDAMisUnevenlySpacedBias(srcw))
			Duplicate/O SIDAMGetBias(srcw, 1) $(NameOfWave(srcw)+"_b")
		else
			SetScale/P x DimOffset(srcw,2), DimDelta(srcw,2), WaveUnits(srcw,2), extw
		endif
		SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(srcw,0)), extw

		SetDataFolder dfrSav
	endfor
End
