#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1
#pragma ModuleName=KMFourierFilter

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant ks_index_filter = "_flt"
Static StrConstant MASKNAME = "KM_mask"
Static StrConstant ORIGINALNAME = "KM_original"
Static StrConstant FOURIERNAME = "KM_fourier"
Static StrConstant FILTEREDNAME = "KM_filtered"

//******************************************************************************
//	メイン関数
//******************************************************************************
Function/WAVE KMFilter(
	Wave/Z srcw,
	Wave/Z paramw,
	[
		String result,
		int invert,
		int endeffect,
		int history
	])
	
	STRUCT paramStruct s
	Wave/Z s.srcw = srcw
	Wave/Z s.pw = paramw
	s.result = SelectString(ParamIsDefault(result), result, NameOfWave(srcw)+ks_index_filter)
	s.invert = ParamIsDefault(invert) ? 0 : invert
	s.endeffect = ParamIsDefault(endeffect) ? 1 : endeffect
	
	//	エラーチェック
	if (!isValidArguments(s))
		print s.errMsg
		return $""
	endif
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + echoStr(srcw, paramw, result, invert, endeffect)
	endif
	
	//	実行
	Wave/WAVE ww = applyFilter(srcw, paramw, s.invert, s.endeffect)
	DFREF dfr = GetWavesDataFolderDFR(srcw)
	Duplicate/O ww[0] dfr:$s.result
	
	return dfr:$s.result
End
//-------------------------------------------------------------
//	引数チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = "**KMFilter gave error: "
	
	String msg = KMFFTCheckWaveMsg(s.srcw)
	if (strlen(msg))
		s.errMsg += msg
		return 0
	endif
	
	if (!WaveExists(s.pw))
		s.errMsg += "the parameter wave is not found."
		return 0
	elseif (DimSize(s.pw,0) != 7)
		s.errMsg += "the size of parameter wave is incorrect."
		return 0
	endif
	
	WaveStats/Q/M=1 s.pw
	if (V_numNaNs || V_numINFs)
		s.errMsg += "the parameter wave must not contain NaN or INF."
		return 0
	endif
	
	if (KMFilterCheckParameters(s.pw, s.srcw))
		s.errMsg += "a parameter(s) is out of range."
		return 0
	endif
	
	if (strlen(s.result) > MAX_OBJ_NAME)
		s.errMsg += "length of name for output wave will exceed the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 0
	endif
	
	s.invert = s.invert ? 1 : 0
	s.endeffect = limit(s.endeffect, 0, 3)
	
	return 1
End
//-------------------------------------------------------------
//	パラメータウエーブチェック用関数
//-------------------------------------------------------------
Static Function KMFilterCheckParameters(Wave pw, Wave srcw)
	
	Make/N=(DimSize(pw,1))/FREE tw
	Make/N=10/FREE tw2
	tw = pw[0][p] ;	tw2[0] = DimSize(srcw,0)-1-WaveMax(tw) ; 	tw2[1] = WaveMin(tw)
	tw = pw[1][p] ;	tw2[2] = DimSize(srcw,1)-1-WaveMax(tw) ; 	tw2[3] = WaveMin(tw)
	tw = pw[3][p] ;	tw2[4] = DimSize(srcw,0)-1-WaveMax(tw) ; 	tw2[5] = WaveMin(tw)
	tw = pw[4][p] ;	tw2[6] = DimSize(srcw,1)-1-WaveMax(tw) ; 	tw2[7] = WaveMin(tw)
	tw = pw[2][p] ;	tw2[8] = WaveMin(tw)
	tw = pw[5][p] ;	tw2[9] = WaveMin(tw)
	
	return (WaveMin(tw2) < 0)
End

Static Structure paramStruct
	String	errMsg
	Wave	srcw
	Wave	pw
	String	result
	uchar	invert
	uchar	endeffect
EndStructure

//-------------------------------------------------------------
//	履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S echoStr(Wave srcw, Wave paramw, String result, int invert, int endeffect)
	
	String paramStr = GetWavesDataFolder(srcw,2)
	paramStr += "," + SelectString(WaveType(paramw,2)==2, GetWavesDataFolder(paramw,2), KMWaveToString(paramw, noquot=1))
	paramStr += SelectString(CmpStr(NameOfWave(srcw)+ks_index_filter,result), "", ",result=\""+result+"\"")
	paramStr += SelectString(invert, "", ",invert="+num2str(invert))
	paramStr += SelectString(endeffect==1, ",endeffect="+num2str(endeffect), "")
	Sprintf paramStr, "KMFilter(%s)", paramStr
	
	return paramStr
End

//-------------------------------------------------------------
//	フィルタの実行関数
//	パネルからも使用できるように、マスクウエーブと結果ウエーブへの参照を返す
//-------------------------------------------------------------
Static Function/WAVE applyFilter(Wave srcw, Wave paramw, int invert, int endeffect)
	
	int nx = DimSize(srcw,0), ny = DimSize(srcw,1), nz = DimSize(srcw,2), dim = WaveDims(srcw), i
	
	//	端処理のためのウエーブ作成
	if (endeffect == 1)		//	wrap
		Wave tsrcw = srcw
	else
		Wave tsrcw = KMEndEffect(srcw,endeffect)
	endif
	
	//	端処理に応じてパラメータウエーブの内容を修正
	Duplicate/FREE paramw tparamw
	if (endeffect != 1)
		Variable cp = nx/2-1, cq = floor(ny/2)
		Variable cp2 = nx*3/2-1, cq2 = floor(ny*3/2)
		tparamw[0][] = cp2 + (paramw[0][q]-cp)*3
		tparamw[1][] = cq2 + (paramw[1][q]-cq)*3
		tparamw[3][] = cp2 + (paramw[3][q]-cp)*3
		tparamw[4][] = cq2 + (paramw[4][q]-cq)*3
		tparamw[6][] = paramw[6][q]*3
	endif
	
	//	マスクウエーブを作成する
	Wave maskw = makeMask(tsrcw, tparamw, invert)
	
	//	フィルタを実行する
	if (dim == 2)
		MatrixOP/FREE/C flt2Dw = fft(tsrcw,0)*maskw
		IFFT/FREE flt2Dw
		Note flt2Dw, KMWaveToString(paramw, noquot=1)
		CopyScales tsrcw, flt2Dw
	else
		Make/N=(nz)/FREE/WAVE ww
		MultiThread ww = applyFilterHelper(tsrcw, p, maskw)
		Duplicate/FREE tsrcw, flt3Dw
		for (i = 0; i < nz; i++)
			Wave tw = ww[i]
			MultiThread flt3Dw[][][i] = tw[p][q]
		endfor
	endif
	
	//	端処理に対応して不要部分を削除したウエーブを用意する
	if (endeffect == 1)
		if (dim == 2)
			Make/N=2/FREE/WAVE rww = {flt2Dw, maskw}
		else
			Make/N=2/FREE/WAVE rww = {flt3Dw, maskw}
		endif
	else
		if (dim == 2)
			Duplicate/FREE/R=[nx, 2*nx-1][ny, 2*ny-1] flt2Dw, fw
		else
			Duplicate/FREE/R=[nx, 2*nx-1][ny, 2*ny-1][] flt3Dw, fw
		endif
		Duplicate/FREE/R=[,nx/2+1][ny,2*ny-1] maskw mw
		mw = maskw(x*3)(y*3)
		Make/N=2/FREE/WAVE rww = {fw, mw}
	endif
	
	return rww
End

ThreadSafe Static Function/WAVE applyFilterHelper(Wave srcw, Variable index, Wave maskw)
	MatrixOP/FREE/C filteredw = fft(srcw[][][index],0)*maskw
	IFFT/FREE filteredw
	return filteredw
End

//-------------------------------------------------------------
//	マスクウエーブを作り、参照を返す
//-------------------------------------------------------------
Static Function/WAVE makeMask(
	Wave w,			//	実空間ウエーブ
	Wave paramw,		//	p0, q0, n0, p1, q1, n1, r
	Variable invert
	)
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1)
	Variable dx = 1 / (DimDelta(w,0)*DimSize(w,0)), dy = 1 / (DimDelta(w,1)*DimSize(w,1))
	Variable ox = (1-DimSize(w,0)/2) / (DimDelta(w,0)*DimSize(w,0)), oy = -1 / (DimDelta(w,1)*2)
	Variable x0, y0, x1, y1, xc, yc, radius
	int n0, n1
	int i, j, n
	
	//	フィルタ中心位置のリストを作成する
	Make/N=(0,3)/FREE lw
	for (i = 0; i < DimSize(paramw,1); i++)
		radius = paramw[6][i]*sqrt(dx^2+dy^2)
		if (radius <= 0)	//	半径が非正ならば中止
			continue
		endif
		for (n0 = -paramw[2][i]; n0 <= paramw[2][i]; n0++)
			for (n1 = -paramw[5][i]; n1 <= paramw[5][i]; n1++)
				if (!n0 && !n1)
					continue
				endif
				n = DimSize(lw,0)
				Redimension/N=(n+1,-1) lw
				x0 = ox + dx*paramw[0][i]
				y0 = oy + dy*paramw[1][i]
				x1 = ox + dx*paramw[3][i] 
				y1 = oy + dy*paramw[4][i]
				lw[n][0] = x0*n0 + x1*n1
				lw[n][1] = y0*n0 + y1*n1
				lw[n][2] = radius
			endfor
		endfor
	endfor
	
	//	中心位置の重複(あれば)を解消する
	for (i = DimSize(lw,0)-1; i >= 0; i--)
		for (j = i - 1; j >= 0; j--)
			if (lw[i][0] == lw[j][0] && lw[i][1] == lw[j][1])
				DeletePoints/M=0 i, 1, lw
				break
			endif
		endfor
	endfor
	
	//	マスク作成
	Make/N=(nx/2+1,ny)/FREE maskw=0
	SetScale/P x 0, dx, "", maskw
	SetScale/P y oy, dy, "", maskw
	Make/N=(DimSize(lw,0))/WAVE/FREE ww
	
	MultiThread ww = makeMaskHelper(maskw, lw, p)	//	時間がかかるのはここ
	
	for (i = 0; i < numpnts(ww); i++)
		Wave tw = ww[i]
		FastOP maskw = maskw + tw
	endfor
	
	Variable v = WaveMax(maskw)
	if (invert)
		FastOP maskw = 1 - (1/v) * maskw
	else
		FastOP maskw = (1/v) * maskw
	endif
	
	return maskw
End

ThreadSafe Static Function/WAVE makeMaskHelper(Wave maskw, Wave lw, int index)
	
	Make/N=(DimSize(maskw,0), DimSize(maskw,1))/FREE rtnw
	CopyScales maskw, rtnw
	
	Variable a = lw[index][0], b = lw[index][1], c = -ln(2)/lw[index][2]^2	//	高速化
	rtnw = ((x-a)^2+(y-b)^2)*c
	MatrixOP/O rtnw = exp(rtnw)
	
	return rtnw
End

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(KMGetImageWaveRef(WinName(0,1)), grfName=WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(Wave w,[String grfName])
	
	//	パネル表示
	String pnlName = KMNewPanel("Fourier filter ("+NameOfWave(w)+")", 680, 370, nofixed=1)	//	680=10+320+10+340, 370=40+320+10
	if (!ParamIsDefault(grfName))	//	右クリックからの実行の場合
		AutoPositionWindow/E/M=0/R=$grfName $pnlName
	endif
	
	//	初期設定
	String dfTmp = pnlInit(pnlName, w)
	SetWindow $pnlName hook(self)=KMFourierFilter#pnlHook
	SetWindow $pnlName userData(dfTmp)=dfTmp
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2), activeChildFrame=0
	
	//	パネル項目
	TabControl mTab pos={1,1}, size={338,368}, proc=KMTabControlProc, win=$pnlName
	TabControl mTab tabLabel(0)="original", tabLabel(1)="filtered", tabLabel(2)="FFT", value=2, win=$pnlName
	
	TitleBox pqT pos={15,24}, frame=0, win=$pnlName
	TitleBox xyT pos={15,24}, frame=0, win=$pnlName
	TitleBox zT pos={15,24}, frame=0, win=$pnlName
	
	DefineGuide/W=$pnlName CTL={FR,-335}, CTT={FB,-220}
	NewPanel/FG=(CTL,FT,FR,CTT)/HOST=$pnlName
	RenameWindow $pnlName#$S_name, table
	ModifyPanel/W=$pnlName#table frameStyle=0
	
	ListBox filL pos={0,18}, size={330,120}, frame=2, mode=5, selRow=-1, win=$pnlName#table
	ListBox filL listWave=$(dfTmp+KM_WAVE_LIST), selWave=$(dfTmp+KM_WAVE_SELECTED), win=$pnlName#table
	
	NewPanel/FG=(CTL,CTT,FR,FB)/HOST=$pnlName
	RenameWindow $pnlName#$S_name, controls
	ModifyPanel/W=$pnlName#controls frameStyle=0
	
	GroupBox filterG title="filter", pos={0,0}, size={190,115}, win=$pnlName#controls
	Button addB title="Add", pos={6,22}, size={60,20}, win=$pnlName#controls
	TitleBox addT title="new filter", pos={76,26}, frame=0, win=$pnlName#controls
	Button deleteB title="Delete", pos={6,53}, size={60,20}, disable=2, win=$pnlName#controls
	TitleBox deleteT title="selected filter", pos={76,57}, frame=0, disable=2, win=$pnlName#controls
	Button applyB title="Apply", pos={6,84}, size={60,20}, disable=2, win=$pnlName#controls
	PopupMenu invertP title="", pos={76,84}, size={70,20}, bodyWidth=70, disable=2, win=$pnlName#controls
	PopupMenu invertP mode=1, value= #"\"pass;stop\"", userData="1", proc=KMFourierFilter#pnlPopup, win=$pnlName#controls
	TitleBox applyT title="filter", pos={156,88}, frame=0, disable=2, win=$pnlName#controls
	
	GroupBox maskG title="mask", pos={200,0}, size={130,115}, disable=2, win=$pnlName#controls
	TitleBox maskT title="color and opacity", pos={210,26}, size={88,12}, frame=0, disable=2, win=$pnlName#controls
	PopupMenu colorP pos={211,53}, size={50,20} ,mode=1, proc=KMFourierFilter#pnlPopup, disable=2, win=$pnlName#controls
	PopupMenu colorP popColor= (65535,65535,65535),value= #"\"*COLORPOP*\"", win=$pnlName#controls
	Slider opacityS pos={211,85}, size={100,19}, limits={0,255,1} ,value=192, vert=0, ticks=0, proc=KMFourierFilter#pnlSlider, disable=2, win=$pnlName#controls
	
	PopupMenu endP title="end effect", pos={20,129}, size={165,20}, bodyWidth=110, disable=2, proc=KMFourierFilter#pnlPopup, win=$pnlName#controls
	PopupMenu endP mode=2, popvalue="wrap", value= #"\"bounce;wrap (none);zero;repeat\"", userData="2", win=$pnlName#controls
	TitleBox endT title="this takes longer time", pos={196,133}, disable=1, frame=0, win=$pnlName#controls
	SetVariable nameV title="output name", pos={8,161}, size={317,16}, bodyWidth=250, proc=KMFourierFilter#pnlSetVar, disable=2, win=$pnlName#controls
	SetVariable nameV value= _STR:(NameOfWave(w)[0,30-strlen(ks_index_filter)]+ks_index_filter), win=$pnlName#controls
	
	Button saveB title="Save", pos={6,192}, size={60,20}, disable=2, win=$pnlName#controls
	CheckBox displayC title="display", pos={75,195}, disable=2, win=$pnlName#controls
	PopupMenu toP title="To", pos={163,192}, size={60,20}, bodyWidth=60, disable=2, win=$pnlName#controls
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMFourierFilter#pnlPopup, win=$pnlName#controls
	Button helpB title="?", pos={231,192}, size={30,20}, win=$pnlName#controls
	Button closeB title="Close", pos={269,192}, size={60,20}, win=$pnlName#controls
	
	ModifyControlList ControlNameList(pnlName+"#controls",";","*B") proc=KMFourierFilter#pnlButton, win=$pnlName#controls
	ModifyControlList ControlNameList(pnlName+"#controls",";","*") focusRing=0, win=$pnlName#controls
	
	//	表示領域
	DefineGuide/W=$pnlName IMGL={FL,9}, IMGT={FT,41}, IMGR={FR,-351}, IMGB={FB,-9}
		//	original
	Display/FG=(IMGL, IMGT, IMGR, IMGB)/HOST=$pnlName/HIDE=1	//	パネル作成時のちらつきを抑制するため
	RenameWindow $pnlName#$S_name, original
	SetWindow $pnlName#original userData(tab)="0"
	AppendImage/W=$pnlName#original $(dfTmp+ORIGINALNAME)
	ModifyGraph/W=$pnlName#original noLabel=2, axThick=0, standoff=0, margin=1
		//	filtered
	Display/FG=(IMGL, IMGT, IMGR, IMGB)/HOST=$pnlName/HIDE=1	//	パネル作成時のちらつきを抑制するため
	RenameWindow $pnlName#$S_name, filtered
	SetWindow $pnlName#filtered userData(tab)="1"
	AppendImage/W=$pnlName#filtered $(dfTmp+FILTEREDNAME)
	ModifyGraph/W=$pnlName#filtered noLabel=2, axThick=0, standoff=0, margin=1
		//	FFT
	Display/FG=(IMGL, IMGT, IMGR, IMGB)/HOST=$pnlName
	RenameWindow $pnlName#$S_name, fourier
	SetWindow $pnlName#fourier userData(tab)="2"
	AppendImage/W=$pnlName#fourier $(dfTmp+FOURIERNAME)
	AppendImage/W=$pnlName#fourier $(dfTmp+MASKNAME)
	ModifyGraph/W=$pnlName#fourier noLabel=2, axThick=0, standoff=0, margin=1
	ModifyImage/W=$pnlName#fourier $FOURIERNAME ctab= {*,WaveMax($(dfTmp+FOURIERNAME))*0.1,Terrain,0}
	
	SetWindow $pnlName#original hide=0
	SetWindow $pnlName#filtered hide=0
	SetActiveSubWindow $pnlName
	KMTabControlInitialize(pnlName,"mTab")
End
//-------------------------------------------------------------
//	パネル初期設定
//-------------------------------------------------------------
Static Function/S pnlInit(String pnlName, Wave w)
	String dfSav = KMNewTmpDf(pnlName,"KMFilterPnl")	//  一時データフォルダ作成
	String dfTmp = GetDataFolder(1)
	
	//	表示用オリジナルウエーブ
	if (WaveDims(w)==2)
		Duplicate w $ORIGINALNAME/WAVE=ow
	else
		Duplicate/R=[][][0] w $ORIGINALNAME/WAVE=ow
		Redimension/N=(-1,-1) ow
	endif
	
	//	フィルタをかけた結果ウエーブ
	Duplicate ow $FILTEREDNAME
	
	//	FFTウエーブ
	SetDataFolder GetWavesDataFolderDFR(w)
	String name = UniqueName("wave",1,0)
	SetDataFolder $dfTmp
	MoveWave KMFFT(ow,result=name,win="Welch",out=3,subtract=1), $FOURIERNAME
	
	//	表示リスト用ウエーブ
	Make/N=(0,7)/T $KM_WAVE_LIST/WAVE=listw
	Make/N=(0,7) $KM_WAVE_SELECTED
	Make/N=7/T/FREE labelw = {"p0","q0","n0","p1","q1","n1","HWHM"}
	int i
	for (i = 0; i < 7; i++)
		SetDimLabel 1, i, $(labelw[i]), listw
	endfor
	
	//	表示リストの変更を拾う従属関係定義
	Variable/G dummy
	String str
	Sprintf str, "KMFourierFilter#pnlListChange(%s,\"%s\")", dfTmp+KM_WAVE_LIST, pnlName
	SetFormula dummy, str
	
	//	マスク表示用ウエーブ
	Make/B/U/N=(DimSize(w,0),DimSize(w,1),4) $MASKNAME/WAVE=maskw
	maskw[][][,2] = 255
	maskw[][][3] = 0
	CopyScales $FOURIERNAME maskw
	
	SetDataFolder $dfSav
	return dfTmp
End

//******************************************************************************
//	フック関数:
//******************************************************************************
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			KMonClosePnl(s.winName)
			break
		case 4:	//	mousemoved
			if (strlen(ImageNameList(s.winName,";")))		//	グラフを表示しているサブウインドウだけで有効
				KMDisplayCtrlBarUpdatePos(s, win=StringFromList(0, s.winName, "#"))
			endif
			break
		case 5:	//	mouseup
			if (strlen(ImageNameList(s.winName,";")))		//	グラフを表示しているサブウインドウだけで有効
				pnlHookMouseup(s)
			endif
			break
		case 6:	//	resize
			Variable tabSize = s.winRect.right-340-2
			TabControl mTab size={tabSize,tabSize+40}, win=$s.winName
			ListBox filL size={330,tabSize+42-250}, win=$s.winName#table
			GetWindow $s.winName wsize
			MoveWindow/W=$s.winName V_left, V_top, V_right, V_top+(tabSize+42)*72/screenresolution
			break
		case 11:	//	keyboard
			if (s.keycode == 27)	//	esc
				KMonClosePnl(s.winName)
				KillWindow $s.winName
			endif
			break
	endswitch
	
	return 0
End
//-------------------------------------------------------------
//	 クリック時の動作、表に値を代入する
//-------------------------------------------------------------
Static Function pnlHookMouseup(STRUCT WMWinHookStruct &s)
	//	マウスカーソルの位置を取得する
	STRUCT KMMousePos ms
	ms.winhs = s
	ms.winhs.winName = s.winName
	if (KMGetMousePos(ms, grid=1))
		return 1
	endif
	
	String  pnlName = StringFromList(0, s.winName, "#")
	SetActiveSubWindow $pnlName
	Wave/SDFR=$GetUserData(pnlName,"","dfTmp") selw = $KM_WAVE_SELECTED
	Wave/SDFR=$GetUserData(pnlName,"","dfTmp")/T listw = $KM_WAVE_LIST
	if (!DimSize(selw,0))
		return 0
	endif
	WaveStats/Q/M=1 selw
	if (!(V_max & 1))	//	選択されているセルが無い
		return 0
	endif
	
	switch(V_maxColLoc)
		case 0:
		case 1:
			listw[V_maxRowLoc][0] = num2str(ms.p)
			listw[V_maxRowLoc][1] = num2str(ms.q)
			break
		case 3:
		case 4:
			listw[V_maxRowLoc][3] = num2str(ms.p)
			listw[V_maxRowLoc][4] = num2str(ms.q)
			break
		default:	//	2, 5, 6
			return 0
	endswitch
	listw[V_maxRowLoc][2] = "1"
	if (!strlen(listw[V_maxRowLoc][6]))
		listw[V_maxRowLoc][6] =  "1"
	endif
	selw[V_maxRowLoc][V_maxColLoc] -= 1	//	選択状態の解除	
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ポップアップメニュー
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	String pnlName = StringFromList(0,s.win,"#")
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	
	strswitch (s.ctrlName)
		case "colorP":
			Variable red, green, blue
			sscanf s.popStr, "(%d,%d,%d)", red, green, blue
			red = round(red/256) ;	green = round(green/256) ;	blue = round(blue/256)	//	高速化のための前処理
			Wave/SDFR=dfrTmp maskw = $MASKNAME
			MultiThread maskw[][][0] = red
			MultiThread maskw[][][1] = green
			MultiThread maskw[][][2] = blue
			break
			
		case "toP":
			Wave srcw = $GetUserData(pnlName,"","src")
			Wave/T/SDFR=dfrTmp listw = $KM_WAVE_LIST
			Make/N=(7,DimSize(listw,0))/FREE paramw = strlen(listw[q][p]) ? str2num(listw[q][p]) : 0
			ControlInfo/W=$s.win nameV ;		String result = S_Value
			ControlInfo/W=$s.win invertP ;	Variable invert = V_Value==2
			ControlInfo/W=$s.win endP ;		Variable endeffect = V_Value-1
			String paramStr = echoStr(srcw, paramw, result, invert, endeffect)
			KMPopupTo(s, paramStr)
			break
			
		case "endP":
			TitleBox endT disable=(s.popNum == 2), win=$s.win
			//*** THROUGH***
		case "invertP":
			if (s.popNum != str2num(GetUserData(s.win, s.ctrlName, "")))
				pnlUpdate(s.win, 1)
				PopupMenu $s.ctrlName userData=num2str(s.popNum), win=$s.win
			endif
			break
	endswitch
End
//-------------------------------------------------------------
//	スライダー
//-------------------------------------------------------------
Static Function pnlSlider(STRUCT WMSliderAction &s)
	if (s.eventCode & 4)
		Wave/SDFR=$GetUserData(StringFromList(0,s.win,"#"),"","dfTmp") maskw = $MASKNAME
		ImageStats/M=1/P=3 maskw
		Variable v = V_max*s.curval
		MultiThread maskw[][][3] = round(maskw[p][q][3]/v)
	endif
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)	
	if (s.eventCode != 2)
		return 1
	endif
	
	Variable disable = KMCheckSetVarString(s.win,s.ctrlName,0)
	pnlUpdate(s.win, disable)
End
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)	
	if (s.eventCode != 2)
		return 0
	endif
	
	String pnlName = StringFromList(0,s.win,"#")
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/T/SDFR=dfrTmp listw = $KM_WAVE_LIST
	Wave/SDFR=dfrTmp selw = $KM_WAVE_SELECTED
	int n = DimSize(selw,0)
	
	strswitch(s.ctrlName)
		case "addB":
			Redimension/N=(n+1,-1) listw, selw
			selw[n][] = 2
			selw[n][0] += 1	//	選択状態にする
			pnlUpdate(s.win, 1)
			break
		
		case "deleteB":
			WaveStats/Q/M=1 selw
			if (V_max & 1)		//	選択されているセルがあれば
				if (n > 1)
					DeletePoints/M=0 V_maxRowLoc, 1, listw, selw	//	selwに対する変更でpnlUpdateは呼ばれることになる
				else
					Redimension/N=(0,-1) listw, selw
					pnlUpdate(s.win, 2)
				endif
			endif
			break
		
		case "applyB":
			pnlButtonApply(s, dfrTmp, listw)
			break
		
		case "saveB":
			pnlButtonSave(s, dfrTmp, listw)
			break
			
		case "helpB":
			KMOpenHelpNote("filter", pnlName=pnlName, title="Fourier Filter")
			break
		
		case "closeB":
			KillWindow $pnlName
			break
	endswitch
End
//-------------------------------------------------------------
//	Applyボタンの動作
//-------------------------------------------------------------
Static Function pnlButtonApply(STRUCT WMButtonAction &s, DFREF dfrTmp, Wave/T listw)	
	if (s.eventCode != 2)
		return 0
	endif
	
	if (!DimSize(listw,0))		//	フィルタが1つも入力されていない
		return 0
	endif
	
	Wave/SDFR=dfrTmp ow=$ORIGINALNAME, maskw=$MASKNAME
	
	//	リストからパラメータウエーブを構成する
	Make/N=(7,DimSize(listw,0))/FREE paramw = strlen(listw[q][p]) ? str2num(listw[q][p]) : 0
	if (KMFilterCheckParameters(paramw, ow))
		DoAlert 0, "a paremeter(s) is out of range"
		return 1
	endif
	
	pnlUpdate(s.win, 3)
	
	//	フィルタ実行
	ControlInfo/W=$s.win invertP ;	int invert = V_Value==2
	ControlInfo/W=$s.win endP ;		int endeffect = V_Value-1
	Wave/WAVE ww = applyFilter(ow, paramw, invert, endeffect)
	
	//	表示用マスクウエーブを作成する
	Wave mw = ww[1]
	Variable nx = DimSize(ow,0), ny = DimSize(ow,1)
	ControlInfo/W=$s.win opacityS
	MultiThread maskw[nx/2-1,][][3] = round((1-mw[p-nx/2+1][q])*V_Value)
	MultiThread maskw[,nx/2-2][][3] = maskw[nx-1-p][ny-1-q]
	
	//	表示用フィルタ済みウエーブへと実行結果をコピーする
	Duplicate/O ww[0] dfrTmp:$FILTEREDNAME
	
	pnlUpdate(s.win, 0)
End
//-------------------------------------------------------------
//	Saveボタンの動作
//-------------------------------------------------------------
Static Function pnlButtonSave(STRUCT WMButtonAction &s, DFREF dfrTmp, Wave/T listw)
	if (s.eventCode != 2)
		return 0
	endif
	
	String pnlName = StringFromList(0,s.win,"#")
	Wave srcw = $GetUserData(pnlName,"","src")
	
	Make/N=(7,DimSize(listw,0))/FREE paramw = strlen(listw[q][p]) ? str2num(listw[q][p]) : 0
	
	ControlInfo/W=$s.win nameV ;	String result = S_Value
	ControlInfo/W=$s.win invertP ;	Variable invert = V_Value==2
	ControlInfo/W=$s.win endP ;	Variable endeffect = V_Value-1
	
	if (WaveDims(srcw) == 2)
		//	2次元の場合は、再計算の必要がないので、
		//	既にある結果を複製し、履歴欄にコマンドを出力する
		DFREF dfr = GetWavesDataFolderDFR(srcw)
		Duplicate/O dfrTmp:$FILTEREDNAME dfr:$result/WAVE=resw
		print PRESTR_CMD + echoStr(srcw, paramw, result, invert, endeffect)
	else
		//	3次元の場合は、全範囲を計算する
		pnlUpdate(s.win, 3)
		Wave resw = KMFilter(srcw, paramw, result=result, invert=invert, endeffect=endeffect, history=1)
		pnlUpdate(s.win, 0)
	endif
	
	ControlInfo/W=$s.win displayC
	if (V_Value)
		KMDisplay(w=resw)
	endif
End

//******************************************************************************
//	パネルコントロール補助関数
//******************************************************************************
//-------------------------------------------------------------
//	表示リストに変更があれば、saveボタンを選択できないようにする従属関係関数
//-------------------------------------------------------------
Static Function pnlListChange(Wave/T w, String pnlName)
	if (DimSize(w,0))	//	初期設定時とdeleteBによりselwが空になった場合には動作を抑制する
		pnlUpdate(pnlName+"#controls", 1)
	endif
	return 0
End
//-------------------------------------------------------------
//	パネルの表示状態を更新
//	0: すべて選択可能, 1: save,displayのみ選択不可能, 2: add, help, close以外選択不可能, 3: すべて選択不可能
//-------------------------------------------------------------
Static Function pnlUpdate(String pnlName, int state)
	
	GroupBox filterG disable=(state==3)*2, win=$pnlName
	Button addB disable=(state==3)*2, win=$pnlName
	TitleBox addT disable=(state==3)*2, win=$pnlName
	
	Button deleteB disable=(state>=2)*2, win=$pnlName
	TitleBox deleteT disable=(state>=2)*2, win=$pnlName
	Button applyB disable=(state>=2)*2, win=$pnlName
	PopupMenu invertP disable=(state>=2)*2, win=$pnlName
	TitleBox applyT disable=(state>=2)*2, win=$pnlName
	
	GroupBox maskG disable=(state>=2)*2, win=$pnlName
	TitleBox maskT disable=(state>=2)*2, win=$pnlName
	PopupMenu colorP disable=(state>=2)*2, win=$pnlName
	Slider opacityS disable=(state>=2)*2, win=$pnlName
	
	PopupMenu endP disable=(state>=2)*2, win=$pnlName
	SetVariable nameV disable=(state>=2)*2, win=$pnlName
	
	Button saveB disable=(state>=1)*2, win=$pnlName
	CheckBox displayC disable=(state>=1)*2, win=$pnlName
	
	PopupMenu toP disable=(state>=2)*2, win=$pnlName
	Button helpB disable=(state==3)*2, win=$pnlName
	Button closeB disable=(state==3)*2, win=$pnlName
	
	ControlInfo/W=$pnlName endT
	if (V_disable==0)
		TitleBox endT disable=(state>=2)*2, win=$pnlName
	endif
	
	ControlUpdate/A/W=$pnlName
End