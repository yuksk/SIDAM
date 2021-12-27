#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilDf

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

	if (WinType(grfName) != 1)	//	not graph
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