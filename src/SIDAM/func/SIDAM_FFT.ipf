#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMFFT

#include "SIDAM_Display"
#include "SIDAM_Preference"
#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//  Names of window functions
Static StrConstant LIST1 = "Bartlett;Blackman367;Blackman361;Blackman492;"
Static StrConstant LIST2 = "Blackman474;Cos1;Cos2;Cos3;Cos4;KaiserBessel20;"
Static StrConstant LIST3 = "KaiserBessel25;KaiserBessel30;Hamming;Hanning;"
Static StrConstant LIST4 = "Parzen;Poisson2;Poisson3;Poisson4;Riemann;SFT3F;"
Static StrConstant LIST5 = "SFT3M;FTNI;SFT4F;SFT5F;SFT4M;FTHP;HFT70;FTSRS;"
Static StrConstant LIST6 = "SFT5M;HFT90D;HFT95;HFT116D;HFT144D;HFT169D;"
Static StrConstant LIST7 = "HFT196D;HFT223D;HFT248D;none;"

//	Names of outputs
Static StrConstant OUTPUT = "complex;real;magnitude;magnitude squared;phase;imaginary"

Static StrConstant SUFFIX = "_FFT"

//@
//	Compute the discrite Fourier transform of the input wave.
//	When the input wave is 3D, the histogram is generated layer by layer.
//
//	## Parameters
//	w : wave
//		The input wave, 2D or 3D.
//	win : string, default "none"
//		An image window function.
//	out : int {1 -- 6}, default 3
//		The Output mode of FFT.
//		1. complex
//		2. real
//		3. magnitude
//		4. magnitude squared
//		5. phase
//		6. imaginary
//	subtract : int {0 or !0}, default 0
//		Set !0 to subtract the average before FFT. For a 3D wave,
//		the average of each layer is subtracted.
//
//	## Returns
//	wave
//		Fourier-transformed wave.
//@
Function/WAVE SIDAMFFT(Wave/Z w, [String win, int out, int subtract])

	STRUCT paramStruct s
	Wave/Z s.w = w
	s.win = SelectString(ParamIsDefault(win), win, "none")
	s.out = ParamIsDefault(out) ? 3 : out
	s.subtract = ParamIsDefault(subtract) ? 0 : subtract

	if (validate(s))
		printf "%s%s gave error: %s\r", PRESTR_CAUTION, GetRTStackInfo(1), s.errMsg
		return $""
	endif

	Wave resw = FFTmain(w, s.win, s.out, s.subtract)
	Note resw, StringFromList(s.out-1, OUTPUT) + ", " + s.win
	return resw
End

Static Function validate(STRUCT paramStruct &s)

	int flag = SIDAMValidateWaveforFFT(s.w)
	if (flag)
		s.errMsg = SIDAMValidateWaveforFFTMsg(flag)
		return 1
	endif

	if (s.out < 1 || s.out > 6)
		s.errMsg = "out must be an integer between 1 and 6."
		return 1

	elseif (WhichListItem(s.win,allWindows()) < 0)
		s.errMsg = "name of window function is not found."
		return 1
	endif

	s.subtract = s.subtract ? 1 : 0

	return 0
End

Static Structure paramStruct
	Wave	w
	String	errMsg
	String	win
	uint16	out
	uint16	subtract
EndStructure

Static Function/S echoStr(Wave w, String win, int out, int subtract,
	String result)
	String paramStr = GetWavesDataFolder(w,2)
	paramStr += SelectString(CmpStr(win, "none"), "", ",win=\""+win+"\"")
	paramStr += SelectString(out==3, ",out="+num2str(out), "")
	paramStr += SelectString(subtract, "", ",subtract="+num2str(subtract))
	Sprintf paramStr, "Duplicate/O SIDAMFFT(%s), %s%s", paramStr\
		, GetWavesDataFolder(w,1), PossiblyQuoteName(result)
	return paramStr
End

//-------------------------------------------------------------
//	Menu function
//-------------------------------------------------------------
Static Function menuDo()
	pnl(WinName(0,1))
End


//******************************************************************************
//	Main part of FFT
//	3D waves are done in layer by layer.
//******************************************************************************
Static Function/WAVE FFTmain(Wave w, String winStr, int out, int subtract)

	Variable nx = DimSize(w,0), ny = DimSize(w,1)

	int win = CmpStr(winStr,"none")
	if (win)
		Wave iw = imageWindowWave2D(nx,ny,winStr)
	endif

	//	Subtract the average / multiply a window function
	//	Even if the input wave is 32 bit, the wave returned by MatrixOP
	//	below is 64 bit
	if (subtract && win)
		MatrixOP/NTHR=0/FREE srcw = subtractMean(w, 0) * iw
	elseif (subtract && !win)
		MatrixOP/NTHR=0/FREE srcw = subtractMean(w, 0)
	elseif (!subtract && win)
		MatrixOP/NTHR=0/FREE srcw = w * iw
	else
		MatrixOP/NTHR=0/FREE srcw = fp64(w)		//	force 64 bit
	endif

	Variable coef = 1/(nx*ny)
	switch(out)
		case 1:	//	complex
			MatrixOP/NTHR=0/FREE tww = fft(srcw,0)*coef
			break
		case 2:	//	real
			MatrixOP/NTHR=0/FREE tww = real(fft(srcw,0))*coef
			break
		case 3:	//	mag
			MatrixOP/NTHR=0/FREE tww = mag(fft(srcw,0))*coef
			break
		case 4:	//	magSqr
			MatrixOP/NTHR=0/FREE tww = magSqr(fft(srcw,0))*coef*coef
			break
		case 5:	//	phase
			MatrixOP/NTHR=0/FREE tww = phase(fft(srcw,0))
			break
		case 6:	//	imag
			MatrixOP/NTHR=0/FREE tww = imag(fft(srcw,0))*coef
			break
	endswitch

	Wave resw = symmetrize(tww,out)

	setScaling(resw, w)

	//	Make the result 32 bit, if the input wave is 32 bit.
	if (NumberByKey("NUMTYPE",WaveInfo(w,0)) & 2)
		Redimension/S resw
	endif

	return resw
End

//-------------------------------------------------------------
//	Return a 2D window wave made by simply multiplying
//	two 1D window waves
//-------------------------------------------------------------
Static Function/WAVE imageWindowWave2D(int nx, int ny, String name)

	Wave xw = imageWindowWave1D(nx, name)
	Wave yw = imageWindowWave1D(ny, name)
	Make/D/N=(nx,ny)/FREE xyw
	MultiThread xyw = xw[p] * yw[q]
	return xyw
End

Static Function/WAVE imageWindowWave1D(int n, String name)

	Make/D/N=(n)/FREE w = 1
	if (CmpStr(name,"none"))
		WindowFunction $name, w
	endif
	return w
End

//-------------------------------------------------------------
//	Make the left half from the right half to symmetrize
//-------------------------------------------------------------
Static Function/WAVE symmetrize(Wave rw, int out)

	//	Reverse horizontally and vertically
	//	reverseCols & reverseRows of MatrixOP can not be used
	//	for this purpose because it does not work for complex waves.
	//	Remove the first and last pixel
	Duplicate/R=[1,DimSize(rw,0)-2][]/FREE rw, lw
	Reverse/P/DIM=0 lw
	Reverse/P/DIM=1 lw

	//	Rotate vertically by 1 pixel upward
	switch (out)
		case 1:		//	complex
			MatrixOP/NTHR=0/FREE resw = conj(rotateCols(lw,1))
			break
		case 5:		//	phase
		case 6:		//	imaginary
			MatrixOP/NTHR=0/FREE resw = -rotateCols(lw,1)
			break
		default:		//  real, magnitude, magnitude squared
			MatrixOP/NTHR=0/FREE resw = rotateCols(lw,1)
	endswitch
	Concatenate/NP=0 {rw}, resw

	return resw
End

//-------------------------------------------------------------
//	Set scaling values of an FFT wave
//	The values are calculated from the original wave because
//	MatrixOP may have been used before calling this function
//-------------------------------------------------------------
Static Function setScaling(Wave resw, Wave w)

	int nx = DimSize(w,0), ny = DimSize(w,1)
	Variable lx = nx*DimDelta(w,0), ly = ny*DimDelta(w,1)
	SetScale/P x -(nx/2-1)/lx, 1/lx, changeUnit(WaveUnits(w,0)), resw
	SetScale/P y -ny/2/ly, 1/ly, changeUnit(WaveUnits(w,1)), resw

	if (WaveDims(resw)==3)
		SetScale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), resw
		SIDAMCopyBias(w, resw)		//	for the MLS mode of Nanonis
	endif
End

//-------------------------------------------------------------
//	Return the unit of an FFT wave
//-------------------------------------------------------------
Static Function/S changeUnit(String unitStr)

	strswitch (unitStr)
		case "s":
		case "sec":
			return "Hz"
		case "Hz":
			return "s"
		default:
			if (!strlen(unitStr))
				return ""
			elseif (strsearch(unitStr,"^-1",0)>=0)
				return RemoveEnding(unitStr,"^-1")
			else
				return unitStr + "^-1"
			endif
	endswitch
End


//******************************************************************************
//	Show a panel
//******************************************************************************
Static Function pnl(String grfName)

	Wave w = SIDAMImageNameToWaveRef(grfName)
	NewPanel/EXT=0/HOST=$grfName/W=(0,0,300,370)/N=FFT
	String pnlName = grfName+ "#FFT"

	String dfTmp = SIDAMNewDF(pnlName,"FFTPnl")
	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	SetWindow $pnlName userData(src)=GetWavesDataFolder(w,2)
	SetWindow $pnlName userData(dfTmp)=dfTmp, activeChildFrame=0

	STRUCT SIDAMPrefs ps
	SIDAMLoadPrefs(ps)

	ControlInfo/W=$pnlName kwBackgroundColor
	STRUCT RGBColor bc
	bc.red = V_Red
	bc.green = V_Green
	bc.blue = V_Blue

	//	wave of a window function
	Make/N=(256,256) $(dfTmp+"win")/WAVE=winw = 1
	SetScale/I x 0, 1, "", winw
	SetScale/I y 0, 1, "", winw

	//	controls
	SetVariable resultV title="output name:", frame=1, win=$pnlName
	SetVariable resultV pos={19,10}, size={269,16}, bodyWidth=200, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)+SUFFIX, win=$pnlName
	SetVariable resultV proc=SIDAMFFT#pnlSetVar, win=$pnlName

	CheckBox subtractC title="subtract average before computing", win=$pnlName
	CheckBox subtractC pos={88,38}, value=ps.fourier[0], win=$pnlName

	PopupMenu outputP title="output type:", pos={25,65}, win=$pnlName
	PopupMenu outputP size={263,19}, mode=ps.fourier[1], win=$pnlName
	PopupMenu outputP bodyWidth=200, value=SIDAMFFT#allOutputs(), win=$pnlName
	PopupMenu windowP title="window:", pos={46,94}, size={242,19}, win=$pnlName
	PopupMenu windowP bodyWidth=200,value=SIDAMFFT#allWindows(), win=$pnlName
	PopupMenu windowP mode=ps.fourier[2], proc=SIDAMFFT#pnlPopup, win=$pnlName

	Button doB title="Do It", pos={10,343}, win=$pnlName
	CheckBox displayC title="display", pos={80,345}, value=1, win=$pnlName
	PopupMenu toP title="To", pos={145,343}, size={50,20}, win=$pnlName
	PopupMenu toP bodyWidth=50, value="Cmd Line;Clip", win=$pnlName
	PopupMenu toP mode=0, proc=SIDAMFFT#pnlPopup, win=$pnlName
	Button cancelB title="Cancel", pos={228,343}, win=$pnlName
	ModifyControlList "doB;cancelB", size={60,20}, proc=SIDAMFFT#pnlButton, win=$pnlName

	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0,win=$pnlName

	//	show a window function
	int left = 37, top = 127, width = 252
	Display/W=(left,top,left+width,top+width*0.8)/HOST=$pnlName
	AppendImage/W=$pnlName#G0 winw
	AppendToGraph/W=$pnlName#G0/L=l2/B=b2/VERT winw[][DimSize(winw,1)/2]
	ModifyGraph axisEnab(bottom)={0.2,1},axisEnab(b2)={0,0.17}

	ModifyImage/W=$pnlName#G0 $NameOfWave(winw) ctab={0,1,Spectrum,0}
	ModifyGraph/W=$pnlName#G0 mirror=0,noLabel=2,axThick=0,standoff=0,margin=1
	ModifyGraph/W=$pnlName#G0 rgb=(0,0,0),wbRGB=(bc.red,bc.green,bc.blue)
	ModifyGraph/W=$pnlName#G0 gbRGB=(V_Red,V_Green,V_Blue)
	SetAxis/A/R/W=$pnlName#G0 b2

	SetActiveSubwindow $pnlName

	changeDisables(pnlName)
	pnlSetWindowWave(pnlName, StringFromList(ps.fourier[2]-1,allWindows()))

	SetActiveSubwindow $grfName
End

Static Function/S allOutputs()
	return OUTPUT
End

Static Function/S allWindows()
	return LIST1+LIST2+LIST3+LIST4+LIST5+LIST6+LIST7
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
			KillWindow $(s.win)
			break
		default:
	endswitch
End

//	SetVariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up, enter key, or end edit
	if (s.eventCode != 1 && s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	changeDisables(s.win)
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif

	strswitch (s.ctrlName)
		case "windowP":
			pnlSetWindowWave(s.win, s.popStr)
			break
		case "toP":
			Wave cvw = SIDAMGetCtrlValues(s.win, "outputP;subtractC")
			Wave/T ctw = SIDAMGetCtrlTexts(s.win, "windowP;resultV")
			String paramStr = echoStr($GetUserData(s.win,"","src"),\
				ctw[%windowP], cvw[%outputP], cvw[%subtractC], ctw[%resultV])
			SIDAMPopupTo(s, paramStr)
			break
	endswitch
End

Static Function pnlDo(String pnlName)
	Wave w = $GetUserData(pnlName,"","src")
	Wave cvw = SIDAMGetCtrlValues(pnlName, "outputP;subtractC;displayC;windowP")
	Wave/T ctw = SIDAMGetCtrlTexts(pnlName, "resultV;windowP")
	KillWindow $pnlName

	Wave/Z fftw = SIDAMFFT(w, win=ctw[%windowP], out=cvw[%outputP], \
		subtract=cvw[%subtractC])
	
	printf "%s%s\r", PRESTR_CMD, echoStr(w, ctw[%windowP], cvw[%outputP]\
		, cvw[%subtractC], ctw[%resultV])
	DFREF dfr = GetWavesDataFolderDFR(w)
	Duplicate/O fftw dfr:$ctw[%resultV]/WAVE=resw
	
	if (cvw[%displayC])
		SIDAMDisplay(resw, history=1)
	endif

	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	prefs.fourier[0] = cvw[%subtractC]
	prefs.fourier[1] = cvw[%outputP]
	prefs.fourier[2] = cvw[%windowP]
	SIDAMSavePrefs(prefs)
End

Static Function pnlSetWindowWave(String pnlName, String name)
	Wave w = imageWindowWave2D(256, 256, name)
	Wave/SDFR=$GetUserData(pnlName, "", "dfTmp") win
	win = w
End

Static Function changeDisables(String pnlName)
	int disable = SIDAMValidateSetVariableString(pnlName,"resultV",0)*2
	Button doB disable=disable, win=$pnlName
	PopupMenu toP disable=disable, win=$pnlName
End
