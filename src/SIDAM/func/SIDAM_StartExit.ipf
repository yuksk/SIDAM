#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Constants"
#include "SIDAM_Utilities_misc"

//******************************************************************************
//	Start SIDAM
//******************************************************************************
Function SIDAMStart()
	printf "\r SIDAM %d.%d.%d\r", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH

	//	List ipf files to be included and write them into SIDAM_Procedures.ipf
	makeProcFile()
	Execute/P "INSERTINCLUDE \"" + SIDAM_FILE_INCLUDE + "\""
	Execute/P "COMPILEPROCEDURES "

	SetIgorHook BeforeFileOpenHook = SIDAMFileOpenHook
	SetIgorHook BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	SetIgorHook AfterCompiledHook = SIDAMAfterCompiledHook
End

Static Function makeProcFile()
	// Prepare SIDAM_Procedures.ipf
	Variable refNum
	String pathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	Open/P=$pathName/Z refNum, as SIDAM_FILE_INCLUDE+".ipf"
	KillPath $pathName
	if (V_flag)
		return 0
	endif

	//	Make a list of ipf files
	Make/T/FREE w0 = {"SIDAM_Menus.ipf", "SIDAM_Constants.ipf", "SIDAM_Hook.ipf"}
	Wave/T w1 = fnList(SIDAM_FOLDER_LOADER)
	Wave/T w2 = fnList(SIDAM_FOLDER_EXT, recursive=1)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	Concatenate/NP/T {w0, w1, w2}, lw
	SetDataFolder dfrSav

	int i

	//	write the hide pragma
	fprintf refNum,  "#ifndef SIDAMshowProc\r#pragma hide = 1\r#endif\r"
	//	write #include ...
	for(i = 0; i < numpnts(lw); i++)
		fprintf refNum, "#include \"%s\"\r", RemoveEnding(lw[i],".ipf")
	endfor
	//	write StrConstant SIDAM_CTABGROUPS
	fprintf refNum, "StrConstant SIDAM_CTABGROUPS = \"%s\"\r", getCtabGroups()

	Close refNum
	return 1
End

//	make a list of ipf files under subFolder
Static Function/WAVE fnList(String subFolder, [int recursive])
	recursive = ParamIsDefault(recursive) ? 0 : recursive

	String pathName = UniqueName("tmpPath",12,0)
	NewPath/O/Q/Z $pathName, SIDAMPath()+subFolder

	String listStr = IndexedFile($pathName,-1,".ipf") + IndexedFile($pathName,-1,".lnk")
	Make/FREE/T/N=(ItemsInList(listStr)) w = RemoveEnding(StringFromList(p,listStr),".lnk")

	if (recursive)
		String dirListStr = IndexedDir($pathName,-1,0)
		int i, n = ItemsInList(dirListStr)
		for (i = 0; i < n; i++)
			Concatenate/T {fnList(subFolder+":"+StringFromList(i,dirListStr),recursive=recursive)}, w
		endfor
	endif

	KillPath $pathName

	return w
End

//-----------------------------------------------------------------------
//	Load the group list of color tables from ctab.ini (SIDAM_FILE_COLORLIST)
//-----------------------------------------------------------------------
Static Function/S getCtabGroups()
	Variable refNum
	String pathStr = SIDAMPath()+SIDAM_FOLDER_COLOR+":"

	//	Open ctab.ini if exists. If not, open ctab.default.ini.
	Open/R/Z refNum as (pathStr+SIDAM_FILE_COLORLIST)
	if (V_flag)
		Open/R refNum as (pathStr+SIDAM_FILE_COLORLIST_DEFAULT)
	endif

	//	return a list of the first item of each line except for comment lines
	String listStr = "", buffer
	int i
	do
		FReadLine refNum, buffer
		//	exclude comment
		i = strsearch(buffer,"//",0)
		if (i == 0)
			continue
		elseif (i != -1)
			buffer = buffer[0,i-1]
		endif
		listStr += SelectString(strlen(buffer),"",StringFromList(0,buffer)+";")
	while (strlen(buffer))
	Close refNum

	return listStr
End

//******************************************************************************
//	Exit SIDAM
//******************************************************************************
Function sidamExit()
	SetIgorHook/K BeforeFileOpenHook = SIDAMFileOpenHook
	SetIgorHook/K AfterCompiledHook = SIDAMAfterCompiledHook
	SetIgorHook/K BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	Execute/P/Q/Z "DELETEINCLUDE \""+SIDAM_FILE_INCLUDE+"\""
	Execute/P/Q/Z "DELETEINCLUDE \""+KM_FILE_INCLUDE+"\""			//	backward compatibility
	Execute/P/Q/Z "SetIgorOption poundUndefine=SIDAMshowProc"
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "BuildMenu \"All\""
	KillPath/Z KMMain
	KillPath/Z KMCtab		//	backward compatibility
	KillPath/Z KMHelp		//	backward compatibility
End
