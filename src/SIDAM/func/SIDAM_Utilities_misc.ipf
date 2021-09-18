#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilMisc

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Function/S menu()
	return SelectString(defined(SIDAMshowProc), "Show", "Hide")+" SIDAM Procedures"
End

//------------------------------------------------------------------------------
//	Show or hide procedures of SIDAM in the procedure list
//	(Window > Procedure Windows)
//------------------------------------------------------------------------------
Function SIDAMShowProcedures()
	if (defined(SIDAMshowProc))
		Execute/P/Q "SetIgorOption poundUndefine=SIDAMshowProc"
	else
		Execute/P/Q "SetIgorOption poundDefine=SIDAMshowProc"
	endif
	Execute/P "COMPILEPROCEDURES "
End

//------------------------------------------------------------------------------
//	Return path to the SIDAM directory
//------------------------------------------------------------------------------
//	GetFileFolderInfo returns S_aliasPath even if the path does not explicitly
//	ends with ".lnk" in Igor 9, although does not return in Igor 8.
#if IgorVersion() >= 9
Function/S SIDAMPath()
	String path = SpecialDirPath("Igor Pro User Files", 0, 0, 0) \
		+ "User Procedures:"+SIDAM_FOLDER_MAIN
	GetFileFolderInfo/Q/Z path
	//	S_path is the path if exist or empty if not.
	path = SelectString(V_isAliasShortcut, S_path, S_aliasPath)
	
	if (!strlen(path))
		Abort "SIDAM folder is not found."
	endif

	return path
End
#else
Function/S SIDAMPath()
	String path = SpecialDirPath("Igor Pro User Files", 0, 0, 0) \
		+ "User Procedures:"+SIDAM_FOLDER_MAIN

	GetFileFolderInfo/Q/Z path
	if (!V_Flag)
		return path
	endif
	
	GetFileFolderInfo/Q/Z path+".lnk"	//	shortcut
	if (!V_Flag && V_isAliasShortcut)
		return S_aliasPath
	endif
	
	Abort "SIDAM folder is not found."
End
#endif

//------------------------------------------------------------------------------
//	Add the check mark to num-th item of menuStr and return it
//------------------------------------------------------------------------------
Function/S SIDAMAddCheckmark(Variable num, String menuStr)
	if (numtype(num))
		return ""
	elseif (num < 0)
		return menuStr
	endif

	String checked = "\\M0:!" + num2char(18)+":", escCode = "\\M0"

	//	add escCode before all items
	menuStr = ReplaceString(";", menuStr, ";"+escCode)
	menuStr = escCode + RemoveEnding(menuStr, escCode)

	//	replace escCode of num-item with the check mark
	menuStr = AddListItem(checked, menuStr, ";", num)
	return ReplaceString(":;"+escCode, menuStr, ":")
End

//------------------------------------------------------------------------------
//	Return the angle in the setting folder
//------------------------------------------------------------------------------
Function SIDAMGetSettingsAngle(Wave/Z w)
	if (!WaveExists(w))
		return nan
	endif
	
	DFREF dfr = GetWavesDataFolderDFR(w):$SIDAM_DF_SETTINGS
	if (!DataFolderRefStatus(dfr))
		return nan
	endif
			
	NVAR/Z/SDFR=dfr angle		//	RHK SM2
	if (NVAR_Exists(angle))
		return angle
	endif
	
	//	For nanonis
	//	Reverse the sign of angle because the angle is positive
	//	for clockwise rotation.
	//	Nanonis 3ds
	SVAR/Z/SDFR=dfr grid = $SIDAMNumStrName("Grid settings", 1)
	if (SVAR_Exists(grid))
		return -str2num(StringFromList(4, grid))
	endif
	
	//	Nanonis sxm
	NVAR/Z/SDFR=dfr anglesxm = angle_deg
	if (NVAR_Exists(anglesxm))
		return -anglesxm
	endif
	NVAR/Z/SDFR=dfr anglesxmold = 'angle (deg)'
	if (NVAR_Exists(anglesxmold))
		return -anglesxmold
	endif
	
	return nan
End

//------------------------------------------------------------------------------
//	Functions for absorbing a change of "Liberal object names" in Igor 9.
//	In Igor 8, liberal object names are allowed for variables and strings
//	although it is not written so in the manual. In Igor 9, they are not allowed.
//------------------------------------------------------------------------------
Function/S SIDAMNumStrName(String name, int isString)
	int objectType = isString ? 4 : 3
	#if IgorVersion() >= 9
		return CreateDataObjectName(:, name, objectType, 0, 3)
	#else
		return SelectString(CheckName(name, objectType), name, CleanupName(name, 1))
	#endif
End

Function/S SIDAMStrVarOrDefault(String name, String def)
	if (strsearch(name, ":", 0) == -1)
		return StrVarOrDefault(SIDAMNumStrName(name, 1), def)
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (movedf(name))
		return def
	endif
		
	name = ParseFilePath(0, name, ":", 1, 0)
	name = ReplaceString("'", name, "")
	String str = StrVarOrDefault(SIDAMNumStrName(name, 1), def)
	SetDataFolder dfrSav
	return str
End

Function SIDAMNumVarOrDefault(String name, Variable def)
	if (strsearch(name, ":", 0) == -1)
		return NumVarOrDefault(SIDAMNumStrName(name, 0), def)
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (movedf(name))
		return def
	endif
	
	name = ParseFilePath(0, name, ":", 1, 0)
	name = ReplaceString("'", name, "")
	Variable num = NumVarOrDefault(SIDAMNumStrName(name, 0), def)
	SetDataFolder dfrSav
	return num
End

Static Function movedf(String name)
	String df = ParseFilePath(1, name, ":", 1, 0)
	DFREF dfr = $ReplaceString("'", RemoveEnding(df, ":"), "")
	if (!DataFolderRefStatus(dfr))
		return 1
	endif
	SetDataFolder dfr
	return 0
End

