#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMLoadDataNanonisCommon

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Functions commonly used for dat and 3ds
//
//	Read the header and save as global variables.
//	Returns the size of header.
Static Function getHeaderDat3ds(String pathStr)
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
		
		//	Handle as the multiline settings if "," is included.
		//	The multiline settings can be included in the main header of 3ds
		//	and under the Bias Spectroscopy header. In the case of the former,
		//	the name starts from "Segment Start (V),..." while it starts from
		//	"MultiLine Settings : Segment Start (V),..." in the case of the latter.
		if (strsearch(name,",",0) > -1)
			if (strsearch(name,":",0) > -1)
				name = name[strsearch(name,":",0)+2,strlen(name)-1]
			endif
			Make/N=(ItemsInList(value),5)/O $"multiline settings"/WAVE=w
			for (i = 0; i < 5; i += 1)
				SetDimLabel 1, i, $StringFromList(i, name, ", "), w
				w[][i] = str2num(StringFromList(i, StringFromList(p, value), ","))
			endfor
		else
			saveToGlobalVariables(name, value)
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

//	Convert raw values to physical or easy-to-read values
Static Function conversion(Wave w, [Variable driveamp, 
	String modulated])

	int isLockin = GrepString(NameOfWave(w),"_LI([RXY]|phi|_Demod)_")
	int isCurrent = GrepString(NameOfWave(w), "_Current")
	int isBias = GrepString(NameOfWave(w), "_Bias")
	SVAR/SDFR=$(GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS) Experiment

	if (isLockin && !ParamIsDefault(modulated) && !ParamIsDefault(driveamp))
		int noLockInHeader = numtype(driveamp) == 2
		int isBiasModulated = !CmpStr(modulated,"Bias (V)")
		int isZModulated = !CmpStr(modulated,"Z (m)")

		if (noLockInHeader)	
			SetScale d WaveMin(w), WaveMax(w), "A", w
			print "CAUTION: Information about lock-in settings is missing. "\
				+ "Conversion is NOT done."

		elseif (isBiasModulated)
			FastOP w = (SIDAM_NANONIS_CONDUCTANCESCALE/driveamp) * w
			SetScale d WaveMin(w), WaveMax(w), SIDAM_NANONIS_CONDUCTANCEUNIT, w

		elseif (isZModulated)
			FastOP w = (1/driveamp) * w
			SetScale d WaveMin(w), WaveMax(w), "A/m", w

		else
			FastOP w = (1/driveamp) * w

		endif

	elseif (isBias)
		FastOP w = (SIDAM_NANONIS_VOLTAGESCALE) * w
		SetScale d WaveMin(w), WaveMax(w), SIDAM_NANONIS_VOLTAGEUNIT, w

	elseif (isCurrent)
		FastOP w = (SIDAM_NANONIS_CURRENTSCALE) * w
		SetScale d WaveMin(w), WaveMax(w), SIDAM_NANONIS_CURRENTUNIT, w
	endif
End

//	Calculate the average between the forward and the backward sweeps
Static Function/WAVE averageSweeps(String bwdStr)
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
		FastOP fwdw = (0.5)*fwdw + (0.5)*bwdw
		KillWaves bwdw
		refw[numpnts(refw)] = {fwdw}
	endfor
	
	return refw
End

//	Save the header values as global variables.
//	This function is used for sxm files as well.
Static Function saveToGlobalVariables(String name, String str)
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
	int isString = GrepString(LowerStr(value),"[^0-9e+-.(inf)]") \
		|| ItemsInList(value,".") > 2 || !strlen(value)
	if (isString)
		String/G $SIDAMNumStrName(name, isString) = value
	else
		Variable/G $SIDAMNumStrName(name, isString) = str2num(value)
	endif
End