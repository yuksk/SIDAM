#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Main function
Function/WAVE LoadNanonisDat(pathStr)
	String pathStr
	
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
	Wave/WAVE resw =  LoadNanonisDatGetData(pathStr, s)
	
	return resw
End


//	Read the header
//
//	The values read from the header are saved as global variables
//	in the current datafolder.
//	Information necessary for the data reading function is saved to
//	the structure "s".
Static Function LoadNanonisDatGetHeader(pathStr, s)
	String pathStr
	STRUCT header &s
	
	LoadNanonisCommonGetHeader(pathStr)
	
	SVAR Experiment
	s.type = Experiment
	strswitch (s.type)
		case  "Z spectroscopy":
			s.skip = 1
			break
		case "bias spectroscopy":
			s.driveamp = NumVarOrDefault(":'Lock-in':Amplitude", NaN)
			s.modulated = StrVarOrDefault(":'Lock-in':'Modulated signal'", "")
			s.skip = !WaveExists('multiline settings')
			break
		case "Spectrum":
			s.skip = 1
			break
		case "History Data":
			s.interval = NumVarOrDefault("Sample Period (ms)",1)
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
Static Function/WAVE LoadNanonisDatGetData(pathStr, s)
	String pathStr
	STRUCT header &s
	
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
			if (!(GetKeyState(1)&4))
				//	Calculate the average between the forward and the backward data
				//	unless the shift key is pressed.
				LoadNanonisCommonDataAvg("_bwd")
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

Static Function LoadNanonisDatGetDataConvert(s, ww)
	STRUCT header &s
	Wave/WAVE ww
	
	Variable i, n
	
	//	The first column is the bias voltage, length, or frequency except
	//	the Histroy Data.
	Wave xw = ww[0]
	
	strswitch (s.type)
		case "bias spectroscopy":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0]*1e3, xw[numpnts(xw)-1]*1e3, "mV", ww[i]	//	V -> mV
				LoadNanonisCommonConversion(ww[i], driveamp=s.driveamp, modulated=s.modulated)
			endfor
			break
		case "Z spectroscopy":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0]*1e10, xw[numpnts(xw)-1]*1e10, "\u00c5", ww[i]		//	m -> angstrom
				LoadNanonisCommonConversion(ww[i])
			endfor
			break
		case "Spectrum":
			for (i = 1, n = numpnts(ww); i < n; i += 1)
				SetScale/I x xw[0], xw[numpnts(xw)-1], "Hz", ww[i]
				LoadNanonisCommonConversion(ww[i])
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


//	Functions commonly used for dat and 3ds
//
//	Read the header and save as global variables.
//	Returns the size of header.
Function LoadNanonisCommonGetHeader(pathStr)
	String pathStr
	
	Variable refNum, subFolder, i
	String buffer, key, name, value
	DFREF dfrSav = GetDataFolderDFR()
	
	strswitch (LowerStr(ParseFilePath(4, pathStr, ":", 0, 0)))	//	an extension
		case "dat":
			key = "%[^\t]\t%[^\t]\t"
			break
		case "3ds":
			key = "%[^=]=%[^\r]\r"
			break
		default:
			return 0
	endswitch
	
	Open/R/T="????" refNum as pathStr
	FReadLine refNum, buffer	//	Read the first line
	do
		sscanf buffer, key, name, value
		//	Make a sub datafolder if ">" is included in the name.
		i = strsearch(name, ">", 0)
		subFolder = (i != -1)
		if (subFolder)
			NewDataFolder/O/S $(name[0,i-1])
			name = name[i+1,strlen(name)-1]
		endif
		
		//	multiline settings if "," is included
		if (strsearch(name,",",0) > -1)
			Make/N=(ItemsInList(value),5)/O $"multiline settings"/WAVE=w
			for (i = 0; i < 5; i += 1)
				SetDimLabel 1, i, $StringFromList(i, name, ", "), w
				w[][i] = str2num(StringFromList(i, StringFromList(p, value), ","))
			endfor
		else
			LoadNanonisCommonVariableString(name, value)
		endif
		
		if (subFolder)
			SetDataFolder dfrSav
		endif
		
		FReadLine refNum, buffer	//	read the next line
	//	empty line (dat) && HEADER_END (3ds)
	while (strlen(buffer) != 1 && CmpStr(buffer,":HEADER_END:\r"))
	
	FStatus refNum
	Close refNum
	
	return V_filePos	//	the size of header
End

//------------------------------------------------------------------------------
//	Convert raw values to physical or easy-to-read values
//------------------------------------------------------------------------------
Function LoadNanonisCommonConversion(Wave w, [Variable driveamp, 
	String modulated])

	int isLockin = GrepString(NameOfWave(w),"_LI([RXY]|phi|_Demod)_")
	int isBias = GrepString(NameOfWave(w), "_Bias")
	SVAR/SDFR=$(GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS) Experiment
	int isFFTspectrum = !CmpStr(Experiment, "Spectrum")

	if (isLockin)
		int noLockInHeader = numtype(driveamp) == 2
		int isBiasModulated = !CmpStr(modulated,"Bias (V)")
		int isZModulated = !CmpStr(modulated,"Z (m)")

		if (noLockInHeader)	
			SetScale d WaveMin(w), WaveMax(w), "A", w
			print "CAUTION: Information about lock-in settings is missing. "\
				+ "Conversion to nS is NOT done."

		elseif (isBiasModulated)
			FastOP w = (1e9/driveamp) * w 	//	A -> nS
			SetScale d WaveMin(w), WaveMax(w), "nS", w

		elseif (isZModulated)
			FastOP w = (1/driveamp) * w
			SetScale d WaveMin(w), WaveMax(w), "A/m", w

		else
			FastOP w = (1/driveamp) * w

		endif

	elseif (isBias)
		FastOP w = (1e3) * w		//	V -> mV
		SetScale d WaveMin(w), WaveMax(w), "mV", w

	elseif (isFFTspectrum)
		FastOP w = (1e15) * w		//	A -> fA
		SetScale d WaveMin(w), WaveMax(w), "fA/sqrt(Hz)", w

	else
		FastOP w = (1e9) * w		//	A -> nA
		SetScale d WaveMin(w), WaveMax(w), "nA", w
	endif
End

//	Calculate the average between the forward and the backward data
Function/WAVE LoadNanonisCommonDataAvg(bwdStr)
	String bwdStr
	
	String listStr = WaveList("*",";",""), name, avgName, subName
	Variable i, n
	Make/WAVE/N=0/FREE refw
	
	//	If a string given by the bwdStr is included in the name of wave,
	//	it is the backward wave. The forward wave is given by removing
	//	the bwdStr from the name of the backward wave.
	for (i = 0, n = ItemsInList(listStr); i < n; i += 1)
		name = StringFromList(i,listStr)
		if (!GrepString(name,bwdStr))
			continue
		endif
		Wave fwdw = $ReplaceString(bwdStr, name, ""), bwdw = $name
		Duplicate/O fwdw $(NameOfWave(fwdw)+"_sub")/WAVE=subw
		FastOP subw = fwdw - bwdw
		FastOP fwdw = (0.5)*fwdw + (0.5)*bwdw
		KillWaves bwdw
		refw[numpnts(refw)] = {fwdw}
	endfor
	
	return refw
End

//	Save the header values as global variables.
//	This function is used for sxm files as well.
Function LoadNanonisCommonVariableString(name,str)
	String name, str
	
	int code = TextEncodingCode(SIDAM_NANONIS_TEXTENCODING)
	String value = ConvertTextEncoding(str, code, 1, 1, 0)	
	
	//	Remove an empty space at the beginning if any (sxm).
	if (char2num(value[0]) == 32)
		do
			value = ReplaceString(" ", value, "", 1, 1)
		while (char2num(value[0]) == 32)
	endif
	
	//	Remove " at the beginning and the end if any (3ds).
	if (!CmpStr(value[0],"\"") && !CmpStr(value[strlen(value)-1],"\""))
		value = ReplaceString("\"",value,"",0,1)
		value = RemoveEnding(value,"\"")
	endif
	
	//	Regard a value as a string if one of the following is satisfied.
	//	1. A character except numbers (including the infinity) is included.
	//	2. Two periods or more are included.
	//	3. Empty
	if (GrepString(LowerStr(value),"[^0-9e+-.(inf)]") || ItemsInList(value,".") > 2 || !strlen(value))
		name = SelectString(CheckName(name, 4), name, CleanupName(name, 1))
		String/G $name = value
	else
		name = SelectString(CheckName(name, 3), name, CleanupName(name, 1))
		Variable/G $name = str2num(value)
	endif
End
