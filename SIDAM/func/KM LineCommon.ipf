#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName=KMLineCommon

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	KMLineProfileとKMLineSpectraで共通に使用される関数

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
	
	STRUCT KMAxisRange s
	KMGetAxis(GetUserData(pnlName,"","parent"),NameOfWave(w),s)	
	
	//	コントロール項目の初期値
	int p1 = round(s.pmin*0.75 + s.pmax*0.25), q1 = round(s.qmin*0.75 + s.qmax*0.25)
	int p2 = round(s.pmin*0.25 + s.pmax*0.75), q2 = round(s.qmin*0.25 + s.qmax*0.75)
	Variable distance = sqrt((p1-p2)^2*dx^2+(q1-q2)^2*dy^2)
	Variable angle = atan2((q2-q1)*dy,(p2-p1)*dx)/pi*180
	
	CheckBox p1C title="start (1)", pos={11,5}, value=1, proc=KMLineCommon#pnlCheck, win=$pnlName
	SetVariable p1V title="p1:", pos={12,25}, value=_NUM:p1, limits={0,nx-1,1}, win=$pnlName
	SetVariable q1V title="q1:", pos={12,46}, value=_NUM:q1, limits={0,ny-1,1}, win=$pnlName
	
	CheckBox p2C title="end (2)", pos={97,5}, value=1, proc=KMLineCommon#pnlCheck, win=$pnlName
	SetVariable p2V title="p2:", pos={101,25}, value=_NUM:p2, limits={0,nx-1,1}, win=$pnlName
	SetVariable q2V title="q2:", pos={101,46}, value=_NUM:q2, limits={0,ny-1,1}, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V" size={73,16}, bodyWidth=55, format="%d", win=$pnlName
	
	SetVariable distanceV title="distance:", pos={188,25}, size={121,16}, value=_NUM:distance, bodyWidth=70, win=$pnlName
	SetVariable angleV title="angle:", pos={206,46}, size={103,15}, value=_NUM:angle, bodyWidth=70, win=$pnlName
	pnlSetVarIncrement(pnlName)	//	distanceのincrement
	
	if (WaveDims(w) == 3)
		TitleBox waterT title="waterfall", pos={11,76}, frame=0, win=$pnlName
		SetVariable axlenV title="axlen:", pos={69,74}, size={90,18}, bodyWidth=55, win=$pnlName
		SetVariable axlenV value=_NUM:0.5, limits={0.1,0.9,0.01}, proc=KMLineCommon#pnlSetVarAxlen, win=$pnlName
		CheckBox hiddenC title="hidden", pos={173,76}, value=0, proc=KMLineCommon#pnlCheck, win=$pnlName
		
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
//	rev. 1156 の変更に伴う後方互換性の確保
//-------------------------------------------------------------
Static Function pnlCtrlsBackwardCompatibility(String pnlName)
	int disable = str2num(GetUserData(pnlName,"","dim")) == 2
	
	TitleBox waterT title="waterfall", pos={11,76}, frame=0, disable=disable, win=$pnlName
	SetVariable axlenV title="axlen:", pos={69,74}, size={90,18}, bodyWidth=55, disable=disable, win=$pnlName
	SetVariable axlenV value=_NUM:0.5, limits={0.1,0.9,0.01}, proc=KMLineCommon#pnlSetVarAxlen, win=$pnlName
	CheckBox hiddenC title="hidden", pos={173,76}, value=0, disable=disable, proc=KMLineCommon#pnlCheck, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	SetDrawLayer/W=$pnlName ProgBack
	SetDrawEnv/W=$pnlName xcoord=rel, ycoord=abs, fillfgc=(58e3,58e3,58e3), linefgc=(58e3,58e3,58e3), linethick=1
	DrawRect/W=$pnlName 0,CTRLHEIGHT2D*72/screenresolution,1,CTRLHEIGHT1D*72/screenresolution
	
	Variable height = disable ? CTRLHEIGHT2D*72/screenresolution : CTRLHEIGHT1D*72/screenresolution
	DefineGuide/W=$pnlName KMFT={FT, height}
	
	SetWindow $pnlName userData(rev)="1156"
End

//=====================================================================================================
//
//	フック関数について
//
//-------------------------------------------------------------
//	親ウインドウ用共通フック関数
//		1回目のクリックで位置表示用ウエーブの始点に値を代入し、2回目の
//		クリックまで代入し続ける
//-------------------------------------------------------------
Static Function pnlHookParentMouse(
	STRUCT WMWinHookStruct &s,
	STRUCT KMMousePos &ms,
	String pnlName
	)
	
	Wave cvw = KMGetCtrlValues(pnlName,"p1C;p2C")
	int p1Checked = cvw[0], p2Checked = cvw[1]
	
	switch (s.eventCode)
		case 3:	//	mousedown
			//	shiftまたはaltが押されている、マウスポインタが外れている、両方の点が固定されている、
			//	のどれかに当てはまる場合には動作しない
			//	s.eventMod&22 は 2^1+2^2+2^4 で、shiftまたはaltが押されているまたは右クリックを意味する
			if ((s.eventMod&22)|| KMGetMousePos(ms) || (!p1Checked && !p2Checked))
				break
			endif
			if (strlen(GetUserData(pnlName,"","clicked")))	//	2回目のクリック
				SetWindow $pnlName userData(clicked)=""
			else			//  1回目のクリック
				if (p1Checked)
					SetVariable p1V value=_NUM:ms.p, win=$pnlName
					SetVariable q1V value=_NUM:ms.q, win=$pnlName
				endif
				if (p2Checked)
					SetVariable p2V value=_NUM:ms.p, win=$pnlName
					SetVariable q2V value=_NUM:ms.q, win=$pnlName
				endif
				SetWindow $pnlName userData(clicked)="1"
			endif
			break
			
		case 4 :	//	mousemoved
			//	shiftが押されている、マウスポインタが外れている、1回目のクリックの後ではない、
			//	のどれかに当てはまる場合には動作しない
			if ((s.eventMod&2) || KMGetMousePos(ms) || !strlen(GetUserData(pnlName,"","clicked")))
				break
			elseif (p2Checked)		//  以下、1回目のクリックがあった後
				SetVariable p2V value=_NUM:ms.p, win=$pnlName
				SetVariable q2V value=_NUM:ms.q, win=$pnlName
			elseif (p1Checked)
				SetVariable p1V value=_NUM:ms.p, win=$pnlName
				SetVariable q1V value=_NUM:ms.q, win=$pnlName
			endif
			break
			
	endswitch
	
	//	p1V, q1V, p2V, q2V が変更されたら、それに応じて distanceV, angleV を変更する
	pnlSetDistanceAngle(pnlName)
End

//-------------------------------------------------------------
//	パネル用フック関数
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	String stackstr = GetRTStackInfo(3)
	int isCalledFromProfile = strsearch(stackstr,"pnlHook,KM LineProfile.ipf",0) != -1
	int isCalledFromSpectra = strsearch(stackstr,"pnlHook,KM LineSpectra.ipf",0) != -1
	if (!isCalledFromProfile && !isCalledFromSpectra)
		return 0
	endif
	
	switch (s.eventCode)
		case 0: 	//	activate
			//	後方互換性のチェック
			//	rev. 1156 より前に作られたものであれば、後方互換を確保する
			Variable rev = str2num(GetUserData(s.winName,"","rev"))
			if (numtype(rev) || rev < 1156)
				if (isCalledFromProfile)
					KMLineProfile#pnlBackwardCompatibility(s.winName)
				elseif (isCalledFromSpectra)
					KMLineSpectra#pnlBackwardCompatibility(s.winName)
				endif
				pnlCtrlsBackwardCompatibility(s.winName)
			endif
			//	---(後方互換ここまで)
			pnlSetVarIncrement(s.winName)
			changeIgorMenuMode(0)
			return 0
			
		case 1:	//	deactivate
			changeIgorMenuMode(1)
			return 0
			
		case 2:	//	kill
			changeIgorMenuMode(1)
			if (isCalledFromProfile)
				KMLineProfile#pnlHookClose(s)
			endif
			if (isCalledFromSpectra)
				KMLineSpectra#pnlHookClose(s)
			endif
			return 0
			
		case 3:	//	mousedown
			//	コントロール表示領域で右クリックしたときにコンテクストメニューを出す
			
			//	グラフ領域でクリックすると、ガイドが存在しないことになる。次の GuideInfo でエラーが出ないようにここで選別する
			if (strsearch(GuideNameList(s.winName,""),"KMFT",0) == -1)
				break
			endif
			Variable ctrlbarHeight = NumberByKey("POSITION",GuideInfo(s.winName, "KMFT"))*screenresolution/72
			if (s.mouseLoc.v<ctrlbarHeight && (s.eventMod&16))	//	コントロール表示領域で右クリック
				if (isCalledFromProfile)
					PopupContextualMenu/N "KMLineProfileMenu"
				endif
				if (isCalledFromSpectra)
					PopupContextualMenu/N "KMLineSpectraMenu"
				endif
				return 1
			endif
			break
			
		case 11:	//	keyboard
			switch (s.keycode)
				case 27:	//	esc
					changeIgorMenuMode(1)
					if (isCalledFromProfile)
						KMLineProfile#pnlHookClose(s)
					endif
					if (isCalledFromSpectra)
						KMLineSpectra#pnlHookClose(s)
					endif
					return 0
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
					break
				case 5:	//	F5
					if (str2num(GetUserData(s.winName,"","dim"))==2)
						KMColor(grfName=s.winName+"#image")
						return 1
					endif
					break
			endswitch
			return 0
			
	endswitch
	
	return 0
End
//-------------------------------------------------------------
//	パネル用フック関数: 矢印キーが押された場合の動作
//-------------------------------------------------------------
Static Function keyArrows(STRUCT WMWinHookStruct &s)
	int i
	
	//	カーソルが表示されていて、アクティブな場合は動作しない
	String infoStr
	for (i = 65; i <= 74; i++)
		infoStr = CsrInfo($num2char(i), s.winName+"#line")
		if (strlen(infoStr) && strsearch(infoStr,"/A=0",0) == -1)
			return 0
		endif
	endfor
	
	Wave cvw = KMGetCtrlValues(s.winName,"p1C;p1V;q1V;p2C;p2V;q2V")
	
	//	1 も 2 も両方offだったら動作しない
	if (!cvw[0] && !cvw[3])
		return 0
	endif
	
	int mag = (s.eventMod & 2) ? 10 : 1	//	shift を押していたら10倍の速さで動かす
	int direction = (s.keycode == 28 || s.keycode == 31) ? -1 : 1		//	左 or 下　なら -1
	Variable pinc = KMGetVarLimits(s.winName, "p1V",2) * mag * direction
	Variable qinc = KMGetVarLimits(s.winName, "q1V",2) * mag * direction
	Wave w = $GetUserData(s.winName,"","src")
	int nx = DimSize(w,0), ny = DimSize(w,1)
	
	switch (s.keycode)
		case 28:		//	左
		case 29:		//	右
			SetVariable p1V value=_NUM:limit(cvw[1]+pinc*cvw[0], 0, nx-1), win=$s.winName
			SetVariable p2V value=_NUM:limit(cvw[4]+pinc*cvw[3], 0, nx-1), win=$s.winName
			break
		case 30:		//	上
		case 31:		//	下
			SetVariable q1V value=_NUM:limit(cvw[2]+qinc*cvw[0], 0, ny-1), win=$s.winName
			SetVariable q2V value=_NUM:limit(cvw[5]+qinc*cvw[3], 0, ny-1), win=$s.winName
			break
	endswitch
	
	//	p1V, q1V, p2V, q2V が変更されたら、それに応じて distanceV, angleV を変更する
	pnlSetDistanceAngle(s.winName)
End
//-------------------------------------------------------------
//	パネル用フック関数: スペースキーが押された場合の動作
//-------------------------------------------------------------
Static Function keySpace(STRUCT WMWinHookStruct &s)
	Variable dim = str2num(GetUserData(s.winName,"","dim"))		//	LineProfileの2次元の場合には nan が入る
	if (dim == 1)
		pnlChangeDim(s.winName, 2)
	elseif (dim == 2)
		pnlChangeDim(s.winName, 1)
	endif
	return 0
End
//-------------------------------------------------------------
//	パネル用フック関数: Fnが押された場合の動作
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
			KMColor(grfName=s.winName+"#image")
			break
	endswitch
	return 0
End
//-------------------------------------------------------------
//	複素数表示の切り替え
//-------------------------------------------------------------
Static Function changeComplex(String pnlName, int mode)
	int dim = str2num(GetUserData(pnlName,"","dim"))
	
	//	キーボードショートカットから呼ばれた場合に備えて、modeが大きすぎるときには0へ戻す
	int numOfModes = ItemsInList(SelectString(dim, MENU_COMPLEX2D, MENU_COMPLEX1D))
	mode = mode < numOfModes ? mode : 0
	
	if (dim==1)
		ModifyGraph/W=$(pnlName+"#line") cmplxMode=mode
	elseif (dim==2)
		ModifyImage/W=$(pnlName+"#image") '' imCmplxMode=mode
	endif
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
			//	** THROUGH **
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
	String grfName = GetUserData(pnlName,"","parent")
	Wave w = KMGetImageWaveRef(grfName)
	STRUCT KMAxisRange s
	KMGetAxis(grfName,NameOfWave(w),s)
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
	if (KMWindowExists(s.win+"#line"))
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
	//	KM LineProfile.ipf もしくは KM LineSpectra.ipf にある pnlHook が起点となって呼ばれたのでなければ続きを実行しない
	String calling0 = "pnlHook,KM LineProfile.ipf"
	String calling1 = "pnlHook,KM LineSpectra.ipf"
	String stackstr = GetRTStackInfo(3)
	if (strsearch(stackstr,calling0,0) && strsearch(stackstr,calling1,0))
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
			return KMAddCheckmark(dim-1, "1D traces;2D image")	//	nan　に対しては空文字を返す
			
		case 2:	//	complex
			int isComplex = WaveType($GetUserData(pnlName,"","src")) & 0x01
			int cmplxMode
			if (!isComplex)
				return ""
			elseif (dim==2)
				cmplxMode = NumberByKey("imCmplxMode",ImageInfo(pnlName+"#image", "", 0),"=")
				return KMAddCheckmark(cmplxMode, MENU_COMPLEX2D)
			else
				cmplxMode = NumberByKey("cmplxMode(x)",TraceInfo(pnlName+"#line", "", 0),"=")
				return KMAddCheckmark(cmplxMode, MENU_COMPLEX1D)
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
			p1 = 0;	p2 = nx-1;	q1 = DimSize(w,1)/2;	q2 = q1
			break
		case 7:	//	vertial
			q1 = 0; 	q2 = ny-1;	p1 = DimSize(w,0)/2-1;	p2 = p1;
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
