#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//  KMNewTmpDf
//    作業用一時フォルダの作成
//    続けて変数等を作成するために、データフォルダは移動したまま
//    ただし、実行前のデータフォルダのパスを返す
//******************************************************************************
Function/S KMNewTmpDf(grfName,procName)
	String procName, grfName
	
	String dfSav = GetDataFolder(1)
	NewDataFolder/O/S $KM_DF
	if (strlen(procName))
		NewDataFolder/O/S $(procName)
		if (strlen(grfName))
			NewDataFolder/O/S $(grfName)
		endif
	endif
	return dfSav
End


//******************************************************************************
//	KMWaveList
//		対象データフォルダ(df)にあるウエーブのリストを出力
//		dimは次元を指定するためのフラッグ
//		bit0: 1D, bit1: 2D, bit2: 3D
//******************************************************************************
Function/S KMWaveList(DFREF dfr, int dim, [int forFFT, int nx, int ny])
	if (!DataFolderRefStatus(dfr))
		dfr = GetDataFolderDFR()
	endif
	
	forFFT = ParamIsDefault(forFFT) ? 0 : forFFT
	
	String waveListStr = ""
	int i, n
	
	for (i = 0, n = CountObjectsDFR(dfr,1); i < n; i++)
		Wave/SDFR=dfr w = $GetIndexedObjNameDFR(dfr,1,i)
		if (!((2^(WaveDims(w)-1)) & dim))	//	次元が合わなければ
			continue
		endif
		if (forFFT)
			if (mod(DimSize(w,0),2))		//  x方向のデータ点数は偶数でなければならない
				continue
			elseif (DimSize(w,0) < 4 || DimSize(w,1) < 4)	//  最低データ点数は4
				continue
			elseif (numtype(sum(w)))		//  NaN や INF を含んではならない, WaveStats を使うより速い
				continue
			endif
		endif
		if (!ParamIsDefault(nx) && DimSize(w,0) != nx)
			continue
		endif
		if (!ParamIsDefault(ny) && DimSize(w,1) != ny)
			continue
		endif
		waveListStr += NameOfWave(w)+";"
	endfor
	
	return waveListStr
End

//******************************************************************************
//	KMWaveToTraceName
//		指定ウインドウにおける、指定ウエーブのトレース名を返す
//		(trace と trace#1 の区別がつく)
//		ウインドウが存在しない、ウエーブが存在しない、指定ウインドウにトレースが存在しない
//		指定ウエーブが指定ウインドウに表示されていない、の場合には空文字列を返す
//******************************************************************************
Function/S KMWaveToTraceName(pnlName,w)
	String pnlName
	Wave w
	
	DoWindow $pnlName
	if (!V_Flag)
		return ""
	endif
	
	if (!WaveExists(w))
		return ""
	endif
	
	String trcList = TraceNameList(pnlName,";",1)
	if (!strlen(trcList))
		return ""
	endif
	
	int i
	String ref
	for (i = 0; i < ItemsInList(trcList); i++)
		ref = GetWavesDataFolder(TraceNameToWaveRef(pnlName,StringFromList(i,trcList)),2)
		if (stringmatch(ref,GetWavesDataFolder(w,2)))
			return StringFromList(i,trcList)
		endif
	endfor
End

//******************************************************************************
//	KMWaveToString
//		ウエーブの内容を文字列として返す
//******************************************************************************
Function/S KMWaveToString(w, [noquot])
	Wave/Z w
	Variable noquot
	
	String str = "{"
	int i, n
	
	if (!WaveExists(w))
		return ""
	endif
	
	if (ParamIsDefault(noquot))
		noquot = 0
	endif
	
	//	入力ウエーブが数値ウエーブの場合は、1・2次元である場合だけ処理する
	if (WaveType(w,1) == 1 && WaveDims(w) == 1)
		for (i = 0, n = numpnts(w); i < n; i++)
			str += num2str(w[i]) + ","
		endfor
		return str[0, strlen(str)-2] + "}"
	elseif (WaveType(w,1) == 1 && WaveDims(w) == 2)
		for (i = 0, n = DimSize(w,1); i < n; i++)
			Make/N=(DimSize(w,0))/FREE tw = w[p][i]
			str += KMWaveToString(tw) + ","
		endfor
		return str[0, strlen(str)-2] + "}"
	endif
	
	//	入力ウエーブがテキストウエーブの場合は、1次元である場合だけ処理する
	if (WaveType(w,1) == 2 && WaveDims(w) == 1)
		Wave/T txtw = w
		if (noquot)
			for (i = 0, n = numpnts(w); i < n; i++)
				str += txtw[i] + ","
			endfor
		else
			for (i = 0, n = numpnts(w); i < n; i++)
				str += "\"" + txtw[i] + "\","
			endfor
		endif
		return str[0, strlen(str)-2] + "}"
	endif
	
	return ""
End

//******************************************************************************
//	非等間隔のバイアス電圧に関する関数
//******************************************************************************
//	バイアス電圧を記録する
Function KMSetBias(Wave w, Wave biasw)
	if (WaveDims(w) != 3)
		return 1
	elseif (DimSize(w,2) != numpnts(biasw))
		return 1
	endif
	
	int i, n = numpnts(biasw)
	for (i = 0; i < n; i++)
		SetDimLabel 2, i, $num2str(biasw[i]), w
	endfor
	return 0
End

//	バイアス電圧を読んでウエーブとして返す
//		dim が 1 の時は1次元ウエーブのX軸用
//		dim が 2 の時は2次元ウエーブのX,Y軸用
Function/WAVE KMGetBias(Wave w, int dim)
	int nz = DimSize(w,2)
	
	Make/N=(nz)/FREE tw = str2num(GetDimLabel(w,2,p))
	
	if (dim == 1)
		return tw
	endif
	
	//	dim == 2
	Make/N=(nz+1)/FREE biasw
	biasw[1,nz-1] = (tw[p-1]+tw[p])/2
	biasw[0] = tw[0]*2 - biasw[1]
	biasw[nz] = tw[nz-1]*2 - biasw[nz-1]
	return biasw
End

//	バイアス電圧をコピーする
Function KMCopyBias(Wave srcw, Wave destw)
	int i, nz = DimSize(srcw,2)
	for (i = 0; i < nz; i++)
		SetDimLabel 2, i, $GetDimLabel(srcw, 2, i), destw
	endfor
End

//	非等間隔バイアス電圧が設定されているかどうかを返す
Function KMisUnevenlySpacedBias(Wave w)
	return strlen(GetDimlabel(w,2,0)) > 0
End


//******************************************************************************
//	KMGetIndexFromValue	:	z値からインデックスを得る、非等間隔バイアス電圧対応
//******************************************************************************
Function KMGetIndexFromValue(Wave w, Variable value)
	if (KMisUnevenlySpacedBias(w))		//	非等間隔バイアス電圧
		//	一番近い値に対応するインデックスを探す
		Make/N=(DimSize(w,2))/FREE dw = abs(str2num(GetDimLabel(w,2,p))-value), iw = p
		Sort dw, iw
		return iw[0]
	else
		return round((value-DimOffset(w,2))/DimDelta(w,2))
	endif
End

//******************************************************************************
//	インデックスからz値を得る、非等間隔バイアス電圧対応
//******************************************************************************
Function KMIndexToScale(Wave w, int index)
	if (KMisUnevenlySpacedBias(w))		//	非等間隔バイアス電圧
		return str2num(GetDimLabel(w,2,index))
	else
		return DimOffset(w,2) + DimDelta(w,2)*index
	endif
End

//******************************************************************************
//	KMEndEffect:	端処理を実現するために、拡張ウエーブを返す
//		0: bounce, w[-i] = w[i], w[n+i] = w[n-i]
//		1: wrap, w[-i] = w[n-i], w[n+i] = w[i]
//		2: zero, w[-i] = w[n+i] = 0
//		3: repeat, w[-i] = w[0], w[n+i] = w[n]
//******************************************************************************
Function/WAVE KMEndEffect(w,endeffect)
	Wave w
	Variable endeffect		//	0: bounce, 1: wrap, 2: zero, 3: repeat
	
	switch (endeffect)
		case 0:	//	bounce
			Make/N=(DimSize(w,0), DimSize(w,1), DimSize(w,2))/FREE xw, yw, xyw
			Reverse/P/DIM=0 w/D=xw				//	左右反転
			Reverse/P/DIM=1 w/D=yw, xw/D=xyw	//	上下反転・上下左右反転
			
			Duplicate/FREE xyw ew0, ew2			//	左下・左上
			Duplicate/FREE xw ew1				//	左中
			
			Concatenate/NP=0 {yw, xyw}, ew0		//	下
			Concatenate/NP=0 {w, xw}, ew1			//	中
			Concatenate/NP=0 {yw, xyw}, ew2		//	上
			Concatenate/NP=1 {ew1, ew2}, ew0		//	上中下合体
			break
		case 1:	//	wrap
			Duplicate/FREE w ew1
			Concatenate/NP=0 {w, w}, ew1			//	行
			Duplicate/FREE ew1, ew0
			Concatenate/NP=1 {ew1, ew1}, ew0		//	上中下合体
			break
		case 2:	//	zero
			Make/N=(DimSize(w,0), DimSize(w,1), DimSize(w,2))/FREE ew1, ew2
			Concatenate/NP=0 {w, ew2}, ew1		//	中
			Make/N=(DimSize(w,0)*3, DimSize(w,1), DimSize(w,2))/FREE ew0, ew3
			Concatenate/NP=1 {ew1, ew3}, ew0		//	上中下合体
			break
		case 3:	//	repeat
			Variable mx = DimSize(w,0)-1, my = DimSize(w,1)-1
			Make/N=(DimSize(w,0), DimSize(w,1), DimSize(w,2))/FREE ew0, ew1, ew2, ew3, ew4
			MultiThread ew0 = w[0][0]			//	左下
			MultiThread ew1 = w[p][0]			//	中下
			MultiThread ew2 = w[mx][0]			//	右下
			Concatenate/NP=0 {ew1, ew2}, ew0	//	下合体
			MultiThread ew1 = w[0][q]			//	左中
			MultiThread ew2 = w[mx][q]			//	右中
			Concatenate/NP=0 {w, ew2}, ew1	//	中合体
			MultiThread ew2 = w[0][my]			//	左上
			MultiThread ew3 = w[p][my]			//	中上
			MultiThread ew4 = w[mx][my]		//	右上
			Concatenate/NP=0 {ew3, ew4}, ew2	//	上合体
			Concatenate/NP=1 {ew1, ew2}, ew0	//	上中下合体
			break
	endswitch
	
	SetScale/P x DimOffset(w,0)-DimDelta(w,0)*DimSize(w,0), DimDelta(w,0), WaveUnits(w,0), ew0
	SetScale/P y DimOffset(w,1)-DimDelta(w,1)*DimSize(w,1), DimDelta(w,1), WaveUnits(w,1), ew0
	SetScale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), ew0
	
	return ew0
End

//******************************************************************************
//	dfr 以下にある V_*, S_* を削除する
//******************************************************************************
Function KMKillVariablesStrings(DFREF dfr)
	DFREF dfrSav = GetDataFolderDFR()
	String listStr
	int i, n
	
	//	データフォルダに対しては自身を再帰的に実行
	for (i = 0, n = CountObjectsDFR(dfr, 4); i < n; i++)
		KMKillVariablesStrings(dfr:$GetIndexedObjNameDFR(dfr,4,i))
	endfor
	
	SetDataFolder dfr
	
	//	Variable
	listStr = VariableList("V_*", ";", 4)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		KillVariables $StringFromList(i, listStr)
	endfor
	
	//	String
	listStr = StringList("S_*", ";")
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		KillStrings $StringFromList(i, listStr)
	endfor
	
	SetDataFolder dfrSav
End