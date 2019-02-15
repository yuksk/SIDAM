#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMCorrelation

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//  結果ウエーブの名前が指定されていないときに、入力ウエーブの名前の後ろにつけて
//  結果ウエーブの名前とするための文字列
Static StrConstant ks_index_Correlation = "_Corr"


//******************************************************************************
//	KMCorrelation
//		入力変数のチェックと実行関数の呼び出し
//******************************************************************************
Function/WAVE KMCorrelation(
	Wave/Z w1,			//	実行対象となるウエーブ
	[
		Wave/Z w2,		//	実行対象となるウエーブ, 省略時はw1と同じ、つまり自己相関を求める
		String result,	//	結果ウエーブの名前, 省略時は"_Corr"が入力ウエーブの名前の後ろについたもの
		int subtract,	//	平均値を引いたものに対して計算を行う(1), そのまま行う(0), 省略時は1
		int normalize,	//	計算後に規格化する(1), しない(0), 省略時は1
		int origin,		//	これが1ならば、w1, w2 がともに3Dウエーブの時に、全てのレイヤーに組み合わせに
							//	ついて相関関数の原点における値を求める. 0ならば対応するレイヤー同士の
							//	相関関数を求める. 省略時は0
		int history		//	bit 0: 履歴欄にコマンドを出力する(1), しない(0)
							//	bit 1: 入力ウエーブが2D-2Dの時に結果ウエーブの最大値とそれを示す座標を履歴欄に出力する(1), しない(0)
							//	省略時は0
	])
	
	STRUCT paramStruct s
	Wave/Z s.w1 = w1
	if (ParamIsDefault(w2))
		Wave/Z s.w2 = w1
	else
		Wave/Z s.w2 = w2
	endif
	s.origin = ParamIsDefault(origin) ? 0 : origin
	s.result = SelectString(ParamIsDefault(result), result, NameOfWave(w1)+ks_index_Correlation)
	s.subtract = ParamIsDefault(subtract) ? 1 : subtract
	s.normalize = ParamIsDefault(normalize) ? 1 : normalize
	
	if (!isValidArguments(s))
		print s.errMsg
		return $""
	endif
	
	//  履歴欄出力
	if (!ParamIsDefault(history) && (history & 0x01))
		print PRESTR_CMD + echoStr(s.w1, s.w2, s.result, s.subtract, s.normalize, s.origin, history)
	endif
	
	//  実行関数
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(w1)
	
	if (WaveDims(w1) == 2 && WaveDims(s.w2) == 2)
		Wave resw = KMCorrelation2D(w1, s.w2, s.result, s.subtract, s.normalize, history&2)
	elseif (WaveDims(w1) != WaveDims(s.w2))
		Wave resw = KMCorrelation2D3D(w1, s.w2, s.result, s.subtract, s.normalize)
	elseif (!origin)
		Wave resw = KMCorrelation3D(w1, s.w2, s.result, s.subtract, s.normalize)
	else
		Wave resw = KMCorrelationOrigin(w1, s.w2, s.result, s.subtract, s.normalize)
	endif
	
	SetDataFolder dfrSav
	
	return resw
End

//-------------------------------------------------------------
//	チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION +"KMCorrelation gave error: "
	
	String msg = KMFFTCheckWaveMsg(s.w1)
	if (strlen(msg))
		s.errMsg += msg
		return 0
	endif
	
	if (!WaveRefsEqual(s.w1, s.w2))
		msg = KMFFTCheckWaveMsg(s.w2)
		if (strlen(msg))
			s.errMsg += msg
			return 1
		elseif (DimSize(s.w1,0) != DimSize(s.w2,0) || DimSize(s.w1,1) != DimSize(s.w2,1))
			s.errMsg += "the input waves must have the same data points in x and y directions."
			return 0
		elseif (WaveDims(s.w1) == 3 && WaveDims(s.w2) == 3 && DimSize(s.w1,2) != DimSize(s.w2,2) && !s.origin)
			s.errMsg += "the input waves must have the same number of data point in z direction." 
			return 0
		endif
	endif
	
	if (s.origin)
		if (WaveDims(s.w1) != 3 || WaveDims(s.w2) != 3)
			s.errMsg += "when the origin is not zero, the input waves must be 3D."
			return 0
		else
			s.origin = 1
		endif
	endif
	
	if (strlen(s.result) > MAX_OBJ_NAME)
		s.errMsg += "length of name for the result wave will exceed the limit ("+num2istr(MAX_OBJ_NAME)+" characters)."
		return 0
	endif
	
	s.subtract = s.subtract ? 1 : 0
	s.normalize = s.normalize ? 1 : 0
	
	return 1
End

Static Structure paramStruct
	String	errMsg
	Wave	w1
	Wave	w2
	String	result
	uchar	origin
	uchar	subtract
	uchar	normalize
EndStructure

//-------------------------------------------------------------
//	履歴欄出力用文字列作成
//-------------------------------------------------------------
Static Function/S echoStr(w1, w2, result, subtract, normalize, origin, history)
	Wave w1, w2
	String result
	Variable subtract, normalize, origin, history
	
	String paramStr = GetWavesDataFolder(w1,2)
	paramStr += SelectString(WaveRefsEqual(w1, w2), ",w2="+GetWavesDataFolder(w2,2),  "")
	paramStr += SelectString(CmpStr(result, NameOfWave(w1)+ks_index_Correlation), "", ",result=\""+result+"\"")
	paramStr += SelectString(subtract==1, ",subtract="+num2str(subtract), "")
	paramStr += SelectString(normalize==1, ",normalize="+num2str(normalize), "")
	paramStr += SelectString(!origin, ",origin="+num2str(origin), "")
	paramStr += SelectString(history&0x02, "", ",history=2")
	Sprintf paramStr, "KMCorrelation(%s)", paramStr
	
	return paramStr
End

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(KMGetImageWaveRef(WinName(0,1)),grfName=WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	KMCorrelation2D
//		2D-2D実行関数, 結果はカレントデータフォルダに出力
//******************************************************************************
Static Function/WAVE KMCorrelation2D(w1,w2,result,subtract,normalize,history)
	Wave w1, w2
	String result
	Variable subtract,normalize,history
	
	Wave tw = KMCorrelation2DWorker(w1,0,w2,0,subtract,normalize)
	Duplicate/O tw $result/WAVE=resw
	
	SetScale/P x -DimDelta(w1,0)*(DimSize(w1,0)/2-1), DimDelta(w1,0), WaveUnits(w1,0), resw
	SetScale/P y -DimDelta(w1,1)*DimSize(w1,1)/2, DimDelta(w1,1), WaveUnits(w1, 1), resw
	
	if (history)
		ImageStats/M=1 resw
		print NameOfWave(resw)
		printf "max: %f @ [%d, %d] ", V_max, V_maxRowLoc, V_maxColLoc
		printf "(%f, %f)\r", DimOffset(resw,0)+DimDelta(resw,0)*V_maxRowLoc, DimOffset(resw,1)+DimDelta(resw,1)*V_maxColLoc
		printf "min: %f @ [%d, %d] ", V_min, V_minRowLoc, V_minColLoc
		printf "(%f, %f)\r", DimOffset(resw,0)+DimDelta(resw,0)*V_minRowLoc, DimOffset(resw,1)+DimDelta(resw,1)*V_minColLoc
	endif
	
	return resw
End
//-------------------------------------------------------------
//	KMCorrelation2DWorker
//		相関関数実行部分
//-------------------------------------------------------------
ThreadSafe Static Function/WAVE KMCorrelation2DWorker(srcw1,index1,srcw2,index2,subtract,normalize)
	Wave srcw1, srcw2
	Variable index1, index2, subtract, normalize
	
	int nx = DimSize(srcw1,0), ny = DimSize(srcw1,1), n = nx * ny
	
	MatrixOP/FREE tw1 = srcw1[][][index1]
	MatrixOP/FREE tw2 = srcw2[][][index2]
	
	//	subtract = 0, normalize = 0 ならば以下の計算は無駄になるが、大抵は両方が1であるので、
	//	ここでまとめて計算しておく
	WaveStats/Q tw1 ;	Variable avg1 = V_avg, sdev1 = V_sdev
	WaveStats/Q tw2 ;	Variable avg2 = V_avg, sdev2 = V_sdev
	
	if (subtract)
		FastOP tw1 = tw1 - (avg1)
		FastOP tw2 = tw2 - (avg2)
	endif
	
	FFT/FREE/DEST=fw1 tw1
	FFT/FREE/DEST=fw2 tw2
	MatrixOP/C/FREE fw3 = fw1 * conj(fw2)	//	fw3 = fw1 * conj(fw2) / n とするよりも実数になってからFastOpを使う方が速い
	
	IFFT/FREE/DEST=cw fw3
	FastOp cw = (1/n)*cw
	
	Variable dp = nx/2-1, dq = floor(ny/2)		//	x方向は常に偶数で入力されるためこれでよい
	MatrixOP/FREE cw = RotateCols(RotateRows(cw,dp),dq)
	
	if (normalize)
		FastOp cw = (n/(n-1)/sdev1/sdev2)*cw	//  Igor で定義されているのは不偏標準偏差なので、変換が必要
	endif
	
	return cw
End


//******************************************************************************
//	KMCorrelation2D3D
//		2D-3D実行関数
//******************************************************************************
Static Function/WAVE KMCorrelation2D3D(w1,w2,result,subtract,normalize)
	Wave w1, w2
	String result
	Variable subtract, normalize
	
	if (WaveDims(w1) == 3)
		Wave s3dw = w1
		Wave s2dw = w2
	else
		Wave s3dw = w2
		Wave s2dw = w1
	endif
	
	int nx = DimSize(w1,0), ny = DimSize(w1,1), nz = DimSize(s3dw,2), i
	
	Make/N=(nz)/FREE/WAVE ww
	MultiThread ww = KMCorrelation2DWorker(s3dw,p,s2dw,0,subtract,normalize)
	
	Make/N=(nx,ny,nz)/O $result/WAVE=resw
	for (i = 0; i < nz; i++)
		Wave tww = ww[i]
		MultiThread resw[][][i] = tww[p][q]
	endfor
	
	SetScale/P x -DimDelta(w1,0)*(nx/2-1), DimDelta(w1,0), WaveUnits(w1,0), resw
	SetScale/P y -DimDelta(w1,1)*ny/2, DimDelta(w1,1), WaveUnits(w1, 1), resw
	SetScale/P z DimOffset(s3dw,2), DimDelta(s3dw,2), WaveUnits(s3dw,2), resw
	
	//	NanonisのMLSモードでのウエーブの場合にはバイアス電圧情報をコピーする必要がある
	if (KMisUnevenlySpacedBias(s3dw))
		KMCopyBias(s3dw, resw)
	endif
	
	return resw
End



//******************************************************************************
//	KMCorrelation3D
//		3D-3D実行関数
//******************************************************************************
Static Function/WAVE KMCorrelation3D(w1,w2,result,subtract,normalize)
	Wave w1, w2
	String result
	Variable subtract, normalize
	
	int nx = DimSize(w1,0), ny = DimSize(w1,1), nz = DimSize(w1,2), i
	
	Make/N=(nz)/FREE/WAVE ww
	MultiThread ww = KMCorrelation2DWorker(w1,p,w2,p,subtract,normalize)
	
	Make/N=(nx,ny,nz)/O $result/WAVE=resw
	for (i = 0; i < nz; i++)
		Wave tww = ww[i]
		MultiThread resw[][][i] = tww[p][q]
	endfor
	
	SetScale/P x -DimDelta(w1,0)*(nx/2-1), DimDelta(w1,0), WaveUnits(w1,0), resw
	SetScale/P y -DimDelta(w1,1)*ny/2, DimDelta(w1,1), WaveUnits(w1, 1), resw
	SetScale/P z DimOffset(w1,2), DimDelta(w1,2), WaveUnits(w1,2), resw
	
	//	NanonisのMLSモードでのウエーブの場合にはバイアス電圧情報をコピーする必要がある
	if (KMisUnevenlySpacedBias(w1))
		KMCopyBias(w1, resw)
	endif
	
	return resw
End

//******************************************************************************
//	KMCorrelationOrigin
//		3D-3D実行関数、全てのレイヤーの組み合わせについて、相関関数の原点における値を求める
//		<f(x,y,z1)g(x,y,z2)> を z1を横軸(x)、z2を縦軸(y)とする2Dウエーブを出力する
//******************************************************************************
Static Function/WAVE KMCorrelationOrigin(w1,w2,result,subtract,normalize)
	Wave w1, w2
	String result
	Variable subtract, normalize
	
	int nx = DimSize(w1,0), ny = DimSize(w1,1)
	int nz1 = DimSize(w1,2), nz2 = DimSize(w2,2)
	Variable sdev1, sdev2
	int i, j
	
	Make/N=(nz1,nz2)/O $result/WAVE=resw
	SetScale/P x DimOffset(w1,2), DimDelta(w1,2), WaveUnits(w1,2), resw
	SetScale/P y DimOffset(w2,2), DimDelta(w2,2), WaveUnits(w2,2), resw
	
	Duplicate/FREE w1, tw1
	Duplicate/FREE w2, tw2
	Make/N=(nz1)/FREE sdevw1
	Make/N=(nz2)/FREE sdevw2
	
	if (subtract || normalize)
		for (i = 0; i < nz1; i++)
			ImageStats/P=(i) w1
			MultiThread tw1[][][i] -= V_avg
			sdevw1[i] = V_sdev
		endfor
		for (j = 0; j < nz2; j++)
			ImageStats/P=(j) w2
			MultiThread tw2[][][j] -= V_avg
			sdevw2[j] = V_sdev
		endfor
	endif
	
	//  原点における値を求めるだけならば、ウエーブの積の平均をとる方が速い
	for (i = 0; i < nz1; i++)
		for (j = 0; j < nz2; j++)
			MatrixOP/FREE/O tw3 = tw1[][][i]*tw2[][][j]
			ImageStats/M=1 tw3
			MultiThread resw[i][j] = normalize ? V_avg/(sdevw1[i]*sdevw2[j])*(nx*ny)/(nx*ny-1) : V_avg
		endfor
	endfor
	
	return resw
End


//=====================================================================================================


//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(Wave w, [String grfName])
	
	//  パネル表示
	String pnlName = KMNewPanel("Correlation", 350, 300)
	if (!ParamIsDefault(grfName))	//	右クリックから呼び出される時
		AutoPositionWindow/E/M=0/R=$grfName $pnlName
	endif
	
	SetWindow $pnlName hook(self)=KMClosePnl
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	
	//  コントロール項目
	GroupBox sourceG title="source", pos={5,5}, size={340,45}, win=$pnlName
	TitleBox sourceT title=GetWavesDataFolder(w,2), pos={24,26}, frame=0, win=$pnlName
	
	GroupBox destG title="destination", pos={5,55}, size={340,80}, win=$pnlName
	PopupMenu dfP title="datafolder:", pos={24,76}, size={196,20}, bodyWidth=140, win=$pnlName
	PopupMenu dfP mode=1, value= #"\"same as source;current datafolder\"", win=$pnlName
	PopupMenu waveP title="wave:", pos={24,104}, size={301,20}, bodyWidth=270, win=$pnlName
	PopupMenu waveP userData(srcDf)=GetWavesDataFolder(w,1), win=$pnlName
	PopupMenu waveP value=#("\"" + NameOfWave(w) + "\""), win=$pnlName	//	表示の遅れを防ぐためにいったん表示する
	
	SetVariable resultV title="output name:", pos={24,153}, size={299,16}, frame=1, bodyWidth=230, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+ks_index_Correlation, proc=KMCorrelation#pnlSetVar, win=$pnlName
	
	CheckBox subtractC title="subtract average before computing", pos={22,186}, size={196,14}, value=1, win=$pnlName
	CheckBox normalizeC title="normalize after computing", pos={22,208}, size={150,14}, value=1, win=$pnlName
	CheckBox maxposC title="output max/min value and location in the history", pos={22,230}, value=0, win=$pnlName
	
	Button doB title="Do It", pos={8,264}, win=$pnlName
	CheckBox displayC title="display", pos={76,267}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={140,264}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, win=$pnlName
	Button helpB title="Help", pos={213,264}, win=$pnlName
	Button cancelB title="Cancel", pos={282,264}, win=$pnlName
	
	ModifyControlList "doB;helpB;cancelB" size={60,20}, proc=KMCorrelation#pnlButton, win=$pnlName
	ModifyControlList "dfP;waveP;toP" proc=KMCorrelation#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	pnlDisable(pnlName)
	
	//	リストの残りを表示する
	DoUpdate/W=$pnlName
	String listStr = pnlWaveList(pnlName, 1)
	PopupMenu waveP value=#("\"" + listStr + "\""), mode=WhichListItem(NameOfWave(w), listStr)+1, win=$pnlName
End
//-------------------------------------------------------------
//	waveP用の候補リストを作成する
//-------------------------------------------------------------
Static Function/S pnlWaveList(
	String pnlName,
	int mode	//	1: same as source, 2: current datafolder
	)
	
	Wave w1 = $GetUserData(pnlName, "", "src")
	
	if (mode == 1)
		DFREF dfr = GetWavesDataFolderDFR(w1)
	else
		DFREF dfr = GetDataFolderDFR()
	endif
	
	String rtnStr = KMWaveList(dfr, 6, forFFT=1, nx=DimSize(w1,0), ny=DimSize(w1,1))
	int i
	
	//	w1 が 3D のとき、w2候補のうち3Dのものはz方向の点数の一致もチェックする
	if (WaveDims(w1) == 3)
		for (i = ItemsInList(rtnStr)-1; i >= 0; i--)
			Wave/SDFR=dfr w2 = $StringFromList(i,rtnStr)
			if (WaveDims(w2) == 3 && DimSize(w1,2) != DimSize(w2,2))
				rtnStr = RemoveFromList(StringFromList(i,rtnStr), rtnStr)
			endif
		endfor
	endif
	
	return rtnStr
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
		case "helpB":
			KMOpenHelpNote("correlation",pnlName=s.win,title="Correlation")
			break
		case "cancelB":
			KillWindow $s.win
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	pnlDisable(s.win)
End
//-------------------------------------------------------------
//	ポップアップ
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "dfP":
			String listStr = pnlWaveList(s.win, s.popNum)
			if (s.popNum == 1)		//	same as source
				Wave w = $GetUserData(s.win,"","src")
				PopupMenu waveP value=#("\""+NameOfWave(w)+"\""), mode=1, disable=0, win=$s.win
				DoUpdate/W=$s.win
				PopupMenu waveP userData(srcDf)=GetWavesDataFolder(w,1), win=$s.win
				PopupMenu waveP value=#("\""+listStr+"\""), mode=WhichListItem(NameOfWave(w), listStr)+1, win=$s.win
			elseif (strlen(listStr))	//	current datafolder, 適当なウエーブあり
				PopupMenu waveP userData(srcDf)=GetDataFolder(1), disable=0, win=$s.win
				PopupMenu waveP value=#("\""+listStr+ "\""), mode=1, win=$s.win
			else					//	current datafolder, 適当なウエーブなし
				PopupMenu waveP disable=2, value="_none_;", mode=1, win=$s.win
			endif
			pnlDisable(s.win)
			break
		case "waveP":
			pnlDisable(s.win)
			break
		case "toP":
			Wave w1 = $GetUserData(s.win, "", "src")
			Wave w2 = KMGetWaveRefFromPopup(s.win, "waveP")
			Wave cvw = KMGetCtrlValues(s.win, "subtractC;normalizeC;maxposC")
			ControlInfo/W=$s.win resultV
			String paramStr = echoStr(w1, w2, S_Value, cvw[0], cvw[1], 0, cvw[2]*2)
			KMPopupTo(s, paramStr)
			break
	endswitch
End

//******************************************************************************
//	パネルの表示状態を設定
//******************************************************************************
Static Function pnlDisable(String pnlName)
	
	Wave w1 = $GetUserData(pnlName, "", "src")
	Wave/Z w2 = KMGetWaveRefFromPopup(pnlName, "waveP")
	if (!WaveExists(w2) || KMCheckSetVarString(pnlName,"resultV",0))
		Button doB disable=2, win=$pnlName
		PopupMenu toP disable=2, win=$pnlName
		return 0
	else
		Button doB disable=0, win=$pnlName
		PopupMenu toP disable=0, win=$pnlName
	endif
	
	if (!WaveRefsEqual(w1,w2) && WaveDims(w1) == 2 && WaveDims(w2) == 2)
		CheckBox maxposC disable=0, win=$pnlName
	else
		CheckBox maxposC disable=2, value=0, win=$pnlName
	endif
End

//******************************************************************************
//	Doボタンの実行関数
//******************************************************************************
Static Function pnlDo(String pnlName)
	
	Wave w1 = $GetUserData(pnlName, "", "src")
	Wave w2 = KMGetWaveRefFromPopup(pnlName, "waveP")
	Wave cvw = KMGetCtrlValues(pnlName, "subtractC;normalizeC;maxposC;displayC")
	ControlInfo/W=$pnlName resultV ;		String result = S_Value
	KillWindow $pnlName
	
	Wave/Z resw = KMCorrelation(w1,w2=w2,result=result,subtract=cvw[0],normalize=cvw[1],history=1+cvw[2]*2)
	
	if (cvw[3])
		SIDAMDisplay(resw, history=1)
	endif
End
