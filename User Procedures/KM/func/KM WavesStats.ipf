#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//  後ろにつけて結果ウエーブの名前とするための文字列
StrConstant ks_index_avg = "_avg"
StrConstant ks_index_sdev = "_sdev"
StrConstant ks_index_skew = "_skew"
StrConstant ks_index_kurt = "_kurt"


//******************************************************************************
//	KMWavesStats
//		エラーチェック、動作振り分け
//******************************************************************************
Function/WAVE KMWavesStats(w,[result,stats,mode,history])
	Wave/Z w			//	1D/3Dウエーブ. 1Dの場合は、指定されたウエーブと同じデータフォルダにある同じサイズのウエーブの集合を対象とする.
						//	1Dウエーブへの参照を持つウエーブでもよい
	Variable stats	//	求める統計量を指定するフラッグ
						//	bit 0: 平均, bit 1: 標準偏差, bit 2: 歪度, bit 3: 尖度 
						//	省略時は1
	Variable mode	//	3Dウエーブのときに、統計を取る方向を指定する
						//	0: xy方向、出力は1次元, 1: z方向、出力は2次元, 省略時は0
	Variable history	//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	String result	//	結果ウエーブの名前, result+"_avg"等になる. 省略時は、入力が1Dウエーブなら、
						//	そのウエーブがあるデータフォルダの名前、3Dウエーブならそのウエーブの名前
	
	STRUCT check s
	Wave/Z s.w = w
	s.result = SelectString(ParamIsDefault(result),result,DefaultBasename(w))
	s.stats =  ParamIsDefault(stats) ? 1 : stats
	s.mode = ParamIsDefault(mode) ? 0 : mode
	
	if (KMWavesStatsCheck(s))
		print s.errMsg
		return $""
	endif
	
	//  履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + KMWavesStatsEcho(s)
	endif
	
	//  実行
	if (WaveDims(w) == 1)
		return KMWavesStats1D(w, s.result, s.stats)
	elseif (WaveDims(w) == 3)
		return KMWavesStats3D(w, s.result, s.stats, s.mode)
	endif
End

//-------------------------------------------------------------
//	DefaultBasename
//		入力ウエーブの次元に応じて、デフォルトのbasenameを返す
//-------------------------------------------------------------
Static Function/S DefaultBasename(w)
	Wave/Z w
	
	if (WaveDims(w) == 1)	//	参照ウエーブは1次元なのでこれでよい
		return PossiblyUnquoteName(GetWavesDataFolder(w,0))
	elseif (WaveDims(w) == 3)
		return NameOfWave(w)
	else
		return ""
	endif
End

//-------------------------------------------------------------
//	KMWavesStatsCheck
//		チェック用関数
//-------------------------------------------------------------
Static Function KMWavesStatsCheck(STRUCT check &s)
	
	s.errMsg = PRESTR_CAUTION + "KMWavesStats gave error: "
	
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 1
	elseif (WaveDims(s.w) != 1 && WaveDims(s.w) != 3)
		s.errMsg += "the dimension of input wave must be 1 or 3."
		return 1
	elseif (WaveType(s.w,1) == 1)	//	数値ウエーブ
		if (WaveDims(s.w) == 1 && ItemsInList(KMWaveList(GetWavesDataFolderDFR(s.w),1,nx=numpnts(s.w))) == 1)
			s.errMsg += "number of waves in \""+GetWavesDataFolder(s.w,1)+"\" must be more than 1."
			return 1
		endif
	elseif (WaveType(s.w,1) == 4)	//	参照ウエーブ
		Wave/WAVE refw = s.w
		Variable i, n = numpnts(refw[0])
		for (i = 0; i < numpnts(refw); i += 1)
			Wave tw = refw[i]
			if (WaveDims(tw) != 1)
				s.errMsg += "the dimension of waves referred by the input wave must be 1."
				return 1
			elseif (numpnts(tw) != n)
				s.errMsg += "all waves referred by the input wave must have the same number of points."
				return 1
			endif
		endfor
	endif
	
	Make/N=4/FREE suffixLenw = {strlen(ks_index_avg),strlen(ks_index_sdev),strlen(ks_index_skew),strlen(ks_index_kurt)}
	if (strlen(s.result) + WaveMax(suffixLenw) > MAX_OBJ_NAME)
		s.errMsg += "length of name for output wave exceeds the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 1
	endif
	
	if (s.stats < 1 || s.stats > 15)
		s.errMsg += "stats must be an integer between 1 and 15."
		return 1
	endif
	
	s.mode = s.mode ? 1 : 0
End

Static Structure check
	String	errMsg
	Wave	w
	String	result
	uint16	stats
	uchar	mode
EndStructure

//-------------------------------------------------------------
//	KMWavesStatsEcho: 		履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S KMWavesStatsEcho(STRUCT check &s)
	
	String paramStr = GetWavesDataFolder(s.w,4)
	paramStr += SelectString(stringmatch(s.result,DefaultBasename(s.w)), ",result=\""+s.result+"\"", "")
	paramStr += SelectString(s.stats==1, ",stats="+num2str(s.stats),"")
	paramStr += SelectString(!s.mode || WaveDims(s.w)==1, ",mode="+num2str(s.mode),"")
	sprintf paramStr, "KMWavesStats(%s)", paramStr
	
	return paramStr
End

//-------------------------------------------------------------
//	KMWavesStatsR: 		右クリック用
//-------------------------------------------------------------
Function KMWavesStatsR()
	KMWavesStatsPnl(KMGetImageWaveRef(WinName(0,1)), grfName=WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	KMWavesStats1D
//		実行関数1D
//******************************************************************************
Static Function/WAVE KMWavesStats1D(w,result,stats)
	Wave w
	String result
	Variable stats
	
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
//	KMWavesStats3D
//		実行関数3D
//******************************************************************************
Static Function/WAVE KMWavesStats3D(w,result,stats,mode, [dfr])
	Wave w
	String result
	Variable stats, mode
	DFREF dfr
	
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
	Variable nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
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

ThreadSafe Static Function/WAVE KMWavesStats3DWorker(w, pp, qq)
	Wave w
	Variable pp, qq
	
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
//	KMWavesStatsPnl
//		パネル表示
//******************************************************************************
Static Function KMWavesStatsPnl(w, [grfName])
	Wave w
	String grfName
	
	//  パネル表示
	String pnlName = KMNewPanel("WavesStats ("+NameOfWave(w)+")", 350, 205)
	if (!ParamIsDefault(grfName))	//	右クリックから呼び出される時
		AutoPositionWindow/E/M=0/R=$grfName $pnlName
	endif
	
	//  フック関数・ユーザデータ
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	
	//  コントロール項目
	SetVariable resultV title="basename:", pos={10,10}, size={332,15}, bodyWidth=275, frame=1, win=$pnlName
	SetVariable resultV value=_STR:DefaultBasename(w), proc=KMWavesStatsPnlSetVar, win=$pnlName
	
	GroupBox statsG title="statistics", pos={11,39}, size={145,120}, win=$pnlName
	CheckBox avgC title="average", pos={24,63}, value=1, proc=KMWavesStatsPnlCheck, win=$pnlName
	CheckBox sdevC title="standard deviation", pos={24,86}, value=0, proc=KMWavesStatsPnlCheck, win=$pnlName
	CheckBox skewC title="skewness", pos={24,109}, value=0, proc=KMWavesStatsPnlCheck, win=$pnlName
	CheckBox kurtC title="kurtosis", pos={24,132}, value=0, proc=KMWavesStatsPnlCheck, win=$pnlName
	
	if (WaveDims(w) == 1)
		TitleBox waveT title="wave(s) to be computed", pos={171,37}, frame=0, win=$pnlName
		NewNotebook/F=0/K=1/N=waveNB/OPTS=2/V=0/W=(168,51,168+170,51+107)/HOST=$pnlName
		String noteStr = KMWaveList(GetWavesDataFolderDFR(w),1,nx=numpnts(w), listSepStr="\r")
		Notebook $pnlName#waveNB text=noteStr, fSize=10, statusWidth=0, writeProtect=1
		Notebook $pnlName#waveNB selection={startOfFile, startOfFile}, text="", visible=(WaveDims(w)==1)	//	先頭にスクロールする
		SetActiveSubwindow $pnlName
	else
		PopupMenu modeP title="dimension", pos={180,49}, size={144,20}, bodyWidth=90, win=$pnlName
		PopupMenu modeP mode=1, value= #"\"x and y;z\"", win=$pnlName
	endif
	
	Button doB title="Do It", pos={5,173}, size={60,20}, proc=KMWavesStatsPnlButton, win=$pnlName
	CheckBox displayC title="display", pos={75,176}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={140,173}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMWavesStatsPnlPopup, win=$pnlName
//	Button helpB title="Help", pos={215,173}, size={60,20}, proc=KMWavesStatsPnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={285,173}, size={60,20}, proc=KMWavesStatsPnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	KMWavesStatsPnlDisable(pnlName)
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	KMWavesStatsPnlButton : ボタン
//-------------------------------------------------------------
Function KMWavesStatsPnlButton(s)
	STRUCT WMButtonAction &s
	
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			KMWavesStatsPnlDo(s.win)
			break
		case "cancelB":
			KillWindow $(s.win)
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	KMWavesStatsPnlPopup : ポップアップ
//-------------------------------------------------------------
Function KMWavesStatsPnlPopup(s)
	STRUCT WMPopupAction &s
	
	if (s.eventCode != 2)
		return 1
	endif
	
	STRUCT check cs
	Wave cs.w = $GetUserData(s.win, "", "src")
	Wave cvw = KMGetCtrlValues(s.win, "avgC;sdevC;skewC;kurtC;modeP")
	cs.stats = cvw[0]+cvw[1]*2+cvw[2]*4+cvw[3]*8
	cs.mode = cvw[4]-1
	ControlInfo/W=$s.win resultV ;	cs.result = S_Value
	KMPopupTo(s, KMWavesStatsEcho(cs))
End
//-------------------------------------------------------------
//	KMWavesStatsPnlSetVar : 値設定
//-------------------------------------------------------------
Function KMWavesStatsPnlSetVar(s)
	STRUCT WMSetVariableAction &s
	if (s.eventCode == 2)
		KMWavesStatsPnlDisable(s.win)
	endif
End
//-------------------------------------------------------------
//	KMWavesStatsPnlCheck : チェックボックス
//-------------------------------------------------------------
Function KMWavesStatsPnlCheck(s)
	STRUCT WMCheckboxAction &s
	if (s.eventCode == 2)
		KMWavesStatsPnlDisable(s.win)
	endif
End

//******************************************************************************
//	KMWavesStatsPnlDisable
//		パネルの表示状態を設定
//******************************************************************************
Static Function KMWavesStatsPnlDisable(pnlName)
	String pnlName
	
	Variable longName = KMCheckSetVarString(pnlName,"resultV",0)
	Variable noCheck = !sum(KMGetCtrlValues(pnlName, "avgC;sdevC;skewC;kurtC;"))
	
	Button doB disable=(longName || noCheck)*2, win=$pnlName
	Popupmenu toP disable=(longName || noCheck)*2, win=$pnlName
	
	if (noCheck)
		GroupBox statsG labelBack=(KM_CLR_CAUTION_R,KM_CLR_CAUTION_B,KM_CLR_CAUTION_B), win=$pnlName
	else
		GroupBox statsG labelBack=0, win=$pnlName
	endif
End

//******************************************************************************
//	KMWavesStatsPnlDo
//		Doボタンの実行関数
//******************************************************************************
Static Function KMWavesStatsPnlDo(pnlName)
	String pnlName
	
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
		KMDisplay(w=resw)
	endif
End