#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMHistogram

#include "SIDAM_Display"
#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant DEFALUT_BINS = 64			//	number of bins
Static StrConstant SUFFIX = "_h"	//	suffix for the result wave

//@
//	Generate a histogram of the input wave.
//	When the input wave is 3D, the histogram is generated layer by layer.
//
//	## Parameters
//	w : wave
//		The input wave, 2D or 3D.
//	startz : variable, default `WaveMin(w)`
//		The start value of a histogram.
//	endz : variable, default `WaveMax(w)`
//		The end value of a histogram.
//	deltaz : variable
//		The width of a bin. Unless given, `endz` is used.
//	bins : int, default 64
//		The number of bins.
//	cumulative : int {0 or !0}, default 0
//		Set !0 for a cumulative histogram.
//	normalize : int {0 or !0}, default 1
//		Set !0 to normalize a histogram.
//	cmplxmode : int {0 -- 3}, default 0
//		Select a mode for a complex input wave.
//		* 0: Amplitude
//		* 1: Real
//		* 2: Imaginary
//		* 3: Phase.
//
//	## Returns
//	wave
//		Histogram wave.
//@
Function/WAVE SIDAMHistogram(Wave/Z w, [Variable startz, Variable endz,
	Variable deltaz, int bins, int cumulative, int normalize, int cmplxmode])

	STRUCT paramStruct s
	Wave/Z s.w = w
	s.bins = ParamIsDefault(bins) ? DEFALUT_BINS : bins
	s.startz = ParamIsDefault(startz) ? NaN : startz
	s.endz = ParamIsDefault(endz) ? NaN : endz
	s.deltaz = ParamIsDefault(deltaz) ? NaN : deltaz
	s.cumulative = ParamIsDefault(cumulative) ? 0 : cumulative
	s.normalize = ParamIsDefault(normalize) ? 1 : normalize
	s.cmplxmode = ParamIsDefault(cmplxmode) ? 0 : cmplxmode
	
	if (validate(s))
		print s.errMsg
		Make/FREE rtnw = {1}
		return rtnw
	endif
	
	if (WaveDims(w) == 2)
		return histogramFrom2D(s)
	elseif (WaveDims(w) == 3)
		return histogramFrom3D(s)
	endif
End

Static Function validate(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "SIDAMHistogram gave error: "
	
	if (WaveExists(s.w))
		if (WaveDims(s.w) != 2 && WaveDims(s.w) != 3)
			s.errMsg += "dimension of input wave must be 2 or 3."
			return 1
		endif
	else
		s.errMsg += "wave not found."
		return 1
	endif
	
	if (s.cmplxmode < 0 || s.cmplxmode > 3)
		s.errMsg += "invalid cmplxmode."
		return 1
	endif
		
	s.initialz = (numtype(s.startz) == 2) ? WaveMin(s.w) : s.startz
	
	//	if both of endz and deltaz are given, return an error.
	//	if neither of them is given, use the default value of endz
	if (!numtype(s.endz) && !numtype(s.deltaz))	//	both
		s.errMsg += "either endz or deltaz should be chosen."
		return 1
	elseif (!numtype(s.deltaz))	//	deltaz is given
		s.finalz = s.deltaz
		s.mode = 1
	elseif (!numtype(s.endz))		//	endz is given
		s.finalz = s.endz
		s.mode = 0
	else								//	none
		Wave minmaxw = getMinMax(s.w,"",cmplxmode=s.cmplxmode)
		s.finalz = minmaxw[1]
		s.mode = 0
	endif
	
	s.cumulative = s.cumulative ? 1 : 0
	s.normalize = s.normalize ? 1 : 0
	
	return 0
End

Static Structure paramStruct
	//	input
	Wave	w
	uint16	bins
	double	startz
	double	endz
	double	deltaz
	uchar	cumulative
	uchar	normalize
	uchar	cmplxmode
	String result
	//	output
	String	errMsg
	uchar	mode	//  0: endz, 1: deltaz
	double	initialz
	double	finalz
EndStructure

Static Function/S echoStr(STRUCT paramStruct &s)
	
	Wave minmaxw = getMinMax(s.w,"",cmplxmode=s.cmplxmode)
	
	String paramStr = GetWavesDataFolder(s.w,2)
	paramStr += SelectString(s.bins==DEFALUT_BINS,\
		",bins="+num2str(s.bins), "")
	paramStr += SelectString(s.initialz==minmaxw[0],\
		",startz="+num2str(s.initialz), "")
	if (s.mode)
		//	when deltaz is specified
		paramStr += ",deltaz="+num2str(s.finalz)
	else
		//	when endz is specified, or neither deltaz nor endz is specified.
		paramStr += SelectString(s.finalz==minmaxw[1],\
			",endz="+num2str(s.finalz), "")
	endif
	paramStr += SelectString(s.cumulative,\
		"", ",cumulative="+num2str(s.cumulative))
	paramStr += SelectString(s.normalize, ",normalize=0", "")
	paramStr += SelectString((WaveType(s.w)&0x01) && s.cmplxmode,\
		"", ",cmplxmode="+num2istr(s.cmplxmode))
		
	Sprintf paramStr, "Duplicate/O SIDAMHistogram(%s), %s%s"\
		, paramStr, GetWavesDataFolder(s.w, 1), PossiblyQuoteName(s.result)
	
	return paramStr
End

//-------------------------------------------------------------
//	Menu function
//-------------------------------------------------------------
Static Function menuDo()
	pnl(SIDAMImageNameToWaveRef(WinName(0,1)), WinName(0,1))
End


//=====================================================================================================


//******************************************************************************
//	Make a histogram from a 2D wave
//******************************************************************************
Static Function/WAVE histogramFrom2D(STRUCT paramStruct &s)
	
	if (WaveType(s.w) & 0x01)
		switch (s.cmplxmode)
		case 0:	//	magnitude
			MatrixOP/FREE tw = mag(s.w)
			break
		case 1:	//	real
			MatrixOP/FREE tw = real(s.w)
			break
		case 2:	//	imaginary
			MatrixOP/FREE tw = imag(s.w)
			break
		case 3:	//	phase
			MatrixOP/FREE tw = phase(s.w)
			break
		endswitch
	else
		Wave tw = s.w
	endif
	
	Make/N=(s.bins)/FREE hw
	if (s.mode)
		SetScale/P x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	else
		SetScale/I x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	endif
	
	if (s.cumulative)
		Histogram/B=2/CUM tw hw
	else
		Histogram/B=2 tw hw
	endif
	
	if (s.normalize)
		hw /= numpnts(s.w)
	endif
	
	return hw
End

//******************************************************************************
//	Make a histogram from a 3D wave
//	Repeat the 2D function for each layer
//******************************************************************************
Static Function/WAVE histogramFrom3D(STRUCT paramStruct &s)

	Make/N=(s.bins,DimSize(s.w,2))/FREE hw
	if (s.mode)
		SetScale/P x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	else
		SetScale/I x s.initialz, s.finalz, StringByKey("DUNITS", WaveInfo(s.w,0)), hw
	endif
	SetScale/P y DimOffset(s.w,2), DimDelta(s.w,2), WaveUnits(s.w,2), hw

	STRUCT paramStruct s1
	s1 = s

	int i
	for (i = 0; i < DimSize(s.w,2); i++)
		MatrixOP/FREE tw1 = s.w[][][i]
		Wave s1.w = tw1
		Wave tw2 = histogramFrom2D(s1)
		hw[][i] = tw2[p]
	endfor
	
	return hw
End


//=====================================================================================================


//******************************************************************************
//	Display a panel
//******************************************************************************
Static Function pnl(Wave w, String grfName)
	NewPanel/EXT=0/HOST=$grfName/W=(0,0,340,220)/N=Histogram
	String pnlName = grfName + "#Histogram"
	SetWindow $pnlName userData(grf)=grfName
	
	Wave minmaxw = getMinMax(w, GetUserData(pnlName,"","grf"))
	
	SetVariable sourceV title="source wave: ", pos={6,6}, size={325,18}, win=$pnlName
	SetVariable sourceV bodyWidth=250, noedit=1, frame=0, win=$pnlName
	SetVariable sourceV value= _STR:GetWavesDataFolder(w,2), win=$pnlName
	SetVariable resultV title="output name:", pos={6,32}, size={325,18}, win=$pnlName
	SetVariable resultV bodyWidth=250, value=_STR:NameOfWave(w)+SUFFIX, win=$pnlName
	SetVariable resultV frame=1, proc=SIDAMHistogram#pnlSetVar, win=$pnlName

	PopupMenu modeP title="mode", pos={9,70}, size={152,20}, bodyWidth=120, win=$pnlName 
	PopupMenu modeP value="start and end;start and delta", mode=1, win=$pnlName
	PopupMenu modeP proc=SIDAMHistogram#pnlPopup, win=$pnlName
	
	SetVariable z1V title="start", pos={13,104}, size={148,15}, win=$pnlName
	SetVariable z1V value=_STR:num2str(minmaxw[0]), win=$pnlName
	SetVariable z2V title="end", pos={19,130}, size={142,15}, win=$pnlName
	SetVariable z2V value=_STR:num2str(minmaxw[1]), win=$pnlName
	SetVariable binsV title="bins", pos={16,156}, size={145,15}, win=$pnlName
	SetVariable binsV value=_STR:num2str(DEFALUT_BINS), win=$pnlName

	ModifyControlList "z1V;z2V;binsV" bodyWidth=120, proc=SIDAMHistogram#pnlSetVar, win=$pnlName
	ModifyControlList "z1V;z2V;binsV" valueColor=(SIDAM_CLR_EVAL_R,SIDAM_CLR_EVAL_G,SIDAM_CLR_EVAL_B), win=$pnlName
	ModifyControlList "z1V;z2V;binsV" fColor=(SIDAM_CLR_EVAL_R,SIDAM_CLR_EVAL_G,SIDAM_CLR_EVAL_B), win=$pnlName
	CheckBox auto1C title="auto", pos={169,105}, value=1, win=$pnlName
	CheckBox auto2C title="auto", pos={169,131}, value=1, win=$pnlName
	
	CheckBox normalizeC title="normalize", pos={250,72}, value=1, win=$pnlName
	CheckBox cumulativeC title="cumulative", pos={250,98}, value=0, win=$pnlName
	
	Button doB title="Do It", pos={8,191}, size={70,20}, proc=SIDAMHistogram#pnlButton, win=$pnlName
	CheckBox displayC title="display", pos={95,193}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={165,191}, size={60,20}, bodyWidth=60, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=SIDAMHistogram#pnlPopup, win=$pnlName
	Button cancelB title="Cancel", pos={260,191}, size={70,20}, proc=SIDAMHistogram#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	String helpstr_blue = " of the histogram. You can enter a formula in a box of "\
		+ "blue letters."
	Make/T/N=(2,10)/FREE helpw
	helpw[][0] = {"resultV", "Enter the name of output wave. The output wave is "\
		+ "saved in the same datafolder where the source wave is."}
	helpw[][1] = {"modeP", "Select a mode to specify a z range of the histogram."}
	helpw[][2] = {"z1V", "Enter the first value"	+ helpstr_blue}
	helpw[][3] = {"z2V", "Enter the last value (end) or the spacing (delta)"\
		+ helpstr_blue}
	helpw[][4] = {"binsV", "Enter the number of bins" + helpstr_blue}
	helpw[][5] = {"auto1C", "Check to use the minimum z value of the source wave "\
		+ "for the first value of the histogram."}
	helpw[][6] = {"auto2C", "Check to use the maximum z value of the source wave "\
		+ "for the last value of the histogram."}
	helpw[][7] = {"displayC", "Check to display the output wave."}
	helpw[][8] = {"normalizeC", "Check to normalize the histogram."}
	helpw[][9] = {"cumulativeC", "Check to generate a cumulative histogram."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
											
	pnlDisable(pnlName)
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
	case "modeP":
		SetVariable z2V title=SelectString(s.popNum-1, "end", "delta"), win=$s.win
		CheckBox auto2C disable=s.popNum==2, win=$s.win
		break
	case "toP":
		String grfName = GetUserData(s.win,"","grf")
		STRUCT paramStruct cs
		ControlInfo/W=$s.win sourceV
		Wave cs.w = $S_Value
		Wave cvw = SIDAMGetCtrlValues(s.win,\
			"modeP;z1V;z2V;binsV;auto1C;auto2C;normalizeC;cumulativeC")
		Wave minmaxw = getMinMax(cs.w,grfName)
		//	When the mode is "start and delta" and auto2C is checked,
		//	set the mode to "start and end"
		cs.mode = (cvw[%modeP]==2 && cvw[%auto2C]) ? 1 : cvw[%modeP] - 1
		cs.initialz = cvw[%auto1C] ? minmaxw[0] : cvw[%z1V]
		cs.finalz = cvw[%auto2C] ? minmaxw[1] : cvw[%z2V]
		cs.bins = cvw[%binsV]
		cs.normalize = cvw[%normalizeC]
		cs.cumulative = cvw[%cumulativeC]
		cs.cmplxmode = NumberByKey("imCmplxMode",ImageInfo(grfName,"", 0),"=")
		ControlInfo/W=$s.win resultV
		cs.result = S_Value
		SIDAMPopupTo(s, echoStr(cs))
		break
	endswitch
End

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	
	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "resultV":
			SIDAMValidateSetVariableString(s.win,s.ctrlName,0)
			break
		case "z1V":
			if (!SIDAMValidateSetVariableString(s.win,s.ctrlName,1))
				CheckBox auto1C value=0, win=$s.win
			endif
			break
		case "z2V":
			if (!SIDAMValidateSetVariableString(s.win,s.ctrlName,1))
				CheckBox auto2C value=0, win=$s.win
			endif
			break
		case "binsV":
			SIDAMValidateSetVariableString(s.win,s.ctrlName,1)
			break
	endswitch
	pnlDisable(s.win)
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			pnlDo(s.win)
			//  *** FALLTHROUGH ***
		case "cancelB":
			KillWindow $s.win
			break
	endswitch
	
	return 0
End

Static Function pnlDisable(String pnlName)
	
	String ctrlList = "resultV;z1V;z2V;binsV"
	int i
	for (i = 0; i < ItemsInList(ctrlList); i++)
		ControlInfo/W=$pnlName $StringFromList(i, ctrlList)
		if (strsearch(S_recreation,"valueBackColor",0) >= 0)
			Button doB disable=2, win=$pnlName
			PopupMenu toP disable=2, win=$pnlName
			return 0
		endif
	endfor
	
	Button doB disable=0, win=$pnlName
	PopupMenu toP disable=0, win=$pnlName
End

Static Function pnlDo(String pnlName)
	
	String grfName = GetUserData(pnlName,"","grf")
	ControlInfo/W=$pnlName sourceV
	Wave w = $S_Value
	Wave cvw = SIDAMGetCtrlValues(pnlName,\
		"modeP;z1V;z2V;binsV;auto1C;auto2C;normalizeC;cumulativeC;displayC")
	
	Wave minmaxw = getMinMax(w,grfName)
	if (cvw[%auto1C] == 1)
		cvw[%z1V] = minmaxw[0]
	endif
	if (cvw[%auto2C] == 1)
		cvw[%modeP] = 1			//	modeP, start and end
		cvw[%z2V] = minmaxw[1]
	endif
	
	STRUCT paramStruct s
	Wave s.w = w
	s.initialz = cvw[%z1V]
	s.finalz = cvw[%z2V]
	s.bins = cvw[%binsV]
	s.normalize = cvw[%normalizeC]
	s.cumulative = cvw[%cumulativeC]
	s.cmplxmode = strlen(grfName) ? NumberByKey("imCmplxMode",ImageInfo(grfName,"", 0),"=") : 0
	ControlInfo/W=$pnlName resultV
	s.result = S_Value

	if (cvw[%modeP] == 1)	//	start and end
		Wave hw = SIDAMHistogram(w, startz=s.initialz, endz=s.finalz, bins=s.bins, \
			normalize=s.normalize,	cumulative=s.cumulative, cmplxmode=s.cmplxmode)
	else				//	start and delta
		Wave hw = SIDAMHistogram(w, startz=s.initialz, deltaz=s.finalz, bins=s.bins, \
			normalize=s.normalize,	cumulative=s.cumulative, cmplxmode=s.cmplxmode)
	endif

	printf "%s%s\r", PRESTR_CMD, echoStr(s)	
	DFREF dfr = GetWavesDataFolderDFR(w)
	Duplicate/O hw dfr:$s.result/WAVE=resw
	
	if (cvw[%displayC])
		SIDAMDisplay(dfr:$S_Value, history=1)
	endif
End

//	returns the minimum and the maximum values of the wave
Static Function/WAVE getMinMax(Wave w, String grfName, [int cmplxmode])
	Make/D/N=2/FREE rtnw

	int isComplex = WaveType(w) & 0x01
	if (isComplex)
		cmplxmode = ParamIsDefault(cmplxmode) ? NumberByKey("imCmplxMode", ImageInfo(grfName,"",0),"=") : cmplxmode
		if (strlen(grfName) || !ParamIsDefault(cmplxmode))
			switch (cmplxmode)
			case 0:	//	magnitude
				MatrixOP/FREE tw = mag(w)
				break
			case 1:	//	real
				MatrixOP/FREE tw = real(w)
				break
			case 2:	//	imaginary
				MatrixOP/FREE tw = imag(w)
				break
			case 3:
				MatrixOP/FREE tw = phase(w)
				break
			endswitch
		else
			MatrixOP/FREE tw = mag(w)
		endif
		rtnw = {WaveMin(tw), WaveMax(tw)}
	else
		rtnw = {WaveMin(w), WaveMax(w)}
	endif
	
	return rtnw
End
