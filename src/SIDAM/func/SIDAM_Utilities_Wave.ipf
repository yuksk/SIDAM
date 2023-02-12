#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilWave

#include "SIDAM_Bias"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Return a reference wave containing references to waves selected in the
//	Data Browser.
//******************************************************************************
Function/WAVE SIDAMSelectedWaves()
	int isNothingSelected = !strlen(GetBrowserSelection(-1))
	if (isNothingSelected)
		return $""
	endif
	
	int i = 0, numOfSelectedWaves = 0
	do
		numOfSelectedWaves += WaveExists($GetBrowserSelection(i))
	while(strlen(GetBrowserSelection(++i)))
	
	Make/N=(numOfSelectedWaves)/WAVE/FREE ww=$GetBrowserSelection(p)
	return ww
End

//******************************************************************************
//	return 0 if FFT is available for the input wave
//******************************************************************************
Function SIDAMValidateWaveforFFT(Wave/Z w)

	if (!WaveExists(w))
		return 1

	elseif (WaveDims(w) != 2 && WaveDims(w) != 3)
		return 2

	// number in the x direction must be even
	elseif (mod(DimSize(w,0),2))
		return 3

	//  minimun data points are 4
	elseif (DimSize(w,0) < 4 || DimSize(w,1) < 4)
		return 4

	//	not complex, FFT itself is available also for complex, though
	elseif (WaveType(w,0) & 0x01)
		return 5

	//	must not contain NaN or INF, faster than WaveStats
	elseif (numtype(sum(w)))
		return 6
		
	endif
	
	return 0
End

Function/S SIDAMValidateWaveforFFTMsg(int flag)

	Make/T/FREE tw = {\
		"",\
		"The input wave not found.",\
		"The dimension of input wave must be 2 or 3.",\
		"The first dimension of input wave must be an even number.",\
		"The minimum length of input wave is 4 points.",\
		"The input wave must be real.",\
		"The input wave must not contain NaNs or INFs."\
	}
	return tw[flag]
End

//@
//	Extension of `ScaleToIndex()` that includes unevenly-spaced bias
//
//	## Parameters
//	w : wave
//		The input wave
//	value : int
//		A scaled coordinate value
//	dim : int {0 -- 3}
//		Specify the dimension.
//		* 0: Rows
//		* 1: Columns
//		* 2: Layers
//		* 3: Chunks
//
//	## Returns
//	variable
//		The index value
//@
Function SIDAMScaleToIndex(Wave/Z w, Variable value, int dim)
	if (!WaveExists(w))
		return nan
	elseif (dim < 0 || dim > 3)
		return nan
	endif

	if (dim == 2 && SIDAMisUnevenlySpacedBias(w))
		//	search index corresponding to the nearest value
		Make/N=(DimSize(w,2))/FREE dw = abs(str2num(GetDimLabel(w,2,p))-value), iw = p
		Sort dw, iw
		return iw[0]
	else
		return ScaleToIndex(w,value,dim)
	endif
End

//@
//	Extension of `IndexToScale()` that includes unevenly-spaced bias
//
//	## Parameters
//	w : wave
//		The input wave
//	index : int
//		An index number
//	dim : int {0 -- 3}
//		Specify the dimension.
//		* 0: Rows
//		* 1: Columns
//		* 2: Layers
//		* 3: Chunks
//
//	## Returns
//	variable
//		The scaled coordinate value
//@
Function SIDAMIndexToScale(Wave w, int index, int dim)
	if (!WaveExists(w))
		return nan
	elseif (dim < 0 || dim > 3)
		return nan
	endif

	if (dim == 2 && SIDAMisUnevenlySpacedBias(w))
		return str2num(GetDimLabel(w,dim,index))
	else
		return IndexToScale(w,index,dim)
	endif
End


//******************************************************************************
///	Return a string converted from a wave
///	@param w			A 1D text wave, a 1D/2D numeric wave
///	@param noquote	Elements of a text wave are returned without quotation marks
//******************************************************************************
Function/S SIDAMWaveToString(Wave/Z w, [int noquote])
	if (!WaveExists(w))
		return ""
	endif

	int isNumeric = WaveType(w,1) == 1
	int isText = WaveType(w,1) == 2
	noquote = ParamIsDefault(noquote) ? 0 : noquote

	if (isText && WaveDims(w)==1)
		return join(w,noquote)

	elseif (isNumeric && WaveDims(w)==1)
		return join(num2text(w),1)

	elseif (isNumeric && WaveDims(w)==2)
		Make/T/N=(DimSize(w,1))/FREE txtw = join(num2text(col(w,p)),1)
		return join(txtw,1)

	else
		return ""
	endif
End

//	Join elements of a text wave and return as a string
Static Function/S join(Wave/T tw, int noquote)
	int i, n = numpnts(tw)
	String str = ""

	if (noquote)
		for (i = 0; i < n; i++)
			str += tw[i] + ","
		endfor
	else
		for (i = 0; i < n; i++)
			str += "\"" + tw[i] + "\","
		endfor
	endif
	return "{" + str[0,strlen(str)-2] + "}"
End

//	Convert a 1D numeric wave to a 1D text wave
Static Function/WAVE num2text(Wave w)
	Make/T/N=(numpnts(w))/FREE txtw = num2str(w[p])
	return txtw
End

//	Return a column of a numeric wave
Static Function/WAVE col(Wave w, Variable index)
	MatrixOP/FREE cw = col(w,index)
	return cw
End