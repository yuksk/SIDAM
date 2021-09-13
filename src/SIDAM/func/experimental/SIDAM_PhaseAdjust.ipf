#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Numerically adjust the phase of lock-in x and y signals.
//
//	## Parameters
//	xw : wave
//		The input wave of x channel, 1D or 3D.
//	yw : wave
//		The input wave of y channel, 1D or 3D. The phase is rotated
//		so that this channel becomes featureless.
//	suffix : string
//		The suffix of output waves. If this is given, phase-adjusted
//		waves are saved in the datafolders where each of x and y wave
//		is. The suffix is used for the name of saved waves.
//	order : int {0 or 1}, default 1
//		When this is 0, the variance of yw is minimized.
//		When this is 1, the variance of yw-(a*v+b) is minimized.
//		(v is the bias voltage.)
//
//	## Returns
//	wave
//		A wave reference wave containing phase-adjusted waves.
//		* x channel : `returnwave[%x]`
//		* y channel : `returnwave[%y]`
//		* angle : `returnwave[%angle]`
//@
Function/WAVE SIDAMPhaseAdjust(Wave xw, Wave yw, [String suffix, int order])
	order = ParamIsDefault(order) ? 1 : order
	
	if (validate(xw, yw))
		return $""
	endif
	
	if (WaveDims(xw) == 1)
		Wave/WAVE ww = fn1D(xw, yw, order)
	else
		Wave/WAVE ww = fn3D(xw, yw, order)
	endif
	
	if (!ParamIsDefault(suffix) && strlen(suffix))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder GetWavesDataFolderDFR(xw)
		saveResults(ww, "x", NameOfWave(xw)+suffix)
		saveResults(ww, "angle", NameOfWave(xw)+suffix+"_angle")
		SetDataFolder  GetWavesDataFolderDFR(yw)
		saveResults(ww, "y", NameOfWave(yw)+suffix)
		SetDataFolder dfrSav
	endif
	
	return ww
End

Static Function validate(Wave xw, Wave yw)
	String errMsg
	sprintf errMsg, "%s%s gave error: ", PRESTR_CAUTION, GetRTStackInfo(2)
	
	if (!EqualWaves(xw, yw, 512))
		print errMsg+"waves must be the same in dimensions."
		return 1
	endif
	
	if (WaveDims(xw) != 1 && WaveDims(xw) !=3)
		print errMsg+"waves must be 1D or 3D"
		return 1
	endif
End

Static Function saveResults(Wave/WAVE refw, String key, String name)
	Duplicate/O refw[%$key] $name
	refw[%$key] = $name
End

Static Function/WAVE fn1D(Wave xw, Wave yw, int order)
	Variable theta = get_phase(xw, yw, order)
	Make/D/FREE pw = {theta}
	MatrixOP/FREE xw_rot = xw*cos(theta) + yw*sin(theta)
	MatrixOP/FREE yw_rot = -xw*sin(theta) + yw*cos(theta)
	CopyScales xw, xw_rot, yw_rot
	
	Make/WAVE/FREE ww = {xw_rot, yw_rot, pw}
	SetDimLabel 0, 0, x, ww
	SetDimLabel 0, 1, y, ww
	SetDimLabel 0, 2, angle, ww
	return ww
End

Static Function/WAVE fn3D(Wave xw, Wave yw, int order)
	
	Duplicate/FREE xw, xw_rot
	Duplicate/FREE yw, yw_rot
	Make/D/N=(DimSize(xw,0),DimSize(xw,1))/FREE pw
	
	MultiThread pw = worker3D(xw_rot, yw_rot, xw, yw, order, p, q)
	Make/WAVE/FREE ww = {xw_rot, yw_rot, pw}
	SetDimLabel 0, 0, x, ww
	SetDimLabel 0, 1, y, ww
	SetDimLabel 0, 2, angle, ww
	return ww
End

ThreadSafe Static Function worker3D(Wave xw_rot, Wave yw_rot, 
	Wave xw, Wave yw, int order, Variable pp, Variable qq)

	MatrixOP/FREE xw1d = beam(xw, pp, qq)
	MatrixOP/FREE yw1d = beam(yw, pp, qq)
	SetScale/P x DimOffset(xw,2), DimDelta(xw,2), "", xw1d, yw1d
	
	Variable theta = get_phase(xw1d, yw1d, order)
	MatrixOP/FREE txw = xw1d*cos(theta) + yw1d*sin(theta)
	MatrixOP/FREE tyw = -xw1d*sin(theta) + yw1d*cos(theta)
	
	xw_rot[pp][qq][] = txw[r]
	yw_rot[pp][qq][] = tyw[r]
	
	return theta
End

//	Return a phase in radian
ThreadSafe Static Function get_phase(Wave xw, Wave yw, int order)
	
	MatrixOP/FREE xw_subtracted = subtractMean(xw,0)
	MatrixOP/FREE yw_subtracted = subtractMean(yw,0)
	MatrixOP/FREE xw_mean = mean(xw)
	MatrixOP/FREE yw_mean = mean(yw)
	MatrixOP/FREE xyw_mean = mean(xw*yw)
	MatrixOP/FREE xw_variance = mean(xw_subtracted*xw_subtracted)
	MatrixOP/FREE yw_variance = mean(yw_subtracted*yw_subtracted)
	
	Variable c1 = xw_variance[0], c2 = yw_variance[0]
	Variable c3 = xw_mean[0]*yw_mean[0] - xyw_mean[0]
	
	if (!order)
		return atan(c3*2 / (c2 - c1)) / 2
	endif
	
	Duplicate/FREE xw, vw
	vw = x
	MatrixOP/FREE vw_subtracted = subtractMean(vw,0)
	MatrixOP/FREE vw_variance = mean(vw_subtracted*vw_subtracted)
	MatrixOP/FREE yvw_variance = mean(yw_subtracted*vw_subtracted)
	MatrixOP/FREE xvw_variance = mean(xw_subtracted*vw_subtracted)
	
	Variable c4 = vw_variance[0], c5 = yvw_variance[0], c6 = xvw_variance[0]

	return atan((c3*c4 + c5*c6)*2 / ((c2-c1)*c4 - c5^2 + c6^2)) / 2
End
