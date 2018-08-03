#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	

#ifndef SIDAMstarting
#include "KM Utilities_Str"		//	for KMUnquoteName
#endif

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

	//	Rename the temporary folder from '_KM' to '_SIDAM'
	updateTemporaryDF("")

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

//--------------------------------------------------------------------------------------

StrConstant OLD_DF = "root:'_KM'"

Static Function updateTemporaryDF(String listStr)
	if (!strlen(listStr))
		listStr = WinList("*",";","WIN:1")
	endif
	
	int i, j
	String win, chdList, dfTmp
	for (i = 0; i < ItemsInList(listStr); i++)
		win = StringFromList(i,listStr)
		chdList = ChildWindowList(win)
		if (strlen(chdList))
			for (j = 0; j < ItemsInList(chdList); j++)
				updateTemporaryDF(win+"#"+StringFromList(j,chdList))
			endfor
		endif
		dfTmp = GetUserData(win,"","dfTmp")
		if (!strlen(dfTmp))
			continue
		endif
		SetWindow $win userData(dfTmp) = ReplaceString(OLD_DF,dfTmp,SIDAM_DF)
	endfor
	
	if (DataFolderExists(OLD_DF))
		RenameDataFolder $OLD_DF $KMUnquoteName(StringFromList(1,SIDAM_DF,":"))
	endif
	
	if (DataFolderExists(SIDAM_DF_CTAB+"KM"))
		RenameDataFolder $(SIDAM_DF_CTAB+"KM") SIDAM
	endif
End

#endif