#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMHistogram

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//  ヒストグラムウエーブの名前が指定されていないときに、入力ウエーブの名前の後につけて
//  ヒストグラムウエーブの名前とするための文字列
Static StrConstant ks_index_histogram = "_h"

//  デフォルトのbinの数
Static Constant k_bins = 64


//******************************************************************************
//	KMHistogram
//		入力変数のチェックとその内容に応じた各実行関数の呼び出し
//******************************************************************************
Function/WAVE KMHistogram(
	Wave/Z w,		//	ヒストグラムを作成する対象となる2D/3Dウエーブ
	[
		String result,		//	結果ウエーブの名前, 省略時は"h_"が入力ウエーブの名前の後についたもの
		Variable startz,		//	最小z, 省略時は入力ウエーブの最小値
		Variable endz,		//	最大z, 省略時は入力ウエーブの最大値
		Variable deltaz,		//	z幅, 省略時はdeltaによる指定ではなくて、最大値による指定となる
								//	(endz と deltaz の両方が指定されている場合にはエラー)
		int bins,				//	bin数, 省略時は下記で指定されているデフォルト値
		int cumulative,		//	0: 通常ヒストグラム, 1:累積ヒストグラム, 省略時は0
		int normalize,		//	0: 規格化せず, 1:規格化する, 省略時は1
		int cmplxmode,		//	入力ウエーブが複素数の時に実行対象を選ぶ
								//	0: 振幅, 1: 実部, 2: 虚部, 3: 位相, 省略時は0
		int history,			//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
		DFREF dfr				//	結果ウエーブを出力するデータフォルダへの参照. 省略時はソースウエーブと同じデータフォルダ
	])
	
	STRUCT paramStruct s
	Wave/Z s.w = w
	s.result = SelectString(ParamIsDefault(result), result, NameOfWave(w)+ks_index_histogram)
	s.bins = ParamIsDefault(bins) ? k_bins : bins
	s.startz = ParamIsDefault(startz) ? NaN : startz	//	ウエーブが指定されない場合に備えてNaNを代入し、KMHistogramCheckでデフォルト値を代入する
	s.endz = ParamIsDefault(endz) ? NaN : endz		//	同上
	s.deltaz = ParamIsDefault(deltaz) ? NaN : deltaz	//	同上
	s.cumulative = ParamIsDefault(cumulative) ? 0 : cumulative
	s.normalize = ParamIsDefault(normalize) ? 1 : normalize
	s.cmplxmode = ParamIsDefault(cmplxmode) ? 0 : cmplxmode
	if (ParamIsDefault(dfr) && WaveExists(w))			//	WaveExistsを入れるのはエラー防止のため
		s.dfr = GetWavesDataFolderDFR(s.w)
	else
		s.dfr = dfr
	endif
	
	if (!isValidArguments(s))
		print s.errMsg
		Make/FREE rtnw = {1}
		return rtnw
	endif
	
	//  履歴
	if (!ParamIsDefault(history) && history == 1)
		print PRESTR_CMD + echoStr(s)
	endif
	
	//  実行関数へ
	if (WaveDims(w) == 2)
		Wave resw = makeHistogramFor2D(s)
	elseif (WaveDims(w) == 3)
		Wave resw = makeHistogramFor3D(s)
	endif
	
	DFREF tdfr = s.dfr
	Duplicate/O resw tdfr:$s.result
	
	//	NanonisのMLSモードでのウエーブの場合にはバイアス電圧情報をコピーする必要がある
	if (SIDAMisUnevenlySpacedBias(s.w))
		Duplicate/O SIDAMGetBias(s.w, 2) tdfr:$(s.result+"_y")
	endif
	
	return tdfr:$s.result
End

Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMHistogram gave error: "
	
	if (WaveExists(s.w))
		if (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
			s.errMsg += "dimension of input wave must be 2 or 3."
			return 0
		endif
	else
		s.errMsg += "wave not found."
		return 0
	endif
	
	if (strlen(s.result) > MAX_OBJ_NAME)
		s.errMsg += "length of name for output wave exceeds the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 0
	endif

	if (!DataFolderRefStatus(s.dfr))
		s.errMsg += "the data folder reference is invalid."
		return 0
	endif
	
	if (s.cmplxmode < 0 || s.cmplxmode > 3)
		s.errMsg += "invalid cmplxmode."
		return 0
	endif
		
	s.initialz = (numtype(s.startz) == 2) ? WaveMin(s.w) : s.startz
	
	//  endz と deltaz は両方同時に指定されていたらエラーを出す
	//  両方とも指定されていなかったら、endzのデフォルト値を採用する
	if (!numtype(s.endz) && !numtype(s.deltaz))	//	endzとdeltazの両方が指定されている場合
		s.errMsg += "either endz or deltaz should be chosen."
		return 0
	elseif (!numtype(s.deltaz))	//	deltazだけが指定されている場合
		s.finalz = s.deltaz
		s.mode = 1
	elseif (!numtype(s.endz))		//	endzだけが指定されている場合
		s.finalz = s.endz
		s.mode = 0
	else								//	両方とも指定されていない場合
		Wave minmaxw = getInitMinMax(s.w,"",cmplxmode=s.cmplxmode)
		s.finalz = minmaxw[1]
		s.mode = 0
	endif
	
	s.cumulative = s.cumulative ? 1 : 0
	s.normalize = s.normalize ? 1 : 0
	
	return 1
End

Static Structure paramStruct
	//	入力
	Wave	w
	String	result
	uint16	bins
	double	startz
	double	endz
	double	deltaz
	uchar	cumulative
	uchar	normalize
	uchar	cmplxmode
	DFREF	dfr
	//	出力
	String	errMsg
	uchar	mode	//  0: 終了値指定, 1: 幅指定
	double	initialz
	double	finalz
EndStructure

//-------------------------------------------------------------
//	履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S echoStr(STRUCT paramStruct &s)
	
	Wave minmaxw = getInitMinMax(s.w,"",cmplxmode=s.cmplxmode)
	
	String paramStr = GetWavesDataFolder(s.w,2)
	paramStr += SelectString(CmpStr(s.result, NameOfWave(s.w)+ks_index_histogram), "", ",result=\""+s.result+"\"")
	paramStr += SelectString(s.bins==k_bins, ",bins="+num2str(s.bins), "")
	paramStr += SelectString(s.initialz==minmaxw[0], ",startz="+num2str(s.initialz), "")
	if (s.mode)	//	deltazが指定されている場合
		paramStr += ",deltaz="+num2str(s.finalz)
	else		//	endzが指定されている場合、もしくはdeltazとendzの両方が指定されていない場合
		paramStr += SelectString(s.finalz==minmaxw[1],",endz="+num2str(s.finalz), "")
	endif
	paramStr += SelectString(s.cumulative, "", ",cumulative="+num2str(s.cumulative))
	paramStr += SelectString(s.normalize, ",normalize=0", "")
	paramStr += SelectString((WaveType(s.w)&0x01) && s.cmplxmode, "", ",cmplxmode="+num2istr(s.cmplxmode))
	paramStr += SelectString(DataFolderRefsEqual(s.dfr,GetWavesDataFolderDFR(s.w)),",dfr="+GetDataFolder(1,s.dfr),"")
	Sprintf paramStr, "KMHistogram(%s)", paramStr
	
	return paramStr
End

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(KMGetImageWaveRef(WinName(0,1)), WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	2Dイメージからヒストグラムを作成する実行関数
//******************************************************************************
Static Function/WAVE makeHistogramFor2D(STRUCT paramStruct &s)
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	int n = numpnts(s.w)
	
	//  一次元化
	if (WaveType(s.w) & 0x01)
		switch (s.cmplxmode)
		case 0:	//	magnitude
			MatrixOP tw = mag(s.w)
			break
		case 1:	//	real
			MatrixOP tw = real(s.w)
			break
		case 2:	//	imaginary
			MatrixOP tw = imag(s.w)
			break
		case 3:	//	phase
			MatrixOP tw = phase(s.w)
			break
		endswitch
		Redimension/N=(n) tw
	else
		Duplicate s.w tw
		Redimension/N=(n) tw
	endif
	
	//  ヒストグラムウエーブ
	Make/N=(s.bins)/O hw
	if (s.mode)
		SetScale/P x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	else
		SetScale/I x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	endif
	
	//  ヒストグラム作成
	Histogram/B=2 tw hw
	
	//  累積ヒストグラム
	if (s.cumulative)
		Integrate/P hw
	endif
	
	//  規格化
	if (s.normalize)
		hw /= n
	endif
	
	SetDataFolder dfrSav
	
	return hw
End

//******************************************************************************
//	3Dウエーブから2Dヒストグラムを作成する実行関数
//	KMHistogram2Dを各レイヤーごとに実行している
//******************************************************************************
Static Function/WAVE makeHistogramFor3D(STRUCT paramStruct &s)
	
	STRUCT paramStruct s1	//	レイヤーごとに実行するための構造体
	int i

	s1 = s

	//  ヒストグラムウエーブ	
	Make/N=(s.bins,DimSize(s.w,2))/FREE hw
	if (s.mode)
		SetScale/P x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	else
		SetScale/I x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	endif
	SetScale/P y DimOffset(s.w,2), DimDelta(s.w,2), WaveUnits(s.w,2), hw
	
	//  ヒストグラム作成
	for (i = 0; i < DimSize(s.w,2); i++)
		MatrixOP/FREE tw1 = s.w[][][i]
		Wave s1.w = tw1
		Wave tw2 = makeHistogramFor2D(s1)
		hw[][i] = tw2[p]
	endfor
	
	return hw
End


//=====================================================================================================


//******************************************************************************
//	表示対象ウエーブを選択するためのパネル
//******************************************************************************
Static Function pnl(Wave w, String grfName	)
	
	//  パネル表示
	String pnlName = SIDAMNewPanel("Histogram ("+NameOfWave(w)+")",350,200)
	AutoPositionWindow/E/M=0/R=$grfName $pnlName
	SetWindow $pnlName userData(grf)=grfName
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	
	//	パネル表示の初期値を得る
	Wave minmaxw = getInitMinMax(w, GetUserData(pnlName,"","grf"))
	
	//  コントロール項目
	SetVariable resultV title="output name:", pos={10,10}, size={329,16}, frame=1, bodyWidth=260, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+ks_index_histogram, proc=KMHistogram#pnlSetVar, win=$pnlName
	
	PopupMenu modeP title="mode", pos={9,44}, size={152,20}, bodyWidth=120, win=$pnlName 
	PopupMenu modeP value="start and end;start and delta", mode=1, proc=KMHistogram#pnlPopup, win=$pnlName
	SetVariable z1V title="start", pos={13,78}, size={148,15}, value=_STR:num2str(minmaxw[0]), win=$pnlName
	SetVariable z2V title="end", pos={19,104}, size={142,15}, value=_STR:num2str(minmaxw[1]), win=$pnlName
	SetVariable binsV title="bins", pos={16,130}, size={145,15}, value=_STR:num2str(k_bins), win=$pnlName
	ModifyControlList "z1V;z2V;binsV" bodyWidth=120, proc=KMHistogram#pnlSetVar, valueColor=(SIDAM_CLR_EVAL_R,SIDAM_CLR_EVAL_G,SIDAM_CLR_EVAL_B), fColor=(SIDAM_CLR_EVAL_R,SIDAM_CLR_EVAL_G,SIDAM_CLR_EVAL_B), win=$pnlName
	CheckBox auto1C title="auto", pos={169,79}, value=1, win=$pnlName
	CheckBox auto2C title="auto", pos={169,105}, value=1, win=$pnlName
	CheckBox autobinC title="auto", pos={169,131}, value=1, win=$pnlName
	
	CheckBox normalizeC title="normalize", pos={250,46}, value=1, win=$pnlName
	CheckBox cumulativeC title="cumulative", pos={250,72}, value=0, win=$pnlName
	
	Button doB title="Do It", pos={5,165}, size={60,20}, proc=KMHistogram#pnlButton, win=$pnlName
	CheckBox displayC title="display", pos={75,168}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={140,165}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=KMHistogram#pnlPopup, win=$pnlName
	Button helpB title="Help", pos={215,165}, size={60,20}, proc=KMHistogram#pnlButton, win=$pnlName
	Button cancelB title="Cancel", pos={285,165}, size={60,20}, proc=KMHistogram#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	pnlDisable(pnlName)
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ポップアップ
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
	case "modeP":
		SetVariable z2V title=SelectString(s.popNum-1, "end", "delta"), win=$s.win
		break
	case "toP":
		String grfName = GetUserData(s.win,"","grf")
		STRUCT paramStruct cs
		Wave cs.w = $GetUserData(s.win, "", "src")
		Wave cvw = KMGetCtrlValues(s.win, "modeP;z1V;z2V;binsV;auto1C;auto2C;autobinC;normalizeC;cumulativeC")
		Wave minmaxw = getInitMinMax(cs.w,grfName)
		cs.mode = (cvw[0]==2 && cvw[5]) ? 1 : cvw[0] - 1	//	start and delta かつ　auto2C にチェックが入っている場合には start and end 扱いにする
		cs.initialz = cvw[4] ? minmaxw[0] : cvw[1]
		cs.finalz = cvw[5] ? minmaxw[1] : cvw[2]
		cs.bins = cvw[6] ? k_bins : cvw[3]
		cs.normalize = cvw[7]
		cs.cumulative = cvw[8]
		cs.cmplxmode = NumberByKey("imCmplxMode",ImageInfo(grfName,"", 0),"=")
		cs.dfr = GetWavesDataFolderDFR(cs.w)
		ControlInfo/W=$s.win resultV ;	cs.result = S_Value
		KMPopupTo(s, echoStr(cs))
		break
	endswitch
End

//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	
	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "resultV":
			KMCheckSetVarString(s.win,s.ctrlName,0)
			break
		case "z1V":
			if (!KMCheckSetVarString(s.win,s.ctrlName,1))
				CheckBox auto1C value=0, win=$s.win
			endif
			break
		case "z2V":
			if (!KMCheckSetVarString(s.win,s.ctrlName,1))
				CheckBox auto2C value=0, win=$s.win
			endif
			break
		case "binsV":
			if (!KMCheckSetVarString(s.win,s.ctrlName,1))
				CheckBox autobinC value=0, win=$s.win
			endif
			break
	endswitch
	pnlDisable(s.win)
End
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
			//  *** FALLTHROUGH ***
		case "cancelB":
			KillWindow $s.win
			break
		case "helpB":
			SIDAMOpenHelpNote("histogram",s.win,"Histogram")
			break
	endswitch
	
	return 0
End
//-------------------------------------------------------------
//	パネルの表示状態の変更
//-------------------------------------------------------------
Static Function pnlDisable(String pnlName)
	
	String ctrlList = "resultV;z1V;z2V;binsV"
	int i
	for (i = 0; i < ItemsInList(ctrlList); i++)
		ControlInfo/W=$pnlName $StringFromList(i, ctrlList)
		if (strsearch(S_recreation,"valueBackColor",0) >= 0)
			Button doB disable=2, win=$pnlName
			PopupMenu toP disable=2, win=$pnlName
			return 0
		endif
	endfor
	
	Button doB disable=0, win=$pnlName
	PopupMenu toP disable=0, win=$pnlName
End


//******************************************************************************
//	Doボタンの実行関数
//******************************************************************************
Static Function pnlDo(String pnlName)
	
	String grfName = GetUserData(pnlName,"","grf")
	Wave w = $GetUserData(pnlName,"","src")
	Wave cvw = KMGetCtrlValues(pnlName, "modeP;z1V;z2V;binsV;auto1C;auto2C;autobinC;normalizeC;cumulativeC;displayC")
	ControlInfo/W=$pnlName resultV ;	String result = S_Value
	
	Wave minmaxw = getInitMinMax(w,grfName)
	if (cvw[4] == 1)	//	auto1C
		cvw[1] = minmaxw[0]	//	z1V
	endif
	if (cvw[5] == 1)	//	auto2C
		cvw[0] = 1			//	modeP, start and end
		cvw[2] = minmaxw[1]	//	z2V
	endif
	if (cvw[6] == 1)	//	autobinC
		cvw[3] = k_bins		//	binsV
	endif
	
	int cmplxmode = strlen(grfName) ? NumberByKey("imCmplxMode",ImageInfo(grfName,"", 0),"=") : 0
	
	if (cvw[0] == 1)	//	start and end
		Wave resw = KMHistogram(w,result=result,startz=cvw[1],endz=cvw[2],bins=cvw[3],normalize=cvw[7],\
			cumulative=cvw[8],cmplxmode=cmplxmode,history=1)
	else				//	start and delta
		Wave resw = KMHistogram(w,result=result,startz=cvw[1],deltaz=cvw[2],bins=cvw[3],normalize=cvw[7],\
			cumulative=cvw[8],cmplxmode=cmplxmode,history=1)
	endif
	
	if (cvw[9])
		SIDAMDisplay(resw, history=1)
	endif
End

//	パネル表示の初期値を得る
Static Function/WAVE getInitMinMax(Wave w, String grfName, [int cmplxmode])
	Make/D/N=2/FREE rtnw

	if (WaveType(w)&0x01)		//	複素数ウエーブならば
		cmplxmode = ParamIsDefault(cmplxmode) ? NumberByKey("imCmplxMode", ImageInfo(grfName,"",0),"=") : cmplxmode
		if (strlen(grfName) || !ParamIsDefault(cmplxmode))
			switch (cmplxmode)
			case 0:	//	magnitude
				MatrixOP/FREE tw = mag(w)
				break
			case 1:	//	real
				MatrixOP/FREE tw = real(w)
				break
			case 2:	//	imaginary
				MatrixOP/FREE tw = imag(w)
				break
			case 3:
				MatrixOP/FREE tw = phase(w)
				break
			endswitch
		else
			MatrixOP/FREE tw = mag(w)
		endif
		rtnw = {WaveMin(tw), WaveMax(tw)}
	else
		rtnw = {WaveMin(w), WaveMax(w)}
	endif
	
	return rtnw
End
