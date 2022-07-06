#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Main function
Function/WAVE SIDAMLoadNanonisDat(String pathStr, int noavg)
	String fileName = ParseFilePath(3, pathStr, ":", 0, 0) //	name w/o an extension
	DFREF dfrSav = GetDataFolderDFR()
	
	//	Read the header
	NewDataFolder/O/S $SIDAM_DF_SETTINGS
	STRUCT header s
	if (LoadNanonisDatGetHeader(pathStr, s))	//	Not a Nanonis data file
		return $""
	endif
	
	//	Read the data
	SetDataFolder dfrSav
	Wave/WAVE resw =  LoadNanonisDatGetData(pathStr, noavg, s)
	
	return resw
End


//	Read the header
//
//	The values read from the header are saved as global variables
//	in the current datafolder.
//	Information necessary for the data reading function is saved to
//	the structure "s".
Static Function LoadNanonisDatGetHeader(String pathStr, STRUCT header &s)
	SIDAMLoadDataNanonisCommon#getHeaderDat3ds(pathStr)

	SVAR Experiment
	s.type = Experiment
	strswitch (s.type)
		case  "Z spectroscopy":
			s.skip = 1
			break
		case "bias spectroscopy":
			s.driveamp = NumVarOrDefault(":'Lock-in':Amplitude", NaN)
			s.modulated = SIDAMStrVarOrDefault(":'Lock-in':'Modulated signal'", "")
			s.skip = !WaveExists('multiline settings')
			break
		case "Spectrum":
			s.skip = 1
			break
		case "History Data":
			s.interval = SIDAMNumVarOrDefault("Sample Period (ms)", 1)
			s.skip = 0
			break
	endswitch
	
	return 0
End

Static Structure header
	String type
	Variable driveamp
	String modulated
	Variable interval
	uchar skip
EndStructure


//	Data reading functions.
//	The resultant waves are saved in the current datafolder.
Static Function/WAVE LoadNanonisDatGetData(String pathStr, int noavg, STRUCT header &s)
	LoadWave/G/W/A/Q pathStr
	Make/N=(ItemsInList(S_waveNames))/WAVE/FREE ww = $StringFromList(p,S_waveNames)
	
	S_waveNames = ReplaceString("__A_",S_waveNames,"")
	S_waveNames = ReplaceString("__V_",S_waveNames,"")
	S_waveNames = ReplaceString("_omega",S_waveNames,"")
	S_waveNames = ReplaceString("_bwd_",S_waveNames,"bwd")
	Variable i
	for (i = 0; i < ItemsInList(S_waveNames); i += 1)
		Wave w = ww[i]
		Rename w $(ParseFilePath(3, pathStr, ":", 0, 0)+"_"+StringFromList(i,S_waveNames))
	endfor
	
	strswitch (s.type)
		case  "Z spectroscopy":
		case "bias spectroscopy":
			LoadNanonisDatGetDataConvert(s, ww)
			if (!noavg)
				SIDAMLoadDataNanonisCommon#averageSweeps("_bwd")
			endif
			break
		case "Spectrum":
		case "History Data":
			LoadNanonisDatGetDataConvert(s, ww)
			break
	endswitch
	
	DFREF dfr = GetDataFolderDFR()
	Make/FREE/N=(CountObjectsDFR(dfr, 1))/WAVE refw = $GetIndexedObjNameDFR(dfr, 1, p)	
	return refw
End

Static Function LoadNanonisDatGetDataConvert(STRUCT header &s, Wave/WAVE ww)
	int i, n
	
	//	The first column is the bias voltage, length, or frequency except
	//	the Histroy Data.
	Wave xw = ww[0]
	
	strswitch (s.type)
		case "bias spectroscopy":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0]*SIDAM_NANONIS_VOLTAGESCALE\
				             , xw[numpnts(xw)-1]*SIDAM_NANONIS_VOLTAGESCALE\
				             , SIDAM_NANONIS_VOLTAGEUNIT, ww[i]
				SIDAMLoadDataNanonisCommon#conversion(ww[i], driveamp=s.driveamp, \
				                                      modulated=s.modulated)
			endfor
			break
		case "Z spectroscopy":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0]*SIDAM_NANONIS_LENGTHSCALE\
				             , xw[numpnts(xw)-1]*SIDAM_NANONIS_LENGTHSCALE\
				             , SIDAM_NANONIS_LENGTHUNIT, ww[i]
				if (strlen(s.modulated))
					SIDAMLoadDataNanonisCommon#conversion(ww[i], driveamp=s.driveamp, \
					                                      modulated=s.modulated)
				else
					SIDAMLoadDataNanonisCommon#conversion(ww[i])
				endif
			endfor
			break
		case "Spectrum":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0], xw[numpnts(xw)-1], "Hz", ww[i]
			endfor
			break
		case "History Data":
			for (i = 0, n = numpnts(ww); i < n; i += 1)
				SetScale/P x 0, s.interval, "ms", ww[i]
			endfor
			break
	endswitch
	
	if (s.skip)
		KillWaves xw
	endif
End
