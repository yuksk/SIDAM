#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=csv_to_ibw

//	All functions are static to avoid possible name collisions

Static Function save_csv_as_ibw(String folderName)
	//	list of subfolders
	String basepathStr = getBasePath()
	Wave/T folders = getFolders(basePathStr)

	String destination = SIDAMPath()+"ctab:"+folderName
	
	for (String dirname: folders)
		Duplicate/O loadCSVFiles(basePathStr+dirname), $dirname
		Save/C/O $dirname as destination+":"+dirname+".ibw"
		print destination+":"+dirname+".ibw"
	endfor
End

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
Static Function/WAVE csvFileNames(String pathStr)
	String path = UniqueName("path", 12,0)
	NewPath/Q $path, pathStr
	Wave/T files = ListToTextWave(IndexedFile($path, -1, ".csv"),";")
	KillPath $path
	return files
End

//	load csv files at a directory designated by pathStr and return
//	as a 3D wave
Static Function/WAVE loadCSVFiles(String pathStr)
	Wave/T csvfiles = csv_to_ibw#csvFileNames(pathStr)
	Make/N=(numpnts(csvfiles))/WAVE/FREE color_waves = loadCSVFile(pathStr+":"+csvfiles[p])
	Make/N=(numpnts(csvfiles))/FREE num_colors = DimSize(color_waves[p],0)
	Make/N=(numpnts(csvfiles))/T/FREE color_names = createCleanName(csvfiles[p]) + "@" + num2istr(num_colors[p])
	Wave bindw = bind_waves(color_waves)
	CopyWaveToDimLabels(color_names, bindw, 2)
	return bindw
End

Static Function/WAVE loadCSVFile(String pathStr)
	LoadWave/J/M/Q/K=0/V={","," $",0,0} pathStr
	return $StringFromList(0, S_waveNames)
End

//	If the name is the same as one of Igor's table, add "2" to the name
Static Function/S createCleanName(String filename)
	String name = ReplaceString(".csv", filename, "")
	if (WhichListItem(name, CTabList(), ";", 0, 0) >= 0)
		name += "2"
	endif
	return name
End

Static Function/WAVE bind_waves(Wave/WAVE refw)
	Make/N=(numpnts(refw))/FREE nums = DimSize(refw[p],0)
	Make/W/U/N=(WaveMax(nums),3,numpnts(refw))/FREE bindw = 0
	
	int i
	for (i = 0; i < numpnts(refw); i++)
		Wave w = refw[i]
		bindw[,DimSize(w,0)-1][][i] = w[p][q]
		KillWaves w
	endfor
	
	return bindw
End