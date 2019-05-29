#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilDev

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
//	Load csv files and save them as ibw files.
//	The mode specifies values written in csv files.
//	mode 0: integer, 0-65535
//	mode 1: floating point, 0-1
//------------------------------------------------------------------------------
Function SIDAMcsv2ibw(String basepath, int mode)
	String pathName = UniqueName("path",12,0)
	int i, n

	NewPath/Q $pathName, basepath
	PathInfo $pathName
	basepath = S_path	//	in case no trailing :
	String dirList = IndexedDir($pathName,-1,0)
	KillPath $pathName

	DFREF dfrSav = GetDataFolderDFR()
	DFREF dfrTmp = $SIDAMNewDF("", "csv2ibw")
	SetDataFolder dfrTmp

	Wave/Z/WAVE ww = loadCSV(basepath, mode)
	saveWaves(ww, basepath)
	for (i = 0, n = ItemsInList(dirList); i < n; i++)
		Wave/Z/WAVE ww = loadCSV(basepath+StringFromList(i,dirList)+":", mode)
		saveWaves(ww, basepath+StringFromList(i,dirList)+":")
	endfor

	SIDAMKillDataFolder(dfrTmp)
	SetDataFolder dfrSav
End

Static Function/WAVE loadCSV(String pathStr, int mode)
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	String csvfileList = IndexedFile($pathName,-1,".csv")
	KillPath $pathName

	int n = ItemsInList(csvfileList)
	if (n == 0)
		return $""
	endif

	//	Load each csv as a wave
	//	mode 0: unsigned 16bit integer, 0-65535
	//	mode 1: 32bit floating point, 0-1
	//	The name of wave is the file name without ".csv"
	String csvfileName, formatStr
	Make/N=(n)/WAVE/FREE ww
	if (mode == 0)
		formatStr = "C=3,F=0,T=80;"
	elseif (mode == 1)
		formatStr = "C=3,F=0,T=2;"
	endif

	int i
	for (i = 0; i < n; i++)
		csvfileName = StringFromList(i,csvfileList)
		LoadWave/J/M/B=formatStr/Q pathStr+csvfileName
		Wave tw = $StringFromList(0,S_waveNames)
		if (mode == 1)
			tw *= 65535
			Redimension/W/U tw
		endif
		ww[i] = tw
		Rename tw, $cleanupColorTableName(csvfileName)
	endfor

	return concatenateIfSameSize(ww, ParseFilePath(0,pathStr,":",1,0))
End

//	If all the loaded waves have identical numbers of points, concatenate
//	the waves. If not, return the input as it is.
Static Function/WAVE concatenateIfSameSize(Wave/WAVE ww, String name)
	Variable size
	int i, n

	for (i = 0, n = numpnts(ww); i < n-1; i++)
		Wave w0 = ww[i], w1 = ww[i+1]
		if (DimSize(w0,0)-DimSize(w1,0))
			return ww
		endif
	endfor

	Make/N=(DimSize(w0,0),3,numpnts(ww))/W/U $name/WAVE=w
	printf "concatenate: "
	for (i = 0, n = numpnts(ww); i < n; i++)
		Wave tw = ww[i]
		w[][][i] = tw[p][q]
		SetDimLabel 2, i, $NameOfWave(tw), w
		printf "%s%s", NameOfWave(tw), SelectString(i==n-1,", ","\r")
	endfor
	Redimension/N=1 ww
	ww[0] = w

	return ww
End

Static Function/S cleanupColorTableName(String csvfileName)
	String name = ParseFilePath(3, csvfileName, ":", 0, 0)	//	name without ext
	String initname = name

	name = ReplaceString("-" , name, "_")

	int isUsedByIgor = WhichListItem(name, CTabList(), ";", 0, 0) != -1
	if (isUsedByIgor)
		name = UniqueName(name, 1, 2)
	endif

	Make/T/FREE/N=11 listw
	listw[][0] = {"CET-CBL","cb_linear"}
	listw[][1] = {"CET-CBD","cb_diverging"}
	listw[][2] = {"CET-CBC","cb_cyclic"}
	listw[][3] = {"CET-CBTL","cbt_linear"}
	listw[][4] = {"CET-CBTD","cbt_diverging"}
	listw[][5] = {"CET-CBTC","cbt_cyclic"}
	listw[][6] = {"CET-L","linear"}
	listw[][7] = {"CET-D","diverging"}
	listw[][8] = {"CET-R","rainbow"}
	listw[][9] = {"CET-C","cyclic"}
	listw[][10] = {"CET-I","isoluminant"}

	int i
	for (i = 0; i < DimSize(listw,1); i++)
		name = ReplaceString(listw[0][i], name, listw[1][i])
	endfor

	if (CmpStr(initname,name))
		printf "rename: %s -> %s\r", initname, name
	endif

	return name
End

Static Function saveWaves(Wave/Z/WAVE ww, String pathStr)
	if (!WaveExists(ww))
		return 0
	endif

	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr

	int i, n = numpnts(ww)
	for (i = 0; i < n; i++)
		Save/C/P=$pathName/O ww[i]
		printf "save: %s\r", NameOfWave(ww[i])
	endfor

	KillPath $pathName
End
