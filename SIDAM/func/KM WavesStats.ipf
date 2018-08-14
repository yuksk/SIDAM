#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = KMWavesStats

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//  後ろにつけて結果ウエーブの名前とするための文字列
StrConstant ks_index_avg = "_avg"
StrConstant ks_index_sdev = "_sdev"
StrConstant ks_index_skew = "_skew"
StrConstant ks_index_kurt = "_kurt"


//******************************************************************************
//	エラーチェック、動作振り分け
//******************************************************************************
Function/WAVE KMWavesStats(
	Wave/Z w,			//	1D/3Dウエーブ. 1Dの場合は、指定されたウエーブと同じデータフォルダにある同じサイズのウエーブの集合を対象とする.
						//	1Dウエーブへの参照を持つウエーブでもよい
	[
		int stats,		//	求める統計量を指定するフラッグ
							//	bit 0: 平均, bit 1: 標準偏差, bit 2: 歪度, bit 3: 尖度 
							//	省略時は1
		int mode,			//	3Dウエーブのときに、統計を取る方向を指定する
							//	0: xy方向、出力は1次元, 1: z方向、出力は2次元, 省略時は0
		int history,		//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
		String result	//	結果ウエーブの名前, result+"_avg"等になる. 省略時は、入力が1Dウエーブなら、
							//	そのウエーブがあるデータフォルダの名前、3Dウエーブならそのウエーブの名前
	])
	
	STRUCT paramStruct s
	Wave/Z s.w = w
	s.result = SelectString(ParamIsDefault(result),result,DefaultBasename(w))
	s.stats =  ParamIsDefault(stats) ? 1 : stats
	s.mode = ParamIsDefault(mode) ? 0 : mode
	
	if (!isValidArguments(s))
		print s.errMsg
		return $""
	endif
	
	//  履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + echoStr(s)
	endif
	
	//  実行
	if (WaveDims(w) == 1)
		return KMWavesStats1D(w, s.result, s.stats)
	elseif (WaveDims(w) == 3)
		return KMWavesStats3D(w, s.result, s.stats, s.mode)
	endif
End

//-------------------------------------------------------------
//	入力ウエーブの次元に応じて、デフォルトのbasenameを返す
//-------------------------------------------------------------
Static Function/S DefaultBasename(Wave/Z w)
	if (WaveDims(w) == 1)	//	参照ウエーブは1次元なのでこれでよい
		return KMUnquoteName(GetWavesDataFolder(w,0))
	elseif (WaveDims(w) == 3)
		return NameOfWave(w)
	else
		return ""
	endif
End

//-------------------------------------------------------------
//	チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMWavesStats gave error: "
	
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 0
	elseif (WaveDims(s.w) != 1 && WaveDims(s.w) != 3)
		s.errMsg += "the dimension of input wave must be 1 or 3."
		return 0
	elseif (WaveType(s.w,1) == 1)	//	数値ウエーブ
		if (WaveDims(s.w) == 1 && ItemsInList(KMWaveList(GetWavesDataFolderDFR(s.w),1,nx=numpnts(s.w))) == 1)
			s.errMsg += "number of waves in \""+GetWavesDataFolder(s.w,1)+"\" must be more than 1."
			return 0
		endif
	elseif (WaveType(s.w,1) == 4)	//	参照ウエーブ
		Wave/WAVE refw = s.w
		int i, n = numpnts(refw[0])
		for (i = 0; i < numpnts(refw); i++)
			Wave tw = refw[i]
			if (WaveDims(tw) != 1)
				s.errMsg += "the dimension of waves referred by the input wave must be 1."
				return 0
			elseif (numpnts(tw) != n)
				s.errMsg += "all waves referred by the input wave must have the same number of points."
				return 0
			endif
		endfor
	endif
	
	Make/N=4/FREE suffixLenw = {strlen(ks_index_avg),strlen(ks_index_sdev),strlen(ks_index_skew),strlen(ks_index_kurt)}
	if (strlen(s.result) + WaveMax(suffixLenw) > MAX_OBJ_NAME)
		s.errMsg += "length of name for output wave exceeds the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 0
	endif
	
	if (s.stats < 1 || s.stats > 15)
		s.errMsg += "stats must be an integer between 1 and 15."
		return 0
	endif
	
	s.mode = s.mode ? 1 : 0
	return 1
End

Static Structure paramStruct
	String	errMsg
	Wave	w
	String	result
	uint16	stats
	uchar	mode
EndStructure

//-------------------------------------------------------------
//	履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S echoStr(STRUCT paramStruct &s)
	String paramStr = GetWavesDataFolder(s.w,2)
	paramStr += SelectString(stringmatch(s.result,DefaultBasename(s.w)), ",result=\""+s.result+"\"", "")
	paramStr += SelectString(s.stats==1, ",stats="+num2str(s.stats),"")
	paramStr += SelectString(!s.mode || WaveDims(s.w)==1, ",mode="+num2str(s.mode),"")
	sprintf paramStr, "KMWavesStats(%s)", paramStr
	return paramStr
End

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(KMGetImageWaveRef(WinName(0,1)))
End


//=====================================================================================================


//******************************************************************************
//	実行関数1D
//******************************************************************************
Static Function/WAVE KMWavesStats1D(Wave w, String result, int stats)
	int n = numpnts(w), i
	
	//  統計取得用一時ウエーブ
	switch (WaveType(w,1))
		case 1:	//	数値ウエーブ
			DFREF dfr = GetWavesDataFolderDFR(w)
			String waveListStr = KMWaveList(dfr,1,nx=numpnts(w))
			Make/N=(ItemsInList(waveListStr), 1, n)/FREE setw
			for (i = 0; i < ItemsInList(waveListStr); i++)
				Wave/SDFR=dfr candidatew = $StringFromList(i,waveListStr)
				setw[i][0][] = candidatew[r]
			endfor
			SetScale/P z leftx(w), deltax(w), WaveUnits(w,0), setw
			SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(w,0)), setw
			break
		case 4:	//	参照ウエーブ
			Wave/WAVE refw = w
			Make/N=(n, 1, numpnts(refw[0]))/FREE setw
			for (i = 0; i < n; i++)
				Wave tw = refw[i]
				setw[i][0][] = tw[r]
			endfor
			SetScale/P z leftx(refw[0]), deltax(refw[0]), WaveUnits(refw[0],0), setw
			SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(refw[0],0)), setw
			break
		default:
			return $""
	endswitch
	
	//  実行
	return KMWavesStats3D(setw, result, stats, 0, dfr=GetWavesDataFolderDFR(w))
End

//******************************************************************************
//	実行関数3D
//******************************************************************************
Static Function/WAVE KMWavesStats3D(Wave w, String result, int stats, int mode, [DFREF dfr])
	int i, j
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//  結果ウエーブ
	if (mode)
		Make/N=(DimSize(w,0),DimSize(w,1)) sw0, sw1, sw2, sw3
		CopyScales w, sw0, sw1, sw2, sw3
	else
		Make/N=(DimSize(w,2)) sw0, sw1, sw2, sw3
		SetScale/P x DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), sw0, sw1, sw2, sw3
	endif
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(w,0)), sw0, sw1
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(w,0))+"^3", sw2
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(w,0))+"^4", sw3
	
	//  実行
	int nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	if (mode)
		Make/N=(nx, ny)/WAVE ww
		MultiThread ww = KMWavesStats3DWorker(w, p, q)
		for (i = 0; i < nx; i++)
			for (j = 0; j < ny; j++)
				Wave tw = ww[i][j]
				sw0[i][j] = tw[0]
				sw1[i][j] = tw[1]
				sw2[i][j] = tw[2]
				sw3[i][j] = tw[3]
			endfor
		endfor
	else
		for (i = 0; i < nz; i++)
			WaveStats/Q/R=[nx*ny*i,nx*ny*(i+1)-1] w	//	ImageStats/P=(i) w としたいが、1次元ウエーブを集めて3次元にした場合にエラーが出る (2013-05-31 Igor ver. 6.31)
			sw0[i] = V_avg
			sw1[i] = V_sdev
			sw2[i] = V_skew
			sw3[i] = V_kurt
		endfor
	endif
	
	//  結果複製
	Make/N=4/WAVE resw
	if (ParamIsDefault(dfr))
		SetDataFolder GetWavesDataFolderDFR(w)
	else
		SetDataFolder dfr
	endif
	if (stats&1)
		Duplicate/O sw0 $(result+ks_index_avg)/WAVE=statsw0
		resw[0] = statsw0
	endif
	if (stats&2)
		Duplicate/O sw1 $(result+ks_index_sdev)/WAVE=statsw1
		resw[1] = statsw1
	endif
	if (stats&4)
		Duplicate/O sw2 $(result+ks_index_skew)/WAVE=statsw2
		resw[2] = statsw2
	endif
	if (stats&8)
		Duplicate/O sw3 $(result+ks_index_kurt)/WAVE=statsw3
		resw[3] = statsw3
	endif
	if (KMisUnevenlySpacedBias(w))	//	NanonisのMLSモードでのウエーブの場合にはバイアス電圧情報を保存する
		Duplicate/O KMGetBias(w, 1) $(result+"_b")
	endif
	
	SetDataFolder dfrSav
	return resw
End

ThreadSafe Static Function/WAVE KMWavesStats3DWorker(Wave w, int pp, int qq)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Make/N=(DimSize(w,2)) tw = w[pp][qq][p]
	WaveStats/Q tw
	Make/N=4 resw = {V_avg, V_sdev, V_skew, V_kurt}
	
	SetDataFolder dfrSav
	return resw
End


//=====================================================================================================


//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(Wave w)
	String grfName = WinName(0,1)
	
	//  パネル表示
	String pnlName = KMNewPanel("WavesStats ("+NameOfWave(w)+")", 350, 205)
	AutoPositionWindow/E/M=0/R=$grfName $pnlName
	
	//  フック関数・ユーザデータ
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	
	//  コントロール項目
	SetVariable resultV title="basename:", pos={11,10}, size={330,15}, bodyWidth=270, frame=1, win=$pnlName
	SetVariable resultV value=_STR:DefaultBasename(w), proc=KMWavesStats#pnlSetVar, win=$pnlName
	
	GroupBox statsG title="statistics", pos={11,39}, size={145,120}, win=$pnlName
	CheckBox avgC title="average", pos={24,63}, value=1, win=$pnlName
	CheckBox sdevC title="standard deviation", pos={24,86}, value=0, win=$pnlName
	CheckBox skewC title="skewness", pos={24,109}, value=0, win=$pnlName
	CheckBox kurtC title="kurtosis", pos={24,132}, value=0, win=$pnlName
	ModifyControlList "avgC;sdevC;skewC;kurtC" proc=KMWavesStats#pnlCheck, win=$pnlName
	
	PopupMenu modeP title="dimension", pos={180,49}, size={144,20}, bodyWidth=90, win=$pnlName
	PopupMenu modeP mode=1, value= #"\"x and y;z\"", win=$pnlName
	
	Button doB title="Do It", pos={10,173}, win=$pnlName
	CheckBox displayC title="display", pos={98,176}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={160,174}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMWavesStats#pnlPopup, win=$pnlName
	Button cancelB title="Cancel", pos={271,173}, win=$pnlName
	ModifyControlList "doB;cancelB" size={70,22}, proc=KMWavesStats#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	pnlDisable(pnlName)
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
	
	strswitch (s.ctrlName)
		case "doB":
			pnlDo(s.win)
			break
		case "cancelB":
			KillWindow $(s.win)
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	ポップアップ
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	STRUCT paramStruct cs
	Wave cs.w = $GetUserData(s.win, "", "src")
	Wave cvw = KMGetCtrlValues(s.win, "avgC;sdevC;skewC;kurtC;modeP")
	cs.stats = cvw[0]+cvw[1]*2+cvw[2]*4+cvw[3]*8
	cs.mode = cvw[4]-1
	ControlInfo/W=$s.win resultV ;	cs.result = S_Value
	KMPopupTo(s, echoStr(cs))
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == 2)
		pnlDisable(s.win)
	endif
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode == 2)
		pnlDisable(s.win)
	endif
End

//******************************************************************************
//	パネルの表示状態を設定
//******************************************************************************
Static Function pnlDisable(String pnlName)
	Variable longName = KMCheckSetVarString(pnlName,"resultV",0)
	Variable noCheck = !sum(KMGetCtrlValues(pnlName, "avgC;sdevC;skewC;kurtC;"))
	
	ModifyControlList "doB;toP" disable=(longName || noCheck)*2, win=$pnlName
	
	if (noCheck)
		GroupBox statsG labelBack=(SIDAM_CLR_CAUTION_R,SIDAM_CLR_CAUTION_B,SIDAM_CLR_CAUTION_B), win=$pnlName
	else
		GroupBox statsG labelBack=0, win=$pnlName
	endif
End

//******************************************************************************
//	Doボタンの実行関数
//******************************************************************************
Static Function pnlDo(String pnlName)
	Wave w = $GetUserData(pnlName,"","src")
	Wave cvw = KMGetCtrlValues(pnlName, "avgC;sdevC;skewC;kurtC;modeP;displayC")
	Variable stats = cvw[0]+cvw[1]*2+cvw[2]*4+cvw[3]*8
	ControlInfo/W=$pnlName resultV ;	String result = S_Value
	KillWindow $pnlName
	
	Wave/WAVE resw = KMWavesStats(w,result=result,stats=stats,mode=cvw[4]-1,history=1)
	
	if (cvw[5])
		int i
		for (i = numpnts(resw)-1; i >= 0; i--)
			if (!WaveExists(resw[i]))
				DeletePoints i, 1, resw
			endif
		endfor
		KMDisplay(w=resw, history=1)
	endif
End