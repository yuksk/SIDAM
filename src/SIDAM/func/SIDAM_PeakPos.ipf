#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMPeakPos

#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Marquee"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Find a peak position by fitting.
//
//	## Parameters
//	w : wave
//		The input wave. If a marquee is shown, use the area specified
//		by the marquee. If not, use the whole wave.
//	fitfn : int {0 or 1}
//		The fitting function.
//		* 0: asymGauss2D
//		* 1: asymLor2D
//
//	## Returns
//	wave
//		A 1D numeric wave is saved in the datafolder where `w` is, and wave reference
//		to the saved wave is returned.
//		The values of fitting results are given as follows.
//		- offset : `wave[%offset]`
//		- amplitude : `wave[%amplitude]`
//		- peak position : `wave[%xcenter]`, `wave[%ycenter]`
//		- peak width : `wave[%xwidthpos]`, `wave[%xwidthneg]`, `wave[%ywidthpos]`, `wave[%ywidthneg]`
//		- peak angle : `wave[%angle]`
//@
Function/WAVE SIDAMPeakPos(Wave w, int fitfn)
	
	Wave mw = SIDAMGetMarquee()
	if (!WaveExists(mw))
		Duplicate/FREE w, tw
	elseif (WaveDims(w)==3)
		//	Use the displayed layer for a 3D wave
		Duplicate/R=[mw[%p][0],mw[%p][1]][mw[%q][0],mw[%q][1]][SIDAMGetLayerIndex(WinName(0,1))]/FREE w, tw
		Redimension/N=(-1,-1) tw
	else
		Duplicate/R=[mw[%p][0],mw[%p][1]][mw[%q][0],mw[%q][1]]/FREE w, tw
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	Variable V_FitError	
	
	//	Use Gauss2D to get initial values
	CurveFit/M=2/W=2/N=1/Q Gauss2D, tw/D
	AbortOnValue V_FitError, 21
	Wave cw = W_coef
	Make/D/N=9 initcoef = {cw[0],cw[1],cw[2],cw[4],cw[3],cw[3],cw[5],cw[5],0}

	Variable fitResult = 0
	Make/D angles = {pi/6, -pi/6}				//	initial angles
	Make/D/N=(2,numpnts(angles)) results	//	[0][] = V_FitError, [1][] = V_chisq
	Make/WAVE/N=(numpnts(angles)) ww			//	coef
	ww = doFit(fitfn, initcoef, angles, tw, results, p)
	
	//	Abort if all initial angles fail
	Make/N=(numpnts(angles)) tw2
	tw2 = results[0][p]
	AbortOnValue WaveMin(tw2), 22
	
	//	Use the initial angle that gives the best result
	tw2 = results[1][p]
	WaveStats/Q/M=1 tw2
	Wave coef = ww[V_minloc]
	
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

Static Function/WAVE doFit(int fitfn,
		Wave initcoef, Wave angle, Wave w, Wave results, int index)
	Duplicate/FREE initcoef, coef
	coef[8] = angle[index]
	Variable V_FitError, V_chisq
	Make/T/FREE T_constraint = {"K8 <= pi/4", "K8 >= -pi/4", "K4 > 0", "K5 > 0", "K6 > 0", "K7 > 0"}
	switch (fitfn)
		case 0:	//	asymmetric gauss2D
			FuncFitMD/N=1/Q/W=2 SIDAMPeakPos#asymGauss2D coef w /D /C=T_constraint
			break
		case 1:	//	asymmetric lorentz2D
			FuncFitMD/N=1/Q/W=2 SIDAMPeakPos#asymLor2D coef w /D /C=T_constraint
			break
	endswitch
	results[0][index] = V_FitError
	results[1][index] = V_chisq
	return coef
End

Static Function marqueeDo(int mode)
	//	do fit
	String grfName = WinName(0,1)
	Wave iw = SIDAMImageNameToWaveRef(grfName)
	try
		Wave posw = SIDAMPeakPos(iw, mode)
	catch
		DoAlert 0, "Failed to fit "+num2istr(V_AbortCode)
		return 0
	endtry

	//	display the fit result
	DFREF dfrTmp = marqueeDoDisplayAttempt(grfName, posw)

	//	zoom in the marquee area
	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(grfName, NameOfWave(iw), s)
	Wave mw = SIDAMGetMarquee()
	SIDAMSetAxis(grfName, NameOfWave(iw), "X", mw[%x][0], mw[%x][1])
	SIDAMSetAxis(grfName, NameOfWave(iw), "Y", mw[%y][0], mw[%y][1])
	#if IgorVersion() >= 9
	SetMarquee/W=$grfName/HAX=$(s.xaxis)/VAX=$(s.yaxis) mw[%x][0],mw[%y][1],mw[%x][1],mw[%y][0]
	#endif
	DoUpdate/W=$grfName

	//	save the result if requested
	marqueeDoSaveWave(posw, GetWavesDataFolderDFR(iw))

	//	set the axes back to the original ranges
	SIDAMSetAxis(grfName, NameOfWave(iw), "X", \
		s.x.min.auto ? NaN : s.x.min.value, s.x.max.auto ? NaN : s.x.max.value)
	SIDAMSetAxis(grfName, NameOfWave(iw), "Y", \
		s.y.min.auto ? NaN : s.y.min.value, s.y.max.auto ? NaN : s.y.max.value)
	#if IgorVersion() >= 9
	DoUpdate/W=$grfName
	SetMarquee/W=$grfName/HAX=$(s.xaxis)/VAX=$(s.yaxis) mw[%x][0],mw[%y][1],mw[%x][1],mw[%y][0]
	#endif

	//	remove the fit result
	marqueeDoRemoveAttempt(grfName, dfrTmp)
End

Static StrConstant ATTEMPTNAME = "SIDAMPeakPosAttempt"

Static Function/DF marqueeDoDisplayAttempt(String grfName, Wave posw)
	DFREF dfrSav = GetDataFolderDFR()
	DFREF dfrTmp = $SIDAMNewDF(StringFromList(0, grfName, "#"),"PeakPos")

	SetDataFolder dfrTmp
	Make/N=5 xw={-posw[%xwidthneg], posw[%xwidthpos], nan, 0, 0}
	Make/N=5 yw={0,0,nan,-posw[%ywidthneg], posw[%ywidthpos]}
	Make/N=5 xw2, yw2
	SetDataFolder dfrSav

	xw2 = xw*cos(posw[%angle]) - yw*sin(posw[%angle]) + posw[%xcenter]
	yw2 = xw*sin(posw[%angle]) + yw*cos(posw[%angle]) + posw[%ycenter]
	AppendToGraph/W=$grfName yw2/TN=$ATTEMPTNAME vs xw2
	ModifyGraph/W=$grfName mode($ATTEMPTNAME)=0, mrkThick($ATTEMPTNAME)=1
	ModifyGraph/W=$grfName rgb($ATTEMPTNAME)=(65535,0,52428)
	
	return dfrTmp
End

Static Function marqueeDoRemoveAttempt(String grfName, DFREF dfrTmp)
	RemoveFromGraph/W=$grfName $ATTEMPTNAME
	DoUpdate/W=$grfName
	SIDAMKillDataFolder(dfrTmp)
End

Static Function marqueeDoSaveWave(Wave posw, DFREF dfr)
	//	Confirm whether saving the result
	String msg
	sprintf msg, "Position: (%g, %g)\rx width: (%g, %g)\ry width: (%g, %g)\r" \
		+ "angle: %g degree\rDo you want to save this result?", \
		posw[%xcenter], posw[%ycenter], posw[%xwidthneg], posw[%xwidthpos], \
		posw[%ywidthneg], posw[%ywidthpos], posw[%angle]/pi*180
	DoAlert 1, msg
	if (V_flag == 2)		//	no is selected
		return 0
	endif

	//	Enter a basename
	String basename = "peakPos"
	Prompt basename, "Enter a basename:"
	DoPrompt "Enter a basename", basename
	if (V_Flag)	// User canceled
		return 0
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
