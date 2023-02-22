#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMCorrelation

#include <PopupWaveSelector>

#include "SIDAM_Bias"
#include "SIDAM_Display"
#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Df"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Wave"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Calculate correlation function.
//
//	## Parameters
//	src : wave
//		The source wave, 2D or 3D.
//	dest : wave, default `src`
//		The destination wave that has the same dimension as the source wave.
//		When the source wave is 3D, a 2D wave that has the same dimension in
//		the x and y directions is also allowed.
//	subtract : int {0 or !0}, default 1
//		Set !0 to subtract the average before the calculation. For a 3D wave,
//		the average of each layer is subtracted.
//	normalize : int {0 or !0}, default 1
//		Set !0 to normalize the result. For a 3D wave, the result is normalized
//		layer-by-layer.
//
//	## Returns
//	wave
//		Correlation wave. When the destination wave is the same as the source
//		wave, this is the auto correlation of the source wave.
//@
Function/WAVE SIDAMCorrelation(Wave/Z src, [Wave/Z dest,
	int subtract, int normalize])
	
	STRUCT paramStruct s
	Wave/Z s.w1 = src
	if (ParamIsDefault(dest))
		Wave/Z s.w2 = src
	else
		Wave/Z s.w2 = dest
	endif
	s.subtract = ParamIsDefault(subtract) ? 1 : subtract
	s.normalize = ParamIsDefault(normalize) ? 1 : normalize
	
	if (validate(s))
		print s.errMsg
		return $""
	endif
	
	return corr(s)
End

Static Function validate(STRUCT paramStruct &s)
	s.errMsg = PRESTR_CAUTION +"SIDAMCorrelation gave error: "
	
	int flag = SIDAMValidateWaveforFFT(s.w1)
	if (flag)
		s.errMsg += SIDAMValidateWaveforFFTMsg(flag)
		return 1
	endif
	
	if (!WaveRefsEqual(s.w1, s.w2))
		flag = SIDAMValidateWaveforFFT(s.w2)
		if (flag)
			s.errMsg += SIDAMValidateWaveforFFTMsg(flag)
			return 1
		elseif (DimSize(s.w1,0) != DimSize(s.w2,0) || DimSize(s.w1,1) != DimSize(s.w2,1))
			s.errMsg += "the input waves must have the same data points in x and y directions."
			return 1
		elseif (WaveDims(s.w1) == 3 && WaveDims(s.w2) == 3 && DimSize(s.w1,2) != DimSize(s.w2,2))
			s.errMsg += "the input waves must have the same number of data point in z direction." 
			return 1
		elseif (WaveDims(s.w1) != WaveDims(s.w2) && WaveDims(s.w1) != 3)
			s.errMsg += "the first wave must be 3D for a 3D and 2D combination." 
			return 1
		endif
	endif
	
	s.subtract = s.subtract ? 1 : 0
	s.normalize = s.normalize ? 1 : 0
	
	return 0
End

Static Structure paramStruct
	String	errMsg
	Wave	w1
	Wave	w2
	uchar	subtract
	uchar	normalize
EndStructure

Static Function/S echoStr(Wave w1, Wave w2, int subtract, int normalize,
	String result)
	
	String paramStr = GetWavesDataFolder(w1,2)
	paramStr += SelectString(WaveRefsEqual(w1, w2), ",w2="+GetWavesDataFolder(w2,2),  "")
	paramStr += SelectString(subtract==1, ",subtract="+num2str(subtract), "")
	paramStr += SelectString(normalize==1, ",normalize="+num2str(normalize), "")
	Sprintf paramStr, "Duplicate/O SIDAMCorrelation(%s), %s%s"\
		, paramStr, GetWavesDataFolder(w1,1), PossiblyQuoteName(result)
		
	return paramStr
End

Static Function menuDo()
	pnl(SIDAMImageNameToWaveRef(WinName(0,1)),WinName(0,1))
End


//******************************************************************************
//	Main
//******************************************************************************
Static Function/WAVE corr(STRUCT paramStruct &s)
	if (s.subtract || s.normalize)
		MatrixOP/FREE tw1 = subtractMean(s.w1,0)
		MatrixOP/FREE tw2 = subtractMean(s.w2,0)
	endif
	
	if (s.subtract)
		MatrixOP/FREE fw1 = fft(tw1,0)
		MatrixOP/FREE fw2 = fft(tw2,0)
	else
		MatrixOP/FREE fw1 = fft(s.w1,0)
		MatrixOP/FREE fw2 = fft(s.w2,0)
	endif
	
	MatrixOP/FREE cw = ifft(fw1*conj(fw2), 1) / numPoints(s.w1)

	//	Since number of points in the x direction is always even
	//	floor is not necessary in the x direction
	MatrixOP/FREE cw = RotateRows(cw,numRows(s.w1)/2-1)
	MatrixOP/FREE resw = RotateCols(cw,floor(numCols(s.w1)/2))
	
	if (s.normalize)
		MatrixOP/FREE ss = sqrt(sum(magSqr(tw1))) * sqrt(sum(magSqr(tw2)))
		MatrixOP/FREE resw = resw * numPoints(s.w1)
		resw /= ss[r]
	endif

	int nx = DimSize(s.w1,0), ny = DimSize(s.w1,1), nz = DimSize(s.w1,2)
	SetScale/P x -DimDelta(s.w1,0)*(nx/2-1), DimDelta(s.w1,0), WaveUnits(s.w1,0), resw
	SetScale/P y -DimDelta(s.w1,1)*ny/2, DimDelta(s.w1,1), WaveUnits(s.w1, 1), resw
	SetScale/P z DimOffset(s.w1,2), DimDelta(s.w1,2), WaveUnits(s.w1,2), resw
	
	SIDAMCopyBias(s.w1, resw)
	
	return resw
End


//******************************************************************************
//	Display a panel
//******************************************************************************
Static StrConstant SUFFIX = "_Corr"

Static Function pnl(Wave w, String grfName)
	String pnlName = grfName+ "#Correlation"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif

	NewPanel/EXT=0/HOST=$grfName/W=(0,0,320,180)/N=Correlation

	String dfTmp = SIDAMNewDF(pnlName,"CorrelationPnl")
	SetWindow $pnlName hook(self)=SIDAMCorrelation#pnlHook
	SetWindow $pnlName userData(dfTmp)=dfTmp, activeChildFrame=0
	String/G $(dfTmp+"path")
		
	SetVariable sourceV title="source", pos={42,6}, frame=0, win=$pnlName
	SetVariable sourceV size={269,18}, bodyWidth=230, noedit=1, win=$pnlName
	SetVariable sourceV value= _STR:GetWavesDataFolder(w,2), win=$pnlName
		
	SetVariable destV title="destination", pos={18,33}, win=$pnlName
	SetVariable destV size={278,18}, bodyWidth=215, win=$pnlName
	
	MakeSetVarIntoWSPopupButton(pnlName, "destV", "SIDAMCorrelation#pnlPutGlobalPath", \
		dfTmp+"path", initialSelection=GetWavesDataFolder(w,2), \
		options=PopupWS_OptionFloat)
	String destBName = GetUserData(pnlName, "destV", "PopupWS_ButtonName")
	Button $destBName userData(PopupWS_filterProc)="SIDAMCorrelation#pnlWaveFilter", win=$pnlName
	//	Show the full path because the initialSelection in MakeSetVarIntoWSPopupButton
	//	sets only the name of source wave.
	SVAR destStr = $GetUserData(pnlName, destBName, "popupWSGString")
	destStr = GetUserData(pnlName, destBName, "PopupWS_FullPath")

	int nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	String optionStr = "TEXT:0,DF:0,WAVE:0,CMPLX:0,MAXCHUNKS:0"
	sprintf optionStr, "%s,MINROWS:%d,MAXROWS:%d,MINCOLS:%d,MAXCOLS:%d", optionStr, nx, nx, ny, ny
	if (WaveDims(w)==3)
		sprintf optionStr, "%s,MINLAYERS:%d,MAXLAYERS:%d", optionStr, nz, nz
	endif
	Button $destBName userData(PopupWS_ListOptions)=optionStr, win=$pnlName
	
	SetVariable resultV title="output name", frame=1, win=$pnlName
	SetVariable resultV pos={12,60}, size={299,16}, bodyWidth=230, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+SUFFIX, win=$pnlName
	SetVariable resultV proc=SIDAMCorrelation#pnlSetVar, win=$pnlName
	
	CheckBox subtractC title="subtract average before computing", win=$pnlName
	CheckBox subtractC pos={20,96}, size={196,14}, value=1, win=$pnlName
	CheckBox normalizeC title="normalize after computing", win=$pnlName
	CheckBox normalizeC pos={20,118}, size={150,14}, value=1, win=$pnlName
	
	Button doB title="Do It", pos={8,150}, win=$pnlName
	CheckBox displayC title="display", pos={79,151}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={145,150}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, win=$pnlName
	PopupMenu toP proc=SIDAMCorrelation#pnlPopup, win=$pnlName
	Button cancelB title="Cancel", pos={252,150}, win=$pnlName
	
	ModifyControlList "doB;cancelB" size={60,20}, proc=SIDAMCorrelation#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	Make/T/N=(2,5)/FREE helpw
	int n = 0
	helpw[][n++] = {"destV", "Click to select the destination wave. When the "\
		+ "destination wave is the same as the source wave, calculate the auto-"\
		+ "correlation of the source wave."}
	helpw[][n++] = {"resultV", "Enter the name of output wave. The output wave is "\
		+ "saved in the same datafolder where the source wave is."}
	helpw[][n++] = {"subtractC", "Check to subtract the average before calculating "\
		+ "FFT. For 3D waves, the average of each layer is subtracted."}
	helpw[][n++] = {"normalizeC", "Check to normalize the correlation wave so that "\
		+ "the maximum of absolute value is 1."}
	helpw[][n++] = {"displayC", "Check to display the output wave."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	pnlDisable(pnlName)
End

//******************************************************************************
//	Hook
//******************************************************************************
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	strswitch (s.eventName)
		case "mousedown":
			//	Explicitly call PopupWaveSelectorPop because clicking the SetVariable
			//	control does not work when the panel is shown a subwindow.
			if (SIDAMPtInRect(s, "destV"))
				PopupWaveSelectorPop(s.winName, GetUserData(s.winName, "destV", "PopupWS_ButtonName"))
			endif
			break
		case "keyboard":	
			if (s.keycode == 27) //	esc
				pnlHookClose(s.winName)
				KillWindow $s.winName
			endif
			break
		case "killVote":	
			pnlHookClose(s.winName)
			break
	endswitch
End

Static Function pnlHookClose(String pnlName)
	KillWindow/Z popupWSPanel
	SIDAMKillDataFolder($GetUserData(pnlName,"","dfTmp"))
	SIDAMKillDataFolder(root:Packages:WM_WaveSelectorList)
End


//******************************************************************************
//	Controls
//******************************************************************************
//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			pnlDo(s.win)
			break
		case "cancelB":
			KillWindow $s.win
			break
	endswitch
End

//	SetVariable (resultV only)
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	pnlDisable(s.win)
End

//	Popup (toP only)
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	Wave cvw = SIDAMGetCtrlValues(s.win, "subtractC;normalizeC")
	Wave/T ctw = SIDAMGetCtrlTexts(s.win, "sourceV;resultV")
	Wave w1 = $ctw[%sourceV]
	Wave w2 = $GetUserData(s.win,"destV","PopupWS_FullPath")
	SIDAMPopupTo(s, echoStr(w1, w2, cvw[%subtractC], cvw[%normalizeC], \
		ctw[%resultV]))
End

//******************************************************************************
//	Helper funcitons for control
//******************************************************************************
Static Function pnlWaveFilter(String path, Variable ListContents)
	return !SIDAMValidateWaveforFFT($path)
End

Static Function pnlPutGlobalPath(Variable event, String wavepath, 
		String windowName, String ctrlName)
	ControlInfo/W=$windowName $ctrlName
	SVAR/SDFR=$S_DataFolder str = $S_Value
	str = wavepath
end

Static Function pnlDisable(String pnlName)
	int disable = 0
	
	ControlInfo/W=$pnlName sourceV
	int flag = SIDAMValidateWaveforFFT($S_Value)
	if (flag)
		String msg = SIDAMValidateWaveforFFTMsg(flag)
		SetVariable resultV title="error", noedit=1, frame=0, win=$pnlName
		SetVariable resultV fColor=(65535,0,0),valueColor=(65535,0,0), win=$pnlName
		SetVariable resultV value=_STR:msg, help={msg}, win=$pnlName
		SetVariable destV disable=2, win=$pnlName
		String destBName = GetUserData(pnlName, "destV", "PopupWS_ButtonName")
		Button $destBName disable=2, win=$pnlName
		disable = 2
	elseif (SIDAMValidateSetVariableString(pnlName,"resultV",0))
		disable = 2
	endif

	Button doB disable=disable, win=$pnlName
	PopupMenu toP disable=disable, win=$pnlName
End

Static Function pnlDo(String pnlName)
	Wave cvw = SIDAMGetCtrlValues(pnlName, "subtractC;normalizeC;displayC")
	Wave/T ctw = SIDAMGetCtrlTexts(pnlName, "sourceV;resultV")
	Wave w1 = $ctw[%sourceV]
	Wave w2 = $GetUserData(pnlName,"destV","PopupWS_FullPath")
	DFREF dfr = GetWavesDataFolderDFR(w1)

	KillWindow $pnlName
	
	printf "%s%s\r", PRESTR_CMD, echoStr(w1, w2, cvw[%subtractC], \
		cvw[%normalizeC], ctw[%resultV])
	Duplicate/O SIDAMCorrelation(w1, dest=w2, subtract=cvw[%subtractC],\
		normalize=cvw[%normalizeC]), dfr:$ctw[%resultV]/WAVE=resw
		
	if (cvw[%displayC])
		SIDAMDisplay(resw, history=1)
	endif
End
