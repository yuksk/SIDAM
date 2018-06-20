#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Constants"
#include "KM Utilities_Str"		//	for KMGetPath
#include "SIDAM_Hook"				//	for hook functions
#include "SIDAM_Compatibility"	//	for SIDAMBackwardCompatibility

//******************************************************************************
//	Start SIDAM
//******************************************************************************
Function SIDAMStart()
	printf "\r SIDAM %d.%d.%d\r", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH
	
	//	List ipf files to be included and write them into SIDAM_Procedures.ipf
	makeProcFile()
	Execute/P "INSERTINCLUDE \"" + SIDAM_FILE_INCLUDE + "\""
	
	//	Update the old include ipf file
	SIDAMBackwardCompatibility()
	
	Execute/P "COMPILEPROCEDURES "
	
	SetIgorHook BeforeFileOpenHook = KMFileOpenHook
	SetIgorHook BeforeExperimentSaveHook = KMBeforeExperimentSaveHook
	SetIgorHook AfterCompiledHook = KMAfterCompiledHook
End

Static Function makeProcFile()
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	Make a list of ipf files
	Concatenate/NP {fnList(SIDAM_FOLDER_FUNC), fnList(SIDAM_FOLDER_LOADER), fnList(SIDAM_FOLDER_EXT)}, listwave
	Wave/T lw = listwave
	
	//	Write the list into SIDAM_Procedures.ipf
	Variable refNum, i
	String pathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	Open/P=$pathName/Z refNum, as SIDAM_FILE_INCLUDE+".ipf"
	if (!V_flag)
		fprintf refNum,  "#ifndef SIDAMshowProc\r#pragma hide = 1\r#endif\r"
		for(i = 0; i < numpnts(lw); i += 1)
			fprintf refNum, "#include \"%s\"\r", RemoveEnding(lw[i],".ipf")
		endfor
		Close refNum
	endif
	KillPath $pathName
	
	SetDataFolder dfrSav
	
	return 1
End

//	make a list of ipf files in subFolder
Static Function/WAVE fnList(String subFolder)
	String pathName = UniqueName("tmpPath",12,0)
	NewPath/O/Q/Z $pathName, KMGetPath()+subFolder
	String listStr = IndexedFile($pathName,-1,".ipf") + IndexedFile($pathName,-1,".lnk")
	KillPath $pathName
	
	Make/FREE/T/N=(ItemsInList(listStr)) w = RemoveEnding(StringFromList(p,listStr),".lnk")
	return w
End


//******************************************************************************
//	Exit SIDAM
//******************************************************************************
Function sidamExit()
	SetIgorHook/K BeforeFileOpenHook = KMFileOpenHook
	SetIgorHook/K AfterCompiledHook = KMAfterCompiledHook
	SetIgorHook/K BeforeExperimentSaveHook = KMBeforeExperimentSaveHook
	Execute/P/Q/Z "DELETEINCLUDE \""+SIDAM_FILE_INCLUDE+"\""
	Execute/P/Q/Z "DELETEINCLUDE \""+KM_FILE_INCLUDE+"\""			//	backward compatibility
	Execute/P/Q/Z "SetIgorOption poundUndefine=SIDAMshowProc"
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "BuildMenu \"All\""
	KillPath/Z KMMain
	KillPath/Z KMCtab		//	backward compatibility
	KillPath/Z KMHelp		//	backward compatibility
End