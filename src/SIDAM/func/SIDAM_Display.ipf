#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMDisplay

#include "KM LayerViewer"
#include "SIDAM_InfoBar"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

///	@param w
///		A numeric wave to be displayed, or a refrence wave containing
///		references to numeric waves.
///	@param traces [optional, default = 0]
///		0, 1, or 2.
///		Set 1 to show a 2D waves as traces. 1st dimension is x, and number of
///		traces is DimSize(w,1).
///		Set 2 to append a 2D wave (2,n) as a trace, as designated by the dimension
///		labels, that is,
///		AppendToGraph w[%y][] vs w[%x][], or AppendToGraph w[%q][] vs w[%p][].
///		When %p and %q are used, ModifyGraph offset and muloffset are used as well.
///	@param history [optional, default = 0]
///		0 or !0. Set !0 to print this command in the history.
///	@return
///		Name of window
Function/S SIDAMDisplay(Wave w, [int traces, int history])

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

	if (s.traces < 0 || s.traces > 2)
		s.errMsg = "traces is 0, 1, or 2."
		return 1
	endif

	if (s.traces && !(WaveType(s.w,1)==1 && WaveDims(s.w)==2))
		s.errMsg = "the traces option is valid for 2D numeric waves."
		return 1
	endif

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
			elseif (s.traces==2 && !canBeDisplayedAsXYTrace(w))
				s.errMsg = "the wave can not be displayed as xy-trace."
				return 1
			endif
			break
	endswitch
	return 0
End

Static Function canBeDisplayedAsXYTrace(Wave/Z w)
	if (WaveDims(w) != 2 || !strlen(WinName(0,1)))
		return 0
	endif

	int hasP = FindDimLabel(w,0,"p")!=-2, hasQ = FindDimLabel(w,0,"q")!=-2
	int hasX = FindDimLabel(w,0,"x")!=-2, hasY = FindDimLabel(w,0,"y")!=-2
	if (hasP && hasQ)
		return 1
	elseif (hasX && hasY)
		return 2
	else
		return 0
	endif
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
	elseif (mode==2 && !canBeDisplayedAsXYTrace($GetBrowserSelection(0)))
		return ""
	endif

	switch (mode)
		case 0:
			return "Display Selected Wave" + SelectString(n>1, "", "s") + shortCutStr
		case 1:	//	display a 2D wave as traces
			return "Display Selected Wave as 1d-traces" + shortCutStr
		case 2:
			return "Append Selected Wave as xy-trace" + shortCutStr
	endswitch
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

	if (WaveDims(w)==1)
		Display/K=1 w
		SIDAMInfoBar(S_name)
		return S_name

	elseif (WaveDims(w)==2 && traces==1)
		return displayNumericWaveTrace(w)

	elseif (canBeDisplayedAsXYTrace(w) && traces==2)
		return displayNumericWaveTraceXY(w)

	else //	2D (trace=0) or 3D
		return KMLayerViewerPnl(w)

	endif
End

Static Function/S displayNumericWaveTrace(Wave w)
	int i
	Display/K=1 w[][0]
	for (i = 1; i < DimSize(w,1); i++)
		AppendToGraph w[][i]/TN=$(NameOfWave(w)+"#"+num2istr(i))
	endfor
	SIDAMInfoBar(S_name)
	return S_name
End

Static Function/S displayNumericWaveTraceXY(Wave w)
	String grfName = WinName(0,1)
	int mode = canBeDisplayedAsXYTrace(w)
	if (mode == 1)
		AppendToGraph/W=$grfName w[%q][] vs w[%p][]
		Wave/Z iw = SIDAMImageWaveRef(grfName)
		if (WaveExists(iw))
			ModifyGraph/W=$grfName offset($NameOfWave(w))={DimOffset(iw,0),DimOffset(iw,1)}
			ModifyGraph/W=$grfName muloffset($NameOfWave(w))={DimDelta(iw,0),DimDelta(iw,1)}
		endif
	elseif (mode == 2)
		AppendToGraph/W=$grfName w[%y][] vs w[%x][]
	endif

	int hasmarker = FindDimLabel(w,0,"marker")!=-2
	if (hasmarker)
		ModifyGraph/W=$grfName mode($NameOfWave(w))=3,zmrkNum($NameOfWave(w))={w[%marker][*]}
	endif

	return grfName
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

	SIDAMInfoBar(grfName)

	return winNameList + grfName
End

//-------------------------------------------------------------
//	History
//-------------------------------------------------------------
Static Function/S echo(Wave w, int traces)
	if (WaveType(w,1) == 1)		//	numeric
		if (traces)
			printf "%sSIDAMDisplay(%s,traces=%d)\r", PRESTR_CMD,GetWavesDataFolder(w,2),traces
		else
			printf "%sSIDAMDisplay(%s)\r", PRESTR_CMD,GetWavesDataFolder(w,2)
		endif

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
