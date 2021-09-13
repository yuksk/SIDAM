#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMCorrelation

#include "SIDAM_Display"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

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
	pnl(SIDAMImageWaveRef(WinName(0,1)),WinName(0,1))
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
	String pnlName = SIDAMNewPanel("Correlation", 320, 260)
	AutoPositionWindow/E/M=0/R=$grfName $pnlName
	
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	
	GroupBox sourceG title="source", pos={5,5}, size={310,45}, win=$pnlName
	TitleBox sourceT title=GetWavesDataFolder(w,2), pos={22,26}, frame=0, win=$pnlName
	
	GroupBox destG title="destination", pos={5,55}, size={310,80}, win=$pnlName
	PopupMenu dfP title="datafolder:", pos={22,76}, size={186,20}, bodyWidth=130, win=$pnlName
	PopupMenu dfP mode=1, value= #"\"same as source;current datafolder\"", win=$pnlName
	PopupMenu waveP title="wave:", pos={22,104}, size={281,20}, bodyWidth=250, win=$pnlName
	PopupMenu waveP userData(srcDf)=GetWavesDataFolder(w,1), win=$pnlName
	//	To show the panel without delay, show the list with one candidate
	PopupMenu waveP value=#("\"" + NameOfWave(w) + "\""), win=$pnlName
	
	SetVariable resultV title="output name:", frame=1, win=$pnlName
	SetVariable resultV pos={22,150}, size={289,16}, bodyWidth=220, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+SUFFIX, win=$pnlName
	SetVariable resultV proc=SIDAMCorrelation#pnlSetVar, win=$pnlName
	
	CheckBox subtractC title="subtract average before computing", win=$pnlName
	CheckBox subtractC pos={20,181}, size={196,14}, value=1, win=$pnlName
	CheckBox normalizeC title="normalize after computing", win=$pnlName
	CheckBox normalizeC pos={20,203}, size={150,14}, value=1, win=$pnlName
	
	Button doB title="Do It", pos={8,232}, win=$pnlName
	CheckBox displayC title="display", pos={79,233}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={145,232}, size={50,20}, bodyWidth=50, win=$pnlName
	PopupMenu toP value="Cmd Line;Clip", mode=0, win=$pnlName
	Button cancelB title="Cancel", pos={252,232}, win=$pnlName
	
	ModifyControlList "doB;cancelB" size={60,20}, proc=SIDAMCorrelation#pnlButton, win=$pnlName
	ModifyControlList "dfP;waveP;toP" proc=SIDAMCorrelation#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	pnlDisable(pnlName)

	//	Show the remaining candidates
	DoUpdate/W=$pnlName
	String listStr = pnlWaveList(pnlName, 1)
	PopupMenu waveP value=#("\"" + listStr + "\""), win=$pnlName
	PopupMenu waveP mode=WhichListItem(NameOfWave(w), listStr)+1, win=$pnlName
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

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	pnlDisable(s.win)
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "dfP":
			String listStr = pnlWaveList(s.win, s.popNum)
			if (s.popNum == 1)		//	same as source
				Wave w = $GetUserData(s.win,"","src")
				PopupMenu waveP value=#("\""+NameOfWave(w)+"\""), mode=1, disable=0, win=$s.win
				DoUpdate/W=$s.win
				PopupMenu waveP userData(srcDf)=GetWavesDataFolder(w,1), win=$s.win
				PopupMenu waveP value=#("\""+listStr+"\""), win=$s.win
				PopupMenu waveP mode=WhichListItem(NameOfWave(w), listStr)+1, win=$s.win
			elseif (strlen(listStr))	//	current datafolder, appropriate waves found
				PopupMenu waveP userData(srcDf)=GetDataFolder(1), disable=0, win=$s.win
				PopupMenu waveP value=#("\""+listStr+ "\""), mode=1, win=$s.win
			else	//	current datafolder, no appropriate wave
				PopupMenu waveP disable=2, value="_none_;", mode=1, win=$s.win
			endif
			pnlDisable(s.win)
			break
		case "waveP":
			pnlDisable(s.win)
			break
		case "toP":
			Wave w1 = $GetUserData(s.win, "", "src")
			Wave w2 = pnlPopupWaveRef(s.win, "waveP")
			Wave cvw = SIDAMGetCtrlValues(s.win, "subtractC;normalizeC")
			ControlInfo/W=$s.win resultV
			SIDAMPopupTo(s, echoStr(w1, w2, cvw[0], cvw[1], S_Value))
			break
	endswitch
End

//******************************************************************************
//	Helper funcitons for control
//******************************************************************************
//-------------------------------------------------------------
//	Make a list for waveP
//-------------------------------------------------------------
Static Function/S pnlWaveList(String pnlName, int mode)
	//	mode 1: same as source, 2: current datafolder
	
	Wave w1 = $GetUserData(pnlName, "", "src")
	int nx = DimSize(w1,0), ny = DimSize(w1,1), nz = DimSize(w1,2), i
	//	number of data points in the x direction must be even
	//	the minimum data points is 4
	if (mod(nx,2) || nx < 4 || ny < 4)
		return ""
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (mode == 1)
		SetDataFolder GetWavesDataFolderDFR(w1)
	endif
	
	//	List waves that have the same dimensions as the source wave.
	//	If the source wave is 3D, 2D waves that have the same dimensions
	//	in x and y directions are also listed.
	String str1, str2
	sprintf str1, "MINROWS:%d,MAXROWS:%d,MINCOLS:%d,MAXCOLS:%d", nx, nx, ny, ny
	str1 += ",MAXCHUNKS:0"
	String rtnStr = WaveList("*",";",str1+",MAXLAYERS:0")
	if (WaveDims(w1) == 3)
		sprintf str2, ",MINLAYERS:%d,MAXLAYERS:%d", nz, nz
		rtnStr += WaveList("*",";",str1+str2)
	endif
	
	//	Remove waves containing NaN or INF
	for (i = ItemsInList(rtnStr)-1; i >= 0; i--)
		//	The following is faster than WaveStats
		if (numtype(sum($StringFromList(i,rtnStr))))
			rtnStr = RemoveListItem(i,rtnStr)
		endif
	endfor	

	SetDataFolder dfrSav
	return rtnStr
End

Static Function pnlDisable(String pnlName)
	Wave w1 = $GetUserData(pnlName, "", "src")
	Wave/Z w2 = pnlPopupWaveRef(pnlName, "waveP")
	if (!WaveExists(w2) || SIDAMValidateSetVariableString(pnlName,"resultV",0))
		Button doB disable=2, win=$pnlName
		PopupMenu toP disable=2, win=$pnlName
		return 0
	else
		Button doB disable=0, win=$pnlName
		PopupMenu toP disable=0, win=$pnlName
	endif
End

Static Function pnlDo(String pnlName)
	Wave w1 = $GetUserData(pnlName, "", "src")
	Wave w2 = pnlPopupWaveRef(pnlName, "waveP")
	DFREF dfr = $GetUserData(pnlName, "waveP", "srcDf")
	Wave cvw = SIDAMGetCtrlValues(pnlName, "subtractC;normalizeC;displayC")
	ControlInfo/W=$pnlName resultV
	String result = S_Value

	KillWindow $pnlName
	
	printf "%s%s\r", PRESTR_CMD, echoStr(w1, w2, cvw[0], cvw[1], result)
	Duplicate/O SIDAMCorrelation(w1, dest=w2, subtract=cvw[0],\
		normalize=cvw[1]), dfr:$result/WAVE=resw
		
	if (cvw[2])
		SIDAMDisplay(resw, history=1)
	endif
End


Static Function/WAVE pnlPopupWaveRef(String pnlName, String ctrlName)
	ControlInfo/W=$pnlName $ctrlName
	//	Nothing is selected
	if (strlen(StringByKey("value",S_recreation,"=",",")) <= 9)
		return $""
	endif
	
	Wave/Z w = $(GetUserData(pnlName, ctrlName, "srcDf") + PossiblyQuoteName(S_Value))
	if (WaveExists(w))
		return w
	else
		return $""
	endif
End
