#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMPeakPos

#include "SIDAM_Utilities_Image"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Find a peak position by fitting
//
//	Parameters
//	----------
//	w : wave
//		The input wave. If a marquee is shown, use the area specified
//		by the marquee. If not, use the whole wave.
//	fitfn : int
//		The fitting function, 0: asymGauss2D, 1: asymLor2D
//
//	Returns
//	-------
//	wave
//		The fitting results are given as follows.
//
//			* offset : returnwave[%offset]
//			* amplitude : returnwave[%amplitude]
//			* peak position : returnwave[%xcenter], returnwave[%ycenter]
//			* peak width : returnwave[%xwidthpos], returnwave[%xwidthneg], returnwave[%ywidthpos], returnwave[%ywidthneg]
//			* peak angle : returnwave[%angle]
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
	String grfName = WinName(0,1)
	Wave iw = SIDAMImageWaveRef(grfName)
	try
		Wave posw = SIDAMPeakPos(iw, mode)
	catch
		DoAlert 0, "Failed to fit "+num2istr(V_AbortCode)
		return 0
	endtry
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(iw)
	String name = Uniquename("peakPos",1,0)
	Duplicate posw $name
	SetDataFolder dfrSav
	
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=xw={-posw[%xwidthneg], posw[%xwidthpos], nan, 0, 0}
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=yw={0,0,nan,-posw[%ywidthneg], posw[%ywidthpos]}
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=xw2
	Make/N=5 $(Uniquename("wave",1,0))/WAVE=yw2
	xw2 = xw*cos(posw[%angle]) - yw*sin(posw[%angle]) + posw[%xcenter]
	yw2 = xw*sin(posw[%angle]) + yw*cos(posw[%angle]) + posw[%ycenter]
	AppendToGraph/W=$grfName yw2 vs xw2
	ModifyGraph/W=$grfName mode($NameOfWave(yw2))=0, mrkThick($NameOfWave(yw2))=1, rgb($NameOfWave(yw2))=(65535,0,52428)
	String msg0, msg1
	sprintf msg0, "Output wave: %s\rPosition: (%g, %g)\r"\
		, GetWavesDataFolder(iw,1)+name, posw[%xcenter], posw[%ycenter]
	sprintf msg1, "x width: (%g, %g)\ry width: (%g, %g)\rangle: %g degree"\
		, posw[%xwidthneg], posw[%xwidthpos], posw[%ywidthneg], posw[%ywidthpos], posw[%angle]/pi*180
	DoUpdate/W=$grfName
	DoAlert 0, msg0+msg1
	RemoveFromGraph/W=$grfName $NameOfWave(yw2)
	KillWaves xw, yw, xw2, yw2
End

Static Function/S marqueeMenu(int mode)
	Wave/Z w = SIDAMImageWaveRef(WinName(0,1))	
	
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
