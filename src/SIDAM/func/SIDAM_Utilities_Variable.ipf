#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Function/S SIDAMStrVarOrDefault(String name, String def)
	if (strsearch(name, ":", 0) == -1)
		return StrVarOrDefault(CreateDataObjectName(:, name, 4, 0, 3), def)
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (movedf(name))
		return def
	endif
		
	name = ParseFilePath(0, name, ":", 1, 0)
	name = ReplaceString("'", name, "")
	String str = StrVarOrDefault(CreateDataObjectName(:, name, 4, 0, 3), def)
	SetDataFolder dfrSav
	return str
End

Function SIDAMNumVarOrDefault(String name, Variable def)
	if (strsearch(name, ":", 0) == -1)
		return NumVarOrDefault(CreateDataObjectName(:, name, 3, 0, 3), def)
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (movedf(name))
		return def
	endif
	
	name = ParseFilePath(0, name, ":", 1, 0)
	name = ReplaceString("'", name, "")
	Variable num = NumVarOrDefault(CreateDataObjectName(:, name, 3, 0, 3), def)
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
