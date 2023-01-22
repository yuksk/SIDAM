#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=csv_to_ibw

//	All functions are static to avoid possible name collisions

//	return the absolute path where this file is
Static Function/S getBasePath()
	String thisFunctionName = StringFromList(0, GetRTStackInfo(0))	//	"getBasePath"
	return ParseFilePath(1, FunctionPath(thisFunctionName), ":", 1, 0)
End

//	return a list of folders as a text wave
Static Function/WAVE getFolders(String pathStr)
	String path = UniqueName("path", 12,0)
	NewPath/Q $path, pathStr
	Wave/T directories = ListToTextWave(IndexedDir($path, -1, 0),";")
	KillPath $path
	return directories
End

//	return a list of csv files as a text wave
Static Function/WAVE getCSVFiles(String pathStr)
	String path = UniqueName("path", 12,0)
	NewPath/Q $path, pathStr
	Wave/T files = ListToTextWave(IndexedFile($path, -1, ".csv"),";")
	KillPath $path
	return files
End

//	If the name is the same as one of Igor's table, add "2" to the name
Static Function/S createCleanName(String filename)
	String name = ReplaceString(".csv", filename, "")
	if (WhichListItem(name, CTabList(), ";", 0, 0) >= 0)
		name += "2"
	endif
	return name
End