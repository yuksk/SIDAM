#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access

Function save_cmcrameri_as_ibw(String basePathStr)
	//	basePathStr is the absolute path to the directory where this ipf is
	basePathStr = RemoveEnding(basePathStr,":")+":cmcrameri:"
	String basepath = UniqueName("path", 12,0), subpath
	NewPath/Q $basepath, basePathStr
	
	//	list of subfolders: 0_Sequential, 1_Diverging, ...
	String dirlist = IndexedDir($basepath, -1, 0)
	
	String dirname, filelist, filename
	int i, j
	
	for (i = 0; i < ItemsInList(dirlist); i++)
		subpath = UniqueName("path", 12,0)
		dirname = StringFromList(i, dirlist)
		NewPath/Q $subpath, basePathStr+dirname
		//	list of csv files in a subfolder
		filelist = IndexedFile($subpath, -1, ".csv")
		KillPath $subpath
		for (j = 0; j < ItemsInList(filelist); j++)
			filename = StringFromList(j, filelist)
			LoadWave/J/M/Q/K=0/V={","," $",0,0} \
				basePathStr+StringFromList(i, dirlist)+":"+filename
			Wave w = $StringFromList(0, S_waveNames)
			if (!j)
				Make/U/W/N=(DimSize(w,0), DimSize(w,1), ItemsInList(filelist)) $dirname/WAVE=outw
			endif
			outw[][][j] = w[p][q]
			SetDimLabel 2, j, $StringFromList(0,filename,"."), outw
			KillWaves w
		endfor
		Save/C outw as SIDAMPath()+SIDAM_FOLDER_COLOR+":SciColMaps:"+NameOfWave(outw)+".ibw"
		KillWaves outw
	endfor
	
	KillPath $basepath
End

Function testfn()
	print GetRTStackInfo(3)
End