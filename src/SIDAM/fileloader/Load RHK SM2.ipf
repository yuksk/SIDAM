#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant ks_dfguide = "pos"		// 	スキャン位置やSTS測定位置を示すウエーブを保存するサブデータフォルダの名前
Static StrConstant ks_index_sdev = "_sdev"
Static Constant k_lockindivider = 0.01		//	ロックイン用のデバイダの値

//******************************************************************************
//	ファイル読み込みメイン
//		データタイプを判定して各ページごとの読み込み関数を実行します
//******************************************************************************
Function/WAVE LoadRHKSM2(pathStr)
	String pathStr
	
	STRUCT SM2Header sHeader
	sHeader.path = pathStr
	sHeader.filename = ParseFilePath(3, pathStr, ":", 0, 0)	//	拡張子抜きのファイル名
	
	//	キーボードの状態
	//	shift が押されていたらスペクトルデータは平均しない
	sHeader.mode = 0
	sHeader.mode += (GetKeyState(1)&4) != 0	//	bit 0: shiftが押されていたら1
	
	LoadRHKSM2GetSize(sHeader)	//	ファイルサイズを得る
	if (LoadRHKSM2CheckID(sHeader) && !(sHeader.mode&1))	//	file_id のチェック
		printf " LoadRHKSM2: '%s' contains more than 1 file_ids. Each page is loaded in each datafolder.\r", sHeader.filename
		sHeader.mode += 1
	endif
	
	//	読み込み実行
	Make/N=0/FREE/WAVE resrefw		//	読み込まれたウエーブへの参照が入る
	Variable pageNum, n
	sHeader.pageOffset = 0
	
	DFREF dfrSav = GetDataFolderDFR()	//	基準となるデータフォルダ
	
	for (pageNum = 0; sHeader.pageOffset < sHeader.filesize; pageNum += 1)
		SetDataFolder dfrSav
		sHeader.pageName = sHeader.filename+"_"+num2str(pageNum)
		//	mode の bit 0 が1のときは各ページを別々のフォルダへ読み込む
		if (sHeader.mode&1)
			NewDataFolder/S $sHeader.pageName
		endif
		//  ヘッダ読み込み
		LoadRHKSM2Header(sHeader)
		//  データ読み込み
		switch (sHeader.sInfo.type)
			case 0:
				Wave/WAVE refw = LoadRHKSM2Type0(sHeader)
				break
			case 1:
				Wave/WAVE refw = LoadRHKSM2Type1(sHeader)
				break
			case 3:
				Wave/WAVE refw = LoadRHKSM2Type3(sHeader)
				break
			default:
				print PRESTR_CAUTION + "LoadRHKSM2 gave error: unknown data type. (page: "+num2str(pageNum)+")"
		endswitch
		//	読み込まれたウエーブへの参照をまとめる
		n = numpnts(resrefw)
		Redimension/N=(n+numpnts(refw)) resrefw
		resrefw[n,] = refw[p-n]
		//	ヘッダ保存
		NewDataFolder/O/S $SIDAM_DF_SETTINGS
		PutSM2Header(sHeader)
		//	次のページを読み込むために pageOffset を増やす
		sHeader.pageOffset += sHeader.sInfo.size+sHeader.sInfo.data_offset
	endfor
	
	//	V から nS への換算
	LoadRHKSM2V2nS(resrefw, sHeader)
	
	return resrefw
End

//---------------------------------------------------------------
//	ファイルサイズを構造体へ読み込む
//---------------------------------------------------------------
Static Function LoadRHKSM2GetSize(sHeader)
	STRUCT SM2Header &sHeader
	
	Variable refNum
	Open/R/T="????" refNum as sHeader.path
	FStatus refNum
	sHeader.filesize = V_logEOF
	Close refNum
End

//---------------------------------------------------------------
//	file_idが同一であるかどうかチェックする
//	異なるものがある場合には、それぞれのページを独立したデータフォルダへ読み込む
//---------------------------------------------------------------
Static Function LoadRHKSM2CheckID(sHeader)
	STRUCT SM2Header &sHeader
	
	sHeader.pageOffset = 0
	Variable fileid = 0
	do
		LoadRHKSM2Header(sHeader)
		if (fileid && fileid != sHeader.sInfo.file_id)
			return 1
		endif
		fileid = sHeader.sInfo.file_id
		sHeader.pageOffset += sHeader.sInfo.size+sHeader.sInfo.data_offset
	while (sHeader.pageOffset < sHeader.filesize)
End

//******************************************************************************
//	ヘッダ読み込みのための構造体定義
//******************************************************************************
// 	SM2ファイルに記述されている内容に対応
//	各変数の名前はUsers GuideのAppendix Aに倣っている
Static Structure SM2DocumentInfo
	string	date
	string	time
	int16 	type
	int16	data_type
	int16	sub_type
	uint32	x_size
	uint32	y_size
	uint32	size
	int16 	page_type
	float		xscale
	float		xoffset
	float		yscale
	float		yoffset
	float		zscale
	float		zoffset
	char		xunits[10]
	char		yunits[10]
	char		zunits[10]
	float		xyscale
	float		angle
	float		current
	float		bias
	float		scan
	float		period
	float		file_id
	float		data_offset
	string	label
	string 	text
endStructure

//  STSに関連したパラメータ
Static Structure STSParameter
	uint32	repeat			//	1点での繰り返し回数
	int16	xpnts			//	stsにおけるx方向(横方向)のデータ点数
	int16	ypnts			//	stsにおけるy方向(縦方向)のデータ点数
	float		dx				//	stsにおけるx方向(横方向)の分解能
	float		dy				//	stsにおけるy方向(縦方向)の分解能
	int16	order			//	スキャン方向についてのフラッグ
							//	bit 0: fast scan の方向, 0: x, 1: y
							//	bit 1: xスキャンの方向, 0: 左から右, 1: 右から左, y方向の1列データの場合は0
							//	bit 2: yスキャンの方向, 0: 下から上, 1: 上から下, x方向の1行データの場合は0
	float		sensitivity		//	ロックインアンプのsensitivity
	float		driveamp			//	ロックインアンプの入力振幅
	float		gain				//	プリアンプのゲイン
	float		divider			//	分圧器の値
endStructure

Static Structure SM2Header
	string 	path				//	ファイルへの絶対パス
	string 	filename			//	拡張子なしのファイル名
	uint32	filesize			//	ファイルサイズ (bytes)
	int16	mode			//	読み込み時の動作
							//	bit 0: 全部のページを同一のデータフォルダに読み込む(0), ページごとにデータフォルダを作成する(1)
							//	bit 1: スペクトルの平均操作をしない(0)、平均する(1)
							//	bit 2: スペクトルのV->nS 変換をしない(0)、する(1)
	string	pageName		// 	ページの名前 (ファイル名+ページ番号)
	uint32	pageOffset		//	ページの開始位置 (bytes)
	STRUCT SM2DocumentInfo sInfo
	STRUCT STSParameter stsParam
endStructure

//******************************************************************************
//  ヘッダ読み込み
//******************************************************************************
Static Function LoadRHKSM2Header(sHeader)
	STRUCT SM2Header &sHeader
	
	String str	
	Variable refNum
	Open/R/T="????" refNum as sHeader.path
	
	//  ファイルサイズのチェック
	FStatus refNum
	if (sHeader.pageoffset > V_logEOF)
		Close refNum
		return 1
	endif
	
	//  以下では、一旦ローカル変数に読み込んでから出ないと構造体への代入ができない
	String ndate, ntime
	Variable type, data_type, sub_type, x_size, y_size, size, page_type
	Variable xscale, xoffset, yscale, yoffset, zscale, zoffset
	String xunits, yunits, zunits
	Variable xyscale, angle
	Variable current, bias
	Variable scan, period
	Variable file_id, data_offset
	String nlabel, text
	
	//  date, time
	FSetPos refNum, (sHeader.pageoffset+0)
	FReadLine/N=32 refNum, str
	sscanf str, "STiMage 3.1 %s %s", ndate, ntime
	sHeader.sInfo.date = ndate
	sHeader.sInfo.time = ntime
	
	//  type, date_type, sub_type, x_size, y_size, size, page_type
	FSetPos refNum, (sHeader.pageoffset+32)
	FReadLine/N=32 refNum, str
	sscanf str, "%d %d %d %d %d %d %d", type, data_type, sub_type, x_size, y_size, size, page_type
	sHeader.sInfo.type = type
	sHeader.sInfo.data_type = data_type
	sHeader.sInfo.sub_type = sub_type
	sHeader.sInfo.x_size = x_size
	sHeader.sInfo.y_size = y_size
	sHeader.sInfo.size = size
	sHeader.sInfo.page_type = page_type
	
	//  xscale, xoffset, xunits
	FSetPos refNum, (sHeader.pageoffset+64)
	FReadLine/N=32 refNum, str
	sscanf str, "X %f %f %s", xscale, xoffset, xunits
	sHeader.sInfo.xscale = xscale
	sHeader.sInfo.xoffset = xoffset 
	sHeader.sInfo.xunits = xunits
	
	//  yscale, yoffset, yunits
	FSetPos refNum, (sHeader.pageoffset+96)
	FReadLine/N=32 refNum, str
	sscanf str, "Y %f %f %s", yscale, yoffset, yunits
	sHeader.sInfo.yscale = yscale
	sHeader.sInfo.yoffset = yoffset 
	sHeader.sInfo.yunits = yunits
	
	//  zscale, zoffset, zunits
	FSetPos refNum, (sHeader.pageoffset+128)
	FReadLine/N=32 refNum, str
	sscanf str, "Z %f %f %s", zscale, zoffset, zunits
	sHeader.sInfo.zscale = zscale
	sHeader.sInfo.zoffset = zoffset 
	sHeader.sInfo.zunits = zunits
	
	//  xyscale, angle
	FSetPos refNum, (sHeader.pageoffset+160)
	FReadLine/N=32 refNum, str
	//	マニュアルによれば str[13] は"q"のはずだが、実際にはchar2num(str[13])=-23の文字が使われている
	//	以下は、文字の種類によらずに読めるようにするための修正 (2005.5.22 YK)
	sscanf str, "XY %f "+str[13]+" %f", xyscale, angle
	//sscanf str, "XY %f q %f", xyscale, angle
	sHeader.sInfo.xyscale = xyscale
	sHeader.sInfo.angle = angle
	
	//  current, bias
	FSetPos refNum, (sHeader.pageoffset+192)
	FReadLine/N=32 refNum, str
	sscanf str, "IV %f %f", current, bias
	sHeader.sInfo.current = current
	sHeader.sInfo.bias = bias
	
	//  scan, period
	FSetPos refNum, (sHeader.pageoffset+224)
	FReadLine/N=32 refNum, str
	sscanf str, "scan %d %f", scan, period
	sHeader.sInfo.scan = scan
	sHeader.sInfo.period = period
	
	//  file_id, data_offset
	FSetPos refNum, (sHeader.pageoffset+256)
	FReadLine/N=32 refNum, str
	sscanf str, "id %d %d", file_id, data_offset
	sHeader.sInfo.file_id = file_id
	sHeader.sInfo.data_offset = data_offset
	
	//  label
	FSetPos refNum, (sHeader.pageoffset+320)
	FReadLine/N=20 refNum, nlabel
	sHeader.sInfo.label = nlabel
	
	//  text
	FSetPos refNum, (sHeader.pageoffset+352)
	FReadLine/N=160 refNum, text
	sHeader.sInfo.text = text
	
	Close refNum
End

//******************************************************************************
// 	ヘッダをグローバル変数として保存
//******************************************************************************
Static Function PutSM2Header(sHeader)
	STRUCT SM2Header &sHeader
	
	String/G date = sHeader.sInfo.date
	String/G time = sHeader.sInfo.time
	Variable/G type = sHeader.sInfo.type
	Variable/G data_type = sHeader.sInfo.data_type
	Variable/G sub_type = sHeader.sInfo.sub_type
	if (sHeader.sInfo.type == 3)
		Variable/G xpnts = sHeader.stsParam.xpnts
		Variable/G ypnts = sHeader.stsParam.ypnts
		Variable/G zpnts = sHeader.sInfo.x_size
		Variable/G repeat = sHeader.stsParam.repeat
		Variable/G order = sHeader.stsParam.order
	else
		Variable/G x_size = sHeader.sInfo.x_size
		Variable/G y_size = sHeader.sInfo.y_size
	endif
	Variable/G size = sHeader.sInfo.size
	Variable/G page_type = sHeader.sInfo.page_type
	Variable/G xscale = sHeader.sInfo.xscale
	Variable/G xoffset  = sHeader.sInfo.xoffset
	Variable/G yscale = sHeader.sInfo.yscale
	Variable/G yoffset  = sHeader.sInfo.yoffset
	Variable/G zscale = sHeader.sInfo.zscale
	Variable/G zoffset = sHeader.sInfo.zoffset
	String/G xunits = sHeader.sInfo.xunits
	String/G yunits = sHeader.sInfo.yunits
	String/G zunits = sHeader.sInfo.zunits	
	Variable/G xyscale = sHeader.sInfo.xyscale
	Variable/G angle = sHeader.sInfo.angle
	Variable/G current = sHeader.sInfo.current
	Variable/G bias = sHeader.sInfo.bias
	Variable/G scan = sHeader.sInfo.scan
	Variable/G period = sHeader.sInfo.period
	Variable/G file_id = sHeader.sInfo.file_id
	Variable/G data_offset = sHeader.sInfo.data_offset
	String/G label = sHeader.sInfo.label
	String/G text = sHeader.sInfo.text
	
	if (sHeader.stsParam.driveamp)
		Variable/G sensitivity = sHeader.stsParam.sensitivity
		Variable/G driveamp = sHeader.stsParam.driveamp
	endif
End

//******************************************************************************
//  type 0 (イメージ) 読み込み
//******************************************************************************
Static Function/WAVE LoadRHKSM2Type0(sHeader)
	STRUCT SM2Header &sHeader
	
	//	イメージウエーブ
	Make/N=(sHeader.sInfo.x_size, sHeader.sInfo.x_size)/O $sHeader.pageName/WAVE=w
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	読み込み実行
	//		ページが type=0 なら data_type=1 、すなわちデータは 2 byte signed integer で保存されている
	//		したがって、 /T={16,2} でよい
	GBLoadWave/B/Q/N=tmp/T={16,2}/S=(sHeader.pageOffset+sHeader.sInfo.data_offset)/W=1/U=(sHeader.sInfo.x_size*sHeader.sInfo.y_size) sHeader.path
	Wave tw = :tmp0
	
	//	1次元ウエーブから2次元ウエーブを構成
	if (sHeader.sInfo.xscale < 0 && sHeader.sInfo.yscale < 0)
		w = tw[(sHeader.sInfo.y_size-1-q)*sHeader.sInfo.x_size+(sHeader.sInfo.x_size-1-p)]
	elseif (sHeader.sInfo.xscale < 0 && sHeader.sInfo.yscale > 0)
		w = tw[q*sHeader.sInfo.x_size+(sHeader.sInfo.x_size-1-p)]
	elseif (sHeader.sInfo.xscale > 0 && sHeader.sInfo.yscale < 0)
		w = tw[(sHeader.sInfo.y_size-1-q)*sHeader.sInfo.x_size+p]
	elseif (sHeader.sInfo.xscale > 0 && sHeader.sInfo.yscale > 0)
		w = tw[q*sHeader.sInfo.x_size+p]
	else
		print PRESTR_CAUTION + "LoadRHKSM2Type0 gave error: xscale and/or yscale are invalid."
		return $""
	endif
	
	//  physical valueに変換
	strswitch (sHeader.sInfo.zunits)
		case "m":
			FastOp w = (sHeader.sInfo.zscale*1e10)*w	//  m -> anstrom への変換を含む
			SetScale d 0, 0, "\u00c5", w
			break
		case "A":
			FastOp w = (sHeader.sInfo.zscale*1e9)*w		//  A -> nA への変換を含む
			SetScale d 0, 0, "nA", w
			break
		default:
			FastOp w = (sHeader.sInfo.zscale)*w
			Execute "SetScale d 0, 0, \""+sHeader.sInfo.zunits+"\", "+GetWavesDataFolder(w,2)
	endswitch
	
	//	スキャン範囲(Å単位)
	Variable xmin = -abs(sHeader.sInfo.xscale) * (sHeader.sInfo.x_size/2 - 1)
	Variable xmax = abs(sHeader.sInfo.xscale) * sHeader.sInfo.x_size/2
	Variable ymin = -abs(sHeader.sInfo.yscale) * (sHeader.sInfo.y_size/2 - 1)
	Variable ymax = abs(sHeader.sInfo.yscale) * sHeader.sInfo.y_size/2
	SetScale/I x (xmin+sHeader.sInfo.xoffset)*1e10, (xmax+sHeader.sInfo.xoffset)*1e10, "\u00c5", w
	SetScale/I y (ymin+sHeader.sInfo.yoffset)*1e10, (ymax+sHeader.sInfo.yoffset)*1e10, "\u00c5", w
	
	SetDataFolder dfrSav
	
	//    スキャン範囲の枠を表示するためのガイドウエーブ
	NewDataFolder/O $ks_dfguide
	Make/N=5/O/FREE txw = {xmin, xmax, xmax, xmin, xmin}
	Make/N=5/O/FREE tyw = {ymin, ymin, ymax, ymax, ymin}
	Make/N=5/O :$(ks_dfguide):scan_x/WAVE=xw
	Make/N=5/O :$(ks_dfguide):scan_y/WAVE=yw
	xw = txw * cos(sHeader.sInfo.angle/180*pi) - tyw * sin(sHeader.sInfo.angle/180*pi) + sHeader.sInfo.xoffset
	yw = txw * sin(sHeader.sInfo.angle/180*pi) + tyw * cos(sHeader.sInfo.angle/180*pi) + sHeader.sInfo.yoffset
	xw *= 1e10
	yw *= 1e10
	
	Make/N=1/WAVE/FREE refw = {w}
	return refw
End

//******************************************************************************
//  スペクトル (type 1) 読み込み
//******************************************************************************
Static Function/WAVE LoadRHKSM2Type1(sHeader)
	STRUCT SM2Header &sHeader
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	読み込み実行
	//	全部まとめて読み込んでから、各ウエーブに分割する
	switch (sHeader.sInfo.data_type)
		case 0:	//  4 byte floating point
			GBLoadWave/B/Q/N=tmp/T={2,2}/S=(sHeader.pageOffset+sHeader.sInfo.data_offset)/W=1/U=(sHeader.sInfo.x_size*sHeader.sInfo.y_size) sHeader.path
			break
		case 1:	//  2 byte signed integer
			GBLoadWave/B/Q/N=tmp/T={16,2}/S=(sHeader.pageOffset+sHeader.sInfo.data_offset)/W=1/U=(sHeader.sInfo.x_size*sHeader.sInfo.y_size) sHeader.path
			break
		default:
			print PRESTR_CAUTION + "LoadRHKSM2Type1 gave error: unknown data type."
			return $""
	endswitch
	Wave tw = :tmp0
	
	//  physical valueに変換
	String yunitsStr = ""
	strswitch (sHeader.sInfo.zunits)
		case "m":
			FastOp tw = (sHeader.sInfo.zscale*1e10)*tw		//  m -> anstrom への変換を含む
			yunitsStr = "\u00c5"
			break
		case "A":
			FastOp tw = (sHeader.sInfo.zscale*1e9)*tw		//  A -> nA への変換を含む
			yunitsStr = "nA"
			break
		default:
			FastOp tw = (sHeader.sInfo.zscale)*tw
			yunitsStr = sHeader.sInfo.zunits
	endswitch
	
	//  X scaling の physical value を用意
	//  x -> バイアス電圧 (mV) for I-V spectrum
	//  x -> 距離 (Å) for I-z spectrum
	Variable convert2pv
	String xunitsStr = ""
	strswitch (sHeader.sInfo.xunits)
		case "m":	//  I-z spectrum: m -> angstrom
			convert2pv = 1e10
			xunitsStr = "\u00c5"
			break
		case "V":	//  I-V spectrum: V -> mV
			convert2pv = 1e3
			xunitsStr = "mV"
			break
		default:
			convert2pv = 1
			xunitsStr = sHeader.sInfo.xunits
	endswitch
	Variable startv = sHeader.sInfo.xscale > 0 ? sHeader.sInfo.xoffset*convert2pv : (sHeader.sInfo.xoffset+sHeader.sInfo.xscale*(sHeader.sInfo.x_size-1))*convert2pv
	Variable endv = sHeader.sInfo.xscale > 0 ? (sHeader.sInfo.xoffset+sHeader.sInfo.xscale*(sHeader.sInfo.x_size-1))*convert2pv : sHeader.sInfo.xoffset*convert2pv
	
	//	平均操作をしない場合は、ここで元のデータフォルダへ戻る
	//	これにより、次の分割操作の結果が保存される
	if (sHeader.mode&1)
		SetDataFolder dfrSav
	endif
	
	//	平均しない場合は、平均前の各ウエーブへの参照が入る
	//	平均する場合には、平均前の各ウエーブへの参照が平均・標準偏差ウエーブへの参照で上書きされる
	Make/N=(sHeader.sInfo.y_size)/WAVE/FREE refw
	
	//  各ウエーブに分割
	Variable i
	for (i = 0; i < sHeader.sInfo.y_size; i += 1)
		Make/N=(sHeader.sInfo.x_size)/O $(sHeader.pageName+"_"+num2str(i))/WAVE=w
		refw[i] = w
		SetScale/I x startv, endv, xunitsStr, w
		SetScale d 0, 0, yunitsStr, w
		if (sHeader.sInfo.xscale > 0)			//  バイアス電圧の掃引方向を反映
			w = tw[sHeader.sInfo.x_size*i+p]
		else
			w = tw[sHeader.sInfo.x_size*(i+1)-1-p]
		endif
	endfor
	
	//	平均操作
	if (!sHeader.mode&1)
		Wave/WAVE statsw = stats(refw, sHeader)
		SetDataFolder dfrSav
		Duplicate/O statsw[0] $sHeader.pageName/WAVE=avgw
		Duplicate/O statsw[1] $(sHeader.pageName+ks_index_sdev)/WAVE=sdevw
		Redimension/N=2 refw
		refw = {avgw, sdevw}
	endif
	
	return refw
End

Static Function/WAVE stats(Wave/WAVE refw, STRUCT SM2Header &sHeader)
	Make/N=(sHeader.sInfo.x_size,sHeader.sInfo.y_size)/FREE tw
	int j
	for (j = 0; j < DimSize(tw,1); j++)
		Wave w = refw[j]
		tw[][j] = w[p]
	endfor
	MatrixOP/FREE avgw = sumRows(tw)/numCols(tw)
	MatrixOP/FREE sdevw = sqrt(varCols(tw^t)^t)
	Copyscales w, avgw, sdevw
	Make/N=2/WAVE/FREE rtnw = {avgw, sdevw}
	return rtnw
End

//******************************************************************************
//	STS, scaning barrier height (type 3) 読み込み
//******************************************************************************
Static Function/WAVE LoadRHKSM2Type3(sHeader)
	STRUCT SM2Header &sHeader
	
	//  stsスキャン情報読み込み
	LoadRHKSM2Type3Repeat(sHeader)
	LoadRHKSM2Type3Pos(sHeader)
	//sHeader.stsParam.order = 7		//	y-scan時にはパラメータが正しく記録されていない。このバグに対応するときにはこの行を書き換える (2012-12-08)
	
	//  データ読み込み
	Wave stsw = LoadRHKSM2Type3Data(sHeader)
	
	//  平均
	if (!sHeader.mode&1)
		if (sHeader.stsParam.repeat > 4)
			return LoadRHKSM2Type3DataAvgS(stsw, sHeader)
		else
			return LoadRHKSM2Type3DataAvgF(stsw, sHeader)
		endif
	else
		Make/N=1/WAVE/FREE refw = {stsw}
		return refw
	endif
End

//---------------------------------------------------------------
//  STSデータ (type 3) の1点での繰り返し回数
//---------------------------------------------------------------
Static Function LoadRHKSM2Type3Repeat(sHeader)
	STRUCT SM2Header &sHeader
	
	//  位置情報記録開始位置 (bytes)
	Variable startOfAdditionalByte = sHeader.pageOffset+sHeader.sInfo.data_offset+sHeader.sInfo.size-sHeader.sInfo.y_size*32
	
	Variable refNum
	Open/R/T="????" refNum as sHeader.path
	
	//  1本目のスペクトルの位置
	Variable Ax, Ay
	if (startOfAdditionalByte+12+4 > sHeader.filesize)	//  ファイルサイズのチェック
		print PRESTR_CAUTION + "LoadRHKSM2Type3Repeat gave error. error 1"
		return 1
	endif
	FSetPos refNum, (startOfAdditionalByte+8)
	FBinRead/B=3/F=4 refNum, Ax
	FSetPos refNum, (startOfAdditionalByte+12)
	FBinRead/B=3/F=4 refNum, Ay
	
	//  ２本目以降のスペクトルの位置
	//		１本目と位置が異なるまでの読み込み回数が１点における繰り返し回数
	Variable Bx, By
	sHeader.stsParam.repeat = 0	//  繰り返し回数, repeat=1 なら繰り返し無し
	do
		sHeader.stsParam.repeat += 1
		if (startOfAdditionalByte+12+32*sHeader.stsParam.repeat+4 > sHeader.filesize)		//  ファイルサイズのチェック
			//print PRESTR_CAUTION + "Load023SM2Type3Repeat gave error. error 2"
			//return 1
			Close refNum							//  2004.2.13 修正 　これでもエラーは出るが読み込める
			LoadRHKSM2Type1(sHeader)
			return 0
		endif
		FSetPos refNum, (startOfAdditionalByte+8+32*sHeader.stsParam.repeat)
		FBinRead/B=3/F=4 refNum, Bx
		FSetPos refNum, (startOfAdditionalByte+12+32*sHeader.stsParam.repeat)
		FBinRead/B=3/F=4 refNum, By
	while ((Ax == Bx) && (Ay == By))
	
	Close refNum
	return 0
End

//---------------------------------------------------------------
//  STSデータ (type 3) のSTS位置情報
//		データが保存されている順序で測定位置を１次元ウエーブ２ヶ(x, y)に保存する
//		スペクトルデータの保存順と実際の位置の関係を確認することができる
//---------------------------------------------------------------
Static Function LoadRHKSM2Type3Pos(sHeader)
	STRUCT SM2Header &sHeader
	
	//  位置情報記録開始位置 (bytes)
	Variable startOfAdditionalByte = sHeader.pageOffset+sHeader.sInfo.data_offset+sHeader.sInfo.size-sHeader.sInfo.y_size*32
	
	//  測定位置保存ウエーブ
	NewDataFolder/O $ks_dfguide
	Make/N=(sHeader.sInfo.y_size/sHeader.stsParam.repeat)/O :$(ks_dfguide):stspos_x/WAVE=xw, :$(ks_dfguide):stspos_y/WAVE=yw
	
	Variable refNum
	Open/R/T="????" refNum as sHeader.path
	
	//  測定位置読み込み
	Variable var, i
	for (i = 0; i < numpnts(xw); i += 1)
		FSetPos refNum, (startOfAdditionalByte+32*sHeader.stsParam.repeat*i+8)
		FBinRead/B=3/F=4 refNum ,var
		xw[i] = var
		FSetPos refNum, (startOfAdditionalByte+32*sHeader.stsParam.repeat*i+12)
		FBinRead/B=3/F=4 refNum, var
		yw[i] = var
	endfor
	Close refNum
	FastOp xw = (1e10)*xw		//  m -> angstrom 変換
	FastOp yw = (1e10)*yw		//  m -> angstrom 変換
	
	//	STS位置情報から fast scan , slow scan の測定点数と基本変移を取り出す
	Variable dx_fast, dy_fast, pts_fast
	Variable dx_slow, dy_slow, pts_slow
	LoadRHKSM2Type3Pos_pts(sHeader, xw, yw, dx_fast, dy_fast, dx_slow, dy_slow, pts_fast, pts_slow)
	
	//	fast scan, slow scan 方向の点数をSTS測定点数として割り当てる
	//	ヘッダの scan の値を信用する
	//	0: right, 1: left, 2: up, 3: down
	Variable isHorizontal = (sHeader.sInfo.scan < 2)
	sHeader.stsParam.xpnts = isHorizontal ? pts_fast : pts_slow
	sHeader.stsParam.ypnts = isHorizontal ? pts_slow : pts_fast
	sHeader.stsParam.dx = isHorizontal ? sqrt(dx_fast^2+dy_fast^2) : sqrt(dx_slow^2+dy_slow^2)
	sHeader.stsParam.dy = isHorizontal ? sqrt(dx_slow^2+dy_slow^2) : sqrt(dx_fast^2+dy_fast^2)
	
	//	スキャン方向についての情報
	//	ここでもヘッダの scan の値を信用する
	//	centerlineの場合(d=0)は常に x scan は右から左、y scan は上から下 であるとみなす
	Variable d = dx_slow*dy_fast - dy_slow*dx_fast		//	外積のz成分
	sHeader.stsParam.order = 0
	sHeader.stsParam.order += (sHeader.sInfo.scan > 1)			//	fast scan は y方向なら true
	sHeader.stsParam.order += (sHeader.sInfo.scan == 1 || (sHeader.sInfo.scan == 2 && d < 0) || (sHeader.sInfo.scan == 3 && d > 0) || !d) * 2	//	xスキャンが右から左なら true
	sHeader.stsParam.order += (sHeader.sInfo.scan == 3 || (sHeader.sInfo.scan == 0 && d > 0) || (sHeader.sInfo.scan == 1 && d < 0) || !d) * 4	//	yスキャンが上から下なら true
End
//---------------------------------------------------------------
//	STS位置情報から fast scan , slow scan の測定点数と基本変移を取り出す
//		各測定点間の距離は必ずしも一定にならない(若干揺らぐ)ことへの対処が必要
//		STS測定点数は4点以上あることを利用する
//---------------------------------------------------------------
Static Function LoadRHKSM2Type3Pos_pts(sHeader, xw, yw, dx_fast, dy_fast, dx_slow, dy_slow, pts_fast, pts_slow)
	STRUCT SM2Header &sHeader
	Wave xw, yw
	Variable &dx_fast, &dy_fast, &dx_slow, &dy_slow, &pts_fast, &pts_slow
	
	Variable i
	Variable minstspnts = 4	//	STS測定点数は4点以上
	
	//	fast scan の基本変移
	dx_fast = xw[1] - xw[0]
	dy_fast = yw[1] - yw[0]
	//	fast scan の点数を取り出す
	i = 0
	if (abs(dx_fast) > abs(dy_fast))
		do
			i +=1
		while (i < numpnts(xw) && abs(xw[i]-xw[i-1]) < (minstspnts - 2)*abs(dx_fast))
	else
		do
			i +=1
		while (i < numpnts(yw) && abs(yw[i]-yw[i-1]) < (minstspnts - 2)*abs(dy_fast))
	endif
	pts_fast = i
	
	//	slow scan方向の基本変移と点数を取り出す
	//	centerlineかどうかで場合分けが必要
	if (numpnts(xw) > pts_fast)
		dx_slow = xw[pts_fast]-xw[0]
		dy_slow = yw[pts_fast]-yw[0]
		i = 0
		if (abs(dx_slow) > abs(dy_slow))
			do
				i += 1
			while (pts_fast*i < numpnts(xw) && abs(xw[pts_fast*i]-xw[pts_fast*(i-1)]) < (minstspnts - 2)*abs(dx_slow))
		else
			do
				i += 1
			while (pts_fast*i < numpnts(yw) && abs(yw[pts_fast*i]-yw[pts_fast*(i-1)]) < (minstspnts - 2)*abs(dy_slow))
		endif
		pts_slow = i
	else		//	centerline
		dx_slow = dx_fast
		dy_slow = dy_fast
		dx_fast = 0
		dy_fast = 0
		pts_slow = pts_fast
		pts_fast = 1
	endif
	
	//******************************************************************************
	//	every pixel に付随するバグに対する対処	(2007-5-25 YK)
	//	(1) centerline ではなく
	//	(2) 縦横の点数が同じでなければ
	//	every pixel のバグの影響を受けているとみなす
	if (pts_fast != 1 && pts_fast != pts_slow)
		LoadRHKSM2Type3Pos_4bug(sHeader, pts_slow, pts_fast, xw, yw)
	endif
	//******************************************************************************
End
//---------------------------------------------------------------
//	every pixel に付随するバグに対する対処
//---------------------------------------------------------------
Static Function LoadRHKSM2Type3Pos_4bug(sHeader, pts_slow, pts_fast, xw, yw)
	STRUCT SM2Header &sHeader
	Variable &pts_slow, &pts_fast
	Wave xw, yw
	
	//	測定点数は最も近い2のべき乗にする
	pts_fast = 2^round(log(pts_fast)/log(2))
	pts_slow = 2^round(log(pts_slow)/log(2))
	printf "Every pixel bug in '%s'.\r", sHeader.pageName
	printf "Numbers of points were overwritten by [%d, %d] points.\r", pts_fast, pts_slow
	
	//	コメントに関連したパラメータの情報が書かれていれば、それらとの整合性をチェックする
	//	ただし、整合性が取れなくても表示をするだけで何も変更はしない
	printf "checking consistency..... "
	
	Variable isHorizontal = (sHeader.sInfo.scan < 2) 
	Variable xpnts = isHorizontal ? pts_fast : pts_slow	//	この段階では構造体にはまだ書き込まれていないので
	Variable ypnts = isHorizontal ? pts_slow : pts_fast	//	このようにする
	
	Variable nx = NumberByKey("nx", sHeader.sInfo.text)
	Variable ny = NumberByKey("ny", sHeader.sInfo.text)
	Variable rep = NumberByKey("rep", sHeader.sInfo.text)
	
	if (numtype(nx))
		printf "nx: N/A\t"
	elseif (nx == xpnts)
		printf "nx: OK\t"
	else
		printf "nx: NO (%f, %f)\t", nx, xpnts
	endif
	
	if (numtype(ny))
		printf "ny: N/A\t"
	elseif (ny == ypnts)
		printf "ny: OK\t"
	else
		printf "ny: NO (%f, %f)\t", ny, ypnts
	endif
	
	if (numtype(rep))
		printf "rep: N/A\t"
	elseif (rep == sHeader.stsParam.repeat)
		printf "rep: OK\t"
	else
		printf "rep: NO (%f, %f)\t", rep, sHeader.stsParam.repeat
	endif
	
	Variable ang = NumberByKey("ang", sHeader.sInfo.text)
	Variable ux = xw[1] - xw[0], uy = yw[1] - yw[0]
	Variable sx, sy
	switch (sHeader.sInfo.scan)
		case 0:	//	right
			sx = 1 ;	sy = 0
			break
		case 1:	//	left
			sx = -1 ;	sy = 0
			break
		case 2:	//	up
			sx = 0 ;	sy = 1
			break
		case 3:	//	down
			sx = 0 ;	sy = -1
			break
		default:
	endswitch
	
	if (numtype(ang))
		print "ang: N/A"
	elseif (abs(ang - acos((sx*ux+sy*uy)/sqrt(ux^2+uy^2)) /pi * 180 * sign(sx*uy-sy*ux)) < 0.1)	//	角度が合っているとみなすのはズレが0.1度以下のとき
		print "ang: OK"
	else
		printf "ang: NO (%f, %f)\r", ang, acos((sx*ux+sy*uy)/sqrt(ux^2+uy^2)) / pi * 180 * sign(sx*uy-sy*ux)
	endif
End
//---------------------------------------------------------------
//  STSデータ (type 3) の読み込み
//---------------------------------------------------------------
Static Function/WAVE LoadRHKSM2Type3Data(sHeader)
	STRUCT SM2Header &sHeader
	
	//  保存形式確認
	//		4 byte floating point, 2 byte signed integer のどちらかであるが、後者であると仮定して進める
	if (sHeader.sInfo.data_type != 1)
		print PRESTR_CAUTION + "LoadRHKSM2Type3Data gave error. error 1"
		return $""
	endif
	
	Variable xpnts = sHeader.stsParam.xpnts, ypnts = sHeader.stsParam.ypnts, zpnts = sHeader.sInfo.x_size
	Variable repeat = sHeader.stsParam.repeat
	Variable fpos = sHeader.pageOffset+sHeader.sInfo.data_offset
	Variable i, j
	
	//  出力ウエーブ
	Make/N=(xpnts,ypnts,zpnts,repeat) $sHeader.pageName/WAVE=stsw
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	読み込み実行
	//	全部のデータを１つのウエーブに読み込んでから、それを4Dウエーブへと再構成する
	GBLoadWave/O/B/Q/N=tmp/T={16,2}/S=(fpos)/W=1/U=(xpnts*ypnts*zpnts*repeat) sHeader.path
	Wave allw = tmp0
	
	if (sHeader.stsParam.order & 1)	//	fast scan が y方向なら
		//stsw = allw[r+zpnts*(s+repeat*(q+ypnts*p))]
		Redimension/N=(zpnts,repeat,ypnts,xpnts) allw
		MultiThread stsw = allw[r][s][q][p]
	else			//	fast scan が x方向なら
		//stsw = allw[r+zpnts*(s+repeat*(p+xpnts*q))]
		Redimension/N=(zpnts,repeat,xpnts,ypnts) allw
		MultiThread stsw = allw[r][s][p][q]
	endif
	
	if (sHeader.sInfo.xscale < 0)		//	バイアス電圧のスイープ方向
		Reverse/DIM=2 stsw
	endif
	if (sHeader.stsParam.order & 2)	//	xスキャンが右から左なら
		Reverse/DIM=0 stsw
	endif
	if (sHeader.stsParam.order & 4)	//	yスキャンが上から下なら
		Reverse/DIM=1 stsw
	endif
	
	//  physical valueに変換
	strswitch (sHeader.sInfo.zunits)
		case "m":
			FastOp stsw = (sHeader.sInfo.zscale*1e10)*stsw		//  m -> anstrom への変換を含む
			SetScale d 0, 0, "\u00c5", stsw
			break
		case "A":
			FastOp stsw = (sHeader.sInfo.zscale*1e9)*stsw		//  A -> nA への変換を含む
			SetScale d 0, 0, "nA", stsw
			break
		default:
			FastOp stsw = (sHeader.sInfo.zscale)*stsw
			Execute "SetScale d 0, 0, \""+sHeader.sInfo.zunits+"\", "+GetWavesDataFolder(stsw,2)
	endswitch
	
	//  scaling を physical value に変換
	//  z -> バイアス電圧　(mV) for I-V spectrum
	//  z -> 距離 (Å) for I-z spectrum
	Variable convert2pv
	String unitsStr = ""
	switch (sHeader.sInfo.sub_type)
		case 7:		//  I-V spectrum
			convert2pv = 1e3
			unitsStr = "mV"
			break
		case 8:		//  I-z spectrum
			convert2pv = 1e10
			unitsStr = "\u00c5"
			break
		default:		// 上記以外はとりあえず1ということにしておく
			convert2pv = 1
			unitsStr = sHeader.sInfo.xunits
	endswitch
	if (sHeader.sInfo.xscale > 0)
		SetScale/P z (sHeader.sInfo.xoffset*convert2pv), (sHeader.sInfo.xscale*convert2pv), unitsStr, stsw
	else
		SetScale/I z ((sHeader.sInfo.xoffset+sHeader.sInfo.xscale*(zpnts-1))*convert2pv),(sHeader.sInfo.xoffset*convert2pv),unitsStr, stsw
	endif
	//  x, y -> スキャン範囲 (Å)
	WaveStats/Q/M=1 $(GetWavesDataFolder(stsw,1)+ks_dfguide+":stspos_x")
	SetScale/P x (V_max+V_min)/2-sHeader.stsParam.dx*sHeader.stsParam.xpnts/2+sHeader.stsParam.dx/2, sHeader.stsParam.dx, "\u00c5", stsw
	WaveStats/Q/M=1 $(GetWavesDataFolder(stsw,1)+ks_dfguide+":stspos_y")
	SetScale/P y (V_max+V_min)/2-sHeader.stsParam.dy*sHeader.stsParam.ypnts/2+sHeader.stsParam.dy/2, sHeader.stsParam.dy, "\u00c5", stsw
	
	SetDataFolder dfrSav
	return stsw
End

//---------------------------------------------------------------
//	STSデータ (type 3) を読み込んだ後に平均
//		repeat が4以下の場合の高速バージョン
//---------------------------------------------------------------
Static Function/WAVE LoadRHKSM2Type3DataAvgF(w, sHeader)
	Wave w
	STRUCT SM2Header &sHeader
	
	if (sHeader.stsParam.repeat == 1)
		Redimension/N=(-1,-1,-1) w
		return $""
	endif
	
	Variable nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	
	Make/N=(nx,ny,nz)/O $("_"+NameOfWave(w))/WAVE=avgw, $(sHeader.pageName+ks_index_sdev)/WAVE=sdevw
	CopyScales/P w, avgw, sdevw
	
	Make/N=(nx,ny,nz)/FREE tw0; MultiThread tw0 = w[p][q][r][0]
	Make/N=(nx,ny,nz)/FREE tw1; MultiThread tw1 = w[p][q][r][1]
	
	if (sHeader.stsParam.repeat >= 3)
		Make/N=(nx,ny,nz)/FREE tw2; MultiThread tw2 = w[p][q][r][2]
	endif
	if (sHeader.stsParam.repeat >= 4)
		Make/N=(nx,ny,nz)/FREE tw3; MultiThread tw3 = w[p][q][r][3]
	endif
	
	switch (sHeader.stsParam.repeat)
		case 2:
			FastOp avgw = 0.5*tw0 + 0.5*tw1
			FastOp sdevw = (1/sqrt(2))*tw0 - (1/sqrt(2))*tw1
			MultiThread sdevw = abs(sdevw)
			break
		case 3:
			FastOp avgw = (1/3)*tw0 + (1/3)*tw1 + (1/3)*tw2
			FastOp tw0 = tw0 - avgw ;	FastOp tw1 = tw1 - avgw ;	FastOp tw2 = tw2 - avgw
			FastOp tw0 = tw0 * tw0 ;	FastOp tw1 = tw1 * tw1 ;	FastOp tw2 = tw2 * tw2
			FastOp sdevw = 0.5 * tw0 + 0.5 * tw1 + 0.5 * tw2
			MultiThread sdevw = sqrt(sdevw)
			break
		case 4:
			FastOp avgw = tw0 + tw1 + tw2 ;		FastOp avgw = 0.25*avgw + 0.25*tw3
			FastOp tw0 = tw0 - avgw ;	FastOp tw1 = tw1 - avgw ;	FastOp tw2 = tw2 - avgw ;	FastOp tw3 = tw3 - avgw
			FastOp tw0 = tw0 * tw0 ;	FastOp tw1 = tw1 * tw1 ;	FastOp tw2 = tw2 * tw2 ;	FastOp tw3 = tw3 * tw3
			FastOp sdevw = tw0 + tw1 + tw2 ;	FastOp sdevw = (1/3)*sdevw + (1/3)*tw3
			MultiThread sdevw = sqrt(sdevw)
			break
	endswitch
	
	KillWaves/Z w
	Rename avgw $sHeader.pageName
	
	Make/N=2/WAVE/FREE refw={avgw, sdevw}
	return refw
End
//---------------------------------------------------------------
//  STSデータ (type 3) を読み込んだ後に平均・標準偏差
//		repeat が5以上の場合の低速バージョン
//---------------------------------------------------------------
Static Function/WAVE LoadRHKSM2Type3DataAvgS(w, sHeader)
	Wave w
	STRUCT SM2Header &sHeader
	
	Make/N=(DimSize(w,0),DimSize(w,1),DimSize(w,2))/O $"avg"/WAVE=aw, $"sdev"/WAVE=sw
	CopyScales/P w, aw
	
	Make/N=(DimSize(w,0),DimSize(w,1),DimSize(w,2))/O $"tmp"/WAVE=tw
	
	Variable i
	for (i=0, tw=0; i<DimSize(w,3); i+=1)
		tw += w[p][q][r][i]
	endfor
	FastOp aw = (1/DimSize(w,3)) * tw
	for (i=0, tw=0; i<DimSize(w,3); i+=1)
		tw += (w[p][q][r][i] - aw[p][q][r])^2
	endfor
	sw = sqrt(tw/(DimSize(w,3)-1))
	
	KillWaves w, tw
	Rename aw $sHeader.pageName
	Rename sw $(sHeader.pageName+ks_index_sdev)
	
	Make/N=2/WAVE/FREE refw={aw, sw}
	return refw
End


//******************************************************************************
//	LoadRHKSM2V2nS
//		V から nS への変換
//******************************************************************************
Static Function LoadRHKSM2V2nS(refw, sHeader)
	Wave/WAVE refw
	STRUCT SM2Header &sHeader
	
	Variable i, numVpage = 0
	
	//	単位が"V"のウエーブの数を数える
	for (i = 0; i < numpnts(refw); i += 1)
		numVpage = stringmatch(WaveUnits(refw[i],-1), "V")
	endfor
	if (!numVpage)	//	0ならば変換の必要なし
		return 0
	endif
	
	//	コメントから変換用のパラメータを読み込む	
	Variable isFromText = LoadRHKSM2V2nSGetParamFromText(sHeader)
	
	//	コメントにパラメータが含まれていない場合には、パネルを表示する
	if (isFromText)
		Variable sens = sHeader.stsParam.sensitivity * 1e3
		printf "lock-in parameters..... "
		printf "excitation: %.3f Vrms\tsensitivity: %.0f mV\tpre-amp: %.0e\tdivider: %.5f\r", sHeader.stsParam.driveamp, sens , sHeader.stsParam.gain, sHeader.stsParam.divider
	elseif (LoadRHKSM2V2nSGetParamFromPnl(sHeader))
		return 0
	endif
	
	//	変換方法について
	//	ここで変換されるウエーブはデータがVで記録されているのが前提です. すると、w*(sens/10)/gain が
	//	dI (A) を与えます. それを dV である driveamp*divider*k_lockindivider で割ると、dI/dV (S) が得られ、
	//	最後に 1e9 をかけて、nS へと変換されます
	Variable coef = (sHeader.stsParam.sensitivity/10)/sHeader.stsParam.gain/(sHeader.stsParam.driveamp*sHeader.stsParam.divider*k_lockindivider)*1e9
	for (i = 0; i < numpnts(refw); i += 1)
		if (stringmatch(WaveUnits(refw[i],-1), "V"))
			Wave w = refw[i]
			FastOp w = (coef)*w
			SetScale d 0, 0, "nS", w
		endif
	endfor
End
//---------------------------------------------------------------
//		コメントから変換用のパラメータを読み込む
//---------------------------------------------------------------
Static Function LoadRHKSM2V2nSGetParamFromText(sHeader)
	STRUCT SM2Header &sHeader
	
	Variable ver = NumberByKey("ver", sHeader.sInfo.text)
	if (ver != 1 && ver != 2)
		return 0
	endif
	
	Variable params = 0
	
	if (!numtype(NumberByKey("mod", sHeader.sInfo.text)))
		sHeader.stsParam.driveamp = NumberByKey("mod", sHeader.sInfo.text)
		params += 1
	endif
	if (!numtype(NumberByKey("sens", sHeader.sInfo.text)))
		sHeader.stsParam.sensitivity = NumberByKey("sens", sHeader.sInfo.text) * 1e-3
		params += 1
	endif
	if (!numtype(NumberByKey("PG", sHeader.sInfo.text)))
		sHeader.stsParam.gain = NumberByKey("PG", sHeader.sInfo.text) * 1e9
		params += 1
	endif
	if (!numtype(NumberByKey("div", sHeader.sInfo.text)))
		switch (NumberByKey("div", sHeader.sInfo.text))
			case 0:
				sHeader.stsParam.divider = 1
				break
			case 1:
				sHeader.stsParam.divider = 0.0996
				break
			case 2:
				sHeader.stsParam.divider = 0.0474
				break
			case 3:
				sHeader.stsParam.divider = 0.00989
				break
			case 4:
				sHeader.stsParam.divider = 0.1
				break
			case 5:
				sHeader.stsParam.divider = 0.01
				break
		endswitch
		params += 1
	endif
	
	return params == 4
End
//---------------------------------------------------------------
//		パネルを開いてパラメータ取得
//---------------------------------------------------------------
Static Function LoadRHKSM2V2nSGetParamFromPnl(sHeader)
	STRUCT SM2Header &sHeader
	
	DoAlert 1, "Do you want to convert "+sHeader.pageName+" from V to nS?"
	if (V_flag == 2)	//	変換しない場合
		return 1
	elseif (LoadRHKSM2V2nSPnl(sHeader))	//	パネル表示
		return 1						//	キャンセルの場合
	else
		return 0
	endif
End
//---------------------------------------------------------------
//		パラメータ取得用のパネル
//---------------------------------------------------------------
Static Function LoadRHKSM2V2nSPnl(sHeader)
	STRUCT SM2Header &sHeader
	
	//	パネル表示直前にコメントを履歴欄に出力する
	printf "%s: %s\r", sHeader.pageName, sHeader.sInfo.text
	
	//	パラメータ取得
	Variable driveamp=1, sens=5, gain=3, divider=0.0996
	Prompt driveamp, "V_mod (V_rms):"
	Prompt sens, "sensitivity:", popup, "1mV;2mV;5mV;10mV;20mV;50mV;100mV;200mV;500mV"
	Prompt gain, "gain:", popup, "1e8;1e9;5e9"
	Prompt divider "divider coef. (V/V):"//, popup, "1;1/10;1/100"
	DoPrompt "V 2 nS", driveamp, sens, gain, divider
	if (V_Flag)	//	キャンセルの場合
		return 1
	endif
	
	sHeader.stsParam.driveamp = driveamp
	
	switch (sens)
		case 1: 
			sHeader.stsParam.sensitivity = 1e-3
			break
		case 2:
			sHeader.stsParam.sensitivity = 2e-3
			break
		case 3:
			sHeader.stsParam.sensitivity = 5e-3
			break
		case 4:
			sHeader.stsParam.sensitivity = 10e-3
			break
		case 5:
			sHeader.stsParam.sensitivity = 20e-3
			break
		case 6:
			sHeader.stsParam.sensitivity = 50e-3
			break
		case 7:
			sHeader.stsParam.sensitivity = 100e-3
			break
		case 8:
			sHeader.stsParam.sensitivity = 200e-3
			break
		case 9:
			sHeader.stsParam.sensitivity = 500e-3
			break
		default:
			sHeader.stsParam.sensitivity = 0
	endswitch
	
	switch (gain)
		case 1:
			sHeader.stsParam.gain = 1e8
			break
		case 2:
			sHeader.stsParam.gain = 1e9
			break
		case 3:
			sHeader.stsParam.gain = 5e9
			break
		default:
			sHeader.stsParam.gain = 0
	endswitch
	
	sHeader.stsParam.divider = divider
	
	return 0
End
