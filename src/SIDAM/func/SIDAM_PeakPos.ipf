#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMPeakPos

#include "SIDAM_Utilities_Df"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Marquee"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant FUNCTION_NAMES = "asymGauss2D;asymLor2D"
Static StrConstant TEMP_NAME = "SIDAMPeakPosTemp"
Static Constant TEMP_CLR_R = 65535
Static Constant TEMP_CLR_G = 0
Static Constant TEMP_CLR_B = 52428

//@
//	Find a peak position by fitting.
//
//	## Parameters
//	w : wave
//		The input wave. The whole wave is fit.
//	fitfn : int {0 or 1}
//		The fitting function.
//		* 0: asymmetric gauss2D
//		* 1: asymmetric lorentz2D
//
//	## Returns
//	wave
//		A 1D numeric wave is saved in the datafolder where the input wave is, and
//		the wave reference to the saved wave is returned.
//		The values of fitting results are given as follows.
//		- offset : `wave[%offset]`
//		- amplitude : `wave[%amplitude]`
//		- peak position : `wave[%xcenter]`, `wave[%ycenter]`
//		- peak width : `wave[%xwidthpos]`, `wave[%xwidthneg]`, `wave[%ywidthpos]`, `wave[%ywidthneg]`
//		- peak angle : `wave[%angle]`
//@
Function/WAVE SIDAMPeakPos(Wave w, int fitfn)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	Variable V_FitError	

	//	Use Gauss2D to get initial values
	CurveFit/M=2/W=2/N=1/Q Gauss2D, w/D
	if (V_FitError)
		SetDataFolder dfrSav
		AbortOnValue V_FitError, V_FitError
	endif

	Wave cw = W_coef
	Make/D/N=9 initcoef = {cw[0],cw[1],cw[2],cw[4],cw[3],cw[3],cw[5],cw[5],0}

	Variable fitResult = 0
	Make/D initangles = {pi/6, -pi/6}	
	Make/D/N=(2,numpnts(initangles)) results		//	[0][] = V_FitError, [1][] = V_chisq
	Make/WAVE/N=(numpnts(initangles)) ww			//	coef
	Make/T T_constraint = {"K8 <= pi/4", "K8 >= -pi/4", "K4 > 0",\
		"K5 > 0", "K6 > 0", "K7 > 0"}
	ww = doFit(w, fitfn, initcoef, initangles, T_constraint, results, p)

	//	Abort if all initial angles fail
	WaveStats/Q/M=1/RMD=[0][] results
	if (V_min)
		SetDataFolder dfrSav
		AbortOnValue V_min, V_min
	endif

	//	Use the initial angle that gives the best result
	WaveStats/Q/M=1/RMD=[1][] results
	Wave coef = ww[V_minColLoc]
	
	SetDimLabel 0, 0, offset, coef
	SetDimLabel 0, 1, amplitude, coef
	SetDimLabel 0, 2, xcenter, coef
	SetDimLabel 0, 3, ycenter, coef
	SetDimLabel 0, 4, xwidthpos, coef
	SetDimLabel 0, 5, xwidthneg, coef
	SetDimLabel 0, 6, ywidthpos, coef
	SetDimLabel 0, 7, ywidthneg, coef
	SetDimLabel 0, 8, angle, coef
	
	SetDataFolder dfrSav
	return coef
End

Static Function/WAVE doFit(Wave w, int fitfn, Wave initcoef, Wave initangle,
	Wave/T constraint, Wave results, int index)

	Duplicate/FREE initcoef, coef
	coef[8] = initangle[index]
	Variable V_FitError, V_chisq
	String fnName = "SIDAMPeakPos#" + StringFromList(fitfn,FUNCTION_NAMES)
	FuncFitMD/N=1/Q/W=2 $fnName coef w /D /C=constraint
	results[0][index] = V_FitError
	results[1][index] = V_chisq
	return coef
End

Static Function marqueeDo(int mode)
	//	do fit
	String grfName = WinName(0,1)
	Wave w = SIDAMImageNameToWaveRef(grfName)
	Wave mw = SIDAMGetMarquee()
	try
		Wave posw = SIDAMPeakPos(SIDAMGetMarqueeAreaWave(w, grfName), mode)
	catch
		informError(V_AbortCode)
		return 0
	endtry

	DFREF dfrTmp = displayAttempt(grfName, posw)

	STRUCT SIDAMAxisRange s
	zoomin(grfName, NameOfWave(w), mw, s)
	String resultName = saveWave(posw, GetWavesDataFolderDFR(w))
	if (strlen(resultName))
		echo(w, mw, grfName, mode, resultName)
	endif

	revertRange(grfName, NameOfWave(w), mw, s)
	removeAttempt(grfName, dfrTmp)
End

Static Function informError(int code)
	String msg = "Failed to fit: "
	if (code & 2^1)
		DoAlert 0, msg + "Singular matrix"
	endif
	if (code & 2^2)
		DoAlert 0, msg + "Out of memory"
	endif
	if (code & 2^3)
		DoAlert 0, msg + "Function returned NaN or INF"
	endif
	if (code & 2^4)
		DoAlert 0, msg + "Fit function requested stop"
	endif
	if (code & 2^5)
		DoAlert 0, msg + "Reentrant curve fitting"
	endif
End

Static Function/DF displayAttempt(String grfName, Wave posw)
	DFREF dfrSav = GetDataFolderDFR()
	DFREF dfrTmp = $SIDAMNewDF(StringFromList(0, grfName, "#"),"PeakPos")

	SetDataFolder dfrTmp
	Make/N=5 xw={-posw[%xwidthneg], posw[%xwidthpos], nan, 0, 0}
	Make/N=5 yw={0,0,nan,-posw[%ywidthneg], posw[%ywidthpos]}
	Make/N=5 xw2, yw2
	SetDataFolder dfrSav

	xw2 = xw*cos(posw[%angle]) - yw*sin(posw[%angle]) + posw[%xcenter]
	yw2 = xw*sin(posw[%angle]) + yw*cos(posw[%angle]) + posw[%ycenter]
	AppendToGraph/W=$grfName yw2/TN=$TEMP_NAME vs xw2
	ModifyGraph/W=$grfName mode($TEMP_NAME)=0, mrkThick($TEMP_NAME)=1
	ModifyGraph/W=$grfName rgb($TEMP_NAME)=(TEMP_CLR_R,TEMP_CLR_G,TEMP_CLR_B)
	
	return dfrTmp
End

Static Function removeAttempt(String grfName, DFREF dfrTmp)
	RemoveFromGraph/W=$grfName $TEMP_NAME
	DoUpdate/W=$grfName
	SIDAMKillDataFolder(dfrTmp)
End

Static Function zoomin(String grfName, String wname, Wave mw,
	STRUCT SIDAMAxisRange &s)

	SIDAMGetAxis(grfName, wname, s)
	SIDAMSetAxis(grfName, wname, "X", mw[%x][0], mw[%x][1])
	SIDAMSetAxis(grfName, wname, "Y", mw[%y][0], mw[%y][1])
	#if IgorVersion() >= 9
	SetMarquee/W=$grfName/HAX=$(s.xaxis)/VAX=$(s.yaxis) mw[%x][0],mw[%y][1],\
		mw[%x][1],mw[%y][0]
	#endif
	DoUpdate/W=$grfName
End

Static Function revertRange(String grfName, String wname, Wave mw,
	STRUCT SIDAMAxisRange &s)
	
	SIDAMSetAxis(grfName, wname, "X", \
		s.x.min.auto ? NaN : s.x.min.value, s.x.max.auto ? NaN : s.x.max.value)
	SIDAMSetAxis(grfName, wname, "Y", \
		s.y.min.auto ? NaN : s.y.min.value, s.y.max.auto ? NaN : s.y.max.value)
	#if IgorVersion() >= 9
	DoUpdate/W=$grfName
	SetMarquee/W=$grfName/HAX=$(s.xaxis)/VAX=$(s.yaxis) mw[%x][0],mw[%y][1],\
		mw[%x][1],mw[%y][0]
	#endif
End

Static Function/S saveWave(Wave posw, DFREF dfr)
	//	Confirm whether saving the result
	String msg
	sprintf msg, "Position: (%g, %g)\rx width: (%g, %g)\ry width: (%g, %g)\r" \
		+ "angle: %g degree\rDo you want to save this result?", \
		posw[%xcenter], posw[%ycenter], posw[%xwidthneg], posw[%xwidthpos], \
		posw[%ywidthneg], posw[%ywidthpos], posw[%angle]/pi*180
	DoAlert 1, msg
	if (V_flag == 2)		//	no is selected
		return ""
	endif

	//	Enter a basename
	String basename = "peakPos"
	Prompt basename, "Enter a basename:"
	DoPrompt "Enter a basename", basename
	if (V_Flag)	// User canceled
		return ""
	endif

	//	Save the result as a wave
	#if IgorVersion() >= 9	
		String name = CreateDataObjectName(dfr, basename, 1, 0, 4)
		Duplicate posw dfr:$name
	#else
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder dfr
		String name = Uniquename(basename,1,0)
		Duplicate posw $name
		SetDataFolder dfrSav
	#endif
	sprintf msg, "The result is saved at %s", GetDataFolder(1, dfr)+name
	DoAlert 0, msg
	
	return name
End

Static Function echo(Wave w, Wave mw, String grfName, int fitfn, String resultName)
	String newName = UniqueName(TEMP_NAME, 1, 0)
	String cmdStr, rmdStr

	if (WaveDims(w)==3)
		sprintf rmdStr, "[%d,%d][%d,%d][%d]", mw[%p][0], mw[%p][1], mw[%q][0], mw[%q][1], SIDAMGetLayerIndex(grfName)
	else
		sprintf rmdStr, "[%d,%d][%d,%d]", mw[%p][0], mw[%p][1], mw[%q][0], mw[%q][1]
	endif
	sprintf cmdStr, "%sDuplicate/R=%s %s %s\r", PRESTR_CMD, rmdStr, GetWavesDataFolder(w,2), newName
	
	if (WaveDims(w)==3)
		sprintf cmdStr, "%s%sRedimension/N=(-1,-1) %s\r", cmdStr, PRESTR_CMD, newName
	endif
	
	sprintf cmdStr, "%s%sDuplicate SIDAMPeakPos(%s, %d) %s%s\r", cmdStr, PRESTR_CMD, newName, \
		fitfn, GetWavesDataFolder(w,1), resultName
	sprintf cmdStr, "%s%sKillWaves %s\r", cmdStr, PRESTR_CMD, newName
	print cmdStr
End


Static Function/S marqueeMenu(int mode)
	Wave/Z w = SIDAMImageNameToWaveRef(WinName(0,1))	
	
	int isComplex = WaveType(w) & 0x01
	if (!WaveExists(w) || isComplex)
		return ""
	endif
	
	String rtnStr = "asymmetric "
	return rtnStr + SelectString(mode, "Gauss2D", "Lorentz2D")
End


ThreadSafe Static Function asymGauss2D(Wave w, Variable x, Variable y)
	Variable cx = x-w[2], cy = y-w[3]
	//	When the angle (w[8]) is 0, see the sign of cx and cy.
	//	When the angle is not 0,
	//	cx > 0 =>　cy > tan(w[8]+pi/2)*cx
	//	cy > 0 => cy > tan(w[8])*x
	Variable wx, wy
	if (w[8] > 0)
		wx = (cy > tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	elseif (w[8] < 0)
		wx = (cy < tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	else
		wx = cx > 0 ? w[4] : w[5]
		wy = cy > 0 ? w[6] : w[7]
	endif
	Variable cx2 = cx*cos(w[8]) + cy*sin(w[8]), cy2 = cx*sin(w[8]) - cy*cos(w[8])
	return w[0] + w[1]*exp(-(cx2/wx)^2)*exp(-(cy2/wy)^2)
End

ThreadSafe Static Function asymLor2D(Wave w, Variable x, Variable y)
	Variable cx = x-w[2], cy = y-w[3]
	Variable cx2 = cx*cos(w[8]) + cy*sin(w[8]), cy2 = -cx*sin(w[8]) + cy*cos(w[8])
	//	When the angle (w[8]) is 0, see the sign of cx and cy.
	//	When the angle is not 0,
	//	cx > 0 =>　cy > tan(w[8]+pi/2)*cx
	//	cy > 0 => cy > tan(w[8])*x
	Variable wx, wy
	if (w[8] > 0)
		wx = (cy > tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	elseif (w[8] < 0)
		wx = (cy < tan(w[8]+pi/2)*cx) ? w[4] : w[5]
		wy = (cy > tan(w[8])*cx) ? w[6] : w[7]
	else
		wx = cx > 0 ? w[4] : w[5]
		wy = cy > 0 ? w[6] : w[7]
	endif
	return w[0] + w[1]*wx^2/(cx2^2+wx^2)*wy^2/(cy2^2+wy^2)
End
