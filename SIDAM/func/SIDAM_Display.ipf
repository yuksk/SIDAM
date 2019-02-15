#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMDisplay

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Main
//******************************************************************************
Function/S SIDAMDisplay(
	Wave w,	//	A numeric wave to be displayed, or a refrence wave containing
				//	references to numeric waves.
	[
		int traces,	//	Show a 2D wave as traces instead of an image(1). Default is 0.
		int history	//	Show the command in the history(1). Default is 0.
	])
	
	STRUCT paramStruct s
	Wave/Z s.w = w
	s.traces  = ParamIsDefault(traces) ? 0 : traces
	s.history = ParamIsDefault(history) ? 0 : history
	
	if (validate(s))
		printf "%sSIDAMDisplay gave error: %s\r", PRESTR_CAUTION, s.errMsg
		return ""
	endif
	
	switch (WaveType(s.w, 1))
		case 1:	//	numeric
			return displayNumericWave(s.w, s.traces, s.history)
		case 3:	//	datafolder reference
			return displayDFRefWave(s.w, s.history)
		case 4:	//	wave reference
			return displayWaveRefWave(s.w, s.history)
	endswitch
End

Static Function validate(STRUCT paramStruct &s)

	switch (WaveType(s.w,1))
		case 0:	//	null (including non-existing wave)
		case 1:	//	numeric
		case 2:	//	text
			if (validateNonRefWave(s.w, s))
				return 1
			endif
			break
			
		case 3:	//	/DF
			//	Make sure if all references are valid
			Wave/DF dfrefw = s.w
			Make/B/U/N=(numpnts(s.w))/FREE tw = DataFolderRefStatus(dfrefw[p])==0
			if (WaveMax(tw))
				s.errMsg = "an invalid datafolder(s) is contained in the reference wave."
				return 1
			endif
			break
			
		case 4:	//	/WAVE
			//	Make sure if all references are valid
			Wave/WAVE wrefw = s.w
			Make/B/U/N=(numpnts(s.w))/FREE tw = validateNonRefWave(wrefw[p],s)
			if (WaveMax(tw))
				s.errMsg = "an invalid wave(s) is contained in the reference wave."
				return 1
			endif
			break
			
	endswitch

	if (s.traces && !(WaveType(s.w,1)==1 && WaveDims(s.w)==2))
		s.errMsg = "the trace option is valid for 2D numeric waves."
		return 1
	endif
		
	s.traces = s.traces ? 1 : 0	
	s.history = s.history ? 1 : 0
	
	return 0
End

Static Function validateNonRefWave(Wave/Z w, STRUCT paramStruct &s)
	if (!WaveExists(w))
		s.errMsg = "wave not found."
		return 1
	endif
	
	switch (WaveType(w,1))
		case 0:	//	null
		case 2:	//	text
			s.errMsg = "the wave must be a numeric wave or a reference wave."
			return 1
			
		case 1:	//	numeric
			if (WaveDims(w) > 3)
				s.errMsg = "the dimension of wave must be less than 4."
				return 1
			elseif (WaveType(w,2) == 2)
				s.errMsg = "a numeric free wave is not accepted."
				return 1
			endif
			break
	endswitch
	return 0	
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	uchar	traces
	uchar	history
EndStructure

//-------------------------------------------------------------
//	Menu functions
//-------------------------------------------------------------
Static Function/S menu(int mode, String shortCutStr)
	
	int isBrowserShown = strlen(GetBrowserSelection(-1))
	int n = SIDAMnumberOfSelectedWaves()
	
	if (!isBrowserShown || !n)
		return ""
	elseif (mode==1 && (n!=1 || WaveDims($GetBrowserSelection(0))!=2))
		return ""
	endif
	
	if (mode==0)
		return "Selected Wave" + SelectString(n>1, "", "s") + shortCutStr
	else	//	mode==1, display a 2D wave as traces
		return "Selected Wave as Traces" + shortCutStr
	endif
End

Static Function menuDo()
	Make/N=(SIDAMnumberOfSelectedWaves())/WAVE/FREE ww=$GetBrowserSelection(p)
	SIDAMDisplay(ww,history=1)
End

//-------------------------------------------------------------
//	For numeric wave
//-------------------------------------------------------------
Static Function/S displayNumericWave(Wave w, int traces, int history)
	
	if (history)
		echo(w,traces)
	endif
	
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
//	For datafolder reference wave
//-------------------------------------------------------------
Static Function/S displayDFRefWave(Wave/DF w, int history)
	
	int i, n = numpnts(w)
	for (i = 0; i < n; i++)
		DFREF df = w[i]
		if (CountObjectsDFR(df,1))
			Make/N=(CountObjectsDFR(df,1))/FREE/WAVE refw
			refw = df:$GetIndexedObjNameDFR(df, 1, p)
			return SIDAMDisplay(w, history=history)
		endif
	endfor
End

//-------------------------------------------------------------
//	For wave reference wave
//-------------------------------------------------------------
Static Function/S displayWaveRefWave(Wave/WAVE w, int history)
	
	String winNameList = ""
	int i
	
	//	Display 2D and 3D waves and remove their references from the input wave
	for (i = numpnts(w) - 1; i >= 0; i--)
		if (WaveDims(w[i]) == 1)
			continue
		endif
		winNameList += SIDAMDisplay(w[i],history=history) + ";"
		DeletePoints i, 1, w
	endfor
	if (!numpnts(w))
		return winNameList
	endif
	
	//	Display the remaining 1D waves
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
//	History
//-------------------------------------------------------------
Static Function/S echo(Wave w, int traces)
	if (WaveType(w,1) == 1)		//	numeric
		printf "%sSIDAMDisplay(%s%s)\r", PRESTR_CMD,GetWavesDataFolder(w,2),SelectString(traces,"",",traces=1")
	
	elseif (WaveType(w,1) == 4)	//	reference
		Wave/WAVE ww = w
		int i, length
		String cmdStr = PRESTR_CMD+"AppendToGraph ", addStr
		
		printf "%sDisplay", PRESTR_CMD
		
		for (i = 0; i < numpnts(ww); i++)
			addStr = GetWavesDataFolder(ww[i],4)
			if (i==0 || length+strlen(addStr)+1 >= MAXCMDLEN)	//	+1 for ","
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