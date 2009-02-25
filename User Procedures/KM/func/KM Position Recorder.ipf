#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMPositionRecorder

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Static Constant ks_pnlHeight = 109
Static Constant ks_tabHeight = 160

//******************************************************************************
//	KMPositionRecorder
//******************************************************************************
Function KMPositionRecorder()
	
	String grfName = WinName(0,1,1)
	if (!strlen(grfName))
		return 1
	endif
	
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,235,ks_pnlHeight)
	RenameWindow $grfName#$S_name, PositionRecorder
	String pnlName = grfName + "#PositionRecorder"
	
	SetWindow $pnlName hook(self)=KMPositionRecorder#pnlHook, activeChildFrame=0
	
	Button startB pos={7,5}, size={60,18}, title="start", disable=2, proc=KMPositionRecorder#buttonCtrl, win=$pnlName
	Button finishB pos={77,5}, size={60,18}, title="finish", disable=2, proc=KMPositionRecorder#buttonCtrl, win=$pnlName
	Button helpB pos={147, 5}, size={18,18}, title="?", proc=KMPositionRecorder#buttonCtrl, win=$pnlName
	Checkbox gridC pos={189,7}, title="grid", value=1, win=$pnlName
	
	GroupBox waveG pos={8,34}, size={220,72}, title="position waves", win=$pnlName
	PopupMenu pwP pos={16,53}, size={151,20}, bodyWidth=140, mode=1, title="p:", userData(mode)="-1", win=$pnlName
	PopupMenu pwP value=#"KMPositionRecorder#popupStr(\"pwP\")", proc=KMPositionRecorder#popupCtrl, win=$pnlName
	PopupMenu qwP pos={16,79}, size={151,20}, bodyWidth=140 ,mode=1, title="q:", userData(mode)="-1", win=$pnlName
	PopupMenu qwP value=#"KMPositionRecorder#popupStr(\"qwP\")", proc=KMPositionRecorder#popupCtrl, win=$pnlName
	Button waveB pos={180,61}, size={40,30}, title="new", proc=KMPositionRecorder#buttonCtrl, win=$pnlName

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
			
			STRUCT KMMousePos ms
			ControlInfo/w=$pnlName gridC
			if (KMGetMousePos(ms, winhs=s, grid=V_Value))
				return 0
			endif
			
			if (s.eventMod & 0x08)	//	ctrl, 一番近くの点を削除
				Duplicate/FREE pw disw, indexw
				disw = (pw-ms.p)^2 + (qw-ms.q)^2
				indexw = p
				Sort disw, indexw
				DeletePoints indexw[0], 1, pw, qw
			else					//	点を追加
				Variable n = numpnts(pw)
				Redimension/N=(n+1) pw, qw
				pw[n] = ms.p
				qw[n] = ms.q
			endif
			break
	endswitch
	return 0
End
//-------------------------------------------------------------
//	KMPositionRecorderPnlHookClose:	自パネルが閉じられたときの動作
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
Static Function buttonCtrl(s)
	STRUCT WMButtonAction &s
	
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
			break
			
		case "finishB":
			SetWindow $grfName hook(positionrecorder)=$""
			KillWindow $(s.win+"#T0")
			MoveSubWindow/W=$s.win fnum=(0,0,235,ks_pnlHeight)
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
Static Function popupCtrl(s)
	STRUCT WMPopupAction &s
	
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
	
	//	制限モード
	Variable mode = str2num(GetUserData(s.win, s.ctrlName, "mode"))
	
	//	自分が制限されていたら、その制限を解除する
	//	自分がフリーであれば相手を制限する
	if (mode >= 0)
		PopupMenu $s.ctrlName userData(mode)="-1", win=$s.win
	elseif (!CmpStr(s.ctrlName, "pwP"))
		PopupMenu qwP userData(mode)=num2istr(numpnts(w)), userData(wave)="", win=$s.win
	else
		PopupMenu pwP userData(mode)=num2istr(numpnts(w)), userData(wave)="", win=$s.win
	endif
	
	//	表示状態の更新
	pnlUpdate(s.win)
End

//	ポップアップメニューに表示する文字列
Static Function/S popupStr(ctrlName)
	String ctrlName
	
	String pnlName = WinName(0,1) + "#PositionRecorder"
	Variable num = str2num(GetUserData(pnlName, ctrlName, "mode"))	//	制限モードにある場合には 非負
	
	String nameStr, optionStr
	if (num < 0)
		nameStr = "*"
		optionStr = "DIMS:1"
	else
		ControlInfo/W=$pnlName $SelectString(CmpStr(ctrlName, "pwP"), "qwP", "pwP")
		nameStr = "!" + S_value	//	他方で選ばれているウエーブはリストしない
		optionStr = "DIMS:" + num2istr(num > 0)
		optionStr += ",MINROWS:" + num2istr(num) + ",MAXROWS:" + num2istr(num)
	endif
	String list = "_none_;" + WaveList(nameStr,";", optionStr)
	
	if (num < 0)	//	非制限モードの時には 個数が 0 のウエーブもリストに加える
		list += ";" + WaveList("*",";","DIMS:0")
	endif
	
	return list
End

//-------------------------------------------------------------
//	KMPositionRecorderPnlUpdate :		表示状態の更新
//-------------------------------------------------------------
Static Function pnlUpdate(pnlName)
	String pnlName
	
	Wave/Z pw = $GetUserData(pnlName, "pwP", "wave"), qw = $GetUserData(pnlName, "qwP", "wave")
	
	//	パネル表示状態の更新
	Variable nowave = !WaveExists(pw) || !WaveExists(qw)
	Variable notab = !strlen(ChildWindowList(pnlName))
	
	Button startB disable=(nowave||!notab)*2, win=$pnlName
	Button finishB disable=notab*2, win=$pnlName
	Button waveB disable=!notab*2, win=$pnlName
	
	//	位置ウエーブの表示
	if (!nowave)
		String grfName = StringFromList(0, pnlName, "#")
		CheckDisplayed/W=$grfName qw
		if (V_flag)		//	既に表示されていたら
			return 0
		endif
		Wave w = KMGetImageWaveRef(grfName)
		AppendToGraph/W=$grfName qw vs pw
		ModifyGraph/W=$grfName offset($NameOfWave(qw))={DimOffset(w,0),DimOffset(w,1)},muloffset($NameOfWave(qw))={DimDelta(w,0),DimDelta(w,1)}, mode=3
	endif
End
