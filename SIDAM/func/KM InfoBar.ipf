#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMInfoBar

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant COORDINATESMENU = "x and y (rectangular);r and theta (polar);1/r and theta (polar, inverse magnitude);x' and y' (rectangular, including angle)"
Static StrConstant TITLEMENU = "Name of graph;Name of wave;Setpoint;Displayed size;Path of wave"

//******************************************************************************
//	情報表示用及び右クリックメニュー用のコントロールバー
//******************************************************************************
Function KMInfoBar(String grfName)
	
	if (!strlen(grfName))
		grfName = WinName(0,1,1)
	endif
	
	//	既に表示されていたら閉じる
	if (!canInfoBarShown(grfName))
		closeInfoBar(grfName)
		return 1
	endif
	
	//  フック関数・ユーザーデータ
	SetWindow $grfName hook(self)=KMInfoBar#hook
	SetWindow $grfName userData(mode)="0"		//	0: x,y;  1: r,theta,   2: r^-1,theta
	SetWindow $grfName userData(title)="1"		//	0: name of graph, 1: name of wave, 2: setpoint, 3: displayed size
	
	Wave/Z w = KMGetImageWaveRef(grfName)
	int is1D = !WaveExists(w)
	int is2D = WaveExists(w) && WaveDims(w)==2
	int is3D = WaveExists(w) && WaveDims(w)==3
	
	//	右クリックメニューを開いたときに、前回開いたときからウエーブに更新があるかどうかをチェックする
	//	ために用いるユーザーデータ
	SetWindow $grfName userData(modtime)=StringByKey("MODTIME", WaveInfo(w, 0))
	
	//	1, 2, 3次元共通部分
	int ctrlHeight = is3D ? 48 : 25
	ControlBar/W=$grfName ctrlHeight
	
	if (is1D)
		TitleBox xyT pos={4,ctrlHeight-18}, frame=0, win=$grfName
	else
		TitleBox pqT title=" ", frame=0, win=$grfName		//	空の文字列をタイトル指定するのは表示位置調整のため
		TitleBox xyT frame=0, win=$grfName
		TitleBox zT frame=0, win=$grfName
	endif
	
	//	3次元の場合
	if (is3D)
		int layer = KMLayerViewerDo(grfName)
		SetVariable indexV title="index:", pos={3,5}, size={96,18}, value=_NUM:layer, format="%d", win=$grfName
		SetVariable energyV title="value:", value=_NUM:KMIndexToScale(w,layer,2), win=$grfName
		ModifyControlList "indexV;energyV" bodyWidth=60, focusRing=0, proc=KMInfoBar#pnlSetvalue2, win=$grfName
		setenergyVLimits(grfName)
		ControlUpdate/W=$grfName indexV	//	ここで更新しておくと KMDisplayCtrlBarAdjust で位置が正しく扱われる
	endif
	
	//	1次元の場合
	if (is1D)
		//	コントロールの幅を得るためには一度表示状態にして更新しなければならない
		CheckBox showC title="show only trace #", disable=0, focusRing=0, proc=KMInfoBar#pnlCheck, win=$grfName
		SetVariable traceV bodyWidth=40, value=_NUM:0, disable=0, focusRing=0, proc=KMInfoBar#pnlSetvalue1, win=$grfName
		ControlUpdate/W=$grfName showC
		ControlUpdate/W=$grfName traceV
		adjustCtrlPos1D(grfName)	//	幅を使って位置調整を行う
		adjustCtrlDisable1D(grfName)
	endif
	
	adjustCtrlPos(grfName)
End
//-------------------------------------------------------------
//	InfoBarを表示できる状態であれば 1 を返す
//-------------------------------------------------------------
Static Function canInfoBarShown(String grfName)
	
	//	グラフが表示されていない
	if (!strlen(grfName) || WinType(grfName) != 1)
		return 0
	endif
	
	//	横のガイドが設定されている
	//	= Line Profile, Line Spectraである
	if (strlen(GuideNameList(grfName,"TYPE:User,HORIZONTAL:1")))
		return 0
	endif
	
	//	コントロールバーが表示されていなければ 1
	ControlInfo/W=$grfName kwControlBar
	return V_Height ? 0 : 1
End
//-------------------------------------------------------------
//	LayerViewerのenergyVの値の範囲を設定する
//-------------------------------------------------------------
Static Function setenergyVLimits(String pnlName)
	
	Wave srcw = KMGetImageWaveRef(pnlName)
	Variable oz = DimOffset(srcw,2), nz = DimSize(srcw,2), dz = DimDelta(srcw,2)
	
	SetVariable indexV limits={0,nz-1,1}, win=$pnlName
	
	if (strlen(GetDimLabel(srcw,2,0)))	//	MLS of nanonis
		Make/N=(nz)/FREE ew = str2num(GetDimLabel(srcw,2,p))
		SetVariable energyV limits={WaveMin(ew),WaveMax(ew),(WaveMax(ew)-WaveMin(ew))/nz}, win=$pnlName
	else
		SetVariable energyV limits={min(oz,oz+(nz-1)*dz),max(oz,oz+(nz-1)*dz),abs(dz)}, win=$pnlName
	endif

End
//-------------------------------------------------------------
//	バーを閉じる
//-------------------------------------------------------------
Static Function closeInfoBar(String pnlName)
	
	//	一時フォルダを使っていた古いバージョンに備えて
	String dfTmp = GetUserData(pnlName,"","dfTmp")
	if (strlen(dfTmp))
		KMonClosePnl(pnlName, df=dfTmp)
		SetWindow $pnlName userData(dfTmp)=""
	endif
	
	SetWindow $pnlName hook(self)=$""
	SetWindow $pnlName userData(mode)=""
	KMKillControls(pnlName)
End

//******************************************************************************
//	メニュー項目
//******************************************************************************
Static Function/S menu()
	return SelectString(canInfoBarShown(WinName(0,1,1)), "(", "")+"Information Bar"
End

Static Function/S rightclickMenu(int menuitem)
	
	String grfName = WinName(0,1)
	if (!strlen(grfName))	//	グラフが何も表示されていないとき
		return ""
	elseif (strsearch(GetRTStackInfo(3),"hook,KM InfoBar.ipf",0) == -1)	//	右クリックによって呼ばれたのではない場合
		return ""
	endif
	
	int mode
	
	switch (menuitem)
		case 0:	//	座標表示設定切り替え
			
			mode = str2num(GetUserData(grfName,"","mode"))
			String menuStr = KMAddCheckmark(mode, COORDINATESMENU)
			
			Wave/Z w = KMGetImageWaveRef(grfName)
			if (!WaveExists(w) || numtype(str2num(KMGetSettings(w,4))))		//	ウエーブが存在しない(1D)、または角度が得られない場合
				menuStr = RemoveListItem(3, menuStr)
			endif
			
			if (!WaveExists(w))		//	1D
				return menuStr
			endif
			
			Variable isFree = str2num(GetUserData(grfName,"","free"))
			menuStr += "-;" + KMAddCheckmark(isFree, "free (allows selecting 'between' pixels);")
			
			return menuStr
			
		case 1:	//	ウインドウタイトル切り替え
			mode = str2num(GetUserData(grfName,"","title"))
			return KMAddCheckmark(mode, TITLEMENU)
		
		case 2:	//	軸表示切替
			return SelectString(KMGetAxThick(grfName),"Show","Hide") + " Axis"
			
		case 3:	//	複素数表示切替 (2D/3D)
			if (isContainedComplexWave(grfName,2))
				mode = NumberByKey("imCmplxMode",ImageInfo(grfName, "", 0),"=")
				return KMAddCheckmark(mode, MENU_COMPLEX2D)
			else
				return ""
			endif
					
		case 4:	//	複素数表示切替 (1D)
			if (isContainedComplexWave(grfName,1))
				mode = NumberByKey("cmplxMode(x)",TraceInfo(grfName, "", 0),"=")
				return KMAddCheckmark(mode, MENU_COMPLEX1D)
			else
				return ""
			endif
			
	endswitch
End

Static Function isContainedComplexWave(String grfName, int dim)
	String listStr
	int n
	
	if (dim == 1)
		listStr = TraceNameList(grfName,";",1)
		n = ItemsInList(listStr)
		if (n == 0)
			return 0
		endif
		Make/N=(n)/WAVE/FREE tww = TraceNameToWaveRef(grfName,StringFromList(p,listStr))
	else //	2
		listStr = ImageNameList(grfName,";")
		n = ItemsInList(listStr)
		if (n == 0)
			return 0
		endif
		Make/N=(n)/WAVE/FREE tww = ImageNameToWaveRef(grfName,StringFromList(p,listStr))
	endif
	Make/N=(numpnts(tww))/FREE tw = WaveType(tww[p]) & 0x01
	return WaveMax(tw)
End

Static Function/S rightclickDo(int mode)
	GetLastUserMenuInfo
	switch (mode)
		case 0:	//	座標表示設定切り替え
			changeCoordinateSetting(WhichListItem(S_value, COORDINATESMENU))			
			break
			
		case 1:	//	ウインドウタイトル切り替え
			changeWindowTitle(V_value-1)
			break
			
		case 2:	//	軸表示切替
			toggleAxis(WinName(0,1))
			break
			
		case 3:	//	複素数表示切り替え 2D/3D
		case 4:	//	1D
			changeComplex(V_value-1, mode-3)
			break
			
	endswitch
End

//-------------------------------------------------------------
//	フック関数
//-------------------------------------------------------------
Static Function hook(STRUCT WMWinHookStruct &s)
	Wave/Z w = KMGetImageWaveRef(s.winName)
	int is1D = !WaveExists(w) && strlen(TraceNameList(s.winName,";",1))
	int is2D = WaveExists(w) && WaveDims(w)==2 
	int is3D = WaveExists(w) && WaveDims(w)==3
	
	switch (s.eventCode)
	
		case 2:	//	kill
			KMonClosePnl(s.winName)
			break
			
		case 3:	//	mousedown
			GetWindow $s.winName, wsizeDC
			if (s.mouseLoc.v < V_top && s.eventMod & 16)	//	コントロールバー内で右クリック
				if (is1D)
					PopupContextualMenu/N/ASYN "SIDAMMenu1D"
				elseif (is2D || is3D)
					PopupContextualMenu/N/ASYN "SIDAMMenu2D3D"
				endif
				return 1
			endif
			return 0
			
		case 4:	//	mouse move
			if (!(s.eventMod&0x02))	//	shiftキーが押されていなければ
				KMDisplayCtrlBarUpdatePos(s)		//	マウス位置座標表示
			endif
			return 0
			
		case 6:	//	resize
			if (is1D)
				adjustCtrlPos1D(s.winName)
			endif
			return 0
			
		case 8:	//	modified
			if (is1D)
				adjustCtrlDisable1D(s.winName)
			elseif (is3D)
				//	マウスホイールやModifyImageパネルから表示レイヤーが変更された場合には、
				//	indexV と energyV を現状に合わせて変更する必要がある
				int plane = KMLayerViewerDo(s.winName)	//	現在の表示レイヤー
				ControlInfo/W=$s.winname indexV
				if (V_Value != plane)
					SetVariable indexV value=_NUM:plane, win=$s.winName
					SetVariable energyV value=_NUM:KMIndexToScale(w,plane,2), win=$s.winName
				endif
			endif
			changeWindowTitle(str2num(GetUserData(s.winName,"","title")))
			return 0
			
		case 11:	//	keyboard
			return keyboardShortcuts(s)
			
		case 22:	//	mouseWheel
			if (s.eventMod & 8)	//	ctrlが押されていたら
				magnify(s)
			elseif (is3D)			//	ctrlキーが押されておらず3Dウエーブの場合は、表示レイヤーの変更
				int direction = (s.wheelDy > 0) ? 1 : -1
				KMLayerViewerDo(s.winName, direction=direction)
			endif
			return 0
			
		default:
			return 0
			
	endswitch
End

//******************************************************************************
//	KMDisplayCtrlBarUpdatePos : マウス位置を取得して代入する
//******************************************************************************
Function KMDisplayCtrlBarUpdatePos(STRUCT WMWinHookStruct &s, [String win])
	
	//	マウス位置取得ウインドウと表示先ウインドウが異なる場合(取得ウインドウがサブウインドウなど)に表示先ウインドウを指定する
	if (ParamIsDefault(win))
		win = s.winName
	endif
	
	STRUCT KMMousePos ms
	Variable grid = (str2num(GetUserData(s.winName,"","free")) != 1)	//  0 または NaN が相当する (ver. 0.93b以前で作成されたものはNaNを返す)
	if (KMGetMousePos(ms, winhs=s, grid=grid) > 1)
		return 1
	endif
	
	int traceOnly = !strlen(ImageNameList(s.winName,";"))	//	トレースのみ
	String pqs, xys, zs
	
	//	[p, q], z の表示
	if (traceOnly)			//	トレースだけの場合には [p, q] z は表示しない
		pqs = ""
		zs = ""
	elseif (strlen(ms.name))	//	イメージ範囲内
		if (ms.grid)
			Sprintf pqs, "[p,q] = [%d, %d]", ms.p, ms.q
		else
			Sprintf pqs, "[p,q] = [%.1f, %.1f]", ms.p, ms.q
		endif
		if (WaveType(ms.w)&0x01)
			Variable mode = NumberByKey("imCmplxMode",ImageInfo(s.winName,NameOfWave(ms.w),0),"=")
			switch (mode)
				case 0:		//	magnitude
					Sprintf zs, "z = %.2e", real(r2polar(ms.z))
					break
				case 1:		//	real
					Sprintf zs, "z = %.2e", real(ms.z)
					break
				case 2:		//	imaginary
					Sprintf zs, "z = %.2e", imag(ms.z)
					break
				case 3:		//	phase (in radian)
					Sprintf zs, "z = %.4fpi", imag(r2polar(ms.z))/pi
					break
			endswitch
		else
			Sprintf zs, "z = %.2e", real(ms.z)
		endif
	else					//	イメージ範囲外
		pqs = "[p,q] = [-, -]"
		zs = "z = -"
	endif
	
	// (x, y) の表示
	strswitch (GetUserData(s.winName,"","mode"))
		default:
			//	***THROUGH***
		case "0":	//	x, y	トレースのみの場合もここ
			if (!WaveExists(ms.w))
				xys = "(x,y) = (-,-)"
			elseif (stringmatch(WaveUnits(ms.w,0),"dat"))
				Sprintf xys, "(x,y) = (%s %s, %.2f)", Secs2Date(ms.x,-2), Secs2Time(ms.x,3), ms.y
			elseif (stringmatch(WaveUnits(ms.w,1),"dat"))
				Sprintf xys, "(x,y) = (%.2f, %s %s)", ms.x, Secs2Date(ms.y,-2), Secs2Time(ms.y,3)
			else
				Sprintf xys, "(x,y) = (%.2f, %.2f)", ms.x, ms.y
			else
			endif
			break
		case "1": 	//	r, theta
			Sprintf xys, "(r,t) = (%.2f, %.2f)", sqrt(ms.x^2+ms.y^2), acos(ms.x/sqrt(ms.x^2+ms.y^2))*180/pi
			break
		case "2": 	//	r^-1, theta-90
			Sprintf xys, "(1/r,t) = (%.2f, %.2f)", 1/sqrt(ms.x^2+ms.y^2), acos(ms.x/sqrt(ms.x^2+ms.y^2))*180/pi
			break
		case "3":	//	x', y', 角度は度
			Variable angle = str2num(KMGetSettings(ms.w,4)) / 180 * pi
			if (numtype(angle))
				xys = "(x',y') = (-,-)"
			else
				Variable cx = DimOffset(ms.w,0) + DimDelta(ms.w,0)*(DimSize(ms.w,0)-1)/2
				Variable cy = DimOffset(ms.w,1) + DimDelta(ms.w,1)*(DimSize(ms.w,1)-1)/2
				Variable rx = (ms.x-cx)*cos(angle) - (ms.y-cy)*sin(angle) + cx
				Variable ry = (ms.x-cx)*sin(angle) + (ms.y-cy)*cos(angle) + cy
				Sprintf xys, "(x',y') = (%.2f, %.2f)", rx, ry
			endif
			break
	endswitch
	xys = ReplaceString("nan", xys, "-")		//	イメージ範囲外では nan が入るので、それの置き換え
	
	//	表示内容を設定する
	if (traceOnly)
		TitleBox xyT title=xys, win=$win
	else
		TitleBox pqT title=pqs, win=$win
		TitleBox xyT title=xys, win=$win
		TitleBox zT title=zs, win=$win
		if (str2num(GetUserData(s.winName,"","title")) == 1)
			DoWindow/T $win, ms.name
		endif
	endif
	
	//	表示位置を更新する
	adjustCtrlPos(win)
End
//-------------------------------------------------------------
//	コントロールパネルの各項目の位置調整
//-------------------------------------------------------------
Static Function adjustCtrlPos(String win)
	
	ControlInfo/W=$win kwControlBar
	Variable ctrlBarHeight = V_Height
	
	//	xyT はトレースだけの場合でも表示されているので、テキストの高さは xyT　から取得する
	ControlInfo/W=$win xyT
	Variable textHeight = V_Height, xyTLeft = V_left
	Variable textTop	 = V_top
	
	//	indexV もしくは pV が存在するかどうか
	String setVarList = ""
	ControlInfo/W=$win indexV
	if (V_flag)
		setVarList = "indexV;energyV;"
	endif
	ControlInfo/W=$win pV
	if (V_flag)
		setVarList = "pV;qV;"
	endif
	
	//	indexV などの setVariable が表示されていたら、それらの位置を更新する
	if (strlen(setVarList))
		ControlInfo/W=$win $StringFromList(0,setVarList)
		Variable setVarHeight = V_Height, setVarTop = (ctrlBarHeight-setVarHeight-textHeight)/3
		Variable setVar0Width = V_Width, setVar0Left = V_Left
		SetVariable $StringFromList(0,setVarList) pos={setVar0Left, setVarTop}, win=$win
		SetVariable $StringFromList(1,setVarList) pos={setVar0Left+setVar0Width+10, setVarTop}, win=$win
	endif
	
	//	コントロールバーが表示されている場合(2D,layerViewer), xyT, pqT, zT の縦方向の位置は、setVariable の有無によって変化する
	//	コントロールバーが表示されていない場合(Fourier filter), xyT, pqT, zT の縦方向の位置については何もしない
	if (strlen(setVarList))
		textTop = setVarTop + setVarHeight + (ctrlBarHeight-setVarHeight-textHeight)/3
	elseif (ctrlBarHeight > 0)
		textTop = (ctrlBarHeight-textHeight)/2
	endif
	
	//	pqT が表示されている場合には、ウインドウにイメージが表示されている
	ControlInfo/W=$win pqT
	int containsImage = V_flag
	
	if (containsImage)
		
		TitleBox pqT pos={V_left, textTop}, win=$win	//	ここでのV_leftは ControlInfo/W=$win pqT で得られたもの
		ControlUpdate/W=$win pqT
		
		ControlInfo/W=$win pqT
		TitleBox xyT pos={V_left+V_width+10, textTop}, win=$win
		ControlUpdate/W=$win xyT
		
		ControlInfo/W=$win xyT
		TitleBox zT pos={V_left+V_width+10, textTop}, win=$win
		ControlUpdate/W=$win zT
		
	else
		
		TitleBox xyT pos={xyTLeft, textTop}, win=$win
		ControlUpdate/W=$win xyT
		
	endif

End
//-------------------------------------------------------------
//	特定トレース表示コントロールの表示・位置
//-------------------------------------------------------------
Static Function adjustCtrlPos1D(String grfName)
	int n = ItemsInList(TraceNameList(grfName,";",1))
	DoUpdate/W=$grfName
	
	GetWindow $grfName gsizeDC			;	Variable pnlRight = V_right
	ControlInfo/W=$grfName kwControlBar	;	Variable ctrlBarHeight = V_Height
	ControlInfo/W=$grfName showC 			;	Variable checkWidth = V_Width, checkHeight = V_Height, checked = V_Value
	ControlInfo/W=$grfName traceV			;	Variable varWidth = V_Width, varHeight = V_Height
	
	//	traceV の位置調整, 横位置の5はパネル右端からのマージン	
	SetVariable traceV pos={pnlRight-varWidth-5,(ctrlBarHeight-varHeight)/2}, disable=(!checked)*2, limits={0,n-1,1}, win=$grfName
	ControlUpdate/W=$grfName traceV
	
	//	showC の位置調整, 横位置の3はtraceVとのマージン
	ControlInfo/W=$grfName traceV
	CheckBox showC pos={V_left-checkWidth-3,(ctrlBarHeight-checkHeight)/2}, win=$grfName
End

Static Function adjustCtrlDisable1D(String grfName)
	if (ItemsInList(TraceNameList(grfName,";",1)) < 2)
		Checkbox showC value=0, disable=1, win=$grfName
		SetVariable traceV value=_NUM:0, disable=1, win=$grfName
	else
		Checkbox showC disable=0, win=$grfName
	endif
End

//-------------------------------------------------------------
//	マウスホイールで表示範囲を拡大縮小する. ctrlを押しているときに有効
//-------------------------------------------------------------
Static Function magnify(STRUCT WMWinHookStruct &hs)
	
	STRUCT KMMousePos s
	if (KMGetMousePos(s, winhs=hs, grid=0) > 0)
		return 1
	endif
	Variable coef = 1 - 0.1*sign(hs.wheelDy)	//	上に回すと数字が小さくなる -> 表示範囲が小さくなる -> 拡大する
	GetAxis/Q/W=$hs.winName $s.xaxis
	SetAxis/W=$hs.winName $s.xaxis  s.x+(V_min-s.x)*coef, s.x+(V_max-s.x)*coef
	GetAxis/Q/W=$hs.winName $s.yaxis
	SetAxis/W=$hs.winName $s.yaxis  s.y+(V_min-s.y)*coef, s.y+(V_max-s.y)*coef
End

//-------------------------------------------------------------
//	キーボードショートカット
//	KM SpectrumViewer.ipf内でも使用されている
//-------------------------------------------------------------
Static Function keyboardShortcuts(STRUCT WMWinHookStruct &s)
	
	Wave/Z w = KMGetImageWaveRef(s.winName)
	int is2D = WaveExists(w) && WaveDims(w)==2
	int is3D = WaveExists(w) && WaveDims(w)==3
	int isWindows = strsearch(IgorInfo(2), "Windows", 0, 2) >= 0
	
	if (isWindows && s.specialKeyCode && (is2D || is3D))
		switch (s.specialKeyCode)
			case 4:		//	F4
				KMRange()
				return 1
			case 5:		//	F5
				KMColor()
				return 1
			case 6:		//	F6
				KMSubtraction#rightclickDo()
				return 1
			case 7:		//	F7
				if (!KMFFTCheckWaveMenu())
					KMFFT#rightclickDo()
				endif
				return 1
		endswitch
	endif
	
	int mode
	switch (s.keycode)
		case 11:		//	PageUp
		case 12:		//	PageDown
			if (is3D)	//	3Dウエーブの場合　表示レイヤーの変更
				int direction = (s.keyCode == 11) ? 1 : -1
				KMLayerViewerDo(s.winName, direction=direction)
			endif
			return 1
		case 27:		//	esc
			closeInfoBar(s.winName)
			return 1
		case 49:		//	1
		case 50:		//	2
		case 51:		//	3
			ModifyGraph/W=$s.winName expand=s.keycode-48
			return 1
		case 65:		//	A (shift + a)
			toggleAxis(s.winName)
			return 1
		case 67:		//	C (shift + c)
			mode = str2num(GetUserData(s.winName,"","mode"))
			changeCoordinateSetting(mode+1)
			KMDisplayCtrlBarUpdatePos(s)
			return 1
		case 84:		//	T (shift + t)
			int titleMode = str2num(GetUserData(s.winName,"","title"))
			changeWindowTitle(titleMode+1)
			return 1
		case 88: 		//	X (shift + x)
			if ((is2D || is3D) && isContainedComplexWave(s.winName,2))
				mode = NumberByKey("imCmplxMode",ImageInfo(s.winName, "", 0),"=")
			elseif (!is2D && !is3D && isContainedComplexWave(s.winName,1))
				mode = NumberByKey("cmplxMode(x)",TraceInfo(s.winName, "", 0),"=")
			else
				return 1
			endif
			changeComplex(++mode,!is2D && !is3D)
			return 1		
		case 97:		//	a
			DoIgorMenu "Graph", "Modify Axis"
			return 1
		case 99:		//	c
			KMExportGraphicsTransparent()
			return 1
		case 103:		//	g
			DoIgorMenu "Graph", "Modify Graph"
			return 1
		case 105:		//	i
			DoIgorMenu "Image", "Modify Image Appearance"
			return 1
		case 115:		//	s
			DoIgorMenu "File", "Save Graphics"
			return 1
		case 116:		//	t
			DoIgorMenu "Graph", "Modify Trace Appearance"
			return 1
	endswitch
	
	return 0
End

//-------------------------------------------------------------
//	座標表示設定の切り替え
//-------------------------------------------------------------
Static Function changeCoordinateSetting(int mode)
	
	String grfName = WinName(0,1)
	
	//	キーボードショートカットから呼ばれた場合に備えて、modeが大きすぎるときには0へ戻す
	Variable maxMode = ItemsInList(COORDINATESMENU) - 1
	Wave/Z w = KMGetImageWaveRef(grfName)
	if (!WaveExists(w) || numtype(str2num(KMGetSettings(w,4))))	//	1Dウエーブもしくは角度が得られない場合
		maxMode -= 1
	endif
	if (mode > maxMode)
		mode = 0
	endif
	
	switch (mode)
		case 0:
		case 1:
		case 2:
		case 3:
			SetWindow $grfName userData(mode)=num2str(mode)
			break
		case -1:
			Variable isFree = str2num(GetUserData(grfName,"","free"))
			SetWindow $grfName userData(free)=num2str(isFree != 1)		//  0 または NaN の場合に1が返る (ver. 0.93b以前で作成されたものはNaNを返す)
			break
	endswitch
End

//-------------------------------------------------------------
//	タイトルの切り替え
//-------------------------------------------------------------
Static Function changeWindowTitle(int mode)
	
	String grfName = WinName(0,1), titleStr
	Wave/Z w = KMGetImageWaveRef(grfName)
	if (!WaveExists(w))	//	例えば1次元ウエーブ
		return 0
	elseif (numtype(mode) == 2)
		return 0		//	未設定のときにショートカットから呼ばれるとここに来る
	endif
	
	switch (mode)
		case 0:
			titleStr = grfName
			break
		case 1:
			titleStr = NameOfWave(w)
			break
		case 2:
			titleStr = KMGetSettings(w,1) + ", " + KMGetSettings(w,2)
			break
		case 3:
			String xaxis = StringByKey("XAXIS",ImageInfo(grfName,"",0))
			String yaxis = StringByKey("YAXIS",ImageInfo(grfName,"",0))
			GetAxis/Q/W=$grfName $xaxis ;	Variable width = V_max - V_min
			GetAxis/Q/W=$grfName $yaxis ;	Variable height = V_max - V_min
			Sprintf titleStr, "%.2f %s ﾗ %.2f %s", width, WaveUnits(w,0), height, WaveUnits(w,1)
			break
		case 4:
			titleStr = GetWavesDataFolder(w,2)
			break
		default:	//	例えば5
			mode = 0
			titleStr = grfName
	endswitch
	
	SetWindow $grfName userData(title)=num2str(mode)	
	DoWindow/T $grfName, titleStr	
End

//-------------------------------------------------------------
//	軸表示の切り替え
//-------------------------------------------------------------
Static Function toggleAxis(String grfName)
	if (KMGetAxThick(grfName))
		ModifyGraph/W=$grfName margin=1, noLabel=2, axThick=0
	else
		ModifyGraph/W=$grfName margin(left)=44, margin(bottom)=36, margin(top)=8, margin(right)=8
		ModifyGraph/W=$grfName tick=0, noLabel=0, axThick=1, btLen=5
	endif
End

//-------------------------------------------------------------
//	複素数表示の切り替え
//-------------------------------------------------------------
Static Function changeComplex(int mode, int dim)
	//	キーボードショートカットから呼ばれた場合に備えて、modeが大きすぎるときには0へ戻す
	int numOfModes = ItemsInList(SelectString(dim, MENU_COMPLEX2D, MENU_COMPLEX1D))
	mode = mode < numOfModes ? mode : 0
	
	if (dim)
		ModifyGraph/W=$WinName(0,1) cmplxMode=mode
	else
		ModifyImage/W=$WinName(0,1) '' imCmplxMode=mode
	endif
End

//-------------------------------------------------------------
//	パネルコントロール
//-------------------------------------------------------------
//-------------------------------------------------------------
//	値設定、トレース用
//-------------------------------------------------------------
Static Function pnlSetvalue1(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode == -1 || s.eventCode == 6)
		return 1
	endif
	
	//	全部隠してから必要なものだけを表示
	ModifyGraph/W=$s.win hideTrace=2
	ModifyGraph/W=$s.win hideTrace[s.dval]=0
	String trcName = StringFromList(s.dval,TraceNameList(s.win,";",1))
	ModifyGraph/Z/W=$s.win hideTrace($("fit_"+trcName))=0	//	フィット関数も一緒に表示する
	
	//	表示されているトレース名の変更
	TextBox/W=$s.win/C/N=$GetUserData(s.win,"showC","textName") trcName
End
//-------------------------------------------------------------
//	値設定、レイヤー用
//-------------------------------------------------------------
Static Function pnlSetvalue2(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode == -1 || s.eventCode == 6)
		return 1
	endif
	
	Wave w = KMGetImageWaveRef(s.win)
	int index
	
	//	evergyV の値が変更された場合でも、対応するインデックスを探し、それを元に evergyV に値を代入する
	strswitch (s.ctrlName)
		case "indexV":
			index = round(s.dval)
			break
		case "energyV":
			index = KMScaleToIndex(w, s.dval,2)
			break
		default:
	endswitch
	SetVariable indexV value=_NUM:index, win=$s.win
	SetVariable energyV value=_NUM:KMIndexToScale(w,index,2), win=$s.win
	
	ModifyImage/W=$s.win $NameOfWave(w) plane=index	//	表示レイヤーの更新
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	SetVariable traceV disable=!s.checked*2, win=$s.win
	ModifyGraph/W=$s.win hideTrace=s.checked*2	//	全部表示、もしくは全部非表示
	
	if (s.checked)
		//	指定されたものだけ表示
		ControlInfo/W=$s.win traceV
		ModifyGraph/W=$s.win hideTrace[V_Value]=0
		//	フィット関数も一緒に表示
		String trcName = StringFromList(V_Value,TraceNameList(s.win,";",1))
		ModifyGraph/Z/W=$s.win hideTrace($("fit_"+trcName))=0
		//	表示されたトレースの名前を表示
		TextBox/W=$s.win/F=0/X=1.00/Y=1.00/E=2 trcName
		String listStr = AnnotationList(s.win)
		String textName = StringFromList(ItemsInList(listStr)-1,listStr)
		CheckBox $s.ctrlName userData(textName)=textName, win=$s.win	//	annotation textの名前を記録
	else
		//	トレース名表示の削除
		TextBox/W=$s.win/K/N=$GetUserData(s.win,s.ctrlName,"textName")
	endif
End

//******************************************************************************
//	後方互換確保
//******************************************************************************
Function KMDisplayCtrlBarHook2(STRUCT WMWinHookStruct &s)
	//	コントロール関数を変更する
	String ctrlList = ControlNameList(s.winName)
	
	if (WhichListItem("indexV",ctrlList) != -1)	//	3D
		SetVariable indexV proc=KMInfoBar#pnlSetvalue2, win=$s.winName
		SetVariable energyV proc=KMInfoBar#pnlSetvalue2, win=$s.winName
	endif
	
	if (WhichListItem("showC",ctrlList) != -1)		//	1D
		CheckBox showC proc=KMInfoBar#pnlCheck, win=$s.winName
		SetVariable traceV proc=KMInfoBar#pnlSetvalue1, win=$s.winName
	endif
	
	//	新しいフック関数を設定する
	SetWindow $s.winName hook(self)=KMInfoBar#hook
End
Function KMDisplayCtrlBarHook(STRUCT WMWinHookStruct &s)	//	rev. 901 -> 903
	
	//	閉じるボタンを削除する
	KillControl/W=$s.winName closeB
	
	//	コントロール類の位置調整
	Wave/Z w = KMGetImageWaveRef(s.winName)
	int traceOnly = !WaveExists(w)
	if (traceOnly)
		adjustCtrlPos1D(s.winName)
		adjustCtrlDisable1D(s.winName)
	endif
	adjustCtrlPos(s.winName)
	
	//	新しいフック関数を設定する
	SetWindow $s.winName hook(self)=KMDisplayCtrlBarHook2
	
	//	rev. 900で導入されたフック関数を設定する
	SetIgorHook AfterCompiledHook
	if (strsearch(S_info, "ProcGlobal#KMAfterCompiledHook", 0) == -1)
		SetIgorHook AfterCompiledHook = KMAfterCompiledHook
	endif
End
Function KMImageViewerBarHook(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName hook(self)=KMDisplayCtrlBarHook
End
Function KMImageViewer2DHook(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName hook(self)=KMDisplayCtrlBarHook
End
Function KMDisplayBarHook(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName hook(self)=KMDisplayCtrlBarHook
End
Function KMDisplayBarSetVar(STRUCT WMSetVariableAction &s)
	SetVariable $s.ctrlName proc=KMInfoBar#pnlSetvalue1, win=$s.win
	pnlSetvalue1(s)
End
Function KMDisplayBarCheck(STRUCT WMCheckboxAction &s)
	Checkbox $s.ctrlName proc=KMInfoBar#pnlCheck, win=$s.win
	pnlCheck(s)
End
