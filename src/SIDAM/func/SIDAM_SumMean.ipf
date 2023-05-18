#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMSumMean

#include <DimensionLabelUtilities>

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Sum of wave elements over a given dimension.
//	The wave scaling and the dimension label in the other dimensions are
//	inherited in the return wave.
//
//	## Parameters
//	w : wave
//		The input wave.
//	dim : int {0 -- 3}
//		The dimension along which a sum is performed.
//
//	## Returns
//	wave
//		A free wave containing the sum values.
//		A null wave is returned when dim >= WaveDims(w)
//@
Function/WAVE SIDAMSum(Wave w, int dim)
	Make/L/U/N=4/FREE n = DimSize(w,p)
	Variable i

	if (dim == 0)
		MatrixOP/FREE tw = sumCols(w)	//	1, n1, n2, n3
		Redimension/N=(numpnts(tw)) tw
		Redimension/N=(n[1], n[2], n[3]) tw
		copyScaleLabel(w, tw, dim)

	elseif (dim == 1)
		MatrixOP/FREE tw = sumRows(w)	//	n0, 1, n2, n3
		Redimension/N=(numpnts(tw)) tw
		Redimension/N=(n[0], n[2], n[3]) tw
		copyScaleLabel(w, tw, dim)

	elseif (dim == 2 && WaveDims(w) == 3)
		MatrixOP/FREE tw = sumBeams(w)
		Copyscales/P w, tw
		CopyDimLabels/ROWS=0/COLS=1 w, tw

	elseif (dim == 2 && WaveDims(w) == 4)
		Duplicate/FREE/R=[0] w, tw	//	to maintain the wave precision
		Redimension/N=(n[0],n[1],n[3]) tw
		tw = 0
		for (i = 0; i < n[2]; i++)
			MultiThread tw += w[p][q][i][r]
		endfor
		Copyscales/P w, tw
		Setscale/P z DimOffset(w,3), DimDelta(w,3), WaveUnits(w,3), tw
		CopyDimLabels/ROWS=0/COLS=1/CHNK=2 w, tw

	elseif (dim == 3)
		MatrixOP/FREE tw = chunk(w,0)
		for (i = 1; i < n[3]; i++)
			MatrixOP/FREE tw = tw + chunk(w,i)
		endfor
		Copyscales/P w, tw
		CopyDimLabels/ROWS=0/COLS=1/LAYR=2 w, tw
	endif

	return tw
End

//@
//	Compute the arithmetic mean along the specified dimension.
//	The wave scaling and the dimension label in the other dimensions are
//	inherited in the return wave.
//
//	## Parameters
//	w : wave
//		The input wave.
//	dim : int {0 -- 3}
//		The dimension along which the mean is computed.
//
//	## Returns
//	wave
//		A free wave containing the mean values.
//		A null wave is returned when dim >= WaveDims(w)
//@
Function/WAVE SIDAMMean(Wave w, int dim)
	Make/L/U/N=4/FREE n = DimSize(w,p)

	if (dim == 0)
		MatrixOP/FREE tw = averageCols(w)	//	1, n1, n2, n3
		Redimension/N=(numpnts(tw)) tw
		Redimension/N=(n[1], n[2], n[3]) tw
		copyScaleLabel(w, tw, dim)

	elseif (dim == 1)
		MatrixOP/FREE tw = averageCols(w^t)^t
		Redimension/N=(numpnts(tw)) tw
		Redimension/N=(n[0], n[2], n[3]) tw
		copyScaleLabel(w, tw, dim)

	else
		Wave tw = SIDAMSum(w, dim)
		tw /= DimSize(w, dim)
	endif

	return tw
End

Static Function copyScaleLabel(Wave srcw, Wave destw, int dim)
	if (dim == 0)
		Setscale d 0, 1, WaveUnits(srcw,-1), destw
		Setscale/P x DimOffset(srcw,1), DimDelta(srcw,1), WaveUnits(srcw,1), destw
		Setscale/P y DimOffset(srcw,2), DimDelta(srcw,2), WaveUnits(srcw,2), destw
		Setscale/P z DimOffset(srcw,3), DimDelta(srcw,3), WaveUnits(srcw,3), destw
		if (WaveDims(srcw) == 2)
			CopyDimLabels/COLS=0 srcw, destw
		elseif (WaveDims(srcw) == 3)
			CopyDimLabels/COLS=0/LAYR=1 srcw, destw
		elseif (WaveDims(srcw) == 4)
			CopyDimLabels/COLS=0/LAYR=1/CHNK=2 srcw, destw
		endif
		
	elseif (dim == 1)
		Setscale d 0, 1, WaveUnits(srcw,-1), destw
		Setscale/P x DimOffset(srcw,0), DimDelta(srcw,0), WaveUnits(srcw,0), destw
		Setscale/P y DimOffset(srcw,2), DimDelta(srcw,2), WaveUnits(srcw,2), destw
		Setscale/P z DimOffset(srcw,3), DimDelta(srcw,3), WaveUnits(srcw,3), destw
		if (WaveDims(srcw) == 2)
			CopyDimLabels/ROWS=0 srcw, destw
		elseif (WaveDims(srcw) == 3)
			CopyDimLabels/ROWS=0/LAYR=1 srcw, destw
		elseif (WaveDims(srcw) == 4)
			CopyDimLabels/ROWS=0/LAYR=1/CHNK=2 srcw, destw
		endif
	endif
End


//----------------------
//	Functions for test
//----------------------
Static Constant testmode = 61	//	1+4+8+16+32

Static Function testSum4D(int n)
	Wave/WAVE ww = createTestData4D(n)
	Wave tw4D=ww[0], ref3a=ww[1], ref3b=ww[2], ref3c=ww[3], ref3d=ww[4]

	int i
	for (i = 0; i < DimSize(tw4D,0); i++)
		MultiThread ref3a += tw4D[i][p][q][r]
	endfor

	for (i = 0; i < DimSize(tw4D,1); i++)
		MultiThread ref3b += tw4D[p][i][q][r]
	endfor

	for (i = 0; i < DimSize(tw4D,2); i++)
		MultiThread ref3c += tw4D[p][q][i][r]
	endfor

	for (i = 0; i < DimSize(tw4D,3); i++)
		MultiThread ref3d += tw4D[p][q][r][i]
	endfor

	print equalwaves(ref3a, SIDAMSum(tw4D, 0), testmode)
	print equalwaves(ref3b, SIDAMSum(tw4D, 1), testmode)
	print equalwaves(ref3c, SIDAMSum(tw4D, 2), testmode)
	print equalwaves(ref3d, SIDAMSum(tw4D, 3), testmode)
End

Static Function testSum3D(int n)
	Wave/WAVE ww = createTestData3D(n)
	Wave tw3D=ww[0], ref2a=ww[1], ref2b=ww[2], ref2c=ww[3]

	int i
	for (i = 0; i < DimSize(tw3D,0); i++)
		MultiThread ref2a += tw3D[i][p][q]
	endfor

	for (i = 0; i < DimSize(tw3D,1); i++)
		MultiThread ref2b += tw3D[p][i][q]
	endfor

	for (i = 0; i < DimSize(tw3D,2); i++)
		MultiThread ref2c += tw3D[p][q][i]
	endfor
	
	print equalwaves(ref2a, SIDAMSum(tw3D, 0), testmode)
	print equalwaves(ref2b, SIDAMSum(tw3D, 1), testmode)
	print equalwaves(ref2c, SIDAMSum(tw3D, 2), testmode)
End

Static Function testSum2D(int n)
	Wave/WAVE ww = createTestData2D(n)
	Wave tw2D=ww[0], ref1a=ww[1], ref1b=ww[2]

	int i
	for (i = 0; i < DimSize(tw2D,0); i++)
		MultiThread ref1a += tw2D[i][p]
	endfor

	for (i = 0; i < DimSize(tw2D,1); i++)
		MultiThread ref1b += tw2D[p][i]
	endfor

	print equalwaves(ref1a, SIDAMSum(tw2D, 0), testmode)
	print equalwaves(ref1b, SIDAMSum(tw2D, 1), testmode)
End

Static Function testMean4D(int n)
	int i

	Wave/WAVE ww = createTestData4D(n)
	Wave tw4D=ww[0], ref3a=ww[1], ref3b=ww[2], ref3c=ww[3], ref3d=ww[4]

	for (i = 0; i < DimSize(tw4D,0); i++)
		MultiThread ref3a += tw4D[i][p][q][r]
	endfor
	ref3a /= DimSize(tw4D,0)

	for (i = 0; i < DimSize(tw4D,1); i++)
		MultiThread ref3b += tw4D[p][i][q][r]
	endfor
	ref3b /= DimSize(tw4D,1)

	for (i = 0; i < DimSize(tw4D,2); i++)
		MultiThread ref3c += tw4D[p][q][i][r]
	endfor
	ref3c /= DimSize(tw4D,2)

	for (i = 0; i < DimSize(tw4D,3); i++)
		MultiThread ref3d += tw4D[p][q][r][i]
	endfor
	ref3d /= DimSize(tw4D,3)

	print equalwaves(ref3a, SIDAMMean(tw4D, 0), testmode)
	print equalwaves(ref3b, SIDAMMean(tw4D, 1), testmode)
	print equalwaves(ref3c, SIDAMMean(tw4D, 2), testmode)
	print equalwaves(ref3d, SIDAMMean(tw4D, 3), testmode)
End

Static Function testMean3D(int n)
	Wave/WAVE ww = createTestData3D(n)
	Wave tw3D=ww[0], ref2a=ww[1], ref2b=ww[2], ref2c=ww[3]

	int i
	for (i = 0; i < DimSize(tw3D,0); i++)
		MultiThread ref2a += tw3D[i][p][q]
	endfor
	ref2a /= DimSize(tw3D,0)

	for (i = 0; i < DimSize(tw3D,1); i++)
		MultiThread ref2b += tw3D[p][i][q]
	endfor
	ref2b /= DimSize(tw3D,1)

	for (i = 0; i < DimSize(tw3D,2); i++)
		MultiThread ref2c += tw3D[p][q][i]
	endfor
	ref2c /= DimSize(tw3D,2)

	print equalwaves(ref2a, SIDAMMean(tw3D, 0), testmode)
	print equalwaves(ref2b, SIDAMMean(tw3D, 1), testmode)
	print equalwaves(ref2c, SIDAMMean(tw3D, 2), testmode)
End

Static Function testMean2D(int n)
	Wave/WAVE ww = createTestData2D(n)
	Wave tw2D=ww[0], ref1a=ww[1], ref1b=ww[2]

	int i
	for (i = 0; i < DimSize(tw2D,0); i++)
		MultiThread ref1a += tw2D[i][p]
	endfor
	ref1a /= DimSize(tw2D,0)

	for (i = 0; i < DimSize(tw2D,1); i++)
		MultiThread ref1b += tw2D[p][i]
	endfor
	ref1b /= DimSize(tw2D,1)

	print equalwaves(ref1a, SIDAMMean(tw2D, 0), testmode)
	print equalwaves(ref1b, SIDAMMean(tw2D, 1), testmode)
End


Static Function/WAVE createTestData4D(int n)
	Make/D/N=(n,n+1,n+2,n+3)/FREE tw = p + q*2 + r*4 + s*8
	Setscale d 0, 1, "-", tw
	Setscale/P x 0, 1, "a", tw
	Setscale/P y 1, 2, "b", tw
	Setscale/P z 2, 4, "c", tw
	Setscale/P t 3, 8, "d", tw
	Make/T/N=(n)/FREE lw0 = num2istr(p)
	Make/T/N=(n+1)/FREE lw1 = num2istr(p*2)
	Make/T/N=(n+2)/FREE lw2 = num2istr(p*4)
	Make/T/N=(n+3)/FREE lw3 = num2istr(p*8)
	CopyWaveToDimLabels(lw0, tw, 0)
	CopyWaveToDimLabels(lw1, tw, 1)
	CopyWaveToDimLabels(lw2, tw, 2)
	CopyWaveToDimLabels(lw3, tw, 3)

	Make/D/N=(n+1,n+2,n+3)/FREE ref0=0
	Setscale d 0, 1, "-", ref0
	Setscale/P x 1, 2, "b", ref0
	Setscale/P y 2, 4, "c", ref0
	Setscale/P z 3, 8, "d", ref0
	CopyWaveToDimLabels(lw1, ref0, 0)
	CopyWaveToDimLabels(lw2, ref0, 1)
	CopyWaveToDimLabels(lw3, ref0, 2)

	Make/D/N=(n,n+2,n+3)/FREE ref1=0
	Setscale d 0, 1, "-", ref1
	Setscale/P x 0, 1, "a", ref1
	Setscale/P y 2, 4, "c", ref1
	Setscale/P z 3, 8, "d", ref1
	CopyWaveToDimLabels(lw0, ref1, 0)
	CopyWaveToDimLabels(lw2, ref1, 1)
	CopyWaveToDimLabels(lw3, ref1, 2)

	Make/D/N=(n,n+1,n+3)/FREE ref2=0
	Setscale d 0, 1, "-", ref2
	Setscale/P x 0, 1, "a", ref2
	Setscale/P y 1, 2, "b", ref2
	Setscale/P z 3, 8, "d", ref2
	CopyWaveToDimLabels(lw0, ref2, 0)
	CopyWaveToDimLabels(lw1, ref2, 1)
	CopyWaveToDimLabels(lw3, ref2, 2)

	Make/D/N=(n,n+1,n+2)/FREE ref3=0
	Setscale d 0, 1, "-", ref3
	Setscale/P x 0, 1, "a", ref3
	Setscale/P y 1, 2, "b", ref3
	Setscale/P z 2, 4, "c", ref3
	CopyWaveToDimLabels(lw0, ref3, 0)
	CopyWaveToDimLabels(lw1, ref3, 1)
	CopyWaveToDimLabels(lw2, ref3, 2)

	Make/N=5/WAVE/FREE ww = {tw, ref0, ref1, ref2, ref3}
	return ww
End

Static Function/WAVE createTestData3D(int n)
	Make/D/N=(n,n+1,n+2,n+3)/FREE tw = p + q*2 + r*4
	Setscale d 0, 1, "-", tw
	Setscale/P x 0, 1, "a", tw
	Setscale/P y 1, 2, "b", tw
	Setscale/P z 2, 4, "c", tw
	Make/T/N=(n)/FREE lw0 = num2istr(p)
	Make/T/N=(n+1)/FREE lw1 = num2istr(p*2)
	Make/T/N=(n+2)/FREE lw2 = num2istr(p*4)
	CopyWaveToDimLabels(lw0, tw, 0)
	CopyWaveToDimLabels(lw1, tw, 1)
	CopyWaveToDimLabels(lw2, tw, 2)

	Make/D/N=(n+1,n+2,n+3)/FREE ref0=0
	Setscale d 0, 1, "-", ref0
	Setscale/P x 1, 2, "b", ref0
	Setscale/P y 2, 4, "c", ref0
	CopyWaveToDimLabels(lw1, ref0, 0)
	CopyWaveToDimLabels(lw2, ref0, 1)

	Make/D/N=(n,n+2,n+3)/FREE ref1=0
	Setscale d 0, 1, "-", ref1
	Setscale/P x 0, 1, "a", ref1
	Setscale/P y 2, 4, "c", ref1
	CopyWaveToDimLabels(lw0, ref1, 0)
	CopyWaveToDimLabels(lw2, ref1, 1)

	Make/D/N=(n,n+1,n+3)/FREE ref2=0
	Setscale d 0, 1, "-", ref2
	Setscale/P x 0, 1, "a", ref2
	Setscale/P y 1, 2, "b", ref2
	CopyWaveToDimLabels(lw0, ref2, 0)
	CopyWaveToDimLabels(lw1, ref2, 1)

	Make/N=5/WAVE/FREE ww = {tw, ref0, ref1, ref2}
	return ww
End

Static Function/WAVE createTestData2D(int n)
	Make/D/N=(n,n+1,n+2,n+3)/FREE tw = p + q*2
	Setscale d 0, 1, "-", tw
	Setscale/P x 0, 1, "a", tw
	Setscale/P y 1, 2, "b", tw
	Make/T/N=(n)/FREE lw0 = num2istr(p)
	Make/T/N=(n+1)/FREE lw1 = num2istr(p*2)
	CopyWaveToDimLabels(lw0, tw, 0)
	CopyWaveToDimLabels(lw1, tw, 1)

	Make/D/N=(n+1,n+2,n+3)/FREE ref0=0
	Setscale d 0, 1, "-", ref0
	Setscale/P x 1, 2, "b", ref0
	CopyWaveToDimLabels(lw1, ref0, 0)

	Make/D/N=(n,n+2,n+3)/FREE ref1=0
	Setscale d 0, 1, "-", ref1
	Setscale/P x 0, 1, "a", ref1
	CopyWaveToDimLabels(lw0, ref1, 0)

	Make/N=5/WAVE/FREE ww = {tw, ref0, ref1}
	return ww
End