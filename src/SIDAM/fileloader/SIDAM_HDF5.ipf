#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMHDF5

#include "SIDAM_Utilities_Wave"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Function/S mainMenuItem()
	int isBrowserShown = strlen(GetBrowserSelection(-1))
	int n = numpnts(SIDAMSelectedWaves())
	if (!isBrowserShown || !n)
		return "(Save Selected Waves as hdf5 Files..."
	elseif (n == 1)
		return "Save Selected Wave as hdf5 File..."
	else
		return "Save Selected Waves as hdf5 Files..."
	endif
End

Static Function mainMenuDo()
	int i
	Wave/WAVE ww = SIDAMSelectedWaves()
	for (i = 0; i < numpnts(ww); i++)
		SIDAMSaveHDF5(ww[i], "", history=1)
	endfor
End

//==================================================================
//	Load an HDF5 file
//==================================================================
Function/WAVE SIDAMLoadHDF5(String pathStr)
	convertWindowsPathToMacPath(pathStr)

	Variable fileID	
	HDF5OpenFile/R/Z fileID as pathStr
	if (V_flag)
		return $""
	endif

	Wave/WAVE ww = loadDatasets(fileID, "/")

	HDF5ListGroup/TYPE=1 fileID, "/"
	int i
	for (i = 0; i < ItemsInList(S_HDF5ListGroup); i++)
		Wave/WAVE ww2 = loadGroup(fileID, "/"+StringFromList(i,S_HDF5ListGroup))
		Concatenate/NP=0 {ww2}, ww
	endfor

	HDF5CloseFile fileID

	return ww
End

Static Function/WAVE loadGroup(Variable fileID, String path)
	DFREF dfrSav = GetDataFolderDFR()

	NewDataFolder/O/S $ParseFilePath(0, path, "/", 1, 0)

	Wave/WAVE ww = loadDatasets(fileID, path)

	HDF5ListGroup/TYPE=1 fileID, path
	int i
	for (i = 0; i < ItemsInList(S_HDF5ListGroup); i++)
		Wave/WAVE ww2 = loadGroup(fileID, path+"/"+StringFromList(i,S_HDF5ListGroup))
		Concatenate/NP=0 {ww2}, ww
	endfor

	SetDataFolder dfrSav

	return ww
End

Static Function/WAVE loadDatasets(Variable fileID, String path)
	HDF5ListGroup/TYPE=2 fileID, path
	int i, n = ItemsInList(S_HDF5ListGroup)
	Make/N=(n)/WAVE/FREE ww
	for (i = 0; i < n; i++)
		HDF5LoadData/IGOR=-1/O/Q fileID, path+"/"+StringFromList(i,S_HDF5ListGroup)
		if (!V_Flag)
			ww[i] = $StringFromList(0,S_waveNames)
		endif
	endfor
	return ww
End

//==================================================================
//	Save a wave as an HDF5 file
//==================================================================
Function SIDAMSaveHDF5(Wave w, String fullPath, [String dataname,
	int history])

	if (ParamIsDefault(dataname))
		dataname = NameOfWave(w)
	endif

	if (!strlen(fullPath))
		Variable refNum
		Open/D/F="All Files:.*;" refNum as NameOfWave(w)+".hdf5"
		if (!strlen(S_fileName))	//	user cancel
			return 0
		endif
		fullPath = S_fileName
	endif

	int noExt = !strlen(ParseFilePath(4, fullPath, ":", 0, 0))
	if (noExt)
		fullPath += ".hdf5"
	endif

	convertWindowsPathToMacPath(fullPath)
	String dirPath = ParseFilePath(1, fullPath, ":", 1, 0)
	String filename = ParseFilePath(0, fullPath, ":", 1, 0)

	String pathName = createPath(dirPath)
	if (strlen(pathName) == 0)
		return 0
	endif

	Variable fileID
	HDF5CreateFile/P=$pathName/O fileID as filename
	HDF5SaveData/GZIP={9,1} w, fileID, dataname
	HDF5CloseFile fileID
	
	if (history)
		printf "%sSIDAMSaveHDF5(%s, \"%s\")\r", PRESTR_CMD \
			, GetWavesDataFolder(w,2), S_path + filename
	endif

	KillPath/Z $pathName
End

//==================================================================
//	Utilities
//==================================================================
//	Avoid problems when a name of folder or file starts with
//	t, r, and n.
Static Function/S convertWindowsPathToMacPath(String &str)
	str = ReplaceString(":\\", str, ":")	//	D:\ -> D:
	str = ReplaceString("\t", str, ":t")	//	\test -> :test
	str = ReplaceString("\n", str, ":n")	//	\new -> :new
	str = ReplaceString("\r", str, ":r")	//	\rev -> :rev
	str = ReplaceString("\\", str, ":")		//	\ -> :
End

Static Function/S createPath(String pathStr)
	String pathName = UniqueName("path",12,0)
	if (strlen(pathStr))
		pathStr = ParseFilePath(5,pathStr,":",0,0)		//	change the delimiter to ":"
		pathStr = ParseFilePath(2,pathStr,":",0,0)		//	add ":" at the end
		NewPath/Q/Z $pathName, pathStr

		//	Make a new folder unless a folder designated by pathStr exists
		if (V_flag)
			int successfullyMade = NewFolder(pathStr)
			if (!successfullyMade)
				printf "%s%s gave error: folder not found\r", PRESTR_CAUTION, GetRTStackInfo(2)
				return ""
			endif
			NewPath/Q $pathName, pathStr
		endif
	else
		//	Show a dialog to select a folder
		GetFileFolderInfo/D/Q/Z=2
		if (V_Flag == -1)	//	user cancel
			return ""
		elseif (V_Flag > 0)	//	not found
			printf "%s%s gave error: folder not found\r", PRESTR_CAUTION, GetRTStackInfo(2)
			return ""
		endif
		NewPath/Q/Z $pathName, S_path
	endif
	return pathName
End

//	Create a new folder
Static Function NewFolder(String pathStr)
	pathStr = ParseFilePath(5,pathStr,":",0,0)		//	change the delimiter to ":"

	//	Confirm if the parent folder exists. If not, make it.
	String parentPath = RemoveEnding(ParseFilePath(1,pathStr,":",1,0),":")
	String pathName = UniqueName("path",12,0)
	NewPath/Q/Z $pathName, parentPath
	if (V_flag)	//	does not exist
		int flag = NewFolder(parentPath)
		if (!flag)
			return 0
		endif
	endif
	KillPath/Z $pathName

	//	Igor does not have a function to create a folder but has one to copy
	//	an existing folder. Therefore, copy the Igor Procedure folder to
	//	make a new folder.
	CopyFolder/Z/P=IgorUserFiles "Igor Procedures" as pathStr
	if (V_flag)
		print "cancelled", V_flag
		return 0
	endif

	//	Delete flies in the created folder.
	pathName = UniqueName("path", 12, 0)
	NewPath/Q/Z $pathName pathStr
	String files = IndexedFile($pathName, -1, "????")
	int i
	for (i = 0; i < ItemsInList(files); i++)
		DeleteFile/P=$pathName StringFromList(i,files)
	endfor

	KillPath $pathName

	return 1
End