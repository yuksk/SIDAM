#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMDisplay

#include "SIDAM_Color"
#include "SIDAM_InfoBar"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Wave"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif


//@
//	Show a trace of 1D wave, an image of 2D wave, and a layer of 3D wave.
//
//	## Parameters
//	w : wave
//		A numeric wave, or a refrence wave containing references to numeric waves.
//	traces : int {0, 1, or 2}, default 0
//		* 0: Normal
//		* 1: Show a 2D waves as traces.
//			1st dimension is `x`, and the number of traces is `DimSize(w,1)`.
//		* 2: Append a 2D wave (2,n) as a trace to a graph.
//			The dimension labels (`%x` and `%y`, or `%p` and `%q`) must
//			be appropriately given. Then this works as
//			`AppendToGraph w[%y][] vs w[%x][]`, or
//			`AppendToGraph w[%q][] vs w[%p][]`.
//	history : int {0 or !0}, default 0
//		Set !0 to print this command in the history.
//
//	## Returns
//	str
//		The name of window.
//@
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
			return displayNumericWave(s)
		case 4:	//	wave reference
			return displayWaveRefWave(s)
	endswitch
End

Static Function validate(STRUCT paramStruct &s)

	if (WaveType(s.w, 1) == 4)	//	wave reference
		//	Make sure if all references are valid
		Wave/WAVE wrefw = s.w
		Make/B/U/N=(numpnts(s.w))/FREE tw = validateWave(wrefw[p],s)
		if (WaveMax(tw))
			s.errMsg = "an invalid wave(s) is contained in the reference wave."
			return 1
		endif
	elseif (validateWave(s.w, s))
		return 1
	endif

	if (s.traces < 0 || s.traces > 2)
		s.errMsg = "traces is 0, 1, or 2."
		return 1
	endif

	s.history = s.history ? 1 : 0

	return 0
End

Static Function validateWave(Wave/Z w, STRUCT paramStruct &s)
	if (!WaveExists(w))
		s.errMsg = "wave not found."
		return 1
	elseif (WaveType(w,1) != 1)	//	null, text, data folder
		s.errMsg = "the wave must be a numeric wave or a reference wave."
		return 1	
	endif

	//	the following for numeric
	if (WaveDims(w) > 3)
		s.errMsg = "the dimension of wave must be less than 4."
		return 1
	elseif (WaveType(w,2) == 2)
		s.errMsg = "a numeric free wave is not accepted."
		return 1
	elseif (s.traces==2 && !xyTraceMode(w))
		s.errMsg = "the wave can not be displayed as xy-trace."
		return 1
	endif
	return 0
End

Static Function isXYTraceModeSame(Wave/WAVE ww)
	if (numpnts(ww) == 0)
		return 0
	endif
	
	int mode = xyTraceMode(ww[0])
	if (numpnts(ww) == 1)
		return mode
	endif
	
	Make/B/U/N=(numpnts(ww))/FREE mw = xyTraceMode(ww[p]) - mode
	return sum(mw) ? 0 : mode
End

Static Function xyTraceMode(Wave w)
	if (WaveDims(w) != 2)
		return 0
	endif
	
	int hasP = FindDimLabel(w,0,"p")!=-2, hasQ = FindDimLabel(w,0,"q")!=-2
	int hasX = FindDimLabel(w,0,"x")!=-2, hasY = FindDimLabel(w,0,"y")!=-2
	int hasXcenter = FindDimLabel(w,0,"xcenter")!=-2
	int hasYcenter = FindDimLabel(w,0,"ycenter")!=-2
	if (hasP && hasQ)
		return 1
	elseif (hasX && hasY)
		return 2
	elseif (hasXcenter && hasYcenter)
		return 3
	else
		return 0
	endif	
End

Static Function isAll2D(Wave/WAVE ww)
	Make/B/U/N=(numpnts(ww))/FREE tw = WaveDims(ww[p]) - 2
	return !sum(tw)
End

Static Structure paramStruct
	Wave w
	String errMsg
	uchar traces
	uchar history
EndStructure

//-------------------------------------------------------------
//	Menu functions
//-------------------------------------------------------------
Static Function/S mainMenuItem(int mode, String shortCutStr)
	int isBrowserShown = strlen(GetBrowserSelection(-1))
	Wave/WAVE selectedSaves = SIDAMSelectedWaves()

	String prefix = ""
	if (!isBrowserShown || !numpnts(selectedSaves))
		prefix = "("
	elseif (mode==1 && !isAll2D(selectedSaves))
		prefix = "("
	elseif (mode==2 && !isXYTraceModeSame(selectedSaves))
		prefix = "("
	endif

	int isPlural = numpnts(selectedSaves) > 1
	String waves = "Selected Wave" + SelectString(isPlural, "", "s")	
	String items = ""
	items += waves + ";"
	items += waves + " as 1d-traces;"
	items += waves + " as " + SelectString(isPlural, "a xy-trace;", "xy-traces;")

	return prefix + StringFromList(mode,items) + shortCutStr
End

Static Function mainMenuDo(int traces)
	SIDAMDisplay(SIDAMSelectedWaves(),traces=traces,history=1)
End

//-------------------------------------------------------------
//	For numeric wave
//-------------------------------------------------------------
Static Function/S displayNumericWave(STRUCT paramStruct &s)
	if (s.history)
		echo(s.w,s.traces)
	endif

	if (WaveDims(s.w)==1)
		Display/K=1 s.w
		SIDAMInfoBar(S_name)
		return S_name

	elseif (WaveDims(s.w)==2 && s.traces==1)
		return displayNumericWaveTrace(s.w)

	elseif (xyTraceMode(s.w) && s.traces==2)
		return displayNumericWaveTraceXY(s.w)

	else //	2D (trace=0) or 3D
		return displayNumericWaveLayer(s.w)

	endif
End

Static Function/S displayNumericWaveLayer(Wave w)
	Display/K=1/HIDE=1 as NameOfWave(w)
	String pnlName = S_name
	AppendImage/W=$pnlName/G=1 w
	ModifyImage/W=$pnlName $PossiblyQuoteName(NameOfWave(w)) ctabAutoscale=3
	ModifyGraph/W=$pnlName standoff=0,tick=3,noLabel=2,axThick=SIDAM_WINDOW_AXTHICK,mirror=2,margin=1
	String cmdStr
	sprintf cmdStr, "ModifyGraph/W=%s width=%s, height=%s"\
		, PossiblyQuoteName(pnlName), SIDAM_WINDOW_WIDTH, SIDAM_WINDOW_HEIGHT
	Execute/Q cmdStr
	DoUpdate/W=$pnlName
	
	SIDAMColor(grfName=pnlName, imgList=PossiblyQuoteName(NameOfWave(w)), \
		ctable=SIDAM_WINDOW_CTAB_TABLE, rev=SIDAM_WINDOW_CTAB_REVERSE, \
		log=SIDAM_WINDOW_CTAB_LOG)

	SIDAMInfoBar(pnlName)
	SetWindow $pnlName hide=0
	
	return pnlName
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
	if (!strlen(grfName))
		Display
		grfName = S_name
	endif
	
	int mode = xyTraceMode(w)
	if (mode == 1)
		AppendToGraph/W=$grfName w[%q][] vs w[%p][]
		Wave/Z iw = SIDAMImageNameToWaveRef(grfName)
		if (WaveExists(iw))
			ModifyGraph/W=$grfName offset($NameOfWave(w))={DimOffset(iw,0),DimOffset(iw,1)}
			ModifyGraph/W=$grfName muloffset($NameOfWave(w))={DimDelta(iw,0),DimDelta(iw,1)}
		endif
	elseif (mode == 2)
		AppendToGraph/W=$grfName w[%y][] vs w[%x][]
	elseif (mode == 3)
		AppendToGraph/W=$grfName w[%ycenter][] vs w[%xcenter][]
	endif

	int hasmarker = FindDimLabel(w,0,"marker")!=-2
	if (hasmarker)
		ModifyGraph/W=$grfName mode($NameOfWave(w))=3,zmrkNum($NameOfWave(w))={w[%marker][*]}
	endif

	return grfName
End

//-------------------------------------------------------------
//	For wave reference wave
//-------------------------------------------------------------
Static Function/S displayWaveRefWave(STRUCT paramStruct &s)
	Wave/WAVE ww = s.w
	
	String winNameList = ""
	int i

	//	Display 2D and 3D waves and remove their references from the input wave
	for (i = numpnts(ww) - 1; i >= 0; i--)
		if (WaveDims(ww[i]) == 1)
			continue
		endif
		winNameList += SIDAMDisplay(ww[i],traces=s.traces,history=s.history) + ";"
		DeletePoints i, 1, ww
	endfor
	if (!numpnts(ww))
		return winNameList
	endif

	//	Display the remaining 1D waves
	Display/K=1
	String grfName = S_name
	for (i = 0; i < numpnts(ww); i++)
		AppendToGraph/W=$grfName ww[i]
	endfor

	if (s.history)
		echo(ww,0)
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
