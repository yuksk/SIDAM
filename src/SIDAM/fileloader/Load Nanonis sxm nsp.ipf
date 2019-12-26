#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1
#pragma ModuleName=KMLoadNanonisSXMNSP

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	ファイル読み込みメイン
//******************************************************************************
Function/WAVE LoadNanonisSxmNsp(String pathStr)
	DFREF dfrSav = GetDataFolderDFR()
	
	//	ヘッダ読み込み
	NewDataFolder/O/S $SIDAM_DF_SETTINGS
	STRUCT header s
	SxmNspHeader(pathStr, s)
	
	//	データ読み込み
	SetDataFolder dfrSav
	if (s.type == 0)
		return SXMData(pathStr, s)
	elseif (s.type == 1)
		return NSPData(pathStr, s)
	endif
End

//	multipass結合関数呼び出し用
Static Function/S menu()
	//	ConcatenateNanonisMultipass で用いているエラーチェックを流用すればより正確な条件判定が
	//	可能ではあるが、メニューが重くなるのを避けるために簡単なチェックのみで済ませる。
	//	(結合済みのウエーブがあるデータフォルダでもメニュー項目が選べてしまうことになるが、関数がエラーを出して停止する)
	Wave/Z configw = $(":"+SIDAM_DF_SETTINGS+":'Multipass-Config'")
	return SelectString(WaveExists(configw),"(","") + "Concatenate multipass waves"
End

//******************************************************************************
//	ヘッダ読み込み
//		ヘッダから読み込んだ値はグローバル変数としてカレントデータフォルダへ保存される
//******************************************************************************
Static Function SxmNspHeader(String pathStr, STRUCT header &s)
	Variable refNum, subFolder
	Variable overwritten = 0	//	Z-controllerモジュールがヘッダが選択保存されている場合にはそちらで上書きするためのフラッグ
	String buffer, name
	DFREF dfrSav = GetDataFolderDFR()
	
	Open/R/T="????" refNum as pathStr
	FReadLine refNum, buffer	//	最初の行を読む
	
	do
		name = buffer[1,strlen(buffer)-3]
		
		strswitch (name)
			case "Z-CONTROLLER":
				NewDataFolder/O/S $name
				SXMHeaderZC(refNum)
				SetDataFolder dfrSav
				break
			case "DATA_INFO":
				Wave/T s.chanInfo = SXMHeaderDI(pathStr, refNum)	//	データ読み込みルーチンのためにヘッダの値を構造体へコピーしておく
				break
			case "COMMENT":
				SXMHeaderComment(refNum)
				break
			case "Multipass-Config":
				SXMHeaderMC(refNum)
				break
			default:
				//	">"を含むならば、サブフォルダを作成する
				Variable n = strsearch(name, ">", 0)
				subFolder = (n != -1)
				if (subFolder)
					//	Z-Controllerモジュールがヘッダに含まれているならそちらを使用する
					if (!CmpStr(name[0,n-1],"Z-Controller") && !overwritten)
						KillDataFolder/Z $"Z-CONTROLLER"
						overwritten = 1
					endif
					NewDataFolder/O/S $(name[0,n-1])
					name = name[n+1, strlen(name)-1]
				endif
				
				//	値を読み込んで保存する
				FReadLine refNum, buffer
				LoadNanonisCommonVariableString(name, buffer[0,strlen(buffer)-2])
				
				if (subFolder)
					SetDataFolder dfrSav
				endif
				break
		endswitch
		
		FReadLine refNum, buffer	//	次の行を読む
		
	while (CmpStr(buffer,":SCANIT_END:\r") && CmpStr(buffer,":HEADER_END:\r"))
	
	//	sxm or nsp ?
	if (NumVarOrDefault("NANONIS_VERSION",0))			//	sxm
		s.type = 0
	elseif (NumVarOrDefault("SPECTRUM_VERSION",0))	//	nsp
		s.type = 1
	endif
	
	//	ヘッダの終わり(1A04)を検出して、ヘッダサイズを読み込みルーチンのために保存する
	s.headerSize = SxmNspHeaderEnd(refNum)
		
	Close refNum
	
	//	データ読み込みルーチンのためにヘッダの値を構造体へコピーしておく
	if (s.type == 0)
		SXMHeaderCvt(s)
	elseif (s.type == 1)
		NSPHeaderCvt(s)
	endif
End

//	Z-CONTROLLER
Static Function SXMHeaderZC(Variable refNum)
	int i
	String buffer
	FReadLine refNum, buffer ;	String names = buffer[1,strlen(buffer)-2]
	FReadLine refNum, buffer ;	String values = buffer[1,strlen(buffer)-2]
	for (i = 0; i < ItemsInList(names,"\t"); i++)
		LoadNanonisCommonVariableString(StringFromList(i,names,"\t"), StringFromList(i,values,"\t"))
	endfor
End

//	DATA_INFO
Static Function/WAVE SXMHeaderDI(String pathStr, Variable refNum)
	String fileName = ParseFilePath(3, pathStr, ":", 0, 0)	//	拡張子抜きの名前
	String s0, s1, s2, buffer
	Variable n
	
	Make/N=(0,3)/T/FREE infow
	FReadLine refNum, buffer	//	Channel	Name などの行を読み飛ばす
	FReadLine refNum, buffer	//	最初の行を読み込む
	do
		n = DimSize(infow,0)
		Redimension/N=(n+1,-1) infow
		sscanf buffer, "%*[\t]%*[0-9]%*[\t]%s%*[\t]%s%*[\t]%s", s0, s1, s2
		infow[n][0] = fileName + "_" + s0
		infow[n][1] = s1
		infow[n][2] = s2
		FReadLine refNum, buffer
	while (CmpStr(buffer,"\r"))	//	空行
	return infow
End

//	COMMENT
Static Function SXMHeaderComment(Variable refNum)
	int code = TextEncodingCode(TEXTENCODING_NANONIS)
	String buffer
	String/G COMMENT = ""
	
	//	コメントの1行目を読む
	FReadLine refNum, buffer
	
	//	コメントは複数行に渡る可能性があるので、次の行が":"で始まるまで読み込む
	do
		COMMENT += ConvertTextEncoding(buffer, code, 1, 1, 0)	
		FGetPos refNum	//	次の行を読み込む前に現在の位置を取得しておく
		FReadLine refNum, buffer
	while (CmpStr(buffer[0],":"))
	
	//	":"で始まる前の位置に戻す
	FSetPos refNum, V_filePos	//	V_filePos は　FGetPos で与えられている
End

//	Multipass-Config
Static Function SXMHeaderMC(Variable refNum)
	String buffer
	Variable i, n
	
	//	項目名はdimension labelへ保存する
	FReadLine refNum, buffer
	n = ItemsInList(buffer, "\t")
	Make/N=(n) $"Multipass-Config"/WAVE=w
	for (i = 0; i < n; i += 1)
		SetDimLabel 0, i, $StringFromList(i, buffer, "\t"), w
	endfor
	
	//	値の保存
	do
		FStatus refNum
		FReadLine refNum, buffer
		if (CmpStr(buffer[0],"\t"))
			FSetPos refNum, V_filePos
			break
		endif
		buffer = ReplaceString("TRUE", buffer, "1")
		buffer = ReplaceString("FALSE", buffer, "0")
		n = DimSize(w,1)
		Redimension/N=(-1,n+1) w
		w[][n] = str2num(StringFromList(p, buffer, "\t"))
	while (V_filePos < V_logEOF)
	
	DeletePoints/M=0 0, 1, w	//	Dimension labelを設定したときの分
End

// ヘッダの終わり(1A04)の検出
Static Function SxmNspHeaderEnd(Variable refNum)
	Make/N=2/B/FREE tw
	do
		FBinRead/B=3/F=1 refNum, tw
		if (tw[0] == 0x1A && tw[1] == 0x04)
			break
		elseif (tw[1] == 0x1A)
			FStatus refNum
			FSetPos refNum, V_filePos-1
		endif
	while (1)
	
	FStatus refNum
	return V_filePos
End

//	Scan Inspectorと同じ変数名に分離・変換しておく
//	分離・変換後にデータ読み込みルーチンのためにヘッダの値を構造体へコピーしておく
Static Function SXMHeaderCvt(STRUCT header &s)
	SVAR REC_DATE, REC_TIME
	String dd, mm, yy
	sscanf REC_DATE, "%2s.%2s.%4s", dd, mm, yy
	String/G 'start time' = yy+"/"+mm+"/"+dd+" "+REC_TIME
	
	NVAR ACQ_TIME;	Variable/G 'acquisition time (s)' = ACQ_TIME
	
	SVAR SCAN_PIXELS, SCAN_RANGE, SCAN_OFFSET
	Variable/G '# pixels', '# lines'
	sscanf SCAN_PIXELS, "%d%d", '# pixels', '# lines'
	Variable/G 'width (m)', 'height (m)'
	sscanf SCAN_RANGE, "%f%f", 'width (m)', 'height (m)'
	Variable/G 'center x (m)', 'center y (m)'	
	sscanf SCAN_OFFSET, "%f%f", 'center x (m)', 'center y (m)'
	
	NVAR SCAN_ANGLE;	Variable/G 'angle (deg)' = SCAN_ANGLE
	SVAR SCAN_DIR;	String/G direction = SCAN_DIR
	NVAR BIAS;	Variable/G 'bias (V)' = BIAS
	
	KillStrings REC_DATE, REC_TIME, SCAN_PIXELS, SCAN_RANGE, SCAN_OFFSET,SCAN_DIR
	KillVariables ACQ_TIME, SCAN_ANGLE, BIAS
	
	//	データ読み込みルーチンのためにヘッダの値を構造体へコピーしておく
	s.xpnts = '# pixels' ;				s.ypnts = '# lines'	
	s.xscale ='width (m)'*1e10; 			s.yscale = 'height (m)'*1e10	// angstrom
	s.xcenter = 'center x (m)'*1e10;	s.ycenter = 'center y (m)'*1e10	// angstrom
	s.direction = stringmatch(direction, "down")
End

//	データ読み込みルーチンのためにヘッダの値を構造体へコピーしておく
Static Function NSPHeaderCvt(STRUCT header &s)
	NVAR DATASIZEROWS, DATASIZECOLS, DELTA_f
	s.xpnts = DATASIZEROWS
	s.ypnts = DATASIZECOLS
	s.yscale = DELTA_f
	
	SVAR START_DATE, START_TIME, END_DATE, END_TIME
	Variable day, month, year, hour, minute, second
	sscanf START_DATE, "%d.%d.%d", day, month, year
	sscanf START_TIME, "%d:%d:%d", hour, minute, second
	s.starttime = date2secs(year,month,day) + hour*3600 + minute*60 + second
	sscanf END_DATE, "%d.%d.%d", day, month, year
	sscanf END_TIME, "%d:%d:%d", hour, minute, second
	s.endtime = date2secs(year,month,day) + hour*3600 + minute*60 + second
End

Static Structure header
	uint16	xpnts, ypnts	//	sxm,nsp共通
	Variable	xcenter, ycenter, xscale, yscale	//	yscaleのみ共通
	uchar	direction		//	sxmのみ
	Variable	starttime, endtime	//	nspのみ
	Variable	headerSize	//	ヘッダのサイズ, sxm,nsp共通
	uchar	type			//	1: sxm, 2: nsp
	Wave/T	chanInfo		//	チャンネル情報, sxmのみ
EndStructure

//******************************************************************************
//	データ読み込み
//		読み込まれたウエーブはカレントデータフォルダへ保存される
//******************************************************************************
//	sxm
Static Function/WAVE SXMData(String pathStr, STRUCT header &s)
	Variable chan, layer, nLayer
	String unit
	
	//	ファイルからデータ読み込み
	GBLoadWave/O/Q/N=tmp/T={2,4}/S=(s.headerSize)/W=1 pathStr
	Wave tw = tmp0
	
	//	読み込んだウエーブを再構成
	for (chan = 0, nLayer = 0; chan < DimSize(s.chanInfo,0); chan += 1) 
		nLayer += CmpStr(s.chanInfo[chan][2],"both") ? 1 : 2
	endfor
	Redimension/N=(s.xpnts, s.ypnts, nLayer) tw
	
	//	上から下へのスキャンならばy方向を逆さにする
	if (s.direction)
		Reverse/DIM=1 tw
	endif	
	
	//	再構成されたウエーブから各イメージウエーブを取り出す
	Make/N=(nLayer)/WAVE/FREE refw	//	各イメージウエーブへの参照
	for (layer = 0, chan = 0; layer < nLayer; layer += 1, chan += 1)
		unit = s.chanInfo[chan][1]
		MatrixOP $CleanupWaveName(s.chanInfo[chan][0],"")/WAVE=topow = tw[][][layer]
		SetScale d, 0, 0, unit, topow
		Redimension/S topow
		refw[layer] = topow
		
		if (!CmpStr(s.chanInfo[chan][2],"both"))
			layer += 1
			MatrixOP $CleanupWaveName(s.chanInfo[chan][0], "_bwd")/WAVE=topow = tw[][][layer]		
			SetScale d, 0, 0, unit, topow
			Reverse/DIM=0 topow
			Redimension/S topow
			refw[layer] = topow
		endif
	endfor
	
	//	物理値へ変換
	for (layer = 0; layer < nLayer; layer += 1)
		Wave lw = refw[layer]
		SetScale/I x, s.xcenter-s.xscale/2, s.xcenter+s.xscale/2, "\u00c5", lw
		SetScale/I y, s.ycenter-s.yscale/2, s.ycenter+s.yscale/2, "\u00c5", lw
		strswitch (WaveUnits(lw, -1))
			case "m":
				FastOP lw = (1e10) * lw	//	angstrom
				SetScale d, WaveMin(lw), WaveMax(lw), "\u00c5", lw
				break
			case "A":
				FastOP lw = (1e9) * lw		//	nA
				SetScale d, WaveMin(lw), WaveMax(lw), "nA", lw
				break
			default:
				SetScale d, WaveMin(lw), WaveMax(lw), "", lw
		endswitch
	endfor
	
	KillWaves tw
	
	return refw
End
//	nsp
Static Function/WAVE NSPData(String pathStr, STRUCT header &s)
	//	ファイルからデータ読み込み
	GBLoadWave/O/Q/N=tmp/T={2,4}/S=(s.headerSize)/W=1 pathStr
	Wave tw = tmp0
	
	//	読み込んだウエーブを再構成
	//	(DATASIZECOLS, DATASIZEROWS) で読み込んでからxy入れ替えで欲しい結果に行き着く
	Redimension/N=(s.ypnts,s.xpnts) tw
	Matrixtranspose tw
	
	//	縦軸・横軸変換
	SetScale/I x s.starttime, s.endtime, "dat", tw
	SetScale/P y 0, s.yscale, "Hz", tw
	
	//	拡張子抜きの名前
	Rename tw $ParseFilePath(3, pathStr, ":", 0, 0)
	
	return tw
End

//	ウエーブの名前が長すぎる場合への対処
//	例えば、***_Current_bwd　という名前が長すぎる場合には、***部分を短くする
Static Function/S CleanupWaveName(String name, String suffix)
	int a = strsearch(name, "_", inf, 1)	//	一番後ろにある "_"　の位置
	String str1 = name[0,a-1]
	String str2 = name[a,inf] + suffix
	if (strlen(str1) > MAX_OBJ_NAME-strlen(str2))
		printf "%s\"%s%s\" is renamed to \"%s%s\" (too long name)\r", PRESTR_CAUTION, str1, str2, str1[0,MAX_OBJ_NAME-strlen(str2)-1], str2
		return str1[0,MAX_OBJ_NAME-strlen(str2)-1] + str2
	else
		return str1 + str2
	endif
End


//******************************************************************************
//	multipass関係の便利関数
//******************************************************************************
//	分かれている像を1つのウエーブにまとめる
Function KMNanonisConcatMultipass(DFREF dfr, [int history])
	history = ParamIsDefault(history) ? 0 : history
	
	Wave/Z/T listw = init(dfr)
	if (!WaveExists(listw))
		return 1
	endif
	Wave/SDFR=dfr:$SIDAM_DF_SETTINGS configw = 'Multipass-Config'
	
	int i, j, isbwd
	int numOfPasses = DimSize(configw,1)/2
	String str0, str1
	
	for (i = 0; i < DimSize(listw,0); i++)
		
		//	結合する
		Wave/SDFR=dfr w0 = $(listw[i][0]+num2istr(1)+listw[i][1])
		for (j = 2; j <= numOfPasses; j++)
			Wave/SDFR=dfr w = $(listw[i][0]+num2istr(j)+listw[i][1])
			Concatenate/NP=2 {w}, w0
			KillWaves w
		endfor
		
		//	バイアス電圧の設定
		isbwd = strsearch(listw[i][1], "_bwd", 0) >= 0
		for (j = 0; j < numOfPasses; j++)
			SetDimLabel 2, j, $num2str(configw[5][j*2+isbwd]*1e3), w0
		endfor
		
		//	バイアス電圧順に入れ替える
		reorder(w0)
		
		//	名前を変更する
		str0 = listw[i][0]
		str1 = listw[i][1]
		Rename w0 $(str0[0,strlen(str0)-4]+str1[1,strlen(str1)-1])
	endfor
	
	if (history)
		printf ,"%sKMNanonisConcatMultipass(%s)\r", PRESTR_CMD, GetDataFolder(1,dfr)
	endif
	
	return 0
End

Static Function/WAVE init(DFREF dfr)
	String errStr = PRESTR_CAUTION+"KMNanonisConcatenateMultipass gave error: "
	
	if (DataFolderRefStatus(dfr) != 1)
		print errStr+"invalid datafolder reference."
		return $""
	elseif (DataFolderRefStatus(dfr:$SIDAM_DF_SETTINGS) != 1)
		print errStr+"the settings datafolder is not found."
		return $""
	endif
	
	Wave/Z/SDFR=dfr:$SIDAM_DF_SETTINGS configw = 'Multipass-Config'
	if (!WaveExists(configw))
		print errStr+"Multipass-Config is not found."
		return $""
	endif
	
	Wave/Z/T listw = constructNameList(dfr,configw)
	if (!DimSize(listw,0))
		print errStr+"No multipass wave is found."
		return $""
	endif
	
	return listw
End

Static Function/WAVE constructNameList(DFREF dfr, Wave configw)
	int i, j, i0
	String str
	
	int numOfPasses = DimSize(configw,1)/2
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder dfr
	
	//	2D, 実数, SP で名前に [P1] を含むもの
	String P1List = WaveList("*[P1]*",";","DIMS:2;CMPLX:0;DP:0")
	
	//	P1List には以下のような文字列で構成されている
	//	t180401001_[P1]_Current
	//	t180401001_[P1]_Current_bwd
	//	t180401001_[P1]_Z
	//	t180401001_[P1]_Z_bwd
	//	このとき、nameList[][0] には t180401001_[P
	//	nameList[][1] には ]_Current, ]_Current_bwd, ]_Z, ]_bwd が入る
	Make/N=(ItemsInList(P1List),2)/T/FREE nameList
	for (i = 0; i < ItemsInList(P1List); i++)
		str = StringFromList(i,P1List)
		i0 = strsearch(str, "[P1]", strlen(str)-1, 1)
		namelist[i][0] = str[0,i0+1]						//	t180401001_[P
		namelist[i][1] = str[i0+3,strlen(str)-1]		//	]_Current
		//	multipassの個数に対応するウエーブがすべてそろっていることを確認する
		for (j = 1; j <= numOfPasses; j++)
			str = nameList[i][0] + num2istr(j) + nameList[i][1]
			if(!WaveExists($str))
				SetDataFolder dfrSav
				return $""
			endif
		endfor
	endfor
	
	SetDataFolder dfrSav
	return namelist
End

//	バイアス順に並べ替える
Static Function reorder(Wave w)
	int i, n = DimSize(w,2)
	
	Make/N=(n)/FREE indexw = p, biasw = str2num(GetDimLabel(w,2,p))
	Sort, biasw, biasw, indexw
	
	Duplicate/FREE w resw
	resw = w[p][q][indexw[r]]
	
	for (i = 0; i < n; i++)
		SetDimLabel 2, i, $num2str(biasw[i]), resw
	endfor
	
	Duplicate/O resw w
End