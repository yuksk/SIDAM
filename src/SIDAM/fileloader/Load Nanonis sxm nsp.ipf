#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

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
	int code = TextEncodingCode(SIDAM_NANONIS_TEXTENCODING)
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