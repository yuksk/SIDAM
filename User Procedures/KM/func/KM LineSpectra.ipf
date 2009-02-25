#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMLineSpectra

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//	dim=2で出力ウエーブの名前が指定されていないときに、入力ウエーブの名前の後ろに付けて
//	出力ウエーブの名前とするための文字列
Static StrConstant ks_index_linespectra = "_ls"

//	パネルで使用する結果ウエーブの名前
Static StrConstant PNL_W = "KMLineSpectraPnl"
Static StrConstant PNL_X = "KMLineSpectraPnlX"
Static StrConstant PNL_Y = "KMLineSpectraPnlY"
Static StrConstant PNL_C = "KMLineSpectraPnlC"
Static StrConstant PNL_B1 = "KMLineSpectraPnl_b"
Static StrConstant PNL_B2 = "KMLineSpectraPnl_x"
Static StrConstant PNL_T = "KMLineSpectraPnlT"

//******************************************************************************
//	 KMLineSpectra
//		条件振り分け・チェック
//******************************************************************************
Function KMLineSpectra(
	Wave/Z w,			//	実行対象となる2D/3Dウエーブ
	Variable p1,		//	開始点のp, q値
	Variable q1,
	Variable p2,		//	終了点のp, q値
	Variable q2,
	[
		String result,	//	結果ウエーブの名前, 出力ウエーブが1次元の場合はこの後に番号がつく
							//	省略時は、入力ウエーブの名前+"_ls"(2次元の場合)
		int mode,			//	スペクトルを取得する方法, 省略時は0
							//	0: 軌跡が通るピクセルからは全てスペクトルを取り出す
							//	1: x, yのどちらかはピクセル上から選択し(軌跡の線分の角度による)、もう片方は内挿する
							//	2: ImageLineProfileを用いる
		int output,		//	サンプリング点を記録したウエーブを出力する(1), しない(0), 省略時は0
							//	名前はresult+"X", result+"Y"になる
		int history		//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	])
	
	STRUCT paramStruct s
	Wave s.w = w
	s.p1 = p1
	s.q1 = q1
	s.p2 = p2
	s.q2 = q2
	s.mode = ParamIsDefault(mode) ? 0 : mode
	s.output = ParamIsDefault(output) ? 0 : output
	s.result = SelectString(ParamIsDefault(result), result, NameOfWave(s.w))
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
		paramStr += SelectString(ParamIsDefault(mode), ",mode="+num2str(mode), "")
		paramStr += SelectString(ParamIsDefault(output), ",output="+num2str(output), "")
		printf "%sKMLineSpectra(%s)\r", PRESTR_CMD, paramStr
	endif
	
	//	実行関数
	getLineSpectra(s)
	
	return 0
End

Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMLineSpectra gave error: "
	
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 0
	elseif (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
		s.errMsg += "the dimension of input wave must be 2 or 3."
		return 0
	endif
	
	if (numtype(s.p1) || numtype(s.q1) || numtype(s.p2) || numtype(s.q2))
		s.errMsg += "coordinate must be a normal number."
		return 0
	endif
	
	if (s.mode > 2)
		s.errMsg += "the mode must be 0, 1, or 2."
		return 0
	endif
	
	if (s.output > 1)
		s.errMsg += "The output must be 0 or 1."
		return 0
	endif
	
	if ((strlen(s.result) > 28-s.output) || (strlen(s.result) > 31-s.output))
		s.errMsg += "length of name for ouput wave exceeds the limit (31 characters)."
		return 0
	endif
	
	return 1
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	double	p1
	double	q1
	double	p2
	double	q2
	String	result
	uchar	mode
	uchar	output
	DFREF dfr
	STRUCT WaveParam waves
EndStructure

//	各モード実行関数との間で結果ウエーブを受け渡しするための構造体
Static Structure WaveParam
	Wave resw
	Wave pw
	Wave qw
	Wave xw
	Wave yw
endStructure

//-------------------------------------------------------------
//	右クリック用
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	実行関数元締め
//		各モードの実行関数からは2次元ウエーブの形で結果を受け取る
//		結果はカレントデータフォルダに出力する
//******************************************************************************
Static Function getLineSpectra(STRUCT paramStruct &s)
	
	int i
	String noteStr
	DFREF dfrSav = GetDataFolderDFR()
	
	//	結果ウエーブ
	Make/N=(DimSize(s.w,2),0)/FREE resw
	Wave s.waves.resw = resw

	Make/N=0/FREE pw, qw, xw, yw
	Wave s.waves.pw = pw, s.waves.qw = qw
	Wave s.waves.xw = xw, s.waves.yw = yw
	
	//	スペクトル取得
	switch (s.mode)
		case 0:
			getLineSpectraMode0(s)
			break
		case 1:
			getLineSpectraMode1(s)
			break
		case 2:
			getLineSpectraMode2(s)
			break
		default:
	endswitch
	
	//	スケーリングとウエーブノート
	SetDataFolder s.dfr
	SetScale/P x DimOffset(s.w,2), DimDelta(s.w,2), WaveUnits(s.w,2), s.waves.resw
	SetScale/I y 0, sqrt(((s.p2-s.p1)*DimDelta(s.w,0))^2+((s.q2-s.q1)*DimDelta(s.w,1))^2), WaveUnits(s.w,0), s.waves.resw
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(s.w,0)), s.waves.resw
	Sprintf noteStr, "src@%s;start@p=%d,q=%d;end@p=%d,q=%d;", GetWavesDataFolder(s.w,2), s.p1, s.q1, s.p2, s.q2
	Note s.waves.resw, noteStr
	Duplicate/O s.waves.resw $s.result
	
	if (KMisUnevenlySpacedBias(s.w))
		Duplicate/O KMGetBias(s.w,1) $(s.result+"_b")
		Duplicate/O KMGetBias(s.w,2) $(s.result+"_x")
	endif
	
	//	位置ウエーブの出力
	if (s.output)
		Duplicate/O xw $(s.result+"X")
		Duplicate/O yw $(s.result+"Y")
	endif
	
	int rtn = DimSize(s.waves.resw,1)
	SetDataFolder dfrSav
	
	return rtn
End

//******************************************************************************
//	軌跡が通過するピクセルからはすべてスペクトルを取得する.
//******************************************************************************
Static Function getLineSpectraMode0(STRUCT paramStruct &s)
	
	//	始点と終点が一致する場合には別に処理をする
	if (s.p1 == s.p2 && s.q1 == s.q2)
		Redimension/N=1 s.waves.pw, s.waves.qw
		s.waves.pw = s.p1
		s.waves.qw = s.q1
	else	
		//	始点・終点の順番について
		//	後で使うソートが常に昇順で行うことができるように、s.p1(s.q1) が s.p2(s.q2) よりも大きければ
		//	符号を逆転しておく
		int revp = (s.p1 > s.p2), revq = (s.q1 > s.q2)
		s.p1 *= revp ? -1 : 1
		s.p2 *= revp ? -1 : 1
		s.q1 *= revq ? -1 : 1
		s.q2 *= revq ? -1 : 1
		
		//	(s.p1,s.q1) -- (s.p2, s.q2) 感を結ぶ直線へ下ろした垂線の足が、
		//	各点のセルの中にあるかどうかを判定する
		Redimension/N=(abs(s.p2-s.p1)+1,abs(s.q2-s.q1)+1) s.waves.pw, s.waves.qw
		Make/N=(abs(s.p2-s.p1)+1,abs(s.q2-s.q1)+1)/FREE xyw
		Make/N=(abs(s.p2-s.p1)+1,abs(s.q2-s.q1)+1)/B/U/FREE inoutw
		
		Setscale/P x min(s.p1,s.p2), 1, "", s.waves.pw, s.waves.qw, xyw, inoutw
		Setscale/P y min(s.q1,s.q2), 1, "", s.waves.pw, s.waves.qw, xyw, inoutw
		
		Variable d = 1 / ((s.p2-s.p1)^2 + (s.q2-s.q1)^2)
		xyw = ((x-s.p1)*(s.p2-s.p1)+(y-s.q1)*(s.q2-s.q1)) * d
		s.waves.pw = s.p1 + xyw*(s.p2-s.p1)
		s.waves.qw = s.q1 + xyw*(s.q2-s.q1)
		
		inoutw = abs(x-s.waves.pw) < 0.5 && abs(y-s.waves.qw) < 0.5
		
		//	ソートして通過点の座標を並べるための準備
		s.waves.pw = x
		s.waves.qw = y
		Redimension/N=(numpnts(inoutw)) s.waves.pw, s.waves.qw, inoutw
		
		//	通過点だけを取り出す
		Sort/R inoutw, s.waves.pw, s.waves.qw
		Deletepoints sum(inoutw), numpnts(inoutw)-sum(inoutw), s.waves.pw, s.waves.qw
		
		//	順番に並べる
		SortColumns keyWaves={s.waves.pw, s.waves.qw}, sortWaves={s.waves.pw, s.waves.qw}
		
		//	逆転した符号を戻す
		s.waves.pw *= revp ? -1 : 1
		s.waves.qw *= revq ? -1 : 1
		s.p1 *= revp ? -1 : 1
		s.p2 *= revp ? -1 : 1
		s.q1 *= revq ? -1 : 1
		s.q2 *= revq ? -1 : 1
	endif
	
	//	スペクトル取得
	if (WaveType(s.w) & 0x01)	//	complex
		Redimension/N=(-1,numpnts(s.waves.pw))/C s.waves.resw
		Wave/C resw = s.waves.resw
		resw = s.w[s.waves.pw[q]][s.waves.qw[q]][p]
	else
		Redimension/N=(-1,numpnts(s.waves.pw)) s.waves.resw
		s.waves.resw = s.w[s.waves.pw[q]][s.waves.qw[q]][p]
	endif
	
	//	位置ウエーブに代入
	Redimension/N=(numpnts(s.waves.pw)) s.waves.xw, s.waves.yw
	s.waves.xw = DimOffset(s.w,0)+DimDelta(s.w,0)*s.waves.pw
	s.waves.yw = DimOffset(s.w,1)+DimDelta(s.w,1)*s.waves.qw
End

//******************************************************************************
//	x, yのどちらかはピクセル上から選択し(線分の角度による)、もう片方は内挿する
//******************************************************************************
Static Function getLineSpectraMode1(STRUCT paramStruct &s)
	
	int n = max(abs(s.p2-s.p1),abs(s.q2-s.q1))+1
	int isComplex = WaveType(s.w) & 0x01
	
	//	スペクトル取得位置ウエーブのサイズ調整
	Redimension/N=(n) s.waves.pw, s.waves.qw
	s.waves.pw = s.p1 + (s.p2-s.p1)/(n-1)*p
	s.waves.qw = s.q1 + (s.q2-s.q1)/(n-1)*p
	Wave pw = s.waves.pw, qw = s.waves.qw	//	ショートカット
	
	//	結果ウエーブのサイズ調整
	if (isComplex)
		Redimension/N=(-1,n)/C s.waves.resw
		Wave/C resw = s.waves.resw
	else
		Redimension/N=(-1,n) s.waves.resw
	endif
		
	//	スペクトル取得
	if (abs(s.p2-s.p1) > abs(s.q2-s.q1))
		if (isComplex)
			//	参考演算子の条件式部分も複素数でないとエラーが出る
			//	実部の零・非零で真偽判定が行われるようだ
			resw = cmplx(floor(qw[q])==ceil(qw[q]),0) ? \
					s.w[pw[q]][qw[q]][p] : \
					s.w[pw[q]][floor(qw[q])][p]*cmplx(ceil(qw[q])-qw[q],0) + s.w[pw[q]][ceil(qw[q])][p]*cmplx(qw[q]-floor(qw[q]),0)
			
		else
			s.waves.resw = floor(qw[q]) == ceil(qw[q]) ? \
							s.w[pw[q]][qw[q]][p] : \
							s.w[pw[q]][floor(qw[q])][p]*(ceil(qw[q])-qw[q]) + s.w[pw[q]][ceil(qw[q])][p]*(qw[q]-floor(qw[q]))
		endif
		
	elseif (abs(s.p2-s.p1) < abs(s.q2-s.q1))
		if (isComplex)
			//	参考演算子の条件式部分も複素数でないとエラーが出る
			//	実部の零・非零で真偽判定が行われるようだ
			resw = cmplx(floor(pw[q])==ceil(pw[q]),0) ? \
					s.w[pw[q]][qw[q]][p] : \
					s.w[floor(pw[q])][qw[q]][p]*cmplx(ceil(pw[q])-pw[q],0) + s.w[ceil(pw[q])][qw[q]][p]*cmplx(pw[q]-floor(pw[q]),0)
		
		else
			s.waves.resw = floor(pw[q]) == ceil(pw[q]) ? \
							s.w[pw[q]][qw[q]][p] : \
							s.w[floor(pw[q])][qw[q]][p]*(ceil(pw[q])-pw[q]) + s.w[ceil(pw[q])][qw[q]][p]*(pw[q]-floor(pw[q]))
		
		endif
			
	elseif (n > 1)
		if (isComplex)
			resw = s.w[pw[q]][qw[q]][p]
		else
			s.waves.resw = s.w[pw[q]][qw[q]][p]
		endif
		
	endif
	
	//	位置ウエーブに代入
	Redimension/N=(numpnts(s.waves.pw)) s.waves.xw, s.waves.yw
	s.waves.xw = DimOffset(s.w,0)+DimDelta(s.w,0)*s.waves.pw
	s.waves.yw = DimOffset(s.w,1)+DimDelta(s.w,1)*s.waves.qw
End

//******************************************************************************
//	ImageLineProfileを用いる
//******************************************************************************
Static Function getLineSpectraMode2(STRUCT paramStruct &s)
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Make/N=2 pw = {s.p1, s.p2}, qw = {s.q1, s.q2}
	
	//	スペクトル取得
	if (WaveType(s.w) & 0x01)	//	complex
		MatrixOP/FREE realw = real(s.w)
		MatrixOP/FREE imagw = imag(s.w)
		//	実部
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/P=-2 xWave=pw, yWave=qw, srcWave=realw
		Wave rw = M_ImageLineProfile
		MatrixTranspose rw
		//	虚部
		SetDataFolder NewFreeDataFolder()
		ImageLineProfile/P=-2 xWave=pw, yWave=qw, srcWave=imagw
		Wave iw = M_ImageLineProfile
		MatrixTranspose iw
		//	複素数
		Redimension/N=(DimSize(rw,0),DimSize(rw,1))/C s.waves.resw
		Wave/C resw = s.waves.resw
		resw = cmplx(rw,iw)
		
	else
		Duplicate s.w tw
		SetScale/P x 0, 1, "", tw
		SetScale/P y 0, 1, "", tw
		ImageLineProfile/P=-2 xWave=pw, yWave=qw, srcWave=tw
		Wave prow = M_ImageLineProfile
		MatrixTranspose prow
		Redimension/N=(DimSize(prow,0),DimSize(prow,1)) s.waves.resw
		s.waves.resw = prow
	endif
	
	//	位置ウエーブ
	Wave xw = W_LineProfileX, yw = W_LineProfileY
	Redimension/N=(numpnts(xw)) s.waves.pw, s.waves.qw, s.waves.xw, s.waves.yw
	s.waves.pw = xw
	s.waves.qw = yw
	s.waves.xw = DimOffset(s.w,0)+DimDelta(s.w,0)*xw
	s.waves.yw = DimOffset(s.w,1)+DimDelta(s.w,1)*yw
	
	SetDataFolder dfrSav
End


//=====================================================================================================


//******************************************************************************
//	パネル
//******************************************************************************
Static Function pnl(String LVName)
	//	既に表示されているパネルがあればそれをフォーカスして終了
	if (strlen(GetUserData(LVName,"","KMLineSpectraPnl")))
		DoWindow/F $GetUserData(LVName,"","KMLineSpectraPnl")
		return 0
	endif
	
	//	初期設定
	String dfTmp = pnlInit(LVName)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder $dfTmp
	
	Wave w = KMGetImageWaveRef(LVName)
	int i
	
	//	表示
	Display/K=1/W=(0,0,315*72/screenresolution,340*72/screenresolution) as NameOfWave(w)
	String pnlName = S_name
	AutoPositionWindow/E/M=0/R=$LVName $pnlName
	
	//  フック関数・ユーザデータ
	SetWindow $pnlName hook(self)=KMLineSpectra#pnlHook, userData(parent)=LVName
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	SetWindow $pnlName userData(grid)="1"
	SetWindow $pnlName userData(dim)="1"
	SetWindow $pnlName userData(highlight)="0"	
	SetWindow $pnlName userData(mode)="0"
	SetWindow $pnlName userData(dfTmp)=dfTmp
	SetWindow $pnlName userData(rev)="1156"
	
	//	コントロール
	KMLineCommon#pnlCtrls(pnlName)
	ModifyControlList "p1V;q1V;p2V;q2V;distanceV;angleV" proc=KMLineSpectra#pnlSetVar, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	//	初期値に対するスペクトル取得
	pnlUpdateLineSpectra(pnlName)
	pnlUpdateTextmarker(pnlName)		//	ラインプロファイルを取得したら親グラフ用のテキストマーカーウエーブも更新する
	
	//	ウォーターフォール表示領域
	if (KMisUnevenlySpacedBias(w))
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W vs {$PNL_B1,*}
	else
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line $PNL_W
	endif
	pnlModifyGraph(pnlName+"#line")
	
	//	イメージ表示領域
	Display/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=image/HIDE=1
	if (KMisUnevenlySpacedBias(w))
		AppendImage/W=$pnlName#image $PNL_W vs {$PNL_B2, *}
	else
		AppendImage/W=$pnlName#image $PNL_W
	endif
	pnlModifyGraph(pnlName+"#image")
	
	pnlSetParent(LVName,pnlName)
	
	SetDataFolder dfrSav
End
//-------------------------------------------------------------
//	パネル初期設定
//-------------------------------------------------------------
Static Function/S pnlInit(String grfName)
	String dfSav = KMNewTmpDf(grfName,"KMLineSpectraPnl")
	String dfTmp = GetDataFolder(1)
	
	Make/N=(1,1) $PNL_W
	Make/N=1 $PNL_X, $PNL_Y, $PNL_B1, $PNL_B2
	Make/N=(1,3) $PNL_C
	Make/T/N=2 $PNL_T = {"1","2"}
	
	SetDataFolder $dfSav
	return dfTmp
End
//-------------------------------------------------------------
//	指定されたウインドウを親ウインドウにする
//-------------------------------------------------------------
Static Function pnlSetParent(String prtName, String chdName)
	SetWindow $prtName hook(KMLineSpectraPnl)=KMLineSpectra#pnlHookParent
	SetWindow $prtName userData(KMLineSpectraPnl)=AddListItem(chdName, GetUserData(prtName,"","KMLineSpectraPnl"))
	SetWindow $chdName userData(parent)=prtName
	DFREF dfrTmp = $GetUserData(chdName,"","dfTmp")
	
	AppendToGraph/W=$prtName dfrTmp:$PNL_Y vs dfrTmp:$PNL_X
	String trcName = KMWaveToTraceName(prtName, dfrTmp:$PNL_Y)
	ModifyGraph/W=$prtName mode($trcName)=4,textMarker($trcName)={dfrTmp:$PNL_T,"default",0,0,1,0.00,0.00},msize($trcName)=5
End
//-------------------------------------------------------------
//	指定されたウインドウを親ウインドウではなくする
//-------------------------------------------------------------
Static Function pnlResetParent(String prtName, String chdName)
	String newList = RemoveFromList(chdName, GetUserData(prtName, "", "KMLineSpectraPnl"))
	if (ItemsInList(newList))
		SetWindow $prtName userData(KMLineSpectraPnl)=newList
	else
		SetWindow $prtName hook(KMLineSpectraPnl)=$"",userdata(KMLineSpectraPnl)=""
	endif
	SetWindow $chdName userData(parent)=""
	
	KMRemoveAll(prtName,df=GetUserData(chdName,"","dfTmp"))
End
//-------------------------------------------------------------
//	グラフ領域の表示詳細
//-------------------------------------------------------------
Static Function pnlModifyGraph(String pnlName)
	ModifyGraph/W=$pnlName margin(top)=8,margin(right)=8,margin(bottom)=36,margin(left)=44
	ModifyGraph/W=$pnlName tick=0,btlen=5,mirror=0,lblMargin=2, gfSize=10
	ModifyGraph/W=$pnlName rgb=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$pnlName axRGB=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$pnlName tlblRGB=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$pnlName alblRGB=(KM_CLR_LINE_R, KM_CLR_LINE_G, KM_CLR_LINE_B)
	ModifyGraph/W=$pnlName gbRGB=(KM_CLR_BG_R, KM_CLR_BG_G, KM_CLR_BG_B)
	ModifyGraph/W=$pnlName wbRGB=(KM_CLR_BG_R, KM_CLR_BG_G, KM_CLR_BG_B)
	Label/W=$pnlName bottom "\\u"
	Label/W=$pnlName left "\\u"
	
	if (!CmpStr(StringFromList(1,pnlName,"#"),"line"))
		ModifyWaterfall/W=$pnlName angle=90,axlen=0.5,hidden=0
		ModifyGraph/W=$pnlName mode=0,useNegRGB=1,usePlusRGB=1,negRGB=(0,0,0),plusRGB=(0,0,0)
		ModifyGraph/W=$pnlName noLabel(right)=2,axThick(right)=0	
	endif
End
//-------------------------------------------------------------
//	パネルの内容に合わせてスペクトルを取得する
//-------------------------------------------------------------
Static Function pnlUpdateLineSpectra(String pnlName)
	STRUCT paramStruct s
	Wave s.w = $GetUserData(pnlName,"","src")
	ControlInfo/W=$pnlName p1V ;	s.p1 = V_Value
	ControlInfo/W=$pnlName q1V ;	s.q1 = V_Value
	ControlInfo/W=$pnlName p2V ;	s.p2 = V_Value
	ControlInfo/W=$pnlName q2V ;	s.q2 = V_Value
	s.output = 1
	s.result = PNL_W
	s.mode = str2num(GetUserData(pnlName,"","mode"))
	s.dfr = $GetUserData(pnlName,"","dfTmp")
	getLineSpectra(s)
	
	//	バイアス非等間隔の場合には、2次元表示用のウエーブしか得られないので、1次元表示用のものも取得しておく
	if (KMisUnevenlySpacedBias(s.w))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder s.dfr
		Duplicate/O KMGetBias(s.w,1) $PNL_B1
		SetDataFolder dfrSav
	endif
End
//-------------------------------------------------------------
//	ラインプロファイルに合わせてマーカーウエーブを更新する
//-------------------------------------------------------------
Static Function pnlUpdateTextmarker(String pnlName)
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/T/SDFR=dfrTmp tw = $PNL_T
	
	tw = ""
	ControlInfo/W=$pnlName p1C;		Variable p1Checked = V_Value | !V_Flag		//	最初に呼び出されるときには1を代入するために!V_Flagを使う
	ControlInfo/W=$pnlName p2C;		Variable p2Checked = V_Value | !V_Flag
	Redimension/N=(DimSize(dfrTmp:$PNL_W,1)) tw
	if (p1Checked)
		tw[0] = "1"
	endif
	if (p2Checked)
		tw[DimSize(dfrTmp:$PNL_W,1)-1] = "2"
	endif
End
//-------------------------------------------------------------
//	カーソルの状態・位置に対応したトレースの色を変える
//-------------------------------------------------------------
Static Function pnlUpdateColor(String grfName)
	String pnlNames = GetUserData(grfName,"","KMLineSpectraPnl")
	String pnlName
	DFREF dfrTmp
	int i, n, p0, p1
	
	for (i = 0, n = ItemsInList(pnlNames); i < n; i++)
		pnlName = StringFromList(i, pnlNames)
		if (CmpStr(GetUserData(pnlName,"","highlight"),"1"))
			continue
		endif
		
		Wave/SDFR=$GetUserData(pnlName,"","dfTmp") w = $PNL_W, clrw = $PNL_C
		Redimension/N=(numpnts(w),3) clrw
		clrw[][0] = KM_CLR_LINE_R
		clrw[][1] = KM_CLR_LINE_G
		clrw[][2] = KM_CLR_LINE_B
		
		p0 = pcsr(A,grfName)*DimSize(w,0)
		p1 = (pcsr(A,grfName)+1)*DimSize(w,0)-1
		clrw[p0,p1][0] = KM_CLR_LINE2_R
		clrw[p0,p1][1] = KM_CLR_LINE2_G
		clrw[p0,p1][2] = KM_CLR_LINE2_B
	endfor
End

//******************************************************************************
//	フック関数
//******************************************************************************
//-------------------------------------------------------------
//	パネル用フック関数
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	//	矢印キー (keycode 28-31) の場合には、スペクトルの更新を行い、それ以外については共通関数で扱う
	//	共通関数では eventCode 0 (activate), 1 (deactivate), 2 (kill), 3 (mousedown), 11 (keyboard) を扱っている
	if (s.eventCode == 11 && 28 <= s.keycode && s.keycode <= 31)
		switch (s.keycode)
			case 28:		//	left
			case 29:		//	right
			case 30:		//	up
			case 31:		//	down
				KMLineCommon#keyArrows(s)
				pnlUpdateLineSpectra(s.winName)
				pnlUpdateTextmarker(s.winName)
				pnlUpdateColor(GetUserData(s.winName,"","parent"))
				return 1
		endswitch
	endif
	
	return KMLineCommon#pnlHook(s)
End
//-------------------------------------------------------------
//	パネルが閉じられた場合の動作
//-------------------------------------------------------------
Static Function pnlHookClose(STRUCT WMWinHookStruct &s)
	String prtName = GetUserData(s.winName,"","parent")
	
	DoWindow $prtName
	if (V_Flag)
		pnlResetParent(prtName,s.winName)
	endif
	
	KMonClosePnl(s.winName)
	KillWindow $s.winName
End

//-------------------------------------------------------------
//	親ウインドウ用
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	String list = GetUserData(s.winName,"","KMLineSpectraPnl")
	int i, n = ItemsInList(list)
	
	switch (s.eventCode)
		case 2:	//	kill
			for (i = 0; i < n; i++)
				KillWindow/Z $StringFromList(i, list)
			endfor
			break
		case 3:	//	mousedown
		case 4:	//	mousemoved
			STRUCT KMMousePos ms
			ms.winhs = s
			for (i = 0; i < n; i++)
				String pnlName = StringFromList(i, list)
				//	rev. 1156 より前に作られたものであれば、後方互換確保の関数を動作させる
				Variable rev = str2num(GetUserData(pnlName,"","rev"))
				if (numtype(rev) || rev < 1156)
					DoWindow/F $pnlName
					break
				endif
				//	---(後方互換ここまで)
				ms.grid = str2num(GetUserData(pnlName,"","grid"))
				KMLineCommon#pnlHookParentMouse(s, ms, pnlName)
				pnlUpdateLineSpectra(pnlName)
				pnlUpdateTextmarker(pnlName)
				DoUpdate/W=$pnlName
			endfor
			pnlUpdateColor(s.winName)
			DoUpdate/W=$s.winName
			break
		case 7:	//	cursor moved
			//	カーソルAに変化があれば動作する
			if (!CmpStr(s.cursorName, "A"))
				pnlUpdateColor(s.winName)
			endif
			break
		default:
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
	pnlUpdateLineSpectra(pnlName)
	
	KillWindow $(pnlName+"#line")
	int hide = str2num(GetUserData(pnlName,"","dim")) == 2
	if (KMisUnevenlySpacedBias(srcw))
		Newwaterfall/FG=(FL,KMFT,FR,FB)/HOST=$pnlName/N=line/HIDE=(hide) $PNL_W vs {$PNL_B1,*}
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
	
	//	変更された値を元にしてスペクトルを更新する
	pnlUpdateLineSpectra(s.win)
	pnlUpdateTextmarker(s.win)
	pnlUpdateColor(GetUserData(s.win,"","parent"))
End


//******************************************************************************
//	右クリックメニュー
//******************************************************************************
//-------------------------------------------------------------
//	LineSpectraの右クリックメニュー
//-------------------------------------------------------------
Menu "KMLineSpectraMenu", dynamic, contextualmenu
	SubMenu "Positions"
		KMLineCommon#pnlRightClickMenu(0), KMLineSpectra#pnlRightClickDo(0)
	End
	SubMenu "Dimension"
		KMLineCommon#pnlRightClickMenu(1), KMLineSpectra#pnlRightClickDo(1)
	End
	SubMenu "Complex"
		KMLineCommon#pnlRightClickMenu(2), KMLineSpectra#pnlRightClickDo(2)
	End
	SubMenu "Sampling mode"
		KMLineSpectra#pnlRightclickMenu(), KMLineSpectra#pnlRightClickDo(5)
	End
	SubMenu "Target window"
		KMSpectrumViewer#rightclickMenuTarget(WinName(0,1)), KMLineSpectra#pnlRightClickDo(6)	//	KMSpectrumViewer#rightclickMenuTargetを使用
	End
	SubMenu "Style"
		KMLineCommon#pnlRightClickMenu(3), KMLineSpectra#pnlRightClickDo(3)
		KMLineCommon#pnlRightClickMenu(4), KMLineSpectra#pnlRightClickDo(4)
	End
	"Extract...", KMLineSpectra#outputPnl(WinName(0,1))
	"-"
	KMLineCommon#pnlRightClickMenu(7),/Q, KMRange(grfName=WinName(0,1)+"#image")
	KMLineCommon#pnlRightClickMenu(8),/Q, KMColor(grfName=WinName(0,1)+"#image")
End
//-------------------------------------------------------------
//	右クリックメニューの表示項目, sampling mode
//-------------------------------------------------------------
Static Function/S pnlRightclickMenu()
	//	KM LineSpectra.ipf にある pnlHook から呼ばれたのでなければ続きを実行しない
	String calling = "pnlHook,KM LineSpectra.ipf"
	if (strsearch(GetRTStackInfo(3),calling,0))
		return ""
	endif
	
	String pnlName = WinName(0,1)	
	int mode = str2num(GetUserData(pnlName,"","mode"))
	return KMAddCheckmark(mode, "Raw data;Interpolate;ImageLineProfile")
End
//-------------------------------------------------------------
//	右クリックメニューの実行項目
//-------------------------------------------------------------
Static Function pnlRightClickDo(int kind)
	String pnlName = WinName(0,1)
	String grfName = GetUserData(pnlName,"","parent")
	int grid = str2num(GetUserData(pnlName,"","grid"))
	
	switch (kind)
		case 0:	//	positions
			//	選択内容に応じて p1V, q1V等の値を変更する
			KMLineCommon#pnlRightclickDoPositions(pnlName)
			//	変更後の p1V, q1V, p2V, q2V の値に合わせてスペクトルを更新する
			pnlUpdateLineSpectra(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(grfName)
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
			//	変更後の値に対応するようにスペクトルも変更する
			pnlUpdateLineSpectra(pnlName)
			pnlUpdateTextmarker(pnlName)
			pnlUpdateColor(grfName)
			break
			
		case 4:	//	Highlight
			int highlight = str2num(GetUserData(pnlName,"","highlight"))
			SetWindow $pnlname userData(highlight)=num2istr(!highlight)
					
			if (highlight)
				//	on -> off
				if(!CmpStr(StringByKey("TNAME",CsrInfo(A,grfName)),PNL_Y))
					Cursor/K/W=$grfName A
				endif
				ModifyGraph/W=$(pnlName+"#line") zColor=0
			else
				//	off -> on
				String cmd
				Sprintf cmd, "Cursor/C=%s/S=1/W=%s A %s 0", StringByKey("rgb(x)",TraceInfo(grfName,PNL_Y,0),"="), grfName, PNL_Y
				Execute cmd
				Wave/SDFR=$GetUserData(pnlName,"","dfTmp") clrw = $PNL_C
				ModifyGraph/W=$(pnlName+"#line") zColor={clrw,*,*,directRGB,0}
			endif
			pnlUpdateColor(grfName)
			break
			
		case 5:	//	sampling mode
			int mode = str2num(GetUserData(pnlName,"","mode"))
			GetLastUserMenuInfo
			if (V_value-1 != mode)
				//	モードの値を変更する
				SetWindow $pnlName userData(mode)=num2istr(V_value-1)
				//	変更後の値に対応するようにスペクトルも変更する
				pnlUpdateLineSpectra(pnlName)
				pnlUpdateTextmarker(pnlName)
				pnlUpdateColor(grfName)
			endif
			break
			
		case 6:	//	target window
			//	マウス座標を取得するウインドウを変更する
			GetLastUserMenuInfo
			pnlResetParent(grfName,pnlName)
			pnlSetParent(StringFromList(V_value-1,GetUserData(pnlName,"","target")), pnlName)			
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
	
	//  パネル表示
	NewPanel/HOST=$profileGrfName/EXT=2/W=(0,0,315,125)/N=Save
	String pnlName = profileGrfName + "#Save"
	
	//  コントロール項目
	DFREF dfrSav = GetDataFolderDFR()
	Wave srcw = $GetUserData(profileGrfName,"","src")
	SetDataFolder GetWavesDataFolderDFR(srcw)
	SetVariable resultV title="output name:", pos={10,10}, size={295,15}, bodyWidth=220, frame=1, win=$pnlName
	SetVariable resultV value=_STR:UniqueName("wave",1,0), proc=KMLineSpectra#outputPnlSetVar, win=$pnlName
	SetDataFolder dfrSav
	
	CheckBox positionC title="save waves of sampling points", pos={10,40}, size={88,14}, value=0, win=$pnlName
	
	Button doB title="Do It", pos={10,95}, win=$pnlName
	Button closeB title="Close", pos={235,95}, win=$pnlName
	ModifyControlList "doB;closeB" size={70,20}, proc=KMLineSpectra#outputPnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function outputPnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 1)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			outputPnlDo(s.win)
			//** THROUGH **
		case "closeB":
			KillWindow $s.win
			break
		case "HelpB":
			KMOpenHelpNote("linespectra",pnlName=StringFromList(0,s.win,"#"),title="Line Spectra")
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
	
	//	結果文字列の長さを判定する
	Variable chklen = KMCheckSetVarString(s.win,s.ctrlName,0,maxlength=MAX_OBJ_NAME-3)
	Button doB disable=chklen*2, win=$s.win
End
//-------------------------------------------------------------
//	Doボタンの実行関数
//-------------------------------------------------------------
Static Function outputPnlDo(String pnlName)
	String parent = StringFromList(0,pnlName,"#")
	
	Wave w = $GetUserData(parent,"","src")
	Wave cvw = KMGetCtrlValues(parent,"p1V;q1V;p2V;q2V")
	ControlInfo/W=$pnlName resultV ;		String result = S_Value
	int mode = str2num(GetUserData(parent,"","mode"))
	ControlInfo/W=$pnlName positionC ;	int output = V_value
	
	KMLineSpectra(w,cvw[0],cvw[1],cvw[2],cvw[3],result=result,mode=mode,output=output,history=1)
End