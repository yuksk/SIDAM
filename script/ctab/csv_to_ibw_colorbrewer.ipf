#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function save_colorbrewer_as_ibw(String basePathStr)
	//	basePathStr is the absolute path to the directory where this ipf is
	String basepath = UniqueName("path", 12,0), subpath
	NewPath/Q $basepath, basePathStr
	
	//	list of subfolders: 0_Sequential, 1_Diverging, 2_Qualitative
	String dirlist = IndexedDir($basepath, -1, 0)
	
	String dirname, filelist, filename, wname
	String destination = SIDAMPath()+"ctab:ColorBrewer:"
	int i, j, is_qualitative
		
	for (i = 0; i < ItemsInList(dirlist); i++)
		dirname = StringFromList(i, dirlist)
		is_qualitative = !CmpStr(dirname, "2_Qualitative")
		
		//	list of csv files in a subfolder
		subpath = UniqueName("path", 12,0)
		NewPath/Q $subpath, basePathStr+dirname
		filelist = IndexedFile($subpath, -1, ".csv")
		KillPath $subpath
		
		for (j = 0; j < ItemsInList(filelist); j++)
			filename = StringFromList(j, filelist)
			LoadWave/J/M/Q/K=0/V={","," $",0,0} \
				basePathStr+StringFromList(i, dirlist)+":"+filename
			Wave w = $StringFromList(0, S_waveNames)
			//	If the name is the same as one of Igor's table,
			//	add "2" to the name
			wname = ReplaceString(".csv", filename, "")
			if (WhichListItem(wname, CTabList(), ";", 0, 0) >= 0)
				wname += "2"
			endif			
			if (is_qualitative)
				Rename w $wname
				Save/C w as destination+ReplaceString(".csv", filename, ".ibw")
				KillWaves w
			else
				if (!j)
					Make/U/W/N=(DimSize(w,0), DimSize(w,1), ItemsInList(filelist)) $dirname/WAVE=outw
				endif
				outw[][][j] = w[p][q]
				SetDimLabel 2, j, $wname, outw
				KillWaves w
			endif
		endfor
		
		if (!is_qualitative)
			Save/C outw as destination+NameOfWave(outw)+".ibw"
			KillWaves outw
		endif
	endfor
	
	KillPath $basepath
End