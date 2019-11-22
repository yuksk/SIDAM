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
	String path = SIDAM_DF+":"
	if (strlen(procName))
		path += procName+":"
		if (strlen(grfName))
			path += grfName
		endif
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder root:
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
///	Kill a datafolder (dfr). This function is intended for killing the temporary
///	datafolder of SIDAM.
///	Kill waves in the datafolder and subfolders at first. If the waves are in
///	use, remove them from graphs and then kill them. If the waves are used as
///	color table waves, preserve them.
///	After killing waves as much as possible, the datafolder is kill if it has no
///	wave.
///	If the datafolder is killed, its parent is recursively kill if the parent
///	does not have either a wave nor a datafolder which is a sibling of the datafolder.
///
///	@param dfr	datafolder
///	@return	1 for dfr is invalid, otherwise 0
//******************************************************************************
Function SIDAMKillDataFolder(DFREF dfr)
	if (!DataFolderRefStatus(dfr))
		return 0
	elseif (DataFolderRefsEqual(dfr,root:))
		return 1
	endif

	int recursive = !CmpStr(GetRTStackInfo(1),GetRTStackInfo(2))
	int hasWave, hasDF
	if (recursive)
		hasWave = CountObjectsDFR(dfr,1)
		hasDF = CountObjectsDFR(dfr,4)
		if (hasWave || hasDf)
			return 2
		endif
	else
		killDependence(dfr)
		hasWave = killWaveDataFolder(dfr)
		if (hasWave)
			return 3
		endif
	endif

	DFREF pdfr = $ParseFilePath(1, GetDataFolder(1,dfr), ":", 1, 0)
	KillDataFolder dfr
	return SIDAMKillDataFolder(pdfr)
End

//	Kill waves in a datafolder and also in subfolders.
//	If waves are in use and unless they are color table waves, kill after removing
//	them from graphs. Kill a subfolder if it's empty after killing waves
//	@param dfr	Datafolder
//	@return		Number of waves remaining in the datafolder without being killed
Static Function killWaveDataFolder(DFREF dfr)	//	tested
	int i, n, count = 0
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder dfr

	//	Kill datafolders in the current datafolder, if possible
	for (i = CountObjectsDFR(dfr,4)-1; i >= 0; i--)
		KillDataFolder/Z $GetIndexedObjNameDFR(dfr,4,i)
	endfor

	//	Call recursively this function for remaining datafolders
	for (i = 0, n = CountObjectsDFR(dfr,4); i < n; i++)
		count += killWaveDataFolder($GetIndexedObjNameDFR(dfr,4,i))
	endfor

	removeImageTrace(dfr)
	KillWaves/A/Z
	count += CountObjectsDFR(dfr,1)

	if (DataFolderRefStatus(dfrSav))
		SetDataFolder dfrSav
	else
		SetDataFolder root:
	endif

	return count
End

//	Kill dependence to all waves, variables, and strings in a datafolder
//	@param dfr	Datafolder
Static Function killDependence(DFREF dfr)
	int type, i, n
	for (type = 1; type <= 3; type++)
		for (i = 0, n = CountObjectsDFR(dfr, type); i < n; i++)
			SetFormula dfr:$GetIndexedObjNameDFR(dfr, type, i), ""
		endfor
	endfor
End

//	Remove traces and images of waves in a datafolder from all displayed graphs
//	Color table waves are not removed.
//	@param dfr	DataFolder
Static Function removeImageTrace(DFREF dfr)	//	tested
	//	Not only graphs but also panels are included in the list because
	//	panels may contain graphs in subwindows
	String grfList = WinList("*",";","WIN:65")
	int i, n
	for (i = 0, n = ItemsInList(grfList); i < n; i++)
		removeImageTraceHelper(dfr, StringFromList(i,grfList))
	endfor
End
		
Static Function removeImageTraceHelper(DFREF dfr, String grfName)
	int i, j, n	
	String imgList, imgName, trcList, trcName
	
	String chdList = ChildWindowList(grfName)
	for (i = 0, n = ItemsInList(chdList); i < n; i++)
		removeImageTraceHelper(dfr, grfName+"#"+StringFromList(i,chdList))
	endfor	
	
	if (WinType(grfName) == 7)	//	panel
		return 0
	endif
	
	for (i = 0, n = CountObjectsDFR(dfr,1); i < n; i++)
		Wave/SDFR=dfr w = $GetIndexedObjNameDFR(dfr,1,i)
		CheckDisplayed/W=$grfName w
		if (!V_flag)
			continue
		endif

		imgList = ImageNameList(grfName,";")
		for (j = ItemsInList(imgList)-1; j >= 0; j--)
			imgName = StringFromList(j,imgList)
			if (WaveRefsEqual(w,ImageNameToWaveRef(grfName,imgName)))
				RemoveImage/W=$grfName $imgName
			endif
		endfor

		trcList = TraceNameList(grfName,";",1)
		for (j = ItemsInList(trcList)-1; j >= 0; j--)
			trcName = StringFromList(j,trcList)
			Wave yw = TraceNameToWaveRef(grfName,trcName)
			Wave/Z xw = XWaveRefFromTrace(grfName,trcName)
			if (WaveRefsEqual(w,yw) || WaveRefsEqual(w,xw))
				RemoveFromGraph/W=$grfName $trcName
			endif
		endfor
	endfor
End

//******************************************************************************
///	Return an extended wave with an end effect similar to that of Smooth
///	@param w	input 2D/3D wave
///	@param endeffect
//		0: bounce, w[-i] = w[i], w[n+i] = w[n-i]
//		1: wrap, w[-i] = w[n-i], w[n+i] = w[i]
//		2: zero, w[-i] = w[n+i] = 0
//		3: repeat, w[-i] = w[0], w[n+i] = w[n]
//******************************************************************************
Function/WAVE SIDAMEndEffect(Wave w, int endeffect)
	if (WaveDims(w) != 2 && WaveDims(w) != 3)
		return $""
	elseif (WaveType(w) & 0x01) //	complex
		return $""
	elseif (endeffect < 0 || endeffect > 3)
		return $""
	endif

	int nx = DimSize(w,0), ny = DimSize(w,1), nz = DimSize(w,2)
	int mx = nx-1, my = ny-1
	switch (endeffect)
		case 0:	//	bounce
			Duplicate/FREE w, xw, yw, xyw
			Reverse/P/DIM=0 xw, xyw
			Reverse/P/DIM=1 yw, xyw
			Concatenate/FREE/NP=0 {xyw, yw, xyw}, ew2	//	top and bottom
			Concatenate/FREE/NP=0 {xw, w, xw}, ew1		//	middle
			Concatenate/FREE/NP=1 {ew2, ew1, ew2}, ew
			break
		case 1:	//	wrap
			Concatenate/FREE/NP=0 {w, w, w}, ew1
			Concatenate/FREE/NP=1 {ew1, ew1, ew1}, ew
			break
		case 2:	//	zero
			Duplicate/FREE w, zw
			MultiThread zw = 0
			Concatenate/FREE/NP=0 {zw, w, zw}, ew1	//	middle
			Redimension/N=(nx*3,-1,-1) zw			//	top and bottom
			Concatenate/FREE/NP=1 {zw, ew1, zw}, ew
			break
		case 3:	//	repeat
			Duplicate/FREE w, ew1, ew2, ew3
			MultiThread ew1 = w[0][0][r]			//	left, bottom
			MultiThread ew2 = w[p][0][r]			//	center, bottom
			MultiThread ew3 = w[mx][0][r]			//	right, bottom
			Concatenate/FREE/NP=0 {ew1,ew2,ew3}, bottom
			MultiThread ew1 = w[0][q][r]			//	left, middle
			MultiThread ew2 = w[mx][q][r]			//	right, middle
			Concatenate/FREE/NP=0 {ew1,w,ew2}, middle
			MultiThread ew1 = w[0][my][r]			//	left, top
			MultiThread ew2 = w[p][my][r]			//	center, top
			MultiThread ew3 = w[mx][my][r]		//	right, top
			Concatenate/FREE/NP=0 {ew1,ew2,ew3}, top
			Concatenate/FREE/NP=1 {bottom,middle,top}, ew
			break
	endswitch

	SetScale/P x DimOffset(w,0)-DimDelta(w,0)*nx, DimDelta(w,0), WaveUnits(w,0), ew
	SetScale/P y DimOffset(w,1)-DimDelta(w,1)*ny, DimDelta(w,1), WaveUnits(w,1), ew
	SetScale/P z DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), ew

	return ew
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
