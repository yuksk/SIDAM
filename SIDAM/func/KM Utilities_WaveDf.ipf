#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilWaveDf

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Create SIDAM temporary folder root:Packages:SIDAM:procName:grfName and
//	return a string containing the path.
//******************************************************************************
Function/S SIDAMNewDF(String grfName, String procName)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder root:
	String path = SIDAM_DF+":"+procName+":"+grfName
	int i
	for (i = 1; i < ItemsInList(path,":"); i++)
		NewDataFolder/O/S $StringFromList(i,path,":")
	endfor
	String dfTmp = GetDataFolder(1)
	SetDataFolder dfrSav
	return dfTmp
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

//******************************************************************************
//	KMEndEffect:	端処理を実現するために、拡張ウエーブを返す
//		0: bounce, w[-i] = w[i], w[n+i] = w[n-i]
//		1: wrap, w[-i] = w[n-i], w[n+i] = w[i]
//		2: zero, w[-i] = w[n+i] = 0
//		3: repeat, w[-i] = w[0], w[n+i] = w[n]
//******************************************************************************
Function/WAVE KMEndEffect(w,endeffect)
	Wave w
	Variable endeffect		//	0: bounce, 1: wrap, 2: zero, 3: repeat

	switch (endeffect)
		case 0:	//	bounce
			Make/N=(DimSize(w,0), DimSize(w,1), DimSize(w,2))/FREE xw, yw, xyw
			Reverse/P/DIM=0 w/D=xw				//	左右反転
			Reverse/P/DIM=1 w/D=yw, xw/D=xyw	//	上下反転・上下左右反転

			Duplicate/FREE xyw ew0, ew2			//	左下・左上
			Duplicate/FREE xw ew1				//	左中

			Concatenate/NP=0 {yw, xyw}, ew0		//	下
			Concatenate/NP=0 {w, xw}, ew1			//	中
			Concatenate/NP=0 {yw, xyw}, ew2		//	上
			Concatenate/NP=1 {ew1, ew2}, ew0		//	上中下合体
			break
		case 1:	//	wrap
			Duplicate/FREE w ew1
			Concatenate/NP=0 {w, w}, ew1			//	行
			Duplicate/FREE ew1, ew0
			Concatenate/NP=1 {ew1, ew1}, ew0		//	上中下合体
			break
		case 2:	//	zero
			Make/N=(DimSize(w,0), DimSize(w,1), DimSize(w,2))/FREE ew1, ew2
			Concatenate/NP=0 {w, ew2}, ew1		//	中
			Make/N=(DimSize(w,0)*3, DimSize(w,1), DimSize(w,2))/FREE ew0, ew3
			Concatenate/NP=1 {ew1, ew3}, ew0		//	上中下合体
			break
		case 3:	//	repeat
			Variable mx = DimSize(w,0)-1, my = DimSize(w,1)-1
			Make/N=(DimSize(w,0), DimSize(w,1), DimSize(w,2))/FREE ew0, ew1, ew2, ew3, ew4
			MultiThread ew0 = w[0][0]			//	左下
			MultiThread ew1 = w[p][0]			//	中下
			MultiThread ew2 = w[mx][0]			//	右下
			Concatenate/NP=0 {ew1, ew2}, ew0	//	下合体
			MultiThread ew1 = w[0][q]			//	左中
			MultiThread ew2 = w[mx][q]			//	右中
			Concatenate/NP=0 {w, ew2}, ew1	//	中合体
			MultiThread ew2 = w[0][my]			//	左上
			MultiThread ew3 = w[p][my]			//	中上
			MultiThread ew4 = w[mx][my]		//	右上
			Concatenate/NP=0 {ew3, ew4}, ew2	//	上合体
			Concatenate/NP=1 {ew1, ew2}, ew0	//	上中下合体
			break
	endswitch

	SetScale/P x DimOffset(w,0)-DimDelta(w,0)*DimSize(w,0), DimDelta(w,0), WaveUnits(w,0), ew0
	SetScale/P y DimOffset(w,1)-DimDelta(w,1)*DimSize(w,1), DimDelta(w,1), WaveUnits(w,1), ew0
	SetScale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), ew0

	return ew0
End

//******************************************************************************
//	return number of waves selected in the data browser
//******************************************************************************
Function SIDAMnumberOfSelectedWaves()
	int i = 0, n = 0
	if (!strlen(GetBrowserSelection(-1)))
		return 0
	endif
	do
		n += WaveExists($GetBrowserSelection(i))
	while(strlen(GetBrowserSelection(++i)))
	return n
End
