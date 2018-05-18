#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMLineProfile

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Static StrConstant PROF_1D_NAME = "W_ImageLineProfile"
Static StrConstant PROF_X_NAME = "W_LineProfileX"
Static StrConstant PROF_Y_NAME = "W_LineProfileY"
Static StrConstant STDV_1D_NAME = "W_LineProfileStdv"
Static StrConstant PROF_2D_NAME = "M_ImageLineProfile"
Static StrConstant STDV_2D_NAME = "M_LineProfileStdv"

Static StrConstant PNL_W = "KMLineProfilePnl"
Static StrConstant PNL_C = "KMLineProfilePnlC"
Static StrConstant PNL_B1 = "KMLineProfilePnl_b"
Static StrConstant PNL_B2 = "KMLineProfilePnl_y"
Static StrConstant PNL_T = "KMLineProfilePnlT"

//******************************************************************************
//	KMLineProfile
//		条件振り分け・チェック
//******************************************************************************
Function KMLineProfile(
	Wave/Z w,			//	実行対象となる2D/3Dウエーブ
	Variable p1,		//	開始点のp, q値
	Variable q1,
	Variable p2,		//	終了点のp, q値
	Variable q2,
	[
		Variable width,	//	断面図取得の幅を指定, 省略時は0
		int output,		//	bit 0: サンプリング点を記録したウエーブを出力する
							//	bit 1: width>0 の時に標準偏差ウエーブを出力する
							//	省略時は0
		int history,		//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
		String result	//	結果ウエーブの名前, 省略時は、W_ImageLineProfile
	])
		
	STRUCT paramStruct s
	Wave s.w = w
	s.p1 = p1
	s.q1 = q1
	s.p2 = p2
	s.q2 = q2
	s.result = SelectString(ParamIsDefault(result), result, PROF_1D_NAME)
	s.width = ParamIsDefault(width) ? 0 : width
	s.output = ParamIsDefault(output) ? 0 : output
	s.dfr = GetWavesDataFolderDFR(s.w)
	
	if (!isValidArguments(s))
		print s.errMsg
		return 1
	endif
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		String paramStr = GetWavesDataFolder(w,2) + ","
		paramStr += num2str(p1) + "," + num2str(q1) + ","
		paramStr += num2str(p2) + "," + num2str(q2)
		paramStr += SelectString(ParamIsDefault(result), ",result=\""+result+"\"", "")
		paramStr += SelectString(ParamIsDefault(width), ",width="+num2str(width), "")
		paramStr += SelectString(ParamIsDefault(output), ",output="+num2str(output), "")
		printf "%sKMLineProfile(%s)\r", PRESTR_CMD, paramStr
	endif
	
	//	実行関数
	getLineProfile(s)
	
	return 0
End

Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMLineProfile gave error: "
	
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 0
	elseif (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
		s.errMsg += "the dimension of input wave must be 2 or 3."
		return 0
	endif
	
	if ((WaveDims(s.w) == 2 && strlen(s.result) > MAX_OBJ_NAME) || (WaveDims(s.w) == 3 && strlen(s.result) > MAX_OBJ_NAME-3))
		s.errMsg += "length of name for output wave exceeds the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 0
	endif
	
	if (numtype(s.p1) || numtype(s.q1) || numtype(s.p2) || numtype(s.q2))
		s.errMsg += "coordinate must be a normal number."
		return 0
	endif
	
	if (s.width < 0)
		s.errMsg += "width must be positive."
		return 0
	endif
	
	if (s.output > 3)
		s.errMsg += "output must be an integer between 0 and 3."
		return 0
	endif
	
	return 1
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	double	p1
	double	p2
	double	q1
	double q2
	double	width
	uchar	output
	String	result
	DFREF dfr
EndStructure

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	String grfName = WinName(0,1), imgName = StringFromList(0, ImageNameList(grfName, ";"))
	pnl(grfName, imgName)
End


//******************************************************************************
//	実行関数
//******************************************************************************
Static Function getLineProfile(STRUCT paramStruct &s)
	
	int i
	DFREF dfrSav = GetDataFolderDFR(), dfr = s.dfr
	SetDataFolder NewFreeDataFolder()
	
	Variable ox = DimOffset(s.w,0), oy = DimOffset(s.w,1)
	Variable dx = DimDelta(s.w,0), dy = DimDelta(s.w,1)
	Make/D/N=2 xw = {ox+dx*s.p1, ox+dx*s.p2}, yw = {oy+dy*s.q1, oy+dy*s.q2}
	
	int isComplex =  WaveType(s.w) & 0x01
	if (isComplex)
		MatrixOP/FREE realw = real(s.w)
		MatrixOP/FREE imagw = imag(s.w)
		Copyscales s.w, realw, imagw
	endif
	
	//	2D & complex
	if (WaveDims(s.w)==2 && isComplex)
		//	実部
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC xWave=xw, yWave=yw, srcwave=realw, width=s.width
		Wave linew0 = $PROF_1D_NAME, sdevw0 = $STDV_1D_NAME
		//	虚部
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC xWave=xw, yWave=yw, srcwave=imagw, width=s.width
		Wave linew1 = $PROF_1D_NAME, sdevw1 = $STDV_1D_NAME
		//	複素数にまとめる
		MatrixOP/C linew = cmplx(linew0,linew1)
		MatrixOP/C sdevw = cmplx(sdevw0,sdevw1)
		//	スケーリング・出力
		scalingLineProfile(s,linew,sdevw)
		Duplicate/O linew dfr:$s.result
		if (s.output&2)
			Duplicate/O sdevw dfr:$STDV_1D_NAME
		endif
		
	//	2D & real
	elseif (WaveDims(s.w)==2)
		ImageLineProfile/S/SC xWave=xw, yWave=yw, srcwave=s.w, width=s.width
		//	スケーリング・出力
		scalingLineProfile(s,$PROF_1D_NAME,$STDV_1D_NAME)
		Duplicate/O $PROF_1D_NAME dfr:$s.result
		if (s.output&2)
			Duplicate/O $STDV_1D_NAME dfr:$STDV_1D_NAME
		endif
		
	//	3D & complex
	elseif (WaveDims(s.w)==3 && isComplex)
		//	実部
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC/P=-2 xWave=xw, yWave=yw, srcwave=realw, width=s.width
		Wave linew0 = $PROF_2D_NAME, sdevw0 = $STDV_2D_NAME
		//	虚部
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/S/SC/P=-2 xWave=xw, yWave=yw, srcwave=imagw, width=s.width
		Wave linew1 = $PROF_2D_NAME, sdevw1 = $STDV_2D_NAME
		//	複素数にまとめる
		MatrixOP/C linew = cmplx(linew0,linew1)
		MatrixOP/C sdevw = cmplx(sdevw0,sdevw1)
		//	スケーリング・出力	
		scalingLineProfile(s, linew, sdevw)
		outputLineProfileWaves(s, linew, sdevw)	
		
	//	3D & real
	elseif (WaveDims(s.w)==3)
		//	まずは2Dウエーブとして作成する
		ImageLineProfile/S/SC/P=-2 xWave=xw, yWave=yw, srcwave=s.w, width=s.width
		//	スケーリング・出力
		scalingLineProfile(s, $PROF_2D_NAME, $STDV_2D_NAME)
		outputLineProfileWaves(s, $PROF_2D_NAME, $STDV_2D_NAME)
	endif
	
	//	サンプリング点を記録したウエーブを出力
	if (s.output&1)
		Wave posxw = $PROF_X_NAME, posyw = $PROF_Y_NAME
		SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,0)), posxw
		SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,1)), posyw
		Duplicate/O posxw dfr:$PROF_X_NAME
		Duplicate/O posyw dfr:$PROF_Y_NAME
	endif
	
	SetDataFolder dfrSav
End
//-------------------------------------------------------------
//	scaling 設定、note 設定などの共通部分
//-------------------------------------------------------------
Static Function scalingLineProfile(STRUCT paramStruct &s, Wave linew, Wave sdevw)
	
	Variable distance = sqrt((s.p1-s.p2)^2*DimDelta(s.w,0)^2+(s.q1-s.q2)^2*DimDelta(s.w,1)^2)
	SetScale/I x 0, distance, WaveUnits(s.w,0), linew, sdevw
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,0)), linew, sdevw
	if (WaveDims(s.w)==3)
		SetScale/P y DimOffset(s.w,2), DimDelta(s.w,2), WaveUnits(s.w,2), linew, sdevw
	endif
	
	String noteStr
	Sprintf noteStr, "src@%s;start@p=%d,q=%d;end@p=%d,q=%d;width=%f", GetWavesDataFolder(s.w, 2), s.p1, s.q1, s.p2, s.q2, s.width
	Note linew, noteStr
	Note sdevw, noteStr
End

Static Function outputLineProfileWaves(STRUCT paramStruct &s, Wave linew, Wave sdevw)
	DFREF dfr = s.dfr
	Duplicate/O linew dfr:$s.result
	if (KMisUnevenlySpacedBias(s.w))
		Duplicate/O KMGetBias(s.w,1) dfr:$(s.result+"_b")
		Duplicate/O KMGetBias(s.w,2) dfr:$(s.result+"_y")
	endif
	if (s.output & 2)
		Duplicate/O $STDV_2D_NAME dfr:$STDV_2D_NAME
	endif
End


//=====================================================================================================


//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(String grfName, String imgName)
	//	重複チェック
	if (strlen(GetUserData(grfName,"","KMLineProfilePnl")))
		DoWindow/F $GetUserData(grfName,"","KMLineProfilePnl")
		return 0
	endif
	
	//	初期設定
	DFREF dfrSav = GetDataFolderDFR()
	String dfTmp = pnlInit(grfName)
	SetDataFolder $dfTmp
	
	Wave w = KMGetImageWaveRef(grfName)
	int i
	
	//	表示
	Display/K=1/W=(0,0,315*72/screenresolution,340*72/screenresolution) as "Line Profile"
	String pnlName = S_name
	AutoPositionWindow/E/M=0/R=$grfName $pnlName
	
	//  フック関数・ユーザデータ
	SetWindow $grfName hook(KMLineProfilePnl)=KMLineProfile#pnlHookParent, userData(KMLineProfilePnl)=pnlName
	SetWindow $pnlName hook(self)=KMLineProfile#pnlHook, userData(parent)=grfName
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	SetWindow $pnlName userData(grid)="1"
	SetWindow $pnlName userData(dfTmp)=dfTmp
	SetWindow $pnlName userData(dim)="1"
	if (WaveDims(w)==3)
		SetWindow $pnlName userData(highlight)="1"
	endif
	SetWindow $pnlName userData(rev)="1156"
	
	//	コントロール
	KMLineCommon#pnlCtrls(pnlName)
	SetVariable widthV title="width", pos={208,4}, size={101,15}, format="%.2f", win=$pnlName
	SetVariable widthV limits={0,inf,0.1}, value=_NUM:0, bodyWidth=70, win=$pnlName
	ModifyControlList "p1V;q1V;p2V;q2V;distanceV;angleV;widthV" proc=KMLineProfile#pnlSetVar, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	//	初期値に対するラインプロファイル取得
	pnlUpdateLineProfile(pnlName)
	//	ラインプロファイルを取得したら親グラフ用のテキストマーカーウエーブも更新する
	pnlUpdateTextmarker(pnlName)
	
	//	ウォーターフォール表示領域
	if (WaveDims(w)==2)
		Display/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W
	elseif (KMisUnevenlySpacedBias(w))
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W vs {*, $PNL_B1}
	else
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W
	endif
	pnlModifyGraph(pnlName+"#line")
	pnlUpdateColor(pnlName)
	
	//	イメージ表示領域
	if (WaveDims(w)==3)
		Display/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=image/HIDE=1
		if (KMisUnevenlySpacedBias(w))
			AppendImage/W=$pnlName#image $PNL_W vs {*, $PNL_B2}
		else
			AppendImage/W=$pnlName#image $PNL_W
		endif
		pnlModifyGraph(pnlName+"#image")
	endif
	SetActiveSubWindow $pnlName
	
	//	親グラフへの表示
	AppendToGraph/W=$grfName $PROF_Y_NAME vs $PROF_X_NAME
	String trcName = KMWaveToTraceName(grfName, $PROF_Y_NAME)
	ModifyGraph/W=$grfName mode($trcName)=4,textMarker($trcName)={$PNL_T,"default",0,0,1,0.00,0.00},msize($trcName)=5
	
	SetDataFolder dfrSav
End
//-------------------------------------------------------------
//	パネル初期設定
//-------------------------------------------------------------
Static Function/S pnlInit(String grfName)
	String dfSav = KMNewTmpDf(grfName,"KMLineProfilePnl")
	String dfTmp = GetDataFolder(1)
	
	Make/N=(1,1) $PNL_W
	Make/N=(1,3) $PNL_C
	Make/T/N=2 $PNL_T = {"1","2"}
	
	SetDataFolder $dfSav
	return dfTmp
End
//-------------------------------------------------------------
//	グラフ領域の表示詳細
//-------------------------------------------------------------
Static Function pnlModifyGraph(String plotArea)
		
	ModifyGraph/W=$plotArea margin(top)=8,margin(right)=8,margin(bottom)=36,margin(left)=44
	ModifyGraph/W=$plotArea tick=0,btlen=5,mirror=0,lblMargin=2, gfSize=10
	ModifyGraph/W=$plotArea rgb=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$plotArea axRGB=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$plotArea tlblRGB=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$plotArea alblRGB=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$plotArea gbRGB=(KM_CLR_BG_R, KM_CLR_BG_G, KM_CLR_BG_B)
	ModifyGraph/W=$plotArea wbRGB=(KM_CLR_BG_R, KM_CLR_BG_G, KM_CLR_BG_B)
	Label/W=$plotArea bottom "Scaling Distance (\\u\M)"
	Label/W=$plotArea left "\\u"
	
	SetDrawLayer/W=$plotArea ProgBack
	SetDrawEnv/W=$plotArea textrgb=(KM_CLR_NOTE_R, KM_CLR_NOTE_G, KM_CLR_NOTE_B), fstyle=2, fsize=10
	SetDrawEnv/W=$plotArea xcoord=rel, ycoord=rel
	DrawText/W=$plotArea 0.03,0.99,"pos 1"
	SetDrawLayer/W=$plotArea ProgBack
	SetDrawEnv/W=$plotArea textrgb=(KM_CLR_NOTE_R, KM_CLR_NOTE_G, KM_CLR_NOTE_B), fstyle=2, fsize=10
	SetDrawEnv/W=$plotArea xcoord=rel,ycoord=rel, textxjust=2
	DrawText/W=$plotArea 0.97,0.99,"pos 2"
	
	String pnlName = StringFromList(0,plotArea,"#")
	int is3D = WaveDims($GetUserData(pnlName,"","src")) == 3
	if (!CmpStr(StringFromList(1,plotArea,"#"),"line") && is3D)
		ModifyWaterfall/W=$plotArea angle=90,axlen=0.5,hidden=0
		ModifyGraph/W=$plotArea mode=0,useNegRGB=1,usePlusRGB=1,negRGB=(0,0,0),plusRGB=(0,0,0)
		ModifyGraph/W=$plotArea noLabel(right)=2,axThick(right)=0
		//	highlightのデフォルト値は1
		Wave/SDFR=$GetUserData(pnlName,"","dfTmp") clrw = $PNL_C
		ModifyGraph/W=$plotArea zColor={clrw,*,*,directRGB,0}
	endif
End
//-------------------------------------------------------------
//	パネルの内容に合わせてラインプロファイルを取得する
//-------------------------------------------------------------
Static Function pnlUpdateLineProfile(String pnlName)
	STRUCT paramStruct s
	Wave s.w = $GetUserData(pnlName,"","src")
	ControlInfo/W=$pnlName p1V ;	s.p1 = V_Value
	ControlInfo/W=$pnlName q1V ;	s.q1 = V_Value
	ControlInfo/W=$pnlName p2V ;	s.p2 = V_Value
	ControlInfo/W=$pnlName q2V ;	s.q2 = V_Value
	ControlInfo/W=$pnlName widthV ;	s.width = V_Value
	s.output = 5
	s.result = PNL_W
	s.dfr = $GetUserData(pnlName,"","dfTmp")
	getLineProfile(s)
End
//-------------------------------------------------------------
//	ラインプロファイルに合わせてマーカーウエーブを更新する
//-------------------------------------------------------------
Static Function pnlUpdateTextmarker(String pnlName)
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/SDFR=dfrTmp lw = $PROF_X_NAME
	Wave/T/SDFR=dfrTmp tw = $PNL_T
	
	tw = ""
	ControlInfo/W=$pnlName p1C;		Variable p1Checked = V_Value | !V_Flag		//	最初に呼び出されるときには1を代入するために!V_Flagを使う
	ControlInfo/W=$pnlName p2C;		Variable p2Checked = V_Value | !V_Flag
	Redimension/N=(numpnts(lw)) tw
	if (p1Checked)
		tw[0] = "1"
	endif
	if (p2Checked)
		tw[numpnts(lw)-1] = "2"
	endif
End
//-------------------------------------------------------------
//	3Dウエーブが対象となっているときに、表示レイヤーに対応するプロファイルの表示色を変更する
//-------------------------------------------------------------
Static Function pnlUpdateColor(String pnlName)
	String grfName = GetUserData(pnlName,"","parent")
	if (WaveDims(KMGetImageWaveRef(grfName))==2)
		return 0
	elseif (CmpStr(GetUserData(pnlName,"","highlight"),"1"))
		return 0
	endif
	
	Wave/SDFR=$GetUserData(pnlName,"","dfTmp") w = $PNL_W, clrw = $PNL_C
	Redimension/N=(numpnts(w),3) clrw
	clrw[][0] = KM_CLR_LINE_R
	clrw[][1] = KM_CLR_LINE_G
	clrw[][2] = KM_CLR_LINE_B
	
	int layer = KMLayerViewerDo(grfName)
	int p0 = layer*DimSize(w,0)
	int p1 = (layer+1)*DimSize(w,0)-1
	clrw[p0,p1][0] = KM_CLR_LINE2_R
	clrw[p0,p1][1] = KM_CLR_LINE2_G
	clrw[p0,p1][2] = KM_CLR_LINE2_B		
End



//******************************************************************************
//	フック関数
//******************************************************************************
//-------------------------------------------------------------
//	パネル用
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	//	矢印キー (keycode 28-31) の場合には、ラインプロファイルの更新を行い、それ以外については共通関数で扱う
	//	共通関数では eventCode 0 (activate), 1 (deactivate), 2 (kill), 3 (mousedown), 11 (keyboard) を扱っている
	if (s.eventCode == 11 && 28 <= s.keycode && s.keycode <= 31)
		switch (s.keycode)
			case 28:		//	left
			case 29:		//	right
			case 30:		//	up
			case 31:		//	down
				KMLineCommon#keyArrows(s)
				pnlUpdateLineProfile(s.winName)
				pnlUpdateTextmarker(s.winName)
				pnlUpdateColor(s.winName)
				return 1
		endswitch
	endif
	
	return KMLineCommon#pnlHook(s)
End
//-------------------------------------------------------------
//	パネルが閉じられた場合の動作
//-------------------------------------------------------------
Static Function pnlHookClose(STRUCT WMWinHookStruct &s)
	String grfName = GetUserData(s.winName,"","parent")
	DoWindow $grfName
	if (V_Flag)
		SetWindow $grfName hook(KMLineProfilePnl)=$"",userdata(KMLineProfilePnl)=""
		KMRemoveAll(grfName,df=GetUserData(s.winName,"","dfTmp"))
	endif
	
	//	Newwaterfall wave0 vs {*, wavez}
	//	NewWaterfall で wavez が有効になっている時(KMLineProfileで非等間隔バイアスウエーブを扱う時)には
	//	表示ウエーブを削除しても wavez が表示されたままの扱いになってしまう (Igorのバグ?)
	//	そこで、s.winName+#line を先に閉じてしまうことにする
	KillWindow $(s.winName+"#line")	
	
	KMonClosePnl(s.winName,df=GetUserData(s.winName,"","dfTmp"))
	KillWindow $s.winName
End
//-------------------------------------------------------------
//	フック関数親ウインドウ用
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	String pnlName = GetUserData(s.winName,"","KMLineProfilePnl")
	switch (s.eventCode)
		case 2:	//	kill
			KillWindow/Z $pnlName
			break
		case 3:	//	mousedown
		case 4:	//	mousemoved
			STRUCT KMMousePos ms
			ms.grid = str2num(GetUserData(pnlName,"","grid"))
			ms.winhs = s
			KMLineCommon#pnlHookParentMouse(s, ms, pnlName)
			//** THROUGH **
		case 8:	//	modified
			//	rev. 1156 より前に作られたものであれば、後方互換確保の関数を動作させる
			Variable rev = str2num(GetUserData(pnlName,"","rev"))
			if (numtype(rev) || rev < 1156)
				DoWindow/F $pnlName
				break
			endif
			//	---(後方互換ここまで)
			pnlUpdateLineProfile(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(pnlName)
			DoUpdate/W=$pnlName
			DoUpdate/W=$s.winName
			break
	endswitch
	return 0
End
//-------------------------------------------------------------
//	rev. 1156 の変更に伴う後方互換性の確保
//-------------------------------------------------------------
Static Function pnlBackwardCompatibility(String pnlName)
	Wave srcw = $GetUserData(pnlName,"","src")
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp"), dfrSav = GetDataFolderDFR()
	SetDataFolder dfrTmp
	
	Make/N=(1,3) $PNL_C
	Rename $"textmarker" $PNL_T
	Rename $PROF_2D_NAME $PNL_W
	if (WaveExists($(PROF_2D_NAME+"_y")))
		Rename $(PROF_2D_NAME+"_y") $PNL_B2
	endif
	pnlUpdateLineProfile(pnlName)
	
	KillWindow $(pnlName+"#line")
	int hide = str2num(GetUserData(pnlName,"","dim")) == 2
	if (KMisUnevenlySpacedBias(srcw))
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line/HIDE=(hide) $PNL_W vs {*, $PNL_B1}
	else
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line/HIDE=(hide) $PNL_W
	endif
	pnlModifyGraph(pnlName+"#line")
	
	SetDataFolder dfrSav
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == -1 || s.eventCode == 6)
		return 1
	endif
	
	//	変更されたコントロールの値に応じて、他のコントロールの値を整合性が取れるように変更する
	KMLineCommon#pnlSetVarUpdateValues(s)
	
	//	変更された値を元にしてラインプロファイルを更新する
	pnlUpdateLineProfile(s.win)
	pnlUpdateTextmarker(s.win)
	pnlUpdateColor(s.win)
End


//******************************************************************************
//	右クリックメニュー
//******************************************************************************
//-------------------------------------------------------------
//	LineProfileの右クリックメニュー
//-------------------------------------------------------------
Menu "KMLineProfileMenu", dynamic, contextualmenu
	SubMenu "Positions"
		KMLineCommon#pnlRightClickMenu(0), KMLineProfile#pnlRightClickDo(0)
	End
	SubMenu "Dimension"
		KMLineCommon#pnlRightClickMenu(1), KMLineProfile#pnlRightClickDo(1)
	End
	SubMenu "Complex"
		KMLineCommon#pnlRightClickMenu(2), KMLineProfile#pnlRightClickDo(2)
	End
	SubMenu "Style"
		KMLineCommon#pnlRightClickMenu(3), KMLineProfile#pnlRightClickDo(3)
		KMLineCommon#pnlRightClickMenu(4), KMLineProfile#pnlRightClickDo(4)
	End
	"Save...", KMLineProfile#outputPnl(WinName(0,1))
	"-"
	KMLineCommon#pnlRightClickMenu(7),/Q, KMRange(grfName=WinName(0,1)+"#image")
	KMLineCommon#pnlRightClickMenu(8),/Q, KMColor(grfName=WinName(0,1)+"#image")
End
//-------------------------------------------------------------
//	右クリックメニューの実行項目
//-------------------------------------------------------------
Static Function pnlRightClickDo(int mode)
	String pnlName = WinName(0,1)
	int grid = str2num(GetUserData(pnlName,"","grid"))
	
	switch (mode)
		case 0:	//	positions
			//	選択内容に応じて p1V, q1V等の値を変更する
			KMLineCommon#pnlRightclickDoPositions(pnlName)
			//	変更後の p1V, q1V, p2V, q2V の値に合わせてラインプロファイルを更新する
			pnlUpdateLineProfile(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(pnlName)
			break
			
		case 1:	//	dim
			int dim = str2num(GetUserData(pnlName,"","dim"))
			GetLastUserMenuInfo
			if (V_value != dim)
				KMLineCommon#pnlChangeDim(pnlName, V_value)
			endif
			break
			
		case 2:	//	complex
			KMLineCommon#pnlRightclickDoComplex(pnlName)
			break
			
		case 3:	//	Free
			//	選択内容に応じて p1V, q1V, p2V, q2Vのフォーマットと値を適切に変更する
			KMLineCommon#pnlRightclickDoFree(pnlName)
			//	変更後の値に対応するようにラインプロファイルも変更する
			pnlUpdateLineProfile(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(pnlName)
			break
			
		case 4:	//	Highlight
			int highlight = str2num(GetUserData(pnlName,"","highlight"))
			SetWindow $pnlname userData(highlight)=num2istr(!highlight)
			
			if (highlight)
				//	on -> off
				ModifyGraph/W=$(pnlName+"#line") zColor=0
			else
				//	off -> on
				Wave/SDFR=$GetUserData(pnlName,"","dfTmp") clrw = $PNL_C
				ModifyGraph/W=$(pnlName+"#line") zColor={clrw,*,*,directRGB,0}
				pnlUpdateColor(pnlName)
			endif
			break
			
	endswitch
End


//=====================================================================================================


//******************************************************************************
//	断面図出力用パネル定義
//******************************************************************************
Static Function outputPnl(String profileGrfName)
	if (WhichListItem("Save",ChildWindowList(profileGrfName)) != -1)
		return 0
	endif
	
	ControlInfo/W=$profileGrfName widthV
	Variable width = V_Value
	
	//  パネル表示
	NewPanel/HOST=$profileGrfName/EXT=2/W=(0,0,315,125)/N=Save
	String pnlName = profileGrfName + "#Save"
	
	//  コントロール項目
	//  sdevC については width が 0 なら選択不可にする
	DFREF dfrSav = GetDataFolderDFR()
	Wave srcw = $GetUserData(profileGrfName,"","src")
	SetDataFolder GetWavesDataFolderDFR(srcw)
	SetVariable resultV title="wave name:", pos={10,10}, size={289,15},  bodyWidth=220, frame=1, win=$pnlName
	SetVariable resultV value=_STR:UniqueName("wave",1,0),proc=KMLineProfile#outputPnlSetVar, win=$pnlName
	SetDataFolder dfrSav
	
	CheckBox positionC title="save waves of sampling points (W_LineProfileX, Y)", pos={10,40}, size={88,14}, value=0, win=$pnlName
	CheckBox sdevC title="save waves of standard deviation (W_LineProfileStdv)", pos={10,64}, size={300,14}, value=0, disable=(!width)*2, win=$pnlName
	
	Button doB title="Do It", pos={10,95}, win=$pnlName
	Button closeB title="Close", pos={235,95}, win=$pnlName
	ModifyControlList "doB;closeB" size={70,20}, proc=KMLineProfile#outputPnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function outputPnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			outputPnlDo(s.win)
			//** THROUGH **
		case "closeB":
			KillWindow $(s.win)
			break
		case "HelpB":
			KMOpenHelpNote("lineprofile",pnlName=StringFromList(0,s.win,"#"),title="Line Profile")
			NoteBook $WinName(0,16) findText={"save:",7}
			break
		default:
	endswitch
	
	return 0
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function outputPnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	//	オリジナルウエーブ
	String grfName = GetUserData(StringFromList(0, s.win, "#"),"","parent")
	Wave w = KMGetImageWaveRef(grfName)
	int maxlength = (WaveDims(w)==3) ? MAX_OBJ_NAME-3 : MAX_OBJ_NAME
	int isProperLength = !KMCheckSetVarString(s.win,s.ctrlName,0,maxlength=maxlength)
	Button doB disable=(!isProperLength)*2, win=$s.win
End
//-------------------------------------------------------------
//	Doボタンの実行関数
//-------------------------------------------------------------
Static Function outputPnlDo(String pnlName)
	String prtName = StringFromList(0, pnlName, "#")
	int output = 0
	ControlInfo/W=$pnlName positionC;	output += V_Value
	ControlInfo/W=$pnlName sdevC;			output += V_Value*2
	ControlInfo/W=$pnlName resultV ;		String result = S_Value
	
	Wave cvw = KMGetCtrlValues(prtName,"p1V;q1V;p2V;q2V;widthV")
	Wave w = $GetUserData(prtName,"","src")
	
	KMLineProfile(w,cvw[0],cvw[1],cvw[2],cvw[3],result=result,width=cvw[4],output=output,history=1)
End