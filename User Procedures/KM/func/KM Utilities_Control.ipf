#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	KMTabControlProc
//		タブによるdisableの変更を担う. 前提として、タブによるdisableの変更を受けるコントロールについては
//		予め、userData(tab)により、所属するタブの番号を記録しておくこと。また、コントロールを定義する
//		際にdisableを指定しておくと、それは対応するタブが開かれたときの初期表示状態を意味する
//******************************************************************************
Function KMTabControlProc(STRUCT WMTabControlAction &s)	
	String listStr, tabInfo, ctrlName, cwinName
	int lastTab = str2num(GetUserData(s.win,s.ctrlName,"KM_LastTab"))
	int disable_saved
	int i, n
	
	//	コントロールについて
	listStr = ControlNameList(s.win)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		ctrlName = StringFromList(i,listStr)
		tabInfo = GetUserData(s.win, ctrlName, "tab")
		if (!strlen(tabInfo))		//	タブに関係ないコントロール
			continue
		elseif (str2num(tabInfo) == s.tab)		//	クリックされたタブに属する場合
			disable_saved = str2num(GetUserData(s.win, s.ctrlName, ctrlName))
			ModifyControl/Z $ctrlName, disable=disable_saved, win=$s.win
		elseif (str2num(tabInfo) == lastTab)		//	クリックされる前までに表示されていたタブに属する場合
			ControlInfo/W=$s.win $ctrlName
			TabControl $s.ctrlName userData($ctrlName)=num2istr(V_Disable), win=$s.win	//	次に表示する場合に備えて,disableの状態を記録しておく
			ModifyControl/Z $ctrlName, disable=1, win=$s.win
		endif
	endfor
	
	//	サブウインドウについて
	listStr = ChildWindowList(s.win)
	for (i = 0, n = ItemsInList(listStr); i < n; i += 1)
		cwinName = s.win + "#" + StringFromList(i, listStr)
		tabInfo = GetUserData(cwinName, "", "tab")
		if (!strlen(tabInfo))		//	タブに関係ないサブウインドウ
			continue
		elseif (str2num(tabInfo) == s.tab)		//	クリックされたタブに属する場合
			disable_saved = str2num(GetUserData(s.win, s.ctrlName, cwinName))
			SetWindow $cwinName hide=disable_saved
		elseif (str2num(tabInfo) == lastTab)		//	クリックされる前までに表示されていたタブに属する場合
			GetWindow $cwinName hide
			TabControl $s.ctrlName userData($cwinName)=num2istr(V_value), win=$s.win	//	次に表示する場合に備えて,hideの状態を記録しておく
			SetWindow $cwinName hide=1
		endif
	endfor
	
	TabControl $s.ctrlName userData(KM_LastTab)=num2istr(s.tab), win=$s.win
End
//-------------------------------------------------------------
//	KMTabControlInitialize
//		タブに関連したコントロールの初期状態を記録した上で、最終的な表示
//		状態にする
//-------------------------------------------------------------
Function KMTabControlInitialize(pnlName,tabName)
	String pnlName,tabName
	
	String listStr, tabInfo, ctrlName, cwinName
	int i, n
	
	ControlInfo/W=$pnlName $tabName ;	Variable tabNum = V_Value
	
	listStr = ControlNameList(pnlName)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		ctrlName = StringFromList(i,listStr)
		tabInfo = GetUserData(pnlName,ctrlName,"tab")
		if (strlen(tabInfo))
			ControlInfo/W=$pnlName $ctrlName
			TabControl $tabName userData($ctrlName)=num2istr(V_Disable), win=$pnlName
			if (str2num(tabInfo) != tabNum)
				ModifyControl/Z $ctrlName, disable=1, win=$pnlName
			endif
		endif
	endfor
	
	listStr = ChildWindowList(pnlName)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		cwinName = pnlName + "#" + StringFromList(i, listStr)
		tabInfo = GetUserData(cwinName, "", "tab")
		if (strlen(tabInfo))
			GetWindow $cwinName hide
			TabControl $tabName userData($cwinName)=num2istr(V_value), win=$pnlName
			if (str2num(tabInfo) != tabNum)
				SetWindow $cwinName hide=1
			endif
		endif
	endfor
	
	TabControl $tabName userData(KM_LastTab)=num2str(tabNum), win=$pnlName
End


//******************************************************************************
//	KMChangeAllControlsDisableState
//		disableの状態がbeforeであるようなコントロールのdisbleをafterへ変更する
//******************************************************************************
Function KMChangeAllControlsDisableState(pnlName,before,after)
	String pnlName
	int before, after
	
	int i
	String ctrlName
	for (i = 0; i < ItemsInList(ControlNameList(pnlName)); i++)
		ctrlName = StringFromList(i,ControlNameList(pnlName))
		ControlInfo/W=$pnlName $ctrlName
		if (V_disable == before)
			ModifyControl/Z $ctrlName, disable=after, win=$pnlName
		endif
	endfor
End


//******************************************************************************
//	KMGetVarLimits
//		値設定の最小値・最大値・ステップを取得する
//******************************************************************************
Function KMGetVarLimits(pnlName,ctrlName,kind)
	String pnlName, ctrlName
	int kind	//	0: 最小値, 1: 最大値, 2: ステップ
	
	DoWindow $pnlName
	if (!V_Flag)
		return NaN
	endif
	ControlInfo/W=$pnlName $ctrlName
	if (V_Flag != 5 && V_Flag != -5)
		return NaN
	endif
	if (kind != 0 && kind != 1 && kind != 2)
		return NaN
	endif
	
	Variable num1 = strsearch(S_recreation,"limits={",0)+8
	Variable num2 = strsearch(S_recreation,"}",num1)-1
	return str2num(StringFromList(kind,S_recreation[num1,num2],","))
End


//******************************************************************************
//	KMCheckSetVarString
//		値設定の文字列変数の内容をチェックする
//		mode 0: 長さ, mode 1: eval可能かどうか
//		不可の場合、値設定の背景色を変える
//******************************************************************************
Function KMCheckSetVarString(pnlName,ctrlName,mode,[minlength, maxlength])
	String pnlName, ctrlName
	int mode, minlength, maxlength
	
	String str
	ControlInfo/W=$pnlName $ctrlName
	if (strlen(S_DataFolder))	//	グローバル変数を使っている場合
		SVAR/SDFR=$S_DataFolder gstr = $S_value
		str = gstr
	else						//	内部変数を使っている場合
		str = S_value
	endif
	
	if (ParamIsDefault(minlength))
		minlength = 1
	endif
	if (ParamIsDefault(maxlength))
		maxlength = MAX_OBJ_NAME
	endif
	
	int rtn
	if (mode)
		rtn = numtype(KMEval(str)) > 0
	else
		rtn = strlen(str) < minlength || strlen(str) > maxlength
	endif
	
	if (rtn)
		SetVariable $ctrlName valueBackColor=(KM_CLR_CAUTION_R,KM_CLR_CAUTION_B,KM_CLR_CAUTION_B), userData(check)="1", win=$pnlName
	else
		SetVariable $ctrlName valueBackColor=0, userData(check)="", win=$pnlName
	endif
	return rtn
End

//-------------------------------------------------------------
//	KMEval
//		入力された文字列を評価して数字を返す
//-------------------------------------------------------------
Static Function KMEval(str)
	String str
	
	DFREF dfrSav = GetDataFolderDFR(), dfrTmp = NewFreeDataFolder()
	SetDataFolder dfrTmp
	Execute/Q/Z "Variable/G v=" + str
	SetDataFolder dfrSav
	
	if (V_flag)
		return NaN
	else
		NVAR/SDFR=dfrTmp v
		return v
	endif
End


//******************************************************************************
//	KMKillControls
//		グラフgrfNameに表示されているコントロールを全て消去します
//		コントロールバーが表示されている場合には、その高さを0にします
//******************************************************************************
Function KMKillControls(grfName,[ctrlList])
	String grfName, ctrlList
	
	String listStr = SelectString(ParamIsDefault(ctrlList), ctrlList, ControlNameList(grfName))
	int i, n = ItemsInList(listStr)
	
	for (i = 0; i < n; i++)
		KillControl/W=$grfName $StringFromList(i,listStr)
	endfor
	
	if (ParamIsDefault(ctrlList))
		ControlInfo/W=$grfName kwControlBar
		if (V_Height)
			ControlBar/W=$grfName 0
		endif
	endif
End


//******************************************************************************
//	KMGetWaveRefFromPopup
//		ポップアップがウエーブを選択するものであった場合(要userdata(srcDF))に
//		選択されているウエーブへの参照を返す
//******************************************************************************
Function/WAVE KMGetWaveRefFromPopup(pnlName, ctrlName)
	String pnlName, ctrlName
	
	ControlInfo/W=$pnlName $ctrlName
	if (strlen(StringByKey("value",S_recreation,"=",",")) <= 9)	//	何も選択されていないとき
		return $""
	endif
	
	Wave/Z w = $(GetUserData(pnlName, ctrlName, "srcDf") + PossiblyQuoteName(S_Value))
	if (WaveExists(w))
		return w
	else
		return $""
	endif
End


//******************************************************************************
//	KMGetCtrlValues, KMGetCtrlTexts
//		コントロール名のリストを渡して、コントロールの値を持つウエーブを返す
//******************************************************************************
//	数値ウエーブを返す。コントロールが文字列だった場合にはevalする
Function/WAVE KMGetCtrlValues(win, ctrlList)
	String win, ctrlList
	
	Make/N=(ItemsInList(ctrlList))/FREE resw
	int i, n = ItemsInList(ctrlList)
	for (i = 0; i < n; i++)
		ControlInfo/W=$win $StringFromList(i, ctrlList)
		switch (V_Flag)
			case 0:	//	not found
				resw[i] = NaN
				break
			case 5:	//	SetVariable
				switch (valueType(S_recreation))
					case 0:
					case 1:
						resw[i] = V_Value
						break
					case 2:
						resw[i] = KMEval(S_Value)
						break
					case 3:
						SVAR/SDFR=$S_DataFolder str = $S_value
						resw[i] = KMEval(str)
						break
					default:
						resw[i] = NaN
				endswitch
				break
			default:	//	others
				resw[i] = V_Value
		endswitch
	endfor
	
	return resw
End

//	コントロールの初期値を含む数値ウエーブを返す。初期値はuserData(init)で保存されていること
Function/WAVE KMGetCtrlInitValues(win, ctrlList)
	String win, ctrlList
	
	//	GetUserDataが空文字を返した場合はNaNが代入される
	Make/N=(ItemsInList(ctrlList))/FREE resw = str2num(GetUserData(win,StringFromList(p, ctrlList),"init"))
	return resw
End

//	文字列ウエーブを返す。コントロールが数値だった場合にはnum2strする
Function/WAVE KMGetCtrlTexts(win, ctrlList)
	String win, ctrlList
	
	Make/N=(ItemsInList(ctrlList))/T/FREE resw
	int i, n = ItemsInList(ctrlList)
	for (i = 0; i < n; i++)
		ControlInfo/W=$win $StringFromList(i, ctrlList)
		switch (V_Flag)
			case 0:	//	not found
				resw[i] = ""
				break
			case 5:	//	SetVariable
				switch (valueType(S_recreation))
					case 0:
					case 1:
						resw[i] = num2str(V_Value)
						break
					case 2:
						resw[i] = S_Value
						break
					case 3:
						SVAR/SDFR=$S_DataFolder str = $S_Value
						resw[i] = str
						break
					default:
						resw[i] = ""
				endswitch
			default:	//	others
				resw[i] = S_Value
		endswitch
	endfor
	
	return resw
End

//	ControlInfoで得られるS_recreationから、そのSetVariableが対象とする変数の種類を返す
Static Function valueType(String recreationStr)	
	Variable n0 = strsearch(recreationStr, "value=", 0)
	Variable n1 = strsearch(recreationStr, ",", n0)
	Variable n2 = strsearch(recreationStr, "\r", n0)
	Variable n3 = (n1 == -1) ? n2 : min(n1, n2)
	String valueStr = recreationStr[n0+6,n3-1]
	
	NVAR/Z npath = $valueStr
	SVAR/Z spath = $valueStr
	if (strsearch(valueStr, "_NUM:", 0) != -1)
		return 0		//	数値・内部変数
	elseif (NVAR_Exists(npath))
		return 1		//	数値・外部変数
	elseif (strsearch(valueStr, "_STR:", 0) != -1)
		return 2		//	文字列・内部変数
	elseif (SVAR_Exists(spath))
		return 3		//	文字列・外部変数
	else
		return -1	//	?
	endif
End


//******************************************************************************
//	KMCtrlClicked:	グループボックスがクリックされたかどうかを返す
//******************************************************************************
Function KMCtrlClicked(STRUCT WMWinHookStruct &s, String grpName)
	ControlInfo/W=$s.winName $grpName
	return (V_left < s.mouseLoc.h && s.mouseLoc.h < V_left + V_width && V_top < s.mouseLoc.v && s.mouseLoc.v < V_top + V_height)
End


//******************************************************************************
//	KMPopupTo:	
//******************************************************************************
Function KMPopupTo(STRUCT WMPopupAction &s, String paramStr)
	switch (s.popNum)
		case 1:
			ToCommandLine paramStr
			break
		case 2:
			PutScrapText paramStr
			break
	endswitch
End


//******************************************************************************
//	KMClickButton
//		実際にクリックするのと同じように(厳密に同じではない)コントロール関数を呼び出す、button用
//******************************************************************************
Function KMClickButton(pnlName,ctrlName,eventCode)
	String pnlName, ctrlName
	Variable eventCode
	
	if (!KMWindowExists(pnlName))
		return 1
	endif
	
	ControlInfo/W=$pnlName $ctrlName
	if (V_Flag != 1)
		return 2
	endif
	
	String fnName = KMGetActionFunctionName(S_recreation)
	if (!strlen(fnName))
		return 3
	else
		FUNCREF KMClickButtonPrototype fn = $fnName
	endif
	
	STRUCT WMButtonAction s
	s.ctrlName = ctrlName
	s.win = pnlName
	KMClickGetWinRect(pnlName, s.winRect)				//	winRect
	KMClickGetCtrlRect(pnlName, ctrlName, s.ctrlRect)	//	ctrlRect
	//s.mouseLoc.v =
	//s.mouseLoc.h =
	s.eventCode = eventCode
	s.eventMod = KMClickGetEventMod()
	s.userData = S_UserData
	
	fn(s)
End
//******************************************************************************
//	KMClickCheckBox
//		実際にクリックするのと同じように(厳密に同じではない)コントロール関数を呼び出す、checkbox用
//******************************************************************************
Function KMClickCheckBox(String pnlName, String ctrlName)
	if (!KMWindowExists(pnlName))
		return 1
	endif
	
	ControlInfo/W=$pnlName $ctrlName
	if (V_Flag != 2)
		return 2
	endif
	
	//	ラジオボタンの時には、クリックされると(初期値によらず)値は1になる。
	//	ラジオボタンではない時には、値は反転する。
	int mode = NumberByKey("mode",S_recreation,"=",",")
	int newValue = (mode==1) ? 1 : !V_Value
	
	CheckBox $ctrlName value=newValue, win=$pnlName	//	変数が関係付けられている場合にはその変数もこれにより変化する
	
	String fnName = KMGetActionFunctionName(S_recreation)
	if (!strlen(fnName))
		return 3
	else
		FUNCREF KMClickCheckBoxPrototype fn = $fnName
	endif
	
	STRUCT WMCheckboxAction s
	s.ctrlName = ctrlName
	s.win = pnlName
	KMClickGetWinRect(pnlName, s.winRect)				//	winRect
	KMClickGetCtrlRect(pnlName, ctrlName, s.ctrlRect)	//	ctrlRect
	//s.mouseLoc.v =
	//s.mouseLoc.h =
	s.eventCode = 2
	s.eventMod = KMClickGetEventMod()
	s.userData = S_UserData
	s.checked = newValue
	
	fn(s)
End
//******************************************************************************
//	KMClickSetVariable
//		実際にクリックするのと同じように(厳密に同じではない)コントロール関数を呼び出す、setvariable用
//******************************************************************************
Function KMClickSetVariable(pnlName,ctrlName,eventCode)
	String pnlName, ctrlName
	Variable eventCode
	
	if (!KMWindowExists(pnlName))
		return 1
	endif
	
	ControlInfo/W=$pnlName $ctrlName
	if (V_Flag != 5 && V_Flag != -5)
		return 2
	endif
	
	String fnName = KMGetActionFunctionName(S_recreation)
	if (!strlen(fnName))
		return 3
	else
		FUNCREF KMClickSetVariablePrototype fn = $fnName
	endif
	
	STRUCT WMSetVariableAction s
	s.ctrlName = ctrlName
	s.win = pnlName
	KMClickGetWinRect(pnlName, s.winRect)				//	winRect
	KMClickGetCtrlRect(pnlName, ctrlName, s.ctrlRect)	//	ctrlRect
	//s.mouseLoc.v =
	//s.mouseLoc.h =
	s.eventCode = eventCode
	s.eventMod = KMClickGetEventMod()
	s.userData = S_UserData
	s.isStr = (numtype(V_Value) == 2)
	s.dval = s.isStr ? NaN : V_Value
	if (s.isStr)
		s.sval = KMClickGetSetVariableString(S_DataFolder+S_value)
	else
		s.sval = num2str(V_Value)
	endif
	s.vName = S_Value
//	s.svWave =
//	s.rowIndex =
//	s.rowLabel =
//	s.colIndex =
//	s.colLabel =
	
	fn(s)
End
//******************************************************************************
//	KMClickPopupMenu
//		実際にクリックするのと同じように(厳密に同じではない)コントロール関数を呼び出す、PopupMenu用
//******************************************************************************
Function KMClickPopupMenu(pnlName, ctrlName, popNum, popStr)
	String pnlName, ctrlName, popStr
	Variable popNum
	
	if (!KMWindowExists(pnlName))
		return 1
	endif
	
	ControlInfo/W=$pnlName $ctrlName
	if (V_Flag != 3 && V_Flag != -3)
		return 2
	endif
	
	String fnName = KMGetActionFunctionName(S_recreation)
	if (!strlen(fnName))
		return 3
	else
		FUNCREF KMClickPopupMenuPrototype fn = $fnName
	endif
	
	STRUCT WMPopupAction s
	s.ctrlName = ctrlName
	s.win = pnlName
	KMClickGetWinRect(pnlName, s.winRect)				//	winRect
	KMClickGetCtrlRect(pnlName, ctrlName, s.ctrlRect)	//	ctrlRect
	//s.mouseLoc.v =
	//s.mouseLoc.h =
	s.eventCode = 2
	s.eventMod = KMClickGetEventMod()
	s.userData = S_UserData
	//s.blockReentry =
	s.popNum = popNum
	s.popStr = popStr
	
	fn(s)
End
//-------------------------------------------------------------
//		プロトタイプ
//-------------------------------------------------------------
Function KMClickButtonPrototype(STRUCT WMButtonAction &s)
End
Function KMClickCheckBoxPrototype(STRUCT WMCheckboxAction &s)
End
Function KMClickSetVariablePrototype(STRUCT WMSetVariableAction &s)
End
Function KMClickPopupMenuPrototype(STRUCT WMPopupAction &s)
End
//-------------------------------------------------------------
//	KMGetActionFunctionName
//		コントロールに関連付けられている関数の名前を返す
//-------------------------------------------------------------
Static Function/S KMGetActionFunctionName(String recreationStr)	
	int num1 = strsearch(recreationStr,"proc=",0)
	if (num1 == -1)
		return ""
	endif
	int num2 = strsearch(recreationStr,",",num1+5)-1
	return recreationStr[num1+5,num2]
End
//-------------------------------------------------------------
//	KMClickGetCtrlRect
//		ウインドウの座標を代入する
//-------------------------------------------------------------
Static Function KMClickGetWinRect(pnlName, winRect)
	String pnlName
	STRUCT Rect &winRect
	
	GetWindow $pnlName wsizeDC
	winRect.top = V_top
	winRect.left = V_left
	winRect.bottom = V_bottom
	winRect.right = V_right
End
//-------------------------------------------------------------
//	KMClickGetCtrlRect
//		コントロールの座標を代入する
//-------------------------------------------------------------
Static Function KMClickGetCtrlRect(pnlName, ctrlName, ctrlRect)
	String pnlName, ctrlName
	STRUCT Rect &ctrlRect
	
	ControlInfo/W=$pnlName $ctrlName
	ctrlRect.top = V_top
	ctrlRect.left = V_left
	ctrlRect.bottom = V_top + V_Height
	ctrlRect.right = V_left + V_Width
End
//-------------------------------------------------------------
//	KMClickGetEventMod
//		eventModを代入する
//-------------------------------------------------------------
Static Function KMClickGetEventMod()
	int key = GetKeyState(1)
	int isCtrlPressed = !!(key & 1)
	int isAltPressed = !!(key & 2)
	int isShiftPressed = !!(key & 4)
	int eventMod = 0
	eventMod += 1		//	クリック時に使われることが前提なのでこれで良い
	eventMod += isShiftPressed*2 + isAltPressed*4 + isCtrlPressed*8
End
//-------------------------------------------------------------
//	KMClickGetSetVariableString
//		SetVariableの変数が文字列のときに、その値を取得する
//-------------------------------------------------------------
Static Function/S KMClickGetSetVariableString(String strPath)
	if (CmpStr(strPath[strlen(strPath)-1],"]"))	//	文字列の場合
		SVAR str = $strPath
		return str
	else		//	ウエーブの場合
		Wave/T w = $(strPath[0,strsearch(strPath,"[",0)-1])
		String numList = ""
		int num1 = 0, num2 = 0
		do
			num1 = strsearch(strPath, "[", num2)
			num2 = strsearch(strPath, "]", num1)
			numList += strPath[num1+1,num2-1] + ";"
		while (num2 < strlen(strPath)-1)
		switch (ItemsInList(numList))
			case 1:
				return w[str2num(StringFromList(0,numList))]
			case 2:
				return w[str2num(StringFromList(0,numList))][str2num(StringFromList(1,numList))]
			default:
				return ""
		endswitch
	endif
End