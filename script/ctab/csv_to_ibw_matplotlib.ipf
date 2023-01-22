#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion = 9

#include ":csv_to_ibw_common"

Function save_matplotlib_as_ibw()
	String basepathStr = csv_to_ibw#getBasePath()
	
	//	list of subfolders: 0_Perceptually_Uniform_Seq, 1_Sequential, 2_Diverging,
	//	3_Cyclic, 4_Qualitative, 5_Miscellaneous
	Wave/T folders = csv_to_ibw#getFolders(basePathStr)
	
	String destination = SIDAMPath()+"ctab:Matplotlib:"
	int is_qualitative
		
	for (String dirname: folders)
		is_qualitative = !CmpStr(dirname, "4_Qualitative")
		Wave/T csvfiles = csv_to_ibw#getCSVFiles(basePathStr+dirname)
		
		for (String filename: csvfiles)
			LoadWave/J/M/Q/K=0/V={","," $",0,0} basePathStr+dirname+":"+filename
			Wave w = $StringFromList(0, S_waveNames)
			filename = csv_to_ibw#createCleanName(filename)
			if (is_qualitative)
				Rename w $filename
				Save/C w as destination+filename+".ibw"
			else
				Wave outw = bind_waves(dirname, filename, w)
			endif
			KillWaves w
		endfor
		
		if (!is_qualitative)
			Save/C outw as destination+dirname+".ibw"
			KillWaves outw
		endif
	endfor
End

Static Function/WAVE bind_waves(String dirname, String filename, Wave w)
	if (!WaveExists($dirname))
		Make/U/W/N=(DimSize(w,0), DimSize(w,1)) $dirname/WAVE=outw
	else
		Wave outw = $dirname
	endif

	int n = DimSize(outw, 2)	
	Redimension/N=(-1, -1, n+1) outw
	outw[][][n] = w[p][q]
	SetDimLabel 2, n, $filename, outw
	
	return outw
End