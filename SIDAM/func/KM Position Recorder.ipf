#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMPositionRecorder

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant ks_pnlHeight = 109
Static Constant ks_tabHeight = 160

//******************************************************************************
//	クリック位置のインデックスを記録
//******************************************************************************
Static Function rightclickDo()
	pnl()
End

Static Function pnl()
	
	String grfName = WinName(0,1,1)
	if (!strlen(grfName))
		return 1
	endif
	
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,235,ks_pnlHeight)/N=PositionRecorder
	String pnlName = grfName + "#PositionRecorder"
	
	SetWindow $pnlName hook(self)=KMPositionRecorder#pnlHook, activeChildFrame=0
	
	Button startB pos={7,5}, size={60,18}, title="start", disable=2, win=$pnlName
	Button finishB pos={77,5}, size={60,18}, title="finish", disable=2, win=$pnlName
	Button helpB pos={147, 5}, size={18,18}, title="?", win=$pnlName
	Checkbox gridC pos={189,7}, title="grid", value=1, win=$pnlName
	
	GroupBox waveG pos={8,34}, size={220,72}, title="waves to save positions", win=$pnlName
	PopupMenu pwP pos={16,53}, title="p:", userData(pts)="-1", value=#"KMPositionRecorder#popupStr(\"pwP\")", win=$pnlName
	PopupMenu qwP pos={16,79}, title="q:", userData(pts)="-1", value=#"KMPositionRecorder#popupStr(\"qwP\")", win=$pnlName
	Button waveB pos={180,61}, size={40,30}, title="new", win=$pnlName
	
	ModifyControlList "pwP;qwP" size={151,20}, bodyWidth=140, mode=1, proc=KMPositionRecorder#pnlPopup, win=$pnlName
	ModifyControlList "startB;finishB;helpB;waveB" proc=KMPositionRecorder#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End
//-------------------------------------------------------------
//	自パネル用フック関数
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			pnlHookClose(s)
			break
		case 11:	//	keyboard
			if (s.keycode == 27)	//	esc
				pnlHookClose(s)
				KillWindow $s.winName
			endif
			break
	endswitch
	return 0
End
//-------------------------------------------------------------
//	親ウインドウ用フック関数
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 5:	//	mouse up
			String pnlName = s.winName+"#PositionRecorder"
			Wave/Z pw = $GetUserData(pnlName, "pwP", "wave"), qw = $GetUserData(pnlName, "qwP", "wave")
			if (!WaveExists(pw) || !WaveExists(qw))
				return 0
			endif
			
			STRUCT SIDAMMousePos ms
			ControlInfo/w=$pnlName gridC
			if (SIDAMGetMousePos(ms, s.winName, s.mouseLoc, grid=V_Value))
				return 0
			endif
			
			if (s.eventMod & 0x08)	//	ctrl, 一番近くの点を削除
				Duplicate/FREE pw disw, indexw
				disw = (pw-ms.p)^2 + (qw-ms.q)^2
				indexw = p
				Sort disw, indexw
				DeletePoints indexw[0], 1, pw, qw
			else					//	点を追加
				int n = numpnts(pw)
				Redimension/N=(n+1) pw, qw
				pw[n] = ms.p
				qw[n] = ms.q
			endif
			break
	endswitch
	return 0
End
//-------------------------------------------------------------
//	自パネルが閉じられたときの動作
//-------------------------------------------------------------
Static Function pnlHookClose(STRUCT WMWinHookStruct &s)	
	String grfName = StringFromList(0, s.winName, "#")
	SetWindow $grfName hook(positionrecorder)=$""
	KMonClosePnl(s.winName)
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	String grfName = StringFromList(0, s.win, "#")
	
	strswitch (s.ctrlName)
		case "startB":
			Wave/Z pw = $GetUserData(s.win, "pwP", "wave"), qw = $GetUserData(s.win, "qwP", "wave")
			if (!WaveExists(pw) || !WaveExists(qw))
				return 0
			endif
			SetWindow $grfName hook(positionrecorder)=KMPositionRecorder#pnlHookParent
			MoveSubWindow/W=$s.win fnum=(0,0,235,ks_pnlHeight+ks_tabHeight)
			Edit/W=(0,ks_pnlHeight,300,ks_pnlHeight+ks_tabHeight)/HOST=$s.win  pw, qw
			ModifyTable width=85, width(Point)=40, format(Point)=1, statsArea=85
			SetActiveSubwindow ##
			Button finishB disable=0, win=$s.win
			ModifyControlList "startB;waveB;pwP;qwP" disable=2, win=$s.win
			break
			
		case "finishB":
			SetWindow $grfName hook(positionrecorder)=$""
			KillWindow $(s.win+"#T0")
			MoveSubWindow/W=$s.win fnum=(0,0,235,ks_pnlHeight)
			Button finishB disable=2, win=$s.win
			ModifyControlList "startB;waveB;pwP;qwP" disable=0, win=$s.win			
			break
			
		case "waveB":
			DFREF dfrSav = GetDataFolderDFR()
			SetDataFolder GetWavesDataFolderDFR(KMGetImageWaveRef(grfName))
			Make/N=0 $UniqueName("wave", 1, 0)/WAVE=w0
			Make/N=0 $UniqueName("wave", 1, 0)/WAVE=w1
			PopupMenu pwP popmatch=NameOfWave(w0), userData(wave)=GetWavesDataFolder(w0,2), win=$s.win
			PopupMenu qwP popmatch=NameOfWave(w1), userData(wave)=GetWavesDataFolder(w1,2), win=$s.win
			SetDataFolder dfrSav
			break
			
		case "helpB":
			KMOpenHelpNote("positionrecorder", pnlName=s.win, title="Position Recorder")
			return 0
			
	endswitch
	pnlUpdate(s.win)
End
//-------------------------------------------------------------
//	ポップアップ
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	//	選択されたウエーブへのパスを保管する
	Wave/Z w = $s.popStr
	if (WaveExists(w))
		PopupMenu $s.ctrlName userData(wave)=GetWavesDataFolder(w,2), win=$s.win
	else		//	_none_ の選択
		PopupMenu $s.ctrlName userData(wave)="", win=$s.win
		pnlUpdate(s.win)
		return 1
	endif
	
	//	これが非負であれば、データ点数がptsであるようなウエーブだけがポップアップにリストされる(制限状態)
	int pts = str2num(GetUserData(s.win, s.ctrlName, "pts"))
	
	//	制限状態であったならば、それを解除する
	//	なかったならば、もう1方のポップアップを制限状態にしてポップアップリストを更新する
	if (pts >= 0)
		PopupMenu $s.ctrlName userData(pts)="-1", win=$s.win
	else
		String name = theOtherPopupName(s.ctrlName)
		PopupMenu $name userData(pts)=num2istr(numpnts(w)), userData(wave)="", win=$s.win
		ControlUpdate/W=$s.win $name
		//	選択肢が実質1つ(_none_ともう1つ)であれば、その1つを選択状態にする
		String popListStr = popupStr(name)
		if (ItemsInList(popListStr) == 2)
			PopupMenu $name mode=2, userData(wave)=GetWavesDataFolder($StringFromList(1,popListStr),2), win=$s.win
		endif
	endif
	
	//	表示状態の更新
	pnlUpdate(s.win)
	return 0
End

//	ポップアップメニューに表示する文字列
Static Function/S popupStr(String ctrlName)
	String pnlName = WinName(0,1) + "#PositionRecorder"
	String listStr = "_none_;"
	
	//	これが非負なら点数がptsであるようなウエーブだけをリストする
	int pts = str2num(GetUserData(pnlName, ctrlName, "pts"))
	
	if (pts < 0)
		listStr += WaveList("*",";","DIMS:1,TEXT:0,WAVE:0")
		listStr += WaveList("*",";","DIMS:0,TEXT:0,WAVE:0")
		return listStr
	endif
	
	ControlInfo/W=$pnlName $theOtherPopupName(ctrlName)
	String optionStr
	if (pts == 0)
		optionStr = "DIMS:0,TEXT:0,WAVE:0"
	else
		sprintf optionStr, "DIMS:1,TEXT:0,WAVE:0,MINROWS:%d,MAXROWS:%d", pts, pts
	endif
	listStr += WaveList("!"+S_value,";", optionStr)	//	他方で選ばれているウエーブはリストしない
	return listStr
End

Static Function/S theOtherPopupName(String ctrlName)
	return SelectString(CmpStr(ctrlName, "pwP"), "qwP", "pwP")
End

//-------------------------------------------------------------
//	表示状態の更新
//-------------------------------------------------------------
Static Function pnlUpdate(String pnlName)	
	Wave/Z pw = $GetUserData(pnlName, "pwP", "wave"), qw = $GetUserData(pnlName, "qwP", "wave")
	
	//	パネル表示状態の更新
	Variable nowave = !WaveExists(pw) || !WaveExists(qw)
	Variable notab = !strlen(ChildWindowList(pnlName))
	
	Button startB disable=(nowave||!notab)*2, win=$pnlName
	
	//	位置ウエーブの表示
	if (!nowave)
		String grfName = StringFromList(0, pnlName, "#")
		CheckDisplayed/W=$grfName qw
		if (V_flag)		//	既に表示されていたら
			return 0
		endif
		Wave w = KMGetImageWaveRef(grfName)
		AppendToGraph/W=$grfName qw vs pw
		ModifyGraph/W=$grfName offset($NameOfWave(qw))={DimOffset(w,0),DimOffset(w,1)}
		ModifyGraph/W=$grfName muloffset($NameOfWave(qw))={DimDelta(w,0),DimDelta(w,1)}, mode($NameOfWave(qw))=3
	endif
End
