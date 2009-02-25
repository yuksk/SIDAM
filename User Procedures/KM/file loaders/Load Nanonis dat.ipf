#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	ファイル読み込みメイン
//******************************************************************************
Function/WAVE LoadNanonisDat(pathStr)
	String pathStr
	
	String fileName = ParseFilePath(3, pathStr, ":", 0, 0)	//	拡張子抜きの名前
	DFREF dfrSav = GetDataFolderDFR()
	
	//	ヘッダ読み込み
	NewDataFolder/O/S $KM_DF_SETTINGS
	STRUCT header s
	if (LoadNanonisDatGetHeader(pathStr, s))	//	Nanonis dat ファイルではない場合
		return $""
	endif
	
	//	データ読み込み
	SetDataFolder dfrSav
	Wave/WAVE resw =  LoadNanonisDatGetData(pathStr, s)
	
	return resw
End


//******************************************************************************
//	ヘッダ読み込み
//		ヘッダから読み込んだ値はグローバル変数としてカレントデータフォルダへ保存される
//******************************************************************************
Static Function LoadNanonisDatGetHeader(pathStr, s)
	String pathStr
	STRUCT header &s
	
	LoadNanonisCommonGetHeader(pathStr)
	
	//	データ読み込みルーチンのためにヘッダの値を構造体へコピーしておく
	SVAR Experiment
	s.type = Experiment
	strswitch (s.type)
		case  "Z spectroscopy":
			s.skip = 1
			break
		case "bias spectroscopy":
			s.driveamp = NumVarOrDefault(":'Lock-in':Amplitude", NaN)
			s.modulated = StrVarOrDefault(":'Lock-in':'Modulated signal'", "")
			s.skip = !WaveExists('multiline settings')
			break
		case "Spectrum":
			s.skip = 1
			break
		case "History Data":
			s.interval = NumVarOrDefault("Sample Period (ms)",1)
			s.skip = 0
			break
	endswitch
	
	return 0
End

Static Structure header
	String type
	Variable driveamp
	String modulated
	Variable interval
	uchar skip
EndStructure


//******************************************************************************
//	データ読み込み
//		読み込まれたウエーブはカレントデータフォルダへ保存される
//******************************************************************************
Static Function/WAVE LoadNanonisDatGetData(pathStr, s)
	String pathStr
	STRUCT header &s
	
	LoadWave/G/W/A/Q pathStr
	Make/N=(ItemsInList(S_waveNames))/WAVE/FREE ww = $StringFromList(p,S_waveNames)
	
	//	名前の変更
	S_waveNames = ReplaceString("__A_",S_waveNames,"")
	S_waveNames = ReplaceString("__V_",S_waveNames,"")
	S_waveNames = ReplaceString("_omega",S_waveNames,"")
	S_waveNames = ReplaceString("_bwd_",S_waveNames,"bwd")
	Variable i
	for (i = 0; i < ItemsInList(S_waveNames); i += 1)
		Wave w = ww[i]
		Rename w $(ParseFilePath(3, pathStr, ":", 0, 0)+"_"+StringFromList(i,S_waveNames))
	endfor
	
	strswitch (s.type)
		case  "Z spectroscopy":
		case "bias spectroscopy":
			LoadNanonisDatGetDataConvert(s, ww)	//	単位変換
			if (!(GetKeyState(1)&4))						//	shiftが押されていなかったら平均を取る
				LoadNanonisCommonDataAvg("_bwd")
			endif
			break
		case "Spectrum":
		case "History Data":
			LoadNanonisDatGetDataConvert(s, ww)	//	単位変換
			break
	endswitch
	
	//	読み込まれたウエーブへの参照を返す
	DFREF dfr = GetDataFolderDFR()
	Make/FREE/N=(CountObjectsDFR(dfr, 1))/WAVE refw = $GetIndexedObjNameDFR(dfr, 1, p)	
	return refw
End

Static Function LoadNanonisDatGetDataConvert(s, ww)
	STRUCT header &s
	Wave/WAVE ww
	
	Variable i, n
	
	//	最初の列はバイアス電圧・距離・周波数が書き込まれている (History Data以外)
	Wave xw = ww[0]
	
	strswitch (s.type)
		case "bias spectroscopy":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0]*1e3, xw[numpnts(xw)-1]*1e3, "mV", ww[i]	//	V -> mV
				LoadNanonisCommonConversion(ww[i], driveamp=s.driveamp, modulated=s.modulated)
			endfor
			break
		case "Z spectroscopy":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0], xw[numpnts(xw)-1]*1e10, "\u00c5", ww[i]		//	m -> angstrom
				LoadNanonisCommonConversion(ww[i])
			endfor
			break
		case "Spectrum":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0], xw[numpnts(xw)-1], "Hz", ww[i]
				LoadNanonisCommonConversion(ww[i])
			endfor
			break
		case "History Data":
			for (i = 0, n = numpnts(ww); i < n; i += 1)
				SetScale/P x 0, s.interval, "ms", ww[i]
			endfor
			break
	endswitch
	
	if (s.skip)
		KillWaves xw
	endif
End


//******************************************************************************
//	datと3dsに共通して使われる関数
//******************************************************************************
//----------------------------------------------------------------------
//	ヘッダを読み込んでグローバル変数として保存する
//	返り値はヘッダのサイズ
//----------------------------------------------------------------------
Function LoadNanonisCommonGetHeader(pathStr)
	String pathStr
	
	Variable refNum, subFolder, i
	String buffer, key, name, value
	DFREF dfrSav = GetDataFolderDFR()
	
	strswitch (LowerStr(ParseFilePath(4, pathStr, ":", 0, 0)))	//	拡張子
		case "dat":
			key = "%[^\t]\t%[^\t]\t"
			break
		case "3ds":
			key = "%[^=]=%[^\r]\r"
			break
		default:
			return 0
	endswitch
	
	Open/R/T="????" refNum as pathStr
	FReadLine refNum, buffer	//	最初の行を読む
	do
		sscanf buffer, key, name, value
		//	">"を含むならば、サブフォルダを作成する
		i = strsearch(name, ">", 0)
		subFolder = (i != -1)
		if (subFolder)
			NewDataFolder/O/S $(name[0,i-1])
			name = name[i+1,strlen(name)-1]
		endif
		
		//	","を含む場合にはmultiline settingsであるとする
		if (strsearch(name,",",0) > -1)
			Make/N=(ItemsInList(value),5)/O $"multiline settings"/WAVE=w
			for (i = 0; i < 5; i += 1)
				SetDimLabel 1, i, $StringFromList(i, name, ", "), w
				w[][i] = str2num(StringFromList(i, StringFromList(p, value), ","))
			endfor
		else
			LoadNanonisCommonVariableString(name, value)
		endif
		
		if (subFolder)
			SetDataFolder dfrSav
		endif
		
		FReadLine refNum, buffer	//	次の行を読む
	while (strlen(buffer) != 1 && CmpStr(buffer,":HEADER_END:\r"))		//	空行でなければ(dat) && HEADER_END(3ds)
	
	FStatus refNum
	Close refNum
	
	return V_filePos	//	ヘッダのサイズ
End

//----------------------------------------------------------------------
//	データの値を物理値に変換する
//----------------------------------------------------------------------
Function LoadNanonisCommonConversion(w, [driveamp, modulated])
	Wave w
	Variable driveamp
	String modulated
	
	if (GrepString(NameOfWave(w),"LI([RXY]|phi)"))	//	Lock-in signal
		if (numtype(driveamp) == 2)			//	ロックインに関するヘッダが読み込まれていない
			SetScale d WaveMin(w), WaveMax(w), "A", w
			print "CAUTION: Information about lock-in settings is missing. Conversion to nS is NOT done."
		elseif (!CmpStr(modulated,"Bias (V)"))	//	バイアス電圧を変調した場合
			FastOP w = (1e9/driveamp) * w 	//	A -> nS
			SetScale d WaveMin(w), WaveMax(w), "nS", w
		elseif (!CmpStr(modulated,"Z (m)"))	//	Zを変調した場合
			FastOP w = (1/driveamp) * w
			SetScale d WaveMin(w), WaveMax(w), "A/m", w
		else
			FastOP w = (1/driveamp) * w
		endif
	elseif (GrepString(NameOfWave(w), "Bias"))	//	Bias
		FastOP w = (1e3) * w		//	V -> mV
		SetScale d WaveMin(w), WaveMax(w), "mV", w
	else
		SVAR/SDFR=$(GetWavesDataFolder(w,1)+KM_DF_SETTINGS) Experiment
		if (!CmpStr(Experiment, "Spectrum"))	//	FFT spectrum
			FastOP w = (1e15) * w		//	A -> fA
			SetScale d WaveMin(w), WaveMax(w), "fA/sqrt(Hz)", w
		else
			FastOP w = (1e9) * w		//	A -> nA
			SetScale d WaveMin(w), WaveMax(w), "nA", w
		endif
	endif
End

//----------------------------------------------------------------------
//	カレントデータフォルダ内でfwd と bwd の平均を求める
//	返り値は平均ウエーブへの参照ウエーブ
//----------------------------------------------------------------------
Function/WAVE LoadNanonisCommonDataAvg(bwdStr)
	String bwdStr
	
	String listStr = WaveList("*",";",""), name, avgName, subName
	Variable i, n
	Make/WAVE/N=0/FREE refw
	
	//	bwdStrで指定した文字列が含まれているものがbackwardウエーブ
	//	backwardウエーブからbwdStrを除いたものがforwardウエーブ
	for (i = 0, n = ItemsInList(listStr); i < n; i += 1)
		name = StringFromList(i,listStr)
		if (!GrepString(name,bwdStr))
			continue
		endif
		Wave fwdw = $ReplaceString(bwdStr, name, ""), bwdw = $name
		Duplicate/O fwdw $(NameOfWave(fwdw)+"_sub")/WAVE=subw
		FastOP subw = fwdw - bwdw
		FastOP fwdw = (0.5)*fwdw + (0.5)*bwdw
		KillWaves bwdw
		refw[numpnts(refw)] = {fwdw}
	endfor
	
	return refw
End

//----------------------------------------------------------------------
//	値を文字列もしくは数値としてグローバル変数に保存する
//	(sxmでもでも使用されている)
//----------------------------------------------------------------------
Function LoadNanonisCommonVariableString(name,str)
	String name, str
	
	int code = TextEncodingCode(TEXTENCODING_NANONIS)
	String value = ConvertTextEncoding(str, code, 1, 1, 0)	
	
	//	最初に空白がある場合にはそれを削除してから処理を行う
	//	(sxmファイルのヘッダはそういうものがある)
	if (char2num(value[0]) == 32)
		do
			value = ReplaceString(" ", value, "", 1, 1)
		while (char2num(value[0]) == 32)
	endif
	
	//	最初と最後に"が含まれる場合には削除する (3dsの文字列ヘッダ)
	if (!CmpStr(value[0],"\"") && !CmpStr(value[strlen(value)-1],"\""))
		value = ReplaceString("\"",value,"",0,1)
		value = RemoveEnding(value,"\"")
	endif
	
	//	数字(無限大含む)以外が含まれている、ピリオドが2つ以上含まれている、空文字列、のいずれかの場合には文字列と見なす
	if (GrepString(LowerStr(value),"[^0-9e+-.(inf)]") || ItemsInList(value,".") > 2 || !strlen(value))
		name = SelectString(CheckName(name, 4), name, CleanupName(name, 1))
		String/G $name = value
	else
		name = SelectString(CheckName(name, 3), name, CleanupName(name, 1))
		Variable/G $name = str2num(value)
	endif
End
