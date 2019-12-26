#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Return path to the SIDAM directory
Function/S SIDAMPath()
	//	path to User Procedures
	String userpath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"

	GetFileFolderInfo/Q/Z (userpath+SIDAM_FOLDER_MAIN+":")
	if(!V_Flag)
		return S_path
	endif
	
	GetFileFolderInfo/Q/Z (userpath+SIDAM_FOLDER_MAIN+".lnk")
	if(V_isAliasShortcut)
		return S_aliasPath
	endif
	
	Abort "SIDAM folder is not found."
End


//	Kill all Variables starting from "V_" and strings starting from "S_" under dfr
Function SIDAMKillVariablesStrings(DFREF dfr)
	DFREF dfrSav = GetDataFolderDFR()
	String listStr
	int i, n
	
	//	Recursively execute for datefolders
	for (i = 0, n = CountObjectsDFR(dfr, 4); i < n; i++)
		SIDAMKillVariablesStrings(dfr:$GetIndexedObjNameDFR(dfr,4,i))
	endfor
	
	SetDataFolder dfr
	
	//	Variable
	listStr = VariableList("V_*", ";", 4)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		KillVariables $StringFromList(i, listStr)
	endfor
	
	//	String
	listStr = StringList("S_*", ";")
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		KillStrings $StringFromList(i, listStr)
	endfor
	
	SetDataFolder dfrSav
End