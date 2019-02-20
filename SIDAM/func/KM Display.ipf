#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=KMDisplay

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	ウエーブ表示
//******************************************************************************
Function/S KMDisplay(
	[
		Wave/Z w,		//	表示対象となるウエーブ, もしくは、表示対象となるウエーブへの参照を持つウエーブ
						//	省略時はプレビューパネルを表示する
		int traces,	//	2Dウエーブをトレースとして表示する(1), しない(0), 省略時は0
		int history	//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	])
	
	STRUCT paramStruct s
	Wave/Z s.w = w
	s.default = ParamIsDefault(w)
	s.traces  = ParamIsDefault(traces) ? 0 : traces
	s.history = ParamIsDefault(history) ? 0 : history
	
	if (isValidArguments(s))
		print s.errMsg
		return s.errMsg
	elseif (s.default)
		KMPreviewPnl()
		return ""
	endif
	
	switch (WaveType(s.w, 1))
		case 1:	//	数値ウエーブ
			return displayNumericWave(s.w, s.traces, s.history)
			break
		case 3:	//	データフォルダへの参照を含むウエーブ
			return displayDFRefWave(s.w, s.history)
			break
		case 4:	//	ウエーブへの参照を含むウエーブ
			return displayWaveRefWave(s.w, s.history)
	endswitch
End

//-------------------------------------------------------------
//	パラメータチェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMDisplay gave error: "
	int i, n
	
	if (s.default)
		if (!strlen(GetBrowserSelection(-1)) || !strlen(GetBrowserSelection(0)))
			//	データブラウザが表示されていない、または表示されていても選択項目がない場合
			return 0	//	パネル表示
		endif
		//	データブラウザに選択項目がある場合
		//	選択ウエーブのうち、3次元以下のウエーブへのリファレンスを持ったウエーブを作成する
		Make/N=0/FREE/WAVE refw
		i = 0
		do
			if (WaveType($GetBrowserSelection(i),1) == 1)		//	数値ウエーブ
				if (WaveDims($GetBrowserSelection(i)) > 3)
					//	4次元以上のウエーブについては警告を表示して、エラーとしては扱わない、リファレンスウエーブにも加えない
					printf "%sthe dimension of wave must be less than 4. (%s)\r", s.errMsg, GetBrowserSelection(i)
				else
					n = numpnts(refw)
					Redimension/N=(n+1) refw
					refw[n] = $GetBrowserSelection(i)
				endif
			endif
			i += 1
		while(strlen(GetBrowserSelection(i)))
		//	データブラウザには選択項目があるが、その中に数値ウエーブが含まれていない場合
		if (!numpnts(refw))
			return 0	//	パネル表示
		else
			Wave s.w = refw
			s.default = 0
			return 0
		endif
	endif
	
	if (!WaveExists(s.w))
		s.errMsg += "wave not found."
		return 1
	endif
	
	if (s.traces && !(WaveType(s.w,1) == 1 && WaveDims(s.w) == 2))
		s.errMsg += "the trace option is valid for 2D numeric waves."
		return 1
	endif
	
	switch (WaveType(s.w,1))
		case 0:	//	null
			s.errMsg += "null wave."
			return 1
			
		case 1:	//	数値ウエーブ
			if (WaveDims(s.w) > 3)
				s.errMsg += "the dimension of wave must be less than 4."
				return 1
			elseif (WaveType(s.w,2) == 2)	//	free wave
				s.errMsg += "a numeric wave must be not a free wave but a normal global wave."
				return 1
			endif
			break
			
		case 2:	//	/T
			s.errMsg += "text wave."
			return 1
			
		case 3:	//	/DF
			//	ウエーブに含まれる全ての参照先について、有効性を確認する
			Wave/DF dfrefw = s.w
			for (i = 0, n = numpnts(dfrefw); i < n; i += 1)
				if (!DataFolderRefStatus(dfrefw[i]))
					s.errMsg += "an invalid datafolder reference is contained"
					return 1
				endif
			endfor
			break
			
		case 4:	//	/WAVE
			//	ウエーブに含まれるすべての参照先について、存在と3次元以下であることを確認する
			Wave/WAVE wrefw = s.w
			for (i = 0, n = numpnts(wrefw); i < n; i += 1)
				if (!WaveExists(wrefw[i]))
					s.errMsg += "a referece to not-existing wave is contained."
					return 1
				elseif (WaveDims(wrefw[i]) > 3)
					s.errMsg += "a referece to wave whose dimension is more than 3 is contained."
					return 1
				endif
			endfor
			break
			
	endswitch
	
	s.traces = s.traces ? 1 : 0	
	s.history = s.history ? 1 : 0
	
	return 0
End

Static Structure paramStruct
	Wave	w
	uchar	default
	String	errMsg
	uchar	traces
	uchar	history
EndStructure

//-------------------------------------------------------------
//	メニュー出力文字列
//-------------------------------------------------------------
Static Function/S menu(int mode)
	STRUCT paramStruct s
	s.default = 1 
	
	if (isValidArguments(s))
		return SelectString(mode,"(Wave","")
	
	elseif (s.default)
		//	表示可能なウエーブがデータブラウザ内で選択されている場合には、
		//	isValidArgument によって s.default=0 に書き換えられる
		//	つまり、書き換えられずに 1 のままの場合は Preview パネル表示
		return SelectString(mode,"Preview","")
	
	elseif (mode)
		//	2Dウエーブをトレース列として表示する場合
		Wave/WAVE ww = s.w
		return SelectString(numpnts(ww)==1 && WaveDims(ww[0])==2,"","Selected Wave as Traces")
	
	else
		//	表示可能なウエーブがデータブラウザで選択されている場合はここに来る
		//	s.w にはデータフォルダで選択されているウエーブへの参照が入っている
		return "Selected " + SelectString(numpnts(s.w)>1, "Wave", "Waves")
	endif
End

//-------------------------------------------------------------
//	数値ウエーブの処理
//-------------------------------------------------------------
Static Function/S displayNumericWave(Wave w, int traces, int history)
	
	if (history)
		echo(w,traces)
	endif
	
	//  実行関数へ
	switch (WaveDims(w))
		case 1:
			Display/K=1 w
			KMInfoBar(S_name)
			return S_name
		case 2:
			if (traces)
				int i
				Display/K=1 w[][0]
				for (i = 1; i < DimSize(w,1); i++)
					AppendToGraph w[][i]/TN=$(NameOfWave(w)+"#"+num2istr(i))
				endfor
				KMInfoBar(S_name)
				return S_name
			endif
			//	*** FALLTHROUGH ***
		case 3:
			return KMLayerViewerPnl(w)
	endswitch
End
//-------------------------------------------------------------
//	データフォルダ参照ウエーブの処理
//-------------------------------------------------------------
Static Function/S displayDFRefWave(Wave/DF w, int history)
	
	int i, n = numpnts(w)
	for (i = 0; i < n; i++)
		DFREF df = w[i]
		if (CountObjectsDFR(df,1))
			Make/N=(CountObjectsDFR(df,1))/FREE/WAVE refw
			refw = df:$GetIndexedObjNameDFR(df, 1, p)
			return KMDisplay(w=refw, history=history)
		endif
	endfor
End
//-------------------------------------------------------------
//	ウエーブ参照ウエーブの処理
//-------------------------------------------------------------
Static Function/S displayWaveRefWave(Wave/WAVE w, int history)
	
	String winNameList = ""
	int i
	
	//	2,3次元ウエーブだけ先に表示してしまい、参照ウエーブからそのウエーブを取り除く
	for (i = numpnts(w) - 1; i >= 0; i--)
		if (WaveDims(w[i]) == 1)
			continue
		endif
		winNameList += KMDisplay(w=w[i],history=history) + ";"
		DeletePoints i, 1, w
	endfor
	if (!numpnts(w))
		return winNameList
	endif
	
	//	残った1次元ウエーブを表示する
	Display/K=1
	String grfName = S_name
	for (i = 0; i < numpnts(w); i++)
		AppendToGraph/W=$grfName w[i]
	endfor
	
	if (history)
		echo(w,0)
	endif
	
	KMInfoBar(grfName)
	
	return winNameList + grfName
End

//-------------------------------------------------------------
//	履歴欄出力
//-------------------------------------------------------------
Static Function/S echo(Wave w, int traces)
	if (WaveType(w,1) == 1)		//	numeric
		printf "%sKMDisplay(w=%s%s)\r", PRESTR_CMD,GetWavesDataFolder(w,2),SelectString(traces,"",",traces=1")
	
	elseif (WaveType(w,1) == 4)	//	reference
		Wave/WAVE ww = w
		int i, length
		String cmdStr = PRESTR_CMD+"AppendToGraph ", addStr
		
		printf "%sDisplay", PRESTR_CMD
		
		for (i = 0; i < numpnts(ww); i++)
			addStr = GetWavesDataFolder(ww[i],4)
			if (i==0 || length+strlen(addStr)+1>=MAXCMDLEN)	//	+1 はコンマの分
				printf "\r%s%s", cmdStr, addStr
				length = strlen(cmdStr)+strlen(addStr)
			else
				printf ",%s", addStr
				length += strlen(addStr)+1
			endif
		endfor
		printf "\r"
	endif
End