#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access

Function save_cmocean_as_ibw(String basePathStr)
	//	basePathStr is the absolute path to the directory where this ipf is
	String basepath = UniqueName("path", 12,0), subpath
	NewPath/Q $basepath, basePathStr
	
	//	list of subfolders: 0_Sequential, 1_Diverging, ...
	//	
	String dirlist = IndexedDir($basepath, -1, 0)
	
	String dirname, filelist, filename, wname
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
			//	If the name is the same as one of Igor's table,
			//	add "2" to the name
			wname = ReplaceString(".csv", filename, "")
			if (WhichListItem(wname, CTabList(), ";", 0, 0) >= 0)
				wname += "2"
			endif
			outw[][][j] = w[p][q]
			SetDimLabel 2, j, $wname, outw
			KillWaves w
		endfor
		Save/C outw as SIDAMPath()+"ctab:cmocean:"+NameOfWave(outw)+".ibw"
		KillWaves outw
	endfor
	
	KillPath $basepath
End