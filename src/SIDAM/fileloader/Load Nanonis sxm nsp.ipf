#pragma TextEncoding="UTF-8"
#pragma rtGlobals=1

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Main function
Function/WAVE LoadNanonisSxmNsp(String pathStr)
	DFREF dfrSav = GetDataFolderDFR()
	
	//	Read the header
	NewDataFolder/O/S $SIDAM_DF_SETTINGS
	STRUCT header s
	SxmNspHeader(pathStr, s)
	
	//	Read the data
	SetDataFolder dfrSav
	if (s.type == 0)
		return SXMData(pathStr, s)
	elseif (s.type == 1)
		return NSPData(pathStr, s)
	endif
End

//	Read the header
//
//	The values read from the header are saved as global variables
//	in the current datafolder.
//	Information necessary for the data reading function is saved to
//	the structure "s".
Static Function SxmNspHeader(String pathStr, STRUCT header &s)
	Variable refNum, subFolder
	Variable overwritten = 0
	String buffer, name
	DFREF dfrSav = GetDataFolderDFR()
	
	Open/R/T="????" refNum as pathStr
	FReadLine refNum, buffer	//	Read the first line
	
	do
		name = buffer[1,strlen(buffer)-3]
		
		strswitch (name)
			case "Z-CONTROLLER":
				NewDataFolder/O/S $name
				SXMHeaderZC(refNum)
				SetDataFolder dfrSav
				break
			case "DATA_INFO":
				Wave/T s.chanInfo = SXMHeaderDI(pathStr, refNum)
				break
			case "COMMENT":
				SXMHeaderComment(refNum)
				break
			case "Multipass-Config":
				SXMHeaderMC(refNum)
				break
			default:
				//	Make a sub datafolder if ">" is included in the name.
				Variable n = strsearch(name, ">", 0)
				subFolder = (n != -1)
				if (subFolder)
					//	If the Z-Controller module is included in the header,
					//	use it.
					if (!CmpStr(name[0,n-1],"Z-Controller") && !overwritten)
						KillDataFolder/Z $"Z-CONTROLLER"
						overwritten = 1
					endif
					NewDataFolder/O/S $(name[0,n-1])
					name = name[n+1, strlen(name)-1]
				endif
				
				//	Read values from the header and save them as global variables.
				FReadLine refNum, buffer
				LoadNanonisCommonVariableString(name, buffer[0,strlen(buffer)-2])
				
				if (subFolder)
					SetDataFolder dfrSav
				endif
				break
		endswitch
		
		FReadLine refNum, buffer	//	read next line
		
	while (CmpStr(buffer,":SCANIT_END:\r") && CmpStr(buffer,":HEADER_END:\r"))
	
	//	sxm or nsp ?
	if (NumVarOrDefault("NANONIS_VERSION",0))			//	sxm
		s.type = 0
	elseif (NumVarOrDefault("SPECTRUM_VERSION",0))	//	nsp
		s.type = 1
	endif
	
	//	save the position of the end of the header for the data reading function.
	s.headerSize = SxmNspHeaderEnd(refNum)
		
	Close refNum
	
	if (s.type == 0)
		SXMHeaderCvt(s)
	elseif (s.type == 1)
		NSPHeaderCvt(s)
	endif
End

//	Z-CONTROLLER
Static Function SXMHeaderZC(Variable refNum)
	int i
	String buffer
	FReadLine refNum, buffer ;	String names = buffer[1,strlen(buffer)-2]
	FReadLine refNum, buffer ;	String values = buffer[1,strlen(buffer)-2]
	for (i = 0; i < ItemsInList(names,"\t"); i++)
		LoadNanonisCommonVariableString(StringFromList(i,names,"\t"), StringFromList(i,values,"\t"))
	endfor
End

//	DATA_INFO
Static Function/WAVE SXMHeaderDI(String pathStr, Variable refNum)
	String fileName = ParseFilePath(3, pathStr, ":", 0, 0) // without an extension
	String s0, s1, s2, buffer
	Variable n
	
	Make/N=(0,3)/T/FREE infow
	FReadLine refNum, buffer	//	Skip one line of "Channel" or "Name"
	FReadLine refNum, buffer	//	Read a line
	do
		n = DimSize(infow,0)
		Redimension/N=(n+1,-1) infow
		sscanf buffer, "%*[\t]%*[0-9]%*[\t]%s%*[\t]%s%*[\t]%s", s0, s1, s2
		infow[n][0] = fileName + "_" + s0
		infow[n][1] = s1
		infow[n][2] = s2
		FReadLine refNum, buffer	//	Read a next line
	while (CmpStr(buffer,"\r"))	//	An empty line
	return infow
End

//	COMMENT
Static Function SXMHeaderComment(Variable refNum)
	int code = TextEncodingCode(SIDAM_NANONIS_TEXTENCODING)
	String buffer
	String/G COMMENT = ""
	
	//	Read the first line of a comment
	FReadLine refNum, buffer
	
	//	The comment may be multiple lines. So read until a next line
	//	begins with ":".
	do
		COMMENT += ConvertTextEncoding(buffer, code, 1, 1, 0)
		//	Get the present position before reading next line
		FGetPos refNum
		FReadLine refNum, buffer
	while (CmpStr(buffer[0],":"))
	
	//	Set the position before ":"
	FSetPos refNum, V_filePos	//	V_filePos is given by FGetPos
End

//	Multipass-Config
Static Function SXMHeaderMC(Variable refNum)
	String buffer
	Variable i, n
	
	//	The labels of multipass-config are saved to the dimension labels
	FReadLine refNum, buffer
	n = ItemsInList(buffer, "\t")
	Make/N=(n) $"Multipass-Config"/WAVE=w
	for (i = 0; i < n; i += 1)
		SetDimLabel 0, i, $StringFromList(i, buffer, "\t"), w
	endfor
	
	do
		FStatus refNum
		FReadLine refNum, buffer
		if (CmpStr(buffer[0],"\t"))
			FSetPos refNum, V_filePos
			break
		endif
		buffer = ReplaceString("TRUE", buffer, "1")
		buffer = ReplaceString("FALSE", buffer, "0")
		n = DimSize(w,1)
		Redimension/N=(-1,n+1) w
		w[][n] = str2num(StringFromList(p, buffer, "\t"))
	while (V_filePos < V_logEOF)
	
	DeletePoints/M=0 0, 1, w
End

// Return the position of the end of the header (1A04)
Static Function SxmNspHeaderEnd(Variable refNum)
	Make/N=2/B/FREE tw
	do
		FBinRead/B=3/F=1 refNum, tw
		if (tw[0] == 0x1A && tw[1] == 0x04)
			break
		elseif (tw[1] == 0x1A)
			FStatus refNum
			FSetPos refNum, V_filePos-1
		endif
	while (1)
	
	FStatus refNum
	return V_filePos
End

//	Convert the raw variables to those used in Scan Inspector.
//	The variables are saved to the structure for the data reading function.
#if IgorVersion() >= 9
Static Function SXMHeaderCvt(STRUCT header &s)
	SVAR REC_DATE, REC_TIME
	String dd, mm, yy
	sscanf REC_DATE, "%2s.%2s.%4s", dd, mm, yy
	String/G start_time = yy+"/"+mm+"/"+dd+" "+REC_TIME
	
	NVAR ACQ_TIME;	Variable/G acquisition_time_s = ACQ_TIME
	
	SVAR SCAN_PIXELS, SCAN_RANGE, SCAN_OFFSET
	Variable/G n_pixels, n_lines
	sscanf SCAN_PIXELS, "%d%d", n_pixels, n_lines
	Variable/G width_m, height_m
	sscanf SCAN_RANGE, "%f%f", width_m, height_m
	Variable/G center_x_m, center_y_m	
	sscanf SCAN_OFFSET, "%f%f", center_x_m, center_y_m
	
	NVAR SCAN_ANGLE;	Variable/G angle_deg = SCAN_ANGLE
	SVAR SCAN_DIR;	String/G direction = SCAN_DIR
	NVAR BIAS;	Variable/G bias_V = BIAS
	
	KillStrings REC_DATE, REC_TIME, SCAN_PIXELS, SCAN_RANGE, SCAN_OFFSET,SCAN_DIR
	KillVariables ACQ_TIME, SCAN_ANGLE, BIAS
	
	s.xpnts = n_pixels
	s.ypnts = n_lines
	s.xscale = width_m * SIDAM_NANONIS_LENGTHSCALE
	s.yscale = height_m * SIDAM_NANONIS_LENGTHSCALE
	s.xcenter = center_x_m * SIDAM_NANONIS_LENGTHSCALE
	s.ycenter = center_y_m * SIDAM_NANONIS_LENGTHSCALE
	s.direction = stringmatch(direction, "down")
End
#else
Static Function SXMHeaderCvt(STRUCT header &s)
	SVAR REC_DATE, REC_TIME
	String dd, mm, yy
	sscanf REC_DATE, "%2s.%2s.%4s", dd, mm, yy
	String/G 'start time' = yy+"/"+mm+"/"+dd+" "+REC_TIME
	
	NVAR ACQ_TIME;	Variable/G 'acquisition time (s)' = ACQ_TIME
	
	SVAR SCAN_PIXELS, SCAN_RANGE, SCAN_OFFSET
	Variable/G '# pixels', '# lines'
	sscanf SCAN_PIXELS, "%d%d", '# pixels', '# lines'
	Variable/G 'width (m)', 'height (m)'
	sscanf SCAN_RANGE, "%f%f", 'width (m)', 'height (m)'
	Variable/G 'center x (m)', 'center y (m)'	
	sscanf SCAN_OFFSET, "%f%f", 'center x (m)', 'center y (m)'
	
	NVAR SCAN_ANGLE;	Variable/G 'angle (deg)' = SCAN_ANGLE
	SVAR SCAN_DIR;	String/G direction = SCAN_DIR
	NVAR BIAS;	Variable/G 'bias (V)' = BIAS
	
	KillStrings REC_DATE, REC_TIME, SCAN_PIXELS, SCAN_RANGE, SCAN_OFFSET,SCAN_DIR
	KillVariables ACQ_TIME, SCAN_ANGLE, BIAS
	
	s.xpnts = '# pixels'
	s.ypnts = '# lines'	
	s.xscale ='width (m)' * SIDAM_NANONIS_LENGTHSCALE
	s.yscale = 'height (m)' * SIDAM_NANONIS_LENGTHSCALE
	s.xcenter = 'center x (m)' * SIDAM_NANONIS_LENGTHSCALE
	s.ycenter = 'center y (m)' * SIDAM_NANONIS_LENGTHSCALE
	s.direction = stringmatch(direction, "down")
End
#endif

Static Function NSPHeaderCvt(STRUCT header &s)
	NVAR DATASIZEROWS, DATASIZECOLS, DELTA_f
	s.xpnts = DATASIZEROWS
	s.ypnts = DATASIZECOLS
	s.yscale = DELTA_f
	
	SVAR START_DATE, START_TIME, END_DATE, END_TIME
	Variable day, month, year, hour, minute, second
	sscanf START_DATE, "%d.%d.%d", day, month, year
	sscanf START_TIME, "%d:%d:%d", hour, minute, second
	s.starttime = date2secs(year,month,day) + hour*3600 + minute*60 + second
	sscanf END_DATE, "%d.%d.%d", day, month, year
	sscanf END_TIME, "%d:%d:%d", hour, minute, second
	s.endtime = date2secs(year,month,day) + hour*3600 + minute*60 + second
End

Static Structure header
	uint16	xpnts, ypnts	//	for both sxm and nsp
	Variable	xcenter, ycenter, xscale, yscale		//	yscale is for both
	uchar	direction		//	for sxm
	Variable	starttime, endtime		//	for nsp
	Variable	headerSize	//	The size of header, for both sxm and nsp
	uchar	type			//	1: sxm, 2: nsp
	Wave/T	chanInfo		//	Information of channels, for sxm
EndStructure

//	Data reading functions.
//	The resultant waves are saved in the current datafolder.

//	sxm
Static Function/WAVE SXMData(String pathStr, STRUCT header &s)
	Variable chan, layer, nLayer
	String unit
	
	GBLoadWave/O/Q/N=tmp/T={2,4}/S=(s.headerSize)/W=1 pathStr
	Wave tw = tmp0
	
	//	Rearrange the wave
	for (chan = 0, nLayer = 0; chan < DimSize(s.chanInfo,0); chan += 1) 
		nLayer += CmpStr(s.chanInfo[chan][2],"both") ? 1 : 2
	endfor
	Redimension/N=(s.xpnts, s.ypnts, nLayer) tw
	
	//	If the slow scan is downward (from the top to the bottom),
	//	reverse the wave in the y direction.
	if (s.direction)
		Reverse/DIM=1 tw
	endif	
	
	//	Separate each wave from the rearranged wave.
	Make/N=(nLayer)/WAVE/FREE refw
	for (layer = 0, chan = 0; layer < nLayer; layer += 1, chan += 1)
		unit = s.chanInfo[chan][1]
		MatrixOP $CleanupWaveName(s.chanInfo[chan][0],"")/WAVE=topow = tw[][][layer]
		SetScale d, 0, 0, unit, topow
		Redimension/S topow
		refw[layer] = topow
		
		if (!CmpStr(s.chanInfo[chan][2],"both"))
			layer += 1
			MatrixOP $CleanupWaveName(s.chanInfo[chan][0], "_bwd")/WAVE=topow = tw[][][layer]		
			SetScale d, 0, 0, unit, topow
			Reverse/DIM=0 topow
			Redimension/S topow
			refw[layer] = topow
		endif
	endfor
	
	//	Physical values
	for (layer = 0; layer < nLayer; layer += 1)
		Wave lw = refw[layer]
		SetScale/I x, s.xcenter-s.xscale/2, s.xcenter+s.xscale/2, SIDAM_NANONIS_LENGTHUNIT, lw
		SetScale/I y, s.ycenter-s.yscale/2, s.ycenter+s.yscale/2, SIDAM_NANONIS_LENGTHUNIT, lw
		strswitch (WaveUnits(lw, -1))
			case "m":	//	height
				FastOP lw = (SIDAM_NANONIS_LENGTHSCALE) * lw	
				SetScale d, WaveMin(lw), WaveMax(lw), SIDAM_NANONIS_LENGTHUNIT, lw
				break
			case "A":	//	current
				FastOP lw = (SIDAM_NANONIS_CURRENTSCALE) * lw
				SetScale d, WaveMin(lw), WaveMax(lw), SIDAM_NANONIS_CURRENTUNIT, lw
				break
			default:
				SetScale d, WaveMin(lw), WaveMax(lw), "", lw
		endswitch
	endfor
	
	KillWaves tw
	
	return refw
End

//	nsp
Static Function/WAVE NSPData(String pathStr, STRUCT header &s)
	GBLoadWave/O/Q/N=tmp/T={2,4}/S=(s.headerSize)/W=1 pathStr
	Wave tw = tmp0
	
	//	Rearrange the wave
	Redimension/N=(s.ypnts,s.xpnts) tw
	Matrixtranspose tw
	
	//	Physical values
	SetScale/I x s.starttime, s.endtime, "dat", tw
	SetScale/P y 0, s.yscale, "Hz", tw
	
	//	name without an extension
	Rename tw $ParseFilePath(3, pathStr, ":", 0, 0)
	
	return tw
End

//	Shorten a wave name if it is too long.
//	This was prepared for an old version of Igor, and is virtually unnecessary.
Static Function/S CleanupWaveName(String name, String suffix)
	int a = strsearch(name, "_", inf, 1)
	String str1 = name[0,a-1]
	String str2 = name[a,inf] + suffix
	if (strlen(str1) > MAX_OBJ_NAME-strlen(str2))
		printf "%s\"%s%s\" is renamed to \"%s%s\" (too long name)\r", PRESTR_CAUTION, str1, str2, str1[0,MAX_OBJ_NAME-strlen(str2)-1], str2
		return str1[0,MAX_OBJ_NAME-strlen(str2)-1] + str2
	else
		return str1 + str2
	endif
End