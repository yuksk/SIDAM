#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMLineCommon

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant CTRLHEIGHT1D = 96
Static Constant CTRLHEIGHT2D = 70

//=====================================================================================================
//
//	パネル表示について
//
//-------------------------------------------------------------
//	パネルコントロールを作成・配置する
//-------------------------------------------------------------
Static Function pnlCtrls(String pnlName)

	Wave w = $GetUserData(pnlName,"","src")
	int nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)

	//	2次元ウエーブのラインプロファイルを表示するときには次元切り替えがないので、2Dイメージ用のガイドを使う
	Variable height = WaveDims(w)==2 ? CTRLHEIGHT2D*72/screenresolution : CTRLHEIGHT1D*72/screenresolution
	DefineGuide/W=$pnlName KMFT={FT, height}

	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(GetUserData(pnlName,"","parent"),NameOfWave(w),s)

	//	コントロール項目の初期値
	int pmin = max(s.pmin, 0), pmax = min(s.pmax, DimSize(w,0)-1)
	int qmin = max(s.qmin, 0), qmax = min(s.qmax, DimSize(w,1)-1)
	int p1 = round(pmin*0.75 + pmax*0.25), q1 = round(qmin*0.75 + qmax*0.25)
	int p2 = round(pmin*0.25 + pmax*0.75), q2 = round(qmin*0.25 + qmax*0.75)
	Variable distance = sqrt((p1-p2)^2*dx^2+(q1-q2)^2*dy^2)
	Variable angle = atan2((q2-q1)*dy,(p2-p1)*dx)/pi*180

	CheckBox p1C title="start (1)", pos={11,5}, value=1, proc=SIDAMLineCommon#pnlCheck, win=$pnlName
	SetVariable p1V title="p1:", pos={12,25}, value=_NUM:p1, limits={0,nx-1,1}, win=$pnlName
	SetVariable q1V title="q1:", pos={12,46}, value=_NUM:q1, limits={0,ny-1,1}, win=$pnlName

	CheckBox p2C title="end (2)", pos={97,5}, value=1, proc=SIDAMLineCommon#pnlCheck, win=$pnlName
	SetVariable p2V title="p2:", pos={101,25}, value=_NUM:p2, limits={0,nx-1,1}, win=$pnlName
	SetVariable q2V title="q2:", pos={101,46}, value=_NUM:q2, limits={0,ny-1,1}, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" size={73,16}, bodyWidth=55, format="%d", win=$pnlName

	SetVariable distanceV title="distance:", pos={188,25}, size={121,16}, value=_NUM:distance, bodyWidth=70, win=$pnlName
	SetVariable angleV title="angle:", pos={206,46}, size={103,15}, value=_NUM:angle, bodyWidth=70, win=$pnlName
	pnlSetVarIncrement(pnlName)

	if (WaveDims(w) == 3)
		TitleBox waterT title="waterfall", pos={11,76}, frame=0, win=$pnlName
		SetVariable axlenV title="axlen:", pos={69,74}, size={90,18}, bodyWidth=55, win=$pnlName
		SetVariable axlenV value=_NUM:0.5, limits={0.1,0.9,0.01}, proc=SIDAMLineCommon#pnlSetVarAxlen, win=$pnlName
		CheckBox hiddenC title="hidden", pos={173,76}, value=0, proc=SIDAMLineCommon#pnlCheck, win=$pnlName

		SetDrawLayer/W=$pnlName ProgBack
		SetDrawEnv/W=$pnlName xcoord=rel, ycoord=abs, fillfgc=(58e3,58e3,58e3), linefgc=(58e3,58e3,58e3), linethick=1
		DrawRect/W=$pnlName 0,CTRLHEIGHT2D*72/screenresolution,1,CTRLHEIGHT1D*72/screenresolution
	endif

	SetWindow $pnlName activeChildFrame=0

	changeIgorMenuMode(0)
End
//-------------------------------------------------------------
//	表示するプロファイルの次元を変える
//-------------------------------------------------------------
Static Function pnlChangeDim(String pnlName, int dim)
	Wave w = $GetUserData(pnlName,"","src")
	SetWindow $pnlName userData(dim)=num2istr(dim)

	int hideLine = (WaveDims(w)==3 && dim==2) ? 1 : 0
	Variable height = hideLine ? CTRLHEIGHT2D*72/screenresolution : CTRLHEIGHT1D*72/screenresolution

	DefineGuide/W=$pnlName KMFT={FT, height}
	SetWindow $pnlName#line hide=hideLine
	SetWindow $pnlname#image hide=!hideLine
	DoUpdate/W=$pnlname
	TitleBox waterT disable=hideLine, win=$pnlName
	SetVariable axlenV disable=hideLine, win=$pnlName
	CheckBox hiddenC disable=hideLine, win=$pnlName
End
//-------------------------------------------------------------
//	Igorメニューの切り替え
//-------------------------------------------------------------
Static Function changeIgorMenuMode(int mode)
	if (mode)
		SetIgorMenuMode "File", "Save Graphics", EnableItem
		SetIgorMenuMode "Edit", "Export Graphics", EnableItem
		SetIgorMenuMode "Edit", "Copy", EnableItem
	else
		SetIgorMenuMode "File", "Save Graphics", DisableItem
		SetIgorMenuMode "Edit", "Export Graphics", DisableItem
		SetIgorMenuMode "Edit", "Copy", DisableItem
	endif
End


//=====================================================================================================
//
//	Window hook functions
//
//-------------------------------------------------------------
//	Helper of the parent hook function, mouse
//-------------------------------------------------------------
Static Function pnlHookParentMouse(STRUCT WMWinHookStruct &s,	String pnlName)

	STRUCT SIDAMMousePos ms
	Wave cvw = KMGetCtrlValues(pnlName,"p1C;p2C")
	int isp1Checked = cvw[0], isp2Checked = cvw[1]
	int isBothFixed = !isp1Checked && !isp1Checked
	int isGrid = str2num(GetUserData(pnlName,"","grid"))
	int isShiftPressed = s.eventMod & 2
	int isAltPressed = s.eventMod & 4
	int isRightClick = s.eventMod & 16
	int isMouseOut = SIDAMGetMousePos(ms,s.winName,s.mouseLoc,grid=isGrid)
	int isAfterClicked = strlen(GetUserData(pnlName,"","clicked"))

	switch (s.eventCode)
		case 3:	//	mousedown
			if (isAltPressed || isShiftPressed || isRightclick || isMouseOut || isBothFixed)
				break
			endif
			if (isAfterClicked)
				SetWindow $pnlName userData(clicked)=""
				break
			endif
			if (isp1Checked)
				SetVariable p1V value=_NUM:ms.p, win=$pnlName
				SetVariable q1V value=_NUM:ms.q, win=$pnlName
			endif
			if (isp2Checked)
				SetVariable p2V value=_NUM:ms.p, win=$pnlName
				SetVariable q2V value=_NUM:ms.q, win=$pnlName
			endif
			SetWindow $pnlName userData(clicked)="1"
			break

		case 4 :	//	mousemoved
			if (isShiftPressed || isMouseOut || !isAfterClicked)
				break
			elseif (isp2Checked)
				SetVariable p2V value=_NUM:ms.p, win=$pnlName
				SetVariable q2V value=_NUM:ms.q, win=$pnlName
			elseif (isp1Checked)
				SetVariable p1V value=_NUM:ms.p, win=$pnlName
				SetVariable q1V value=_NUM:ms.q, win=$pnlName
			endif
			break

	endswitch

	pnlSetDistanceAngle(pnlName)
End

//-------------------------------------------------------------
//	Helper of the parent hook function
//	Check the presence of children, and run the closing process
//	unless a child exists.
//-------------------------------------------------------------
Static Function pnlHookParentCheckChild(String grfName, String key,
	FUNCREF SIDAMLineCommonResetPrototype resetFn)

	String pnlList = GetUserData(grfName,"",key), pnlName
	DFREF dfrTmp
	int i, n

	for (i = 0, n = ItemsInList(pnlList); i < n; i++)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		dfrTmp = $StringFromList(1,StringFromList(i,pnlList),"=")
		if (!SIDAMWindowExists(pnlName))
			resetFn(grfName, pnlName)
			SIDAMKillDataFolder(dfrTmp)
		endif
		if (!ItemsInList(GetUserData(grfName,"",key)))
			return 1
		endif
	endfor
	return 0
End

Function SIDAMLineCommonResetPrototype(String s0, String s1)
End

//-------------------------------------------------------------
//	Helper of the parent hook function, rename
//-------------------------------------------------------------
Static Function pnlHookParentRename(STRUCT WMWinHookStruct &s, String key)
	String pnlList = GetUserData(s.winName,"",KEY), pnlName
	int i, n

	for (i = 0, n = ItemsInList(pnlList); i < n; i += 1)
		pnlName = StringFromList(0,StringFromList(i,pnlList),"=")
		String parentList = GetUserData(pnlName, "", "parent")
		SetWindow $pnlName userData(parent)=\
			AddListItem(s.winName,RemoveFromList(s.oldWinName,parentList))
	endfor
End

//-------------------------------------------------------------
//	Hook function of the panel, main
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 0: 	//	activate
			//	In case the parent window had been closed before compiling
			String parentList = GetUserData(s.winName,"","parent")
			int i, n
			for (i = 0, n = ItemsInList(parentList); i < n; i++)
				if (SIDAMWindowExists(StringFromList(i,parentList)))
					pnlSetVarIncrement(s.winName)
					changeIgorMenuMode(0)
					return 0
				endif
			endfor
			SIDAMKillDataFolder($GetUserData(s.winName,"","dfTmp"))
			KillWindow $s.winName
			changeIgorMenuMode(1)
			return 0

		case 1:	//	deactivate
			changeIgorMenuMode(1)
			return 0

		case 2:	//	kill
			changeIgorMenuMode(1)
			//	Removing the hook function of the parent window (the parent hook function)
			//	will be done by itself because it will detect this panel is closed.
			//	Similarly, SIDAMKillDataFolder below also can be done by the parent hook
			//	function. However, if SIDAMKillDataFolder below is removed, the trajectory
			//	trace will not be removed from the parent window immediately after the panel
			//	is close but will be removed when the mouse cursor is on the parent window
			//	and the parent hook function is called. This is why SIDAMKillDataFolder below
			//	is left here instead being moved to the parent hook function.
			SIDAMKillDataFolder($GetUserData(s.winName,"","dfTmp"))
			return 0

		case 3:	//	mousedown
			//	Show the contextmenu for right-clicking in the control bar.
			//	GuideInfo below will give an error if the graph region is clicked.
			//	To prevent this error, confirm the presence of the guide before GuideInfo.
			if (strsearch(GuideNameList(s.winName,""),"KMFT",0) == -1)
				return 0
			endif
			Variable ctrlbarHeight = NumberByKey("POSITION",GuideInfo(s.winName, "KMFT"))*screenresolution/72
			int inCtrlbar = s.mouseLoc.v < ctrlbarHeight
			int isRightClick = s.eventMod & 16
			if (!inCtrlbar || !isRightClick)
				return 0
			endif
			String menuNames = "SIDAMLineProfileMenu;SIDAMLineSpectraMenu;"
			PopupContextualMenu/N StringFromList(whoCalled(s.winName),menuNames)
			return 1

		case 11:	//	keyboard
			return pnlHookKeyboard(s)

		case 13:	//	rename
			pnlHookRename(s)
			return 0

		default:
			return 0
	endswitch
End

Static Function whoCalled(String pnlName)
	String dfTmp = GetUserData(pnlName,"","dfTmp")
	if (strsearch(dfTmp,"LineProfile",0) >= 0)
		return 0
	elseif (strsearch(dfTmp,"LineSpectra",0) >= 0)
		return 1
	else
		return -1
	endif
End

//-------------------------------------------------------------
//	Helper of the panel hook function, rename
//-------------------------------------------------------------
Static Function pnlHookRename(STRUCT WMWinHookStruct &s)
	String dfTmp = GetUserData(s.winName,"","dfTmp")
	if (strlen(dfTmp))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder $dfTmp
		RenameDataFolder $dfTmp, $s.winName
		dfTmp = GetDataFolder(1)	//	new path after renaming
		SetWindow $s.winName userData(dfTmp)=dfTmp
		SetDataFolder dfrSav
	endif

	//	update lists of children
	String parentList = GetUserData(s.winName, "", "parent")
	String key = GetUserData(s.winName,"","key")
	String parentName, oldList
	int i, n
	for (i = 0, n = ItemsInList(parentList); i < n; i++)
		parentName = StringFromList(i,parentList)
		oldList = GetUserData(parentName,"",key)
		SetWindow $parentName userData($key)=\
			AddListItem(s.winName+"="+dfTmp,RemoveByKey(s.oldWinName,oldList,"="))
	endfor
End

//-------------------------------------------------------------
//	Helper of the panel hook function, keyboard
//-------------------------------------------------------------
Static Function pnlHookKeyboard(STRUCT WMWinHookStruct &s)
	switch (s.keycode)
		case 27:	//	esc
			changeIgorMenuMode(1)
			SIDAMKillDataFolder($GetUserData(s.winName,"","dfTmp"))
			KillWindow $s.winName
			return 0

		case 28:		//	left
		case 29:		//	right
		case 30:		//	up
		case 31:		//	down
			keyArrows(s)
			switch (whoCalled(s.winName))
				case 0:
					SIDAMLineProfile#pnlHookArrows(s.winName)
					break
				case 1:
					SIDAMLineSpectra#pnlHookArrows(s.winName)
					break
			endswitch
			return 1

		case 32:	//	space
			keySpace(s)
			return 1

		case 49:	//	1
		case 50:	//	2
			KMClickCheckBox(s.winName,"p"+num2istr(s.keycode-48)+"C")
			return 1

		case 120:	//	x
			int isComplex = WaveType($GetUserData(s.winName,"","src")) & 0x01
			int dim = str2num(GetUserData(s.winName,"","dim"))
			int cmplxMode
			if (!isComplex)
				return 1
			elseif (dim==2)
				cmplxMode = NumberByKey("imCmplxMode",ImageInfo(s.winName+"#image", "", 0),"=")
			else
				cmplxMode = NumberByKey("cmplxMode(x)",TraceInfo(s.winName+"#line", "", 0),"=")
			endif
			changeComplex(s.winName, ++cmplxMode)
			return 1
	endswitch

	switch (s.specialKeyCode)
		case 4:	//	F4
			if (str2num(GetUserData(s.winName,"","dim"))==2)
				KMRange(grfName=s.winName+"#image")
				return 1
			endif
			return 0

		case 5:	//	F5
			if (str2num(GetUserData(s.winName,"","dim"))==2)
				SIDAMColor(grfName=s.winName+"#image")
				return 1
			endif
			return 0
	endswitch

	return 0
End
//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, arrows
//-------------------------------------------------------------
Static Function keyArrows(STRUCT WMWinHookStruct &s)
	//	Do nothing if a cursor is displayed and active
	int i
	String infoStr
	for (i = 65; i <= 74; i++)
		infoStr = CsrInfo($num2char(i), s.winName+"#line")
		if (strlen(infoStr) && strsearch(infoStr,"/A=0",0) == -1)
			return 0
		endif
	endfor

	Wave cvw = KMGetCtrlValues(s.winName,"p1C;p1V;q1V;p2C;p2V;q2V")

	//	Do nothing if neither 1 nor 2 is checked
	if (!cvw[0] && !cvw[3])
		return 0
	endif

	int isLeft = s.keycode == 28, isRight = s.keycode == 29
	int isUp = s.keycode == 30, isDown = s.keycode == 31
	int step = (s.eventMod & 2) ? 10 : 1	//	if the shift key is pressed, move 10 times faster
	int direction = (isLeft || isDown) ? -1 : 1
	Variable pinc = KMGetVarLimits(s.winName, "p1V",2) * step * direction
	Variable qinc = KMGetVarLimits(s.winName, "q1V",2) * step * direction
	Wave w = $GetUserData(s.winName,"","src")
	int nx = DimSize(w,0), ny = DimSize(w,1)

	if (isLeft || isRight)
		SetVariable p1V value=_NUM:limit(cvw[1]+pinc*cvw[0], 0, nx-1), win=$s.winName
		SetVariable p2V value=_NUM:limit(cvw[4]+pinc*cvw[3], 0, nx-1), win=$s.winName
	elseif (isUp || isDown)
		SetVariable q1V value=_NUM:limit(cvw[2]+qinc*cvw[0], 0, ny-1), win=$s.winName
		SetVariable q2V value=_NUM:limit(cvw[5]+qinc*cvw[3], 0, ny-1), win=$s.winName
	endif

	pnlSetDistanceAngle(s.winName)
End
//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, space
//-------------------------------------------------------------
Static Function keySpace(STRUCT WMWinHookStruct &s)
	Variable dim = str2num(GetUserData(s.winName,"","dim"))		//	nan for 2D LineProfile
	if (dim == 1)
		pnlChangeDim(s.winName, 2)
	elseif (dim == 2)
		pnlChangeDim(s.winName, 1)
	endif
	return 0
End
//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, function keys
//-------------------------------------------------------------
Static Function keySpecial(STRUCT WMWinHookStruct &s)
	NVAR/SDFR=$GetUserData(s.winName,"","dfTmp") dim
	if (dim != 2)
		return 0
	endif

	switch (s.specialKeyCode)
		case 4:	//	F4
			KMRange(grfName=s.winName+"#image")
			break
		case 5:	//	F5
			SIDAMColor(grfName=s.winName+"#image")
			break
	endswitch
	return 0
End
//-------------------------------------------------------------
//	Helper of pnlHookKeyboard, complex
//-------------------------------------------------------------
Static Function changeComplex(String pnlName, int mode)
	int dim = str2num(GetUserData(pnlName,"","dim"))

	//	Make mode 0 if it's too large.
	//	This can occur when this function is called by the keyboard shortcut.
	int numOfModes = ItemsInList(SelectString(dim, MENU_COMPLEX2D, MENU_COMPLEX1D))
	mode = mode < numOfModes ? mode : 0

	if (dim==1)
		ModifyGraph/W=$(pnlName+"#line") cmplxMode=mode
	elseif (dim==2)
		ModifyImage/W=$(pnlName+"#image") '' imCmplxMode=mode
	endif
End


//=====================================================================================================
//
//	パネルコントロールについて
//
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "p1C":
		case "p2C":
			ControlInfo/W=$s.win p1C;		int p1Checked = V_Value
			ControlInfo/W=$s.win p2C;		int p2Checked = V_Value

			SetVariable p1V disable=(!p1Checked)*2, win=$s.win
			SetVariable q1V disable=(!p1Checked)*2, win=$s.win
			SetVariable p2V disable=(!p2Checked)*2, win=$s.win
			SetVariable q2V disable=(!p2Checked)*2, win=$s.win
			SetVariable distanceV disable=!(p1Checked || p2Checked)*2, win=$s.win
			SetVariable angleV disable=!(p1Checked || p2Checked)*2, win=$s.win

			//	line profile には widthV が存在する
			ControlInfo/W=$s.win widthV
			if (V_Flag)
				SetVariable widthV disable=!(p1Checked || p2Checked)*2, win=$s.win
			endif

			//	テキストマーカーの表示状態を更新
			GetWindow $s.win hook(self)
			strswitch (StringFromList(0,S_Value,"#"))
				case "KMLineSpectra":
					SIDAMLineSpectra#pnlUpdateTextmarker(s.win)
					break
				case "KMLineProfile":
					SIDAMLineProfile#pnlUpdateTextmarker(s.win)
					break
			endswitch
			break

		case "hiddenC":
			ModifyWaterfall/W=$(s.win+"#line") hidden=s.checked
			break
	endswitch
End
//-------------------------------------------------------------
//	変更されたコントロールの値に応じて、他のコントロールの値を整合性が取れるように変更する
//	つまり、
//	distanceV, angleV の値に応じて p1V, q1V, p2V, q2V の値を設定する
//	あるいは
//	p1V, q1V, p2V, q2V の値に応じて distanceV, angleV の値を設定する
//-------------------------------------------------------------
Static Function pnlSetVarUpdateValues(STRUCT WMSetVariableAction &s)
	DFREF dfrTmp = $GetUserData(s.win,"","dfTmp")
	Wave w = $GetUserData(s.win,"","src")
	int grid = str2num(GetUserData(s.win,"","grid"))

	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Variable ox = DimOffset(w,0), oy = DimOffset(w,1)
	Variable vx, vy

	strswitch (s.ctrlName)
		case "distanceV":
		case "angleV":
			Wave cvw = KMGetCtrlValues(s.win,"p1C;p1V;q1V;p2C;p2V;q2V;distanceV;angleV")
			if (cvw[3])		//	p2Cがチェックされている場合
				vx = limit(ox+dx*cvw[1]+cvw[6]*cos(cvw[7]*pi/180), ox, ox+dx*(nx-1))
				vy = limit(oy+dy*cvw[2]+cvw[6]*sin(cvw[7]*pi/180), oy, oy+dy*(ny-1))
				SetVariable p2V value=_NUM:(grid ? round((vx-ox)/dx) : (vx-ox)/dx), win=$s.win
				SetVariable q2V value=_NUM:(grid ? round((vy-oy)/dy) : (vy-oy)/dy), win=$s.win
			elseif (cvw[0])	//	p1Cがチェックされている場合
				vx = limit(ox+dx*cvw[4]-cvw[6]*cos(cvw[7]*pi/180), ox, ox+dx*(nx-1))
				vy = limit(oy+dy*cvw[5]-cvw[6]*sin(cvw[7]*pi/180), oy, oy+dy*(ny-1))
				SetVariable p1V value=_NUM:(grid ? round((vx-ox)/dx) : (vx-ox)/dx), win=$s.win
				SetVariable q1V value=_NUM:(grid ? round((vy-oy)/dy) : (vy-oy)/dy), win=$s.win
			endif
			//	*** FALLTHROUGH ***
		case "p1V":
		case "p2V":
		case "q1V":
		case "q2V":
			if (strlen(s.ctrlName) == 3)	//	distanceV, angleV でなければ
				SetVariable $s.ctrlName value=_NUM:(grid ? round(s.dval) : s.dval), win=$s.win
			endif
			pnlSetDistanceAngle(s.win)
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	p1V, q1V, p2V, q2V の値に応じて distanceV, angleV の値を設定する
//-------------------------------------------------------------
Static Function pnlSetDistanceAngle(String pnlName)
	Wave cvw = KMGetCtrlValues(pnlName,"p1V;q1V;p2V;q2V")
	Wave w = $GetUserData(pnlName,"","src")
	Variable vx = (cvw[2]-cvw[0])*DimDelta(w,0), vy = (cvw[3]-cvw[1])*DimDelta(w,1)
	SetVariable distanceV value=_NUM:sqrt(vx^2+vy^2), win=$pnlName
	SetVariable angleV value=_NUM:atan2(vy,vx)/pi*180, win=$pnlName
End
//-------------------------------------------------------------
//	値設定のステップを決める, 今のところdistanceだけに使われている
//-------------------------------------------------------------
Static Function pnlSetVarIncrement(String pnlName)
	String grfName = StringFromList(0,GetUserData(pnlName,"","parent"))
	Wave w = KMGetImageWaveRef(grfName)
	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(grfName,NameOfWave(w),s)
	SetVariable distanceV limits={0,inf,sqrt((s.xmax-s.xmin)^2+(s.ymax-s.ymin)^2)/128}, win=$pnlName
End
//-------------------------------------------------------------
//	Waterfall
//-------------------------------------------------------------
Static Function pnlSetVarAxlen(STRUCT WMSetVariableAction &s)
	//	Newwaterfall wave0 vs {*, wavez}
	//	NewWaterfall で wavez が有効になっている時(KMLineProfileで非等間隔バイアスウエーブを扱う時)には
	//	表示ウエーブを削除しても wavez が表示されたままの扱いになってしまう (Igorのバグ?)
	//	そのため、s.win を閉じる時に、エラーが出ないように s.win+#line を先に閉じる
	//	したがって、この関数が呼ばれる際に　s.win+#line が存在しないタイミングがあるため、存在チェックを行う
	if (SIDAMWindowExists(s.win+"#line"))
		ModifyWaterfall/W=$(s.win+"#line") axlen=s.dval
	endif
End

//=====================================================================================================
//
//	右クリックに関して
//
//-------------------------------------------------------------
//	メニュー表示項目
//-------------------------------------------------------------
Static Function/S pnlRightClickMenu(int mode)
	//	pnlHook が起点となって呼ばれたのでなければ続きを実行しない
	String calling = "pnlHook,KM LineCommon.ipf"
	if (strsearch(GetRTStackInfo(3),calling,0))
		return ""
	endif

	String pnlName = WinName(0,1)
	Variable dim = str2num(GetUserData(pnlName,"","dim"))		//	2Dの時は nan が入る

	switch (mode)
		case 0:	//	positions
			String rtnStr = "origin && 0\u00B0;"
			rtnStr += "origin && 30\u00B0;"
			rtnStr += "origin && 45\u00B0;"
			rtnStr += "origin && 60\u00B0;"
			rtnStr += "origin && 90\u00B0;"
			rtnStr += "horizontal;vertical;-;exchange"
			return rtnStr

		case 1:	//	dim
			return SIDAMAddCheckmark(dim-1, "1D traces;2D image")	//	nan　に対しては空文字を返す

		case 2:	//	complex
			int isComplex = WaveType($GetUserData(pnlName,"","src")) & 0x01
			int cmplxMode
			if (!isComplex)
				return ""
			elseif (dim==2)
				cmplxMode = NumberByKey("imCmplxMode",ImageInfo(pnlName+"#image", "", 0),"=")
				return SIDAMAddCheckmark(cmplxMode, MENU_COMPLEX2D)
			else
				cmplxMode = NumberByKey("cmplxMode(x)",TraceInfo(pnlName+"#line", "", 0),"=")
				return SIDAMAddCheckmark(cmplxMode, MENU_COMPLEX1D)
			endif

		case 3:	//	Free
			int grid = str2num(GetUserData(pnlName,"","grid"))
			return SelectString(grid, "! ", "") + "Free"

		case 4:	//	Highlight
			Variable highlight = str2num(GetUserData(pnlName,"","highlight"))	//	2Dの時は nan が入る
			return SelectString(dim==2, "","(") + SelectString(highlight, "Highlight", "! Highlight")				//	nan　に対しては空文字を返す

		case 7:	//	Range
			return SelectString(dim==2, "(","") + "Range..."

		case 8:	//	Color Table
			return SelectString(dim==2, "(","") + "Color Table..."
	endswitch
End
//-------------------------------------------------------------
//	マウス座標を取得するウインドウのリストを作成する
//-------------------------------------------------------------
Static Function/S rightclickMenuTarget()
	String pnlName = WinName(0,1)
	if (!strlen(pnlName))
		return ""
	endif
	
	strswitch (GetUserData(pnlName,"","key"))
		case "SIDAMLineSpectra":
			Wave/Z srcw = $GetUserData(pnlName, "", "src")
			break
		case "SIDAMSpectrumViewer":
			Wave/Z srcw = TraceNameToWaveRef(pnlName,StringFromList(0,TraceNameList(pnlName,";",1)))
			break
		default:
			return ""	//	呼び出し元に関する制限、かつ、ウインドウが表示されていない場合
	endswitch

	if (!WaveExists(srcw))
		return ""
	endif

	String allList = WinList("*",";","WIN:1,VISIBLE:1"), win
	String rtnList = ""		//	メニュー表示用文字列
	String grfList = ""		//	メニュー選択時に使用されるグラフリスト
	int i, n

	for (i = 0, n = ItemsInList(allList); i < n; i += 1)
		win = StringFromList(i, allList)
		Wave/Z imgw = KMGetImageWaveRef(win)
		if (!WaveExists(imgw) || DimSize(srcw,0) != DimSize(imgw,0) || DimSize(srcw,1) != DimSize(imgw,1))
			continue
		elseif (WhichListItem(win, GetUserData(pnlName,"","parent")) != -1)
			rtnList += "\\M0:!" + num2char(18) + ":"+NameOfWave(imgw) + " (" + win + ");"	//	チェックがつき、選択不可
		else
			rtnList += "\\M0" + NameOfWave(imgw) + " (" + win + ");"
		endif
		grfList += win + ";"
	endfor
	SetWindow $pnlName userData(target)=grfList

	return rtnList
End
//-------------------------------------------------------------
//	positionsに関する実行項目
//	メニューでの選択内容に応じて p1V, q1V, p2V, q2V, distanceV, angleV に適切な値を入れる
//-------------------------------------------------------------
Static Function pnlRightclickDoPositions(String pnlName)
	Wave w = $GetUserData(pnlName,"","src")
	int grid = str2num(GetUserData(pnlName,"","grid"))

	int nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = DimDelta(w,0), dy = DimDelta(w,1)
	Variable p1, q1, p2, q2, v
	GetLastUserMenuInfo
	//	origin & x の時の　origin
	if (1 <= V_Value && V_Value <=5)		//	origin & x
		p1 = grid ? round(-DimOffset(w,0)/dx) : -DimOffset(w,0)/dx
		q1 = grid ? round(-DimOffset(w,1)/dy) : -DimOffset(w,1)/dy
	endif
	//	origin & 30, 45, 60　の時に dx != dy の場合に備えて係数を求めておく
	if (2 <= V_value && V_value <= 4)
		Make/D/N=3/FREE tw = {30,45,60}
		v = dy/dx/tan(tw[V_value-2]/180*pi)
	endif
	switch (V_value)
		case 1:	//	origin & 0
			p2 = nx-1;	q2 = q1
			break
		case 2:	//	origin & 30
		case 3:	//	origin & 45
		case 4:	//	origin & 60
			p2 = min(nx-1, p1+(grid ? round((ny-1-q1)*v) : (ny-1-q1)*v))
			q2 = min(ny-1, q1+(grid ? round((nx-1-p1)/v) : (nx-1-p1)/v))
			break
		case 5:	//	origin & 90
			p2 = p1;	q2 = ny-1
			break
		case 6:	//	horizontal
			p1 = 0;	p2 = nx-1;	q1 = Ceil(DimSize(w,1)/2)-1;	q2 = q1
			break
		case 7:	//	vertial
			q1 = 0; 	q2 = ny-1;	p1 = Ceil(DimSize(w,0)/2)-1;	p2 = p1;
			break
		case 9:	//	exchange
			Wave cw = KMGetCtrlValues(pnlName, "p1V;q1V;p2V;q2V")
			p1 = cw[2];	q1 = cw[3];	p2 = cw[0];	q2 = cw[1]
			break
	endswitch
	SetVariable p1V value=_NUM:p1, win=$pnlName
	SetVariable q1V value=_NUM:q1, win=$pnlName
	SetVariable p2V value=_NUM:p2, win=$pnlName
	SetVariable q2V value=_NUM:q2, win=$pnlName

	//	変更後の p1V, q1V, p2V, q2V の値に合わせて angleV, distanceV を変更する
	pnlSetDistanceAngle(pnlName)
End
//-------------------------------------------------------------
//	複素数表示の切り替え
//-------------------------------------------------------------
Static Function pnlRightclickDoComplex(String pnlName)
	GetLastUserMenuInfo
	changeComplex(pnlName, V_value-1)
End
//-------------------------------------------------------------
//	Free/Grid の切り替え
//	p1V, q1V, p2V, q2Vのフォーマットと値を適切に変更する
//	変更後の値に対応するように distanceV と angleV を変更する
//-------------------------------------------------------------
Static Function pnlRightclickDoFree(String pnlName)
	int grid = str2num(GetUserData(pnlName,"","grid"))
	String ctrlList = "p1V;q1V;p2V;q2V"
	ModifyControlList ctrlList format=SelectString(grid,"%d","%.2f"), win=$pnlName
	Wave cvw = KMGetCtrlValues(pnlName,ctrlList), w = $GetUserData(pnlName,"","src")
	if (!grid)
		SetVariable p1V value=_NUM:round(cvw[0]), win=$pnlName
		SetVariable q1V value=_NUM:round(cvw[1]), win=$pnlName
		SetVariable p2V value=_NUM:round(cvw[2]), win=$pnlName
		SetVariable q2V value=_NUM:round(cvw[3]), win=$pnlName
		pnlSetDistanceAngle(pnlName)
	endif
	SetWindow $pnlName userData(grid)=num2istr(!grid)
End
