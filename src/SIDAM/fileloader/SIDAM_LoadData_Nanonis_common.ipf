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
	
	if (isLockin && !ParamIsDefault(modulated) && !ParamIsDefault(driveamp))
		SVAR/SDFR=$(GetWavesDataFolder(w,1)+SIDAM_DF_SETTINGS+":'Bias Spectroscopy'")/Z Lock_In_run
		int noExcitation = SVAR_Exists(Lock_In_run) && !CmpStr(Lock_In_run, "FALSE")
		int noLockInHeader = numtype(driveamp) == 2
		int isBiasModulated = !CmpStr(modulated,"Bias (V)")
		int isZModulated = !CmpStr(modulated,"Z (m)")

		if (noExcitation)	
			SetScale d WaveMin(w), WaveMax(w), "A", w
			return 1

		elseif (noLockInHeader)	
			SetScale d WaveMin(w), WaveMax(w), "A", w
			return 2

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
	
	return 0
End

Static Function showConversionCaution(Wave/WAVE statusw)
	Wave/T names = statusw[%name]
	Wave flags = statusw[%flag]
	
	if (!WaveMax(flags))
		return 0
	endif
	
	if (WaveMax(flags) == 1)
		print "AC voltages were not applyied during the measurement. "\
			+ "No conversion is done for the following waves."
	elseif (WaveMax(flags) == 2)
		print "Information about the lock-in settings is missing. "\
			+ "No conversion is done for the following waves."
	endif
	
	int i
	String str = ""
	for (i = 0; i < numpnts(flags); i++)
		if (!flags[i])
			continue
		endif
		str += names[i] + ";"
	endfor
	
	int length = 0, oneline = 200
	for (i = 0; i < ItemsInList(str); i++)
		printf SelectString(length, "%s", ", %s"), StringFromList(i, str)
		length += strlen(StringFromList(i, str))
		if (length > oneline)
			printf "\r"
			length = 0
		endif
	endfor
	if (length)
		printf "\r"
	endif
End

Static Function/WAVE averageSweeps(Wave/WAVE specw, String bwdStr, Wave/WAVE statusw)
	Make/WAVE/N=(numpnts(specw))/FREE avgWaves
	Make/T/N=(numpnts(specw))/FREE names = NameOfWave(specw[p])
	int i, n = 0
	
	//	Regard a wave as a backward sweep if the bwdStr is included in
	//	the name of wave. The corresponding forward wave is given by
	//	removing the bwdStr from the name of the backward sweep wave.
	String fwdName
	for (i = 0; i < numpnts(names); i++)
		if (!GrepString(names[i], bwdStr))
			continue
		endif
		fwdName = ReplaceString(bwdStr, names[i], "")
		Wave fwdw = $fwdName, bwdw = $names[i]
		//	Use the name of the forward sweep as the name of the average sweep.
		//	So change the name of the forward sweep
		MatrixOP/FREE avgw = fp32((fwdw + bwdw) * 0.5)
		Copyscales fwdw, avgw
		SIDAMCopyBias(fwdw, avgw)
		updateStatus(statusw, {fwdw, bwdw}, fwdName)	
		killSweeps(specw, {fwdw, bwdw})
		Duplicate avgw, $fwdName
		avgWaves[n++] = $fwdName
	endfor
	
	DeletePoints n, numpnts(avgWaves)-n, avgWaves
	return avgWaves
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
		String/G $CreateDataObjectName(:, name, 4, 0, 3) = value
	else
		Variable/G $CreateDataObjectName(:, name, 3, 0, 3) = str2num(value)
	endif
End

Static Function nonZeroAngleCaution()
	printf "%sThe scan angle is not 0.\r", PRESTR_CAUTION
	printf "%sBe careful that the xy scaling values except for the center of the image do not represent the actual coordinates.\r", PRESTR_CAUTION
	printf "%sThe scan size is correctly reflected in the xy scaling values.\r", PRESTR_CAUTION
End

//	Concatenate waves saved by "save all" into one wave.
Static Function/WAVE concatSaveAllSweeps(Wave/WAVE sweepRefs, Wave/WAVE statusw)
	Make/T/N=(numpnts(sweepRefs))/FREE sweepNames = NameOfWave(sweepRefs[p])

	//	Remove average waves and the bias calc wave from the list
	//	"dat" contains _AVG_ and "3ds" contains [AVG] in the file name
	//	The bias calc wave is included in "dat".
	Grep/E="^(?!.*((_|\[)AVG(_|\])|_calc$))" sweepNames as sweepNames
	
	Make/WAVE/N=(numpnts(sweepRefs))/FREE concatWaves
	String basename 
	int i = 0, n = 0
	for (i = 0; numpnts(sweepNames) && i < numpnts(sweepRefs); i++)
		basename = fetchBasename(sweepNames)
		if (!strlen(basename))
			continue
		endif
		Wave/WAVE sweeps = fetchSweeps(sweepNames, basename)
		concatWaves[n] = concatSweeps(sweeps, basename)
		updateStatus(statusw, sweeps, NameOfWave(concatWaves[n++]))
		killSweeps(sweepRefs, sweeps)
		removeNames(sweepNames, basename)
	endfor
	
	DeletePoints n, numpnts(concatWaves)-n, concatWaves
	return concatWaves
End

Static Function/S fetchBasename(Wave/T names)
	int index
	String name = names[0]
	
	//	3ds
	index = strsearch(name, "_[", 0)
	if (index != -1)
		return name[0,index-1]
	endif
	
	//	dat
	index = strsearch(name, "__", 0)
	if (index != -1)
		return name[0,index-1]
	endif
	
	return ""
End

Static Function/WAVE fetchSweeps(Wave/T names, String basename)
	Make/T/N=1/FREE fetchedNames
	Grep/E=("^"+basename+".*") names as fetchedNames
	Make/WAVE/N=(numpnts(fetchedNames))/FREE sweeps = $fetchedNames[p]
	return sweeps
End

Static Function/WAVE concatSweeps(Wave/WAVE sweeps, String basename)
	Wave w0 = sweeps[0]
	Make/L/U/N=4/FREE n = DimSize(sweeps[0],p)
	int dim = WaveDims(sweeps[0])
	
	//	Use duplicate to inherit the wave type
	Duplicate/R=[0]/O w0, $basename/WAVE=concatw
	
	switch (dim)
		case 1:
			Redimension/N=(n[0], numpnts(sweeps)) concatw
			break
		case 2:
			Redimension/N=(n[0],n[1],numpnts(sweeps)) concatw
			break
		case 3:
			Redimension/N=(n[0],n[1],n[2],numpnts(sweeps)) concatw
			break
	endswitch
	Copyscales sweeps[0], concatw

	int i
	for (i = 0; i < numpnts(sweeps); i++)
		Wave w1 = sweeps[i]
		switch (dim)
			case 1:
				concatw[][i] = w1[p]
				break
			case 2:
				concatw[][][i] = w1[p][q]
				break
			case 3:
				concatw[][][][i] = w1[p][q][r]
				break
		endswitch
	endfor
	
	Make/T/N=(numpnts(sweeps))/FREE names = NameOfWave(sweeps[p])
	CopyWaveToDimLabels(names, concatw, dim)

	return concatw
End

Static Function killSweeps(Wave/WAVE sweepRefs, Wave/WAVE sweeps)
	int i, j
	for (i = 0; i < numpnts(sweeps); i++)
		for (j = 0; j < numpnts(sweepRefs); j++)
			if (WaveRefsEqual(sweeps[i], sweepRefs[j]))
				Wave tw = sweepRefs[j]
				KillWaves tw
				DeletePoints j, 1, sweepRefs
				break
			endif
		endfor
	endfor
End

Static Function updateStatus(Wave/WAVE statusw, Wave/WAVE wavesToBeRemoved,
	String nameToBeAdded)
	
	Wave/T names = statusw[%name]
	Wave flags = statusw[%flag]
	int i, n, flag
	
	for (i = 0; i < numpnts(wavesToBeRemoved); i++)
		FindValue/TEXT=(NameOfWave(wavesToBeRemoved[i])) names
		if (V_Value < 0)
			continue
		elseif (!i)
			flag = flags[V_Value]
		endif
		DeletePoints V_Value, 1, names, flags
	endfor
	
	n = numpnts(names)
	Redimension/N=(n+1) names, flags
	names[n] = nameToBeAdded
	flags[n] = flag
End

Static Function removeNames(Wave/T sweepNames, String basename)
	Grep/E=("^(?!"+basename+")") sweepNames as sweepNames
End