#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMWorkfunction

#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant SUFFIX_AMP = "_a"
Static StrConstant SUFFIX_OFFSET = "_off"
Static StrConstant SUFFIX_WF = "_wf"
Static StrConstant SUFFIX_CHISQ = "_chisq"
Static StrConstant SUFFIX_ERROR = "_err"
Static StrConstant SUFFIX_QUIT = "_quit"

Static Constant HBAR = 1.054571817e-34				//	hbar, J s
Static Constant MASS =  9.109383701500001e-31		//	electron mass, kg
Static Constant CHARGE = 1.602176634e-19			//	elementary charge, C

//@
//	Calculate the work function.
//
//	## Parameters
//	w : wave
//		The input wave, 1D or 3D.
//	startp : int, default 0
//		Range of fitting, start index.
//	endp : int, default `numpnts(w)-1` for 1D, `DimSize(w,2)-1` for 3D
//		Range of fitting, end index.
//	offset : variable
//		The offset of current. By default, this is a fitting parameter.
//	basename : string
//		The basename of output waves. This is used when the input wave is 3D.
//		If this is specified, output waves are saved in the data folder
//		where the input wave is.
//
//	## Returns
//	wave
//		For 1D input wave, a numeric wave is returned.
//		For 3D input wave, a wave reference wave is returned.
//		In both cases, the result can be referred as follows.
//		* work function : `wave[%workfunction]`
//		* current amplitude : `wave[%amplitude]`
//		* current offset : `wave[%offset]`
//		* chi-squared : `wave[%chisq]`
//@
Function/WAVE SIDAMWorkfunction(Wave/Z w, [int startp, int endp,
	Variable offset, String basename])

	STRUCT paramStruct s
	Wave/Z s.w = w
	s.startp = ParamIsDefault(startp) ? 0 : startp
	s.endp = ParamIsDefault(endp) ? DimSize(w,WaveDims(w)-1)-1 : endp
	s.offset = ParamIsDefault(offset) ? inf : offset

	int error = validate(s)
	if (error)
		print PRESTR_CAUTION + "SIDAMWorkfunction gave error: " + errormsg(error, s.w)
		return $""
	endif

	if (WaveDims(w) == 1)
		return wf1D(w, s.startp, s.endp, s.offset)
	endif
	
	Wave/WAVE refw = wf3D(w, s.startp, s.endp, s.offset)
	
	if (!ParamIsDefault(basename) && strlen(basename))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder GetWavesDataFolderDFR(w)
		saveResults(refw, "amplitude", basename+SUFFIX_AMP)
		saveResults(refw, "offset", basename+SUFFIX_OFFSET)
		saveResults(refw, "workfunction", basename+SUFFIX_WF)
		saveResults(refw, "chisq", basename+SUFFIX_CHISQ)
		saveResults(refw, "fiterror", basename+SUFFIX_ERROR)
		saveResults(refw, "fitquitreason", basename+SUFFIX_QUIT)
		SetDataFolder dfrSav
	endif
	
	return refw
End

Static Function validate(STRUCT paramStruct &s)

	if (!WaveExists(s.w))
		return 1
	elseif (WaveDims(s.w) != 1 && WaveDims(s.w) != 3)
		return 2
	elseif ((WaveType(s.w,1) != 1) || (WaveType(s.w) & 0x01))
		return 3
	elseif (s.startp < 0 || s.startp > DimSize(s.w, WaveDims(s.w)-1) - 1)
		return 4
	elseif (s.endp < 0 || s.endp > DimSize(s.w, WaveDims(s.w)-1)-1)
		return 5
	elseif (abs(s.startp - s.endp) < 2)
		return 6
	elseif (WhichListItem(WaveUnits(s.w,WaveDims(s.w)-1)"m;nm;\u00c5") == -1)
		return 7
	endif

	return 0
End

Static Function/S errormsg(int num, Wave w)
	Make/T/FREE msgw = {\
		"The input wave is not found.",\
		"The dimension of the input wave must be 1 or 3.",\
		"The input wave must be real.",\
		"The startp must be an integer between 0 and "+num2str(DimSize(w, WaveDims(w)-1)-1),\
		"The endp must be an integer between 0 and "+num2str(DimSize(w, WaveDims(w)-1)-1),\
		"You must have at least as many data point as fit parameters.",\
		"The unit in the " + SelectString(WaveDims(w)-1,"x","z") + " direction "\
			+ "must be either m, nm, or \u00c5 (\\u00c5)"\
	}
	return msgw[num-1]
End

Static Structure paramStruct
	Wave	w
	uint16	startp
	uint16	endp
	Variable	offset
EndStructure

//	return the maximum length among the suffix strings
Static Function MaxSuffixLength()
	Make/T/FREE tw = {SUFFIX_AMP, SUFFIX_OFFSET, SUFFIX_WF, SUFFIX_CHISQ,\
		SUFFIX_ERROR, SUFFIX_QUIT}
	Make/N=(numpnts(tw))/FREE lw = strlen(tw[p])
	return WaveMax(lw)
End

Static Function/S echoStr(Wave w, int startp, int endp, Variable offset,
	String basename)
	String paramStr = GetWavesDataFolder(w,2)
	paramStr += SelectString(startp,"",",startp="+num2str(startp))
	paramStr += SelectString(endp==DimSize(w,WaveDims(w)-1)-1,",endp="+num2str(endp),"")
	paramStr += SelectString(numtype(offset)==1,",offset="+num2str(offset),"")
	paramStr += SelectString(strlen(basename),"",",basename=\""+basename+"\"")
	Sprintf paramStr, "SIDAMWorkfunction(%s)", paramStr
	return paramStr
End

Static Function saveResults(Wave/WAVE refw, String key, String name)
	Duplicate/O refw[%$key] $name
	refw[%$key] = $name
End

Static Function menuDo()
	pnl()
End


//-------------------------------------------------------------
//	Calculation
//-------------------------------------------------------------
//	for 1D
Static Function/WAVE wf1D(Wave w, int startp, int endp, Variable offset)

	Variable V_fitOptions=4, V_FitError=0, V_FitQuitReason=0

	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	if (numtype(offset) == 1)		//	variable offset
		CurveFit/NTHR=0/Q/K={0}/W=0 exp_XOffset w[startp,endp]
	else								//	fixed offset
		K0 = offset
		CurveFit/NTHR=0/Q/K={0}/W=0/H="100" exp_XOffset w[startp,endp]
	endif
	Wave coefw = $"W_coef"
	SetDataFolder dfrSav
	
	if (V_FitError)
		print PRESTR_CAUTION + "SIDAMWorkfunction gave error: fitting error ("+num2str(V_FitQuitReason)+")"
		return $""
	endif

	Make/N=4/FREE resw
	SetDimLabel 0, 0, workfunction, resw
	SetDimLabel 0, 1, amplitude, resw
	SetDimLabel 0, 2, chisq, resw
	SetDimLabel 0, 3, offset, resw
	resw[%workfunction] = convCoef(w)/coefw[2]^2
	resw[%amplitude] = coefw[1]
	resw[%offset] = coefw[0]
	resw[%chisq] = V_chisq
	
	printf "wave:\t%s\r", NameOfWave(w)
	printf "fitting function: I = A*exp(-z/z0)+I0\r"
	printf "\tz0:\t%e [%s]\r", coefw[2], WaveUnits(w,0)
	printf "\tA:\t%e [%s]\r", resw[%amplitude], StringByKey("DUNITS", WaveInfo(w,0))
	printf "\tI0:\t%e [%s]\r", resw[%offset], StringByKey("DUNITS", WaveInfo(w,0))
	printf "\tchisq:\t%e\r", resw[%chisq]
	printf "work function: %f [eV]\r", resw[%workfunction]

	return resw
End

//	for 3D
Static Function/WAVE wf3D(Wave w, int startr, int endr, Variable offset)

	//	return wave
	Make/N=6/FREE/WAVE rtnw
	SetDimLabel 0, 0, workfunction, rtnw
	SetDimLabel 0, 1, amplitude, rtnw
	SetDimLabel 0, 2, chisq, rtnw
	SetDimLabel 0, 3, offset, rtnw
	SetDimLabel 0, 4, fiterror, rtnw
	SetDimLabel 0, 5, fitquitreason, rtnw

	int nx = DimSize(w,0), ny = DimSize(w,1)
	
	//	fitting
	Make/N=(nx,ny)/FREE/WAVE ww
	MultiThread ww = fit3D(w, p, q, startr, endr, offset)
	
	//	result waves
	Make/N=(nx,ny)/FREE aw, wfw, chisqw, offsetw, errw, qw
	SetScale/P x DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), wfw, aw, chisqw, offsetw, errw, qw
	SetScale/P y DimOffset(w,1), DimDelta(w,1), WaveUnits(w,1), wfw, aw, chisqw, offsetw, errw, qw
	SetScale d 0, 0, "eV", wfw
	SetScale d 0, 0, StringByKey("DUNITS", WaveInfo(w,0)), aw, offsetw

	Variable coef = convCoef(w)
	MultiThread offsetw = worker(ww, p, q, 0)
	MultiThread aw = worker(ww, p, q, 1)
	MultiThread wfw =  coef/(worker(ww, p, q, 2))^2
	MultiThread chisqw = worker(ww, p, q, 3)
	MultiThread errw = worker(ww, p, q, 4)
	MultiThread qw = worker(ww, p, q, 5)
	rtnw[%offset] = offsetw
	rtnw[%amplitude] = aw
	rtnw[%workfunction] = wfw
	rtnw[%chisq] = chisqw
	rtnw[%fiterror] = errw
	rtnw[%fitquitreason] = qw

	return rtnw
End

ThreadSafe Static Function/WAVE fit3D(Wave srcw, int pp, int qq, 
	int startr, int endr, Variable offset)

	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	Make/N=6 resw
	Make/N=(DimSize(srcw,2)) tw = srcw[pp][qq][p]
	SetScale/P x DimOffset(srcw, 2), DimDelta(srcw, 2), "", tw

 	Variable V_fitOptions=4, V_FitError = 0, V_FitQuitReason = 0
	if (numtype(offset) == 1)	//	variable offset
		CurveFit/N=1/NTHR=0/Q/W=0 exp_XOffset tw[startr,endr]
		Wave coefw = $"W_coef"
	else							//	fixed offset
		Make/N=3 $"W_coef"/WAVE=coefw
		coefw[0] = offset
		CurveFit/N=1/NTHR=0/Q/W=0/H="100" exp_XOffset tw[startr,endr]
	endif
	resw[,2] = coefw[p]	//	offset, amplitude, tau
	resw[3] = V_chisq
	resw[4] = V_FitError
	resw[5] = V_FitQuitReason

	SetDataFolder dfrSav

	return resw
End

ThreadSafe Static Function worker(Wave/WAVE ww, int pp, int qq, int index)
	Wave tww = ww[pp][qq]
	return tww[index]
End

Static Function convCoef(Wave w)
	Variable scale
	strswitch (WaveUnits(w, WaveDims(w)-1))
		case "m":
			scale = 1
			break
		case "nm":
			scale = 1e9
			break
		case "\u00c5":	//	angstrom
			scale = 1e10
			break
	endswitch
	return (HBAR * scale)^2 / (8 * MASS * CHARGE)
End

//-------------------------------------------------------------
//	Panel
//-------------------------------------------------------------
Static Constant PNLWIDTH = 315
Static Constant PNLHEIGHT = 175
Static Function pnl()
	String grfName = WinName(0,1)

	Wave/Z w = SIDAMImageNameToWaveRef(grfName)	//	for a 3D wave
	if (!WaveExists(w))		//	for a 1D wave
		Wave w = TraceNameToWaveRef(grfName,StringFromList(0,TraceNameList(grfName,";",1)))
	endif

	NewPanel/EXT=0/HOST=$grfName/W=(0,0,PNLWIDTH,PNLHEIGHT)/N=WorkFunction
	String pnlName = StringFromList(0, grfName, "#") + "#WorkFunction"

	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	int dim = WaveDims(w)

	SetVariable sourceV title="source wave: ", pos={6,6}, size={300,18}, win=$pnlName
	SetVariable sourceV bodyWidth=225, noedit=1, frame=0, win=$pnlName
	SetVariable sourceV value= _STR:GetWavesDataFolder(w,2), win=$pnlName
	SetVariable basenameV title="basename:", pos={18,32}, win=$pnlName
	SetVariable basenameV size={285,16}, frame=1, bodyWidth=225, win=$pnlName
	SetVariable basenameV proc=SIDAMWorkfunction#PnlSetVar, win=$pnlName
	if (dim == 1)
		SetVariable basenameV disable=2, value=_STR:"", win=$pnlName
	else
		SetVariable basenameV value=_STR:NameOfWave(w), win=$pnlName
	endif

	GroupBox rangeG title="fitting range", pos={9,60}, size={155,75}, win=$pnlName
	SetVariable startpV title="start:", pos={18,84}, size={85,15}, win=$pnlName
	SetVariable startpV value=_NUM:0, limits={0,DimSize(w,dim-1)-4,1}, disable=2, win=$pnlName
	SetVariable startpV userData(max)=num2str(DimSize(w,dim-1)-4), win=$pnlName
	SetVariable endpV title="end:", pos={21,109}, size={82,18}, win=$pnlName
	SetVariable endpV value=_NUM:DimSize(w,dim-1)-1, limits={3,DimSize(w,dim-1)-1,1}, disable=2, win=$pnlName
	SetVariable endpV userData(max)=num2str(DimSize(w,dim-1)-1), win=$pnlName
	CheckBox startC title="auto", pos={113,85}, value=1, win=$pnlName
	CheckBox endC title="auto", pos={113,110}, value=1, win=$pnlName

	GroupBox offsetG title="current offset", pos={172,60}, size={135,75}, win=$pnlName
	CheckBox fitC title="fit", pos={182,85}, mode=1, value=1, win=$pnlName
	CheckBox fixC title="fixed:", pos={182,110}, mode=1, value=0, win=$pnlName
	SetVariable offsetV title="", pos={240,109}, size={55,18}, win=$pnlName
	SetVariable offsetV limits={-10,10,0.001}, value=_NUM:0, win=$pnlName

	Button doB title="Do It", pos={8,145}, win=$pnlName
	PopupMenu toP title="To", pos={110,146}, bodyWidth=60, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, proc=SIDAMWorkfunction#pnlPopup, win=$pnlName
	Button cancelB title="Cancel", pos={236,145}, win=$pnlName

	ModifyControlList "startpV;endpV;offsetV" bodyWidth=55, proc=SIDAMWorkfunction#pnlSetVar, win=$pnlName
	ModifyControlList "startC;endC;fitC;fixC" proc=SIDAMWorkfunction#pnlCheckBox, win=$pnlName
	ModifyControlList "doB;cancelB" size={70,20}, proc=SIDAMWorkfunction#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	Make/T/N=(2,8)/FREE helpw
	helpw[][0] = {"basenameV", "Enter the basename of output waves. The output "\
		+ "waves are saved in the same datafolder where the source wave is."}
	helpw[][1] = {"startpV", "Enter the first index of the range for fitting."}
	helpw[][2] = {"endpV", "Enter the last index of the range for fitting."}
	helpw[][3] = {"startC", "Check to use the first index of the input wave as "\
		+ "the first index of the range for fitting."}
	helpw[][4] = {"endC", "Check to use the last index of the input wave as "\
		+ "the last index of the range for fitting."}
	helpw[][5] = {"fitC", "Check to fit the current offset."}
	helpw[][6] = {"fixC", "Check to use a fixed value for the current offset."}
	helpw[][7] = {"offsetV", "Enter a value for the fixed current offset."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	pnlValidateWave(pnlName)
	
	SetActiveSubwindow $pnlName
End

Static Function pnlValidateWave(String pnlName)
	STRUCT paramStruct s
	ControlInfo/W=$pnlName sourceV
	Wave s.w = $S_Value
	Wave cvw = SIDAMGetCtrlValues(pnlName, "startpV;endpV;fitC;offsetV")
	s.startp = cvw[%startpV]
	s.endp = cvw[%endpV]
	s.offset = cvw[%fitC] ? inf : cvw[%offsetV]
	
	int error = validate(s)
	if (!error)
		return 0
	endif
	String msg = errormsg(error, s.w)
	SetVariable basenameV title="error: ", noedit=1, frame=0, win=$pnlName
	SetVariable basenameV fColor=(65535,0,0),valueColor=(65535,0,0), win=$pnlName
	SetVariable basenameV value=_STR:msg, help={msg}, win=$pnlName
	String ctrlList = "startpV;endpV;offsetV;startC;endC;fitC;fixC;doB;toP;rangeG;offsetG"
	ModifyControlList ctrlList, disable=2, win=$pnlName
End

//--------------------------------------------------
//	Controls
//--------------------------------------------------
//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode == 2)
		Wave/T ctw = SIDAMGetCtrlTexts(s.win, "sourceV;basenameV")
		Wave cvw = SIDAMGetCtrlValues(s.win, "startpV;endpV;fitC;offsetV")
		Variable offset = cvw[%fitC] ? inf : cvw[%offsetV]
		String paramStr = echoStr($ctw[%sourceV], 	cvw[%startpV], cvw[%endpV], \
			offset, ctw[%basenameV])
		SIDAMPopupTo(s, paramStr)
	endif
End

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif

	strswitch (s.ctrlName)
		case "basenameV":
			int disable = SIDAMValidateSetVariableString(s.win,s.ctrlName,0,\
				maxlength=MAX_OBJ_NAME-MaxSuffixLength())*2
			Button doB disable=disable, win=$s.win
			PopupMenu toP disable=disable, win=$s.win
			break

		case "startpV":
			SetVariable startpV value=_NUM:round(s.dval), win=$s.win
			SetVariable endpV limits={round(s.dval)+3,getMax(s.win,"endpV"),1}, win=$s.win
			break

		case "endpV":
			SetVariable startpV limits={0,round(s.dval)-3,1}, win=$s.win
			SetVariable endpV value=_NUM:round(s.dval), win=$s.win
			break

		case "offsetV":
			CheckBox fitC value=0, win=$s.win
			CheckBox fixC value=1, win=$s.win
			break
	endswitch
End

//	checkbox
Static Function pnlCheckBox(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "startC":
			SetVariable startpV disable=s.checked*2, win=$s.win
			if (s.checked)
				SetVariable startpV value=_NUM:0, win=$s.win
				SetVariable endpV limits={3,getMax(s.win,"endpV"),1}, win=$s.win
			endif
			break

		case "endC":
			SetVariable endpV disable=s.checked*2, win=$s.win
			if (s.checked)
				SetVariable startpV limits={0,getMax(s.win,"startpV"),1}, win=$s.win
				SetVariable endpV value=_NUM:getMax(s.win,"endpV"), win=$s.win
			endif
			break

		case "fitC":
			CheckBox fixC value=0, win=$s.win
			break

		case "fixC":
			CheckBox fitC value=0, win=$s.win
			break

	endswitch
End

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif

	strswitch (s.ctrlName)
		case "doB":
			pnlButtonDo(s.win)
			break
		case "cancelB":
			KillWindow $s.win
			break
		default:
	endswitch
End

Static Function pnlButtonDo(String pnlName)
	Wave/T ctw = SIDAMGetCtrlTexts(pnlName, "sourceV;basenameV")
	Wave cvw = SIDAMGetCtrlValues(pnlName, "startpV;endpV;fitC;offsetV")
	Variable offset = cvw[%fitC] ? inf : cvw[%offsetV]
	KillWindow $pnlName
	printf "%s%s\r", PRESTR_CMD, echoStr($ctw[%sourceV],cvw[%startpV],\
		cvw[%endpV],offset,ctw[%basenameV])
	SIDAMWorkfunction($ctw[%sourceV],startp=cvw[%startpV],endp=cvw[%endpV],\
		offset=offset,basename=ctw[%basenameV])
End

Static Function getMax(String pnlName, String ctrlName)
	return str2num(GetUserData(pnlName,ctrlName,"max"))
End
