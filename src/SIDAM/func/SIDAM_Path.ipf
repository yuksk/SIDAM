#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//------------------------------------------------------------------------------
//	Return path to the SIDAM directory
//------------------------------------------------------------------------------
Function/S SIDAMPath()
	String path = SIDAMResolvePath(SpecialDirPath("Igor Pro User Files", 0, 0, 0) \
		+ "User Procedures:"+SIDAM_FOLDER_MAIN)
	
	if (!strlen(path))
		Abort "SIDAM folder is not found."
	endif

	return path
End

//------------------------------------------------------------------------------
//	Return the full path.
//------------------------------------------------------------------------------
//	GetFileFolderInfo returns S_aliasPath even if the path does not explicitly
//	ends with ".lnk" in Igor 9.
Function/S SIDAMResolvePath(String path)
	GetFileFolderInfo/Q/Z path
	return SelectString(V_isAliasShortcut, S_path, S_aliasPath)
End
