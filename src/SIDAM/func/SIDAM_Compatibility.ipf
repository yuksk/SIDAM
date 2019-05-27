#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#ifdef SIDAMstarting
// Update All KM Procedures.ipf for backward compatibility
Function SIDAMBackwardCompatibility()
	updateOldIncludeFile()
	updateOldPackageFile()
End
#endif

#ifndef SIDAMstarting
Function SIDAMBackwardCompatibility()
	//	Change the unit string from ﾅ \u00c5 (Igor Pro 6 -> 7)
	angstromStr(root:)

	//	Set the temporary folder to root:Packages:SIDAM
	updateDF("")
	
	//	Rename KM*Hook to SIDAM*Hook
	updateHookFunctions()
	
	//	If All KM Procedures.ipf is included, it means that this function is called in opening 
	//	an experiment file in which KM was used and that #include "All KM Procedures" exists
	//	in the procedure window. The following is to remove the dependence to the old file.
	if (strlen(WinList(KM_FILE_INCLUDE+".ipf",";","WIN:128")) > 0)
		Execute/P "DELETEINCLUDE \"" + KM_FILE_INCLUDE + "\""
		Execute/P "INSERTINCLUDE \"" + SIDAM_FILE_INCLUDE + "\""
		Execute/P "COMPILEPROCEDURES "
	endif
End
#endif

//--------------------------------------------------------------------------------------

#ifdef SIDAMstarting

Static Function updateOldIncludeFile()
	Variable refNum
	String pathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	Open/P=$pathName/Z refNum, as KM_FILE_INCLUDE+".ipf"
	if (!V_flag)
		fprintf refNum, "//\tThis file is left for backward compatibility to prevent a compile error\r"
		fprintf refNum, "//\tin opening an experiment file created by Kohsaka Macro. You can remove\r"
		fprintf refNum, "//\tthis file and solve the error by yourself. In the error dialog saying\r"
		fprintf refNum, "//\t\"include file not found\", you can edit the command from '#include \"All\r"
		fprintf refNum, "//\tKM Procedures\"' to '#include \"SIDAM_Procedures\" and click the Retry button.\r"
		fprintf refNum, "#include \"%s\"\r", SIDAM_FILE_INCLUDE
		Close refNum
	endif
	KillPath $pathName
End

Static Function updateOldPackageFile()
	String packages = SpecialDirPath("Packages",0,0,0)
	MoveFolder/Z packages+"Kohsaka Macro" as packages+"SIDAM"
	if (V_flag)	//	Old directory did not exist
		return 0
	endif
	MoveFile/Z packages+"SIDAM:KM.bin" as packages+"SIDAM:SIDAM.bin"
End
#endif

//--------------------------------------------------------------------------------------

#ifndef SIDAMstarting

Static Function angstromStr(DFREF dfr)
	int i, n, dim
	
	for (i = 0, n = CountObjectsDFR(dfr, 4); i < n; i++)
		angstromStr(dfr:$GetIndexedObjNameDFR(dfr, 4, i))
	endfor
	
	for (i = 0, n = CountObjectsDFR(dfr, 1); i < n; i++)
		Wave/SDFR=dfr w = $GetIndexedObjNameDFR(dfr, 1, i)
		for (dim = -1; dim <= 3; dim++)
			changeUnitStr(w, dim)
		endfor
	endfor
End

Static Function changeUnitStr(Wave w, int dim)
	String oldUnit = "ﾅ"
	String newUnit = "\u00c5"
	String unit = WaveUnits(w,dim)
	
	if (CmpStr(ConvertTextEncoding(unit,4,1,3,0), oldUnit) && CmpStr(unit, oldUnit))
		return 0
	endif
	
	SetWaveTextEncoding 1,2, w
	switch (dim)
		case -1:
			Setscale d, WaveMin(w), WaveMax(w), newUnit, w
			break
		case 0:
			Setscale/P x DimOffset(w,0), DimDelta(w,0), newUnit, w
			break
		case 1:
			Setscale/P y DimOffset(w,1), DimDelta(w,1), newUnit, w
			break
		case 2:
			Setscale/P z DimOffset(w,2), DimDelta(w,2), newUnit, w
			break
		case 3:
			Setscale/P t DimOffset(w,3), DimDelta(w,3), newUnit, w
			break
	endswitch
	
	return 1
End

Static StrConstant OLD_DF1 = "root:'_KM'"
Static StrConstant OLD_DF2 = "root:'_SIDAM'"

Static Function updateDF(String grfPnlList)
	//	When grfPnlList is given, update the information recorded
	//	in userdata of each window.
	if (strlen(grfPnlList))
		int i
		for (i = 0; i < ItemsInList(grfPnlList); i++)
			updateDFUserData(StringFromList(i,grfPnlList))
		endfor
		return 0
	endif
	
	//	When grfPnlList is empty (this is how this function called
	//	from SIDAMBackwardCompatibility), update the datafolders.
	DFREF dfrSav = GetDataFolderDFR()
	
	if (DataFolderExists(OLD_DF1))
		NewDataFolder/O/S root:Packages
		MoveDataFolder $OLD_DF1 :
		RenameDataFolder '_KM', SIDAM
	elseif (DataFolderExists(OLD_DF2))
		NewDataFolder/O/S root:Packages
		MoveDataFolder $OLD_DF2 :
		RenameDataFolder '_SIDAM', SIDAM
	endif
	
	if (DataFolderExists(SIDAM_DF_CTAB+"KM"))
		RenameDataFolder $(SIDAM_DF_CTAB+"KM") SIDAM
	endif	
	
	updateDFMatplotlib()
	
	SetDataFolder dfrSav
	
	String winListStr = WinList("*",";","WIN:65")
	if (strlen(winListStr))
		updateDF(winListStr)
	endif
End

Static Function updateDFMatplotlib()
	int exist1 = DataFolderExists(SIDAM_DF_CTAB+"Matplotlib1")
	int exist2 = DataFolderExists(SIDAM_DF_CTAB+"Matplotlib2")
	
	if (!exist1 && !exist2)
		return 0
	elseif (exist1 && !exist2)
		RenameDataFolder $(SIDAM_DF_CTAB+"Matplotlib1") Matplotlib
		return 0
	elseif (!exist1 && exist2)
		RenameDataFolder $(SIDAM_DF_CTAB+"Matplotlib2") Matplotlib
		return 0
	endif
	
	//	The remaining case is both 1 and 2 exist
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder $SIDAM_DF_CTAB
	
	RenameDataFolder Matplotlib1 Matplotlib
	SetDataFolder Matplotlib2
	int i
	for (i = CountObjectsDFR(:,4)-1; i >= 0; i--)
		MoveDataFolder $GetIndexedObjNameDFR(:,4,i) ::Matplotlib
	endfor
	SetDataFolder ::
	KillDataFolder Matplotlib2
	
	SetDataFolder dfrSav
End

Static Function updateDFUserData(String grfName)
	String chdList = ChildWindowList(grfName), chdName
	String oldTmp, newTmp
	int i, j, n0, n1
	for (i = 0; i < ItemsInList(chdList); i++)
		chdName = StringFromList(i,chdList)
		if (CmpStr(chdName,"Color"))
			updateDFUserData(grfName+"#"+chdName)
		else
			String oldList = GetUserData(chdName,"","KMColorSettings"), newList="", item
			for (j = 0; j < ItemsInList(oldList); j++)
				item = StringFromList(j,oldList)
				n0 = strsearch(item,"ctab=",0)
				n1 = strsearch(item,":ctable:",n1)
				newList += ReplaceString(item[n0+5,n1+7],item,SIDAM_DF_CTAB)+";"
			endfor
			SetWindow $chdName userData(SIDAMColorSettings)=newList
			SetWindow $chdName userData(KMColorSettings)=""
		endif
	endfor
	oldTmp = GetUserData(grfName,"","dfTmp")
	if (strlen(oldTmp))
		newTmp = ReplaceString(OLD_DF1,oldTmp,SIDAM_DF)
		newTmp = ReplaceString(OLD_DF2,newTmp,SIDAM_DF)
		SetWindow $grfName userData(dfTmp)=newTmp
	endif
End

Static Function updateHookFunctions()
	SetIgorHook BeforeFileOpenHook
	if (WhichListItem("ProcGlobal#KMFileOpenHook",S_info) >= 0)
		SetIgorHook/K BeforeFileOpenHook = KMFileOpenHook
		SetIgorHook BeforeFileOpenHook = SIDAMFileOpenHook
	endif
	
	SetIgorHook BeforeExperimentSaveHook
	if (WhichListItem("ProcGlobal#KMBeforeExperimentSaveHook",S_info) >= 0)
		SetIgorHook/K BeforeExperimentSaveHook = KMBeforeExperimentSaveHook
		SetIgorHook BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	endif
	
	SetIgorHook AfterCompiledHook
	if (WhichListItem("ProcGlobal#KMAfterCompiledHook",S_info) >= 0)
		SetIgorHook/K AfterCompiledHook = KMAfterCompiledHook
		SetIgorHook AfterCompiledHook = SIDAMAfterCompiledHook
	endif	
End

#endif
