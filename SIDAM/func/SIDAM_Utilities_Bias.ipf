#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilBias

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Functions for dealing with unevenly spaced biases
//******************************************************************************
///	Set information of unevenly spaced biases
///	@param w		A 3D wave
///	@param biasw	A 1D numeric wave containing bias values
///	@return		0: Successfully copied
///					!0:	Error
Function SIDAMSetBias(Wave/Z w, Wave/Z biasw)
	if (!WaveExists(w) || !WaveExists(biasw))
		return 1
	elseif (WaveDims(w) != 3)
		return 2
	elseif (DimSize(w,2) != numpnts(biasw))
		return 3
	elseif (WaveType(biasw) & 0x01)	//	complx
		return 4
	elseif (WaveType(biasw,1) != 1)	//	not numeric
		return 5
	endif

	int i, n = numpnts(biasw)
	for (i = 0; i < n; i++)
		SetDimLabel 2, i, $num2str(biasw[i]), w
	endfor
	return 0
End

///	Return a wave of unevenly spaced biases
///	@param w		A 3D wave with unevenly spaced biases
///	@param dim	1: The returned wave contains unevely spaced biases as they are.
///						This is used as an x wave to display a trace.
///					2: The returned wave contains average two neighboring layers.
///						This is used as an x wave or a y wave to display an image.
///	@return		a 1D wave, or a null wave for any error
Function/WAVE SIDAMGetBias(Wave/Z w, int dim)
	if (SIDAMisUnevenlySpacedBias(w) != 1 || dim < 1 || dim > 2)
		return $""
	endif
	int nz = DimSize(w,2)

	Make/N=(nz)/FREE tw = str2num(GetDimLabel(w,2,p))
	if (dim == 1)
		return tw
	endif

	//	dim == 2
	Make/N=(nz+1)/FREE biasw
	biasw[1,nz-1] = (tw[p-1]+tw[p])/2
	biasw[0] = tw[0]*2 - biasw[1]
	biasw[nz] = tw[nz-1]*2 - biasw[nz-1]
	return biasw
End

///	Copy information of unevevly spaced biases from one to another
///	@param srcw	A 3D wave with unevenly spaced biases
///	@param destw	A 3D wave to which the information is copied from srcw
///	@return		0: Successfully copied
///					1:	Error
Function SIDAMCopyBias(Wave/Z srcw, Wave/Z destw)
	if (SIDAMisUnevenlySpacedBias(srcw) != 1 || DimSize(srcw,2)!=DimSize(destw,2))
		return 1
	endif
	int i, nz = DimSize(srcw,2)
	for (i = 0; i < nz; i++)
		SetDimLabel 2, i, $GetDimLabel(srcw, 2, i), destw
	endfor
	return 0
End

///	Return if a wave is a 3D wave with unevenly spaced biases
///	@param w	A 3D wave
///	@return 	0:	false
///				1:	true
///				-1:	error
Function SIDAMisUnevenlySpacedBias(Wave/Z w)		//	tested
	if (!WaveExists(w))
		return -1
	elseif (WaveDims(w) != 3)
		return 0
	endif
	Make/N=(DimSize(w,2))/FREE tw = numtype(str2num(GetDimlabel(w,2,p)))
	return WaveMax(tw) == 0	//	true if all labels are numeric
End


///	Extension of ScaleToIndex
///	@param w		A wave
///	@param value	A scaled index
///	@param dim	A dimension number from 0 to 3
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

///	Extension of IndexToScale
///	@param w		A wave
///	@param index	An integer
///	@param dim	A dimension number from 0 to 3
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
