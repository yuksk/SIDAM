#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMConfig

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Utilities_misc"

//	Open SIDAM.toml if exists. If not, open SIDAM.default.toml
//	Then, proceed to a table designated by the tableName parameter.
Function SIDAMConfig(String tableName)
	Variable refNum
	Open/R/Z refNum as SIDAMPath()+SIDAM_FILE_CONFIG
	if (V_flag)
		Open/R/Z refNum as SIDAMPath()+SIDAM_FILE_CONFIG_DEFAULT
	endif
	if (V_flag)
		Abort "Error in reading the config file."
	endif

	int notfound = proceedToTable(refNum, tableName)
	return notfound ? NaN : refNum
End

//	Open SIDAM.toml as a notebook
Function SIDAMConfigNoteBook()
	OpenNoteBook/ENCG=1/Z SIDAMPath()+SIDAM_FILE_CONFIG
	if (V_flag)
		OpenNoteBook/ENCG=1/R/Z SIDAMPath()+SIDAM_FILE_CONFIG_DEFAULT
	endif
	if (V_flag)
		Abort "Error in opening the config file."
	endif
End

//	Write configuration as constants
Function SIDAMConfigToProc(Variable refNum)
	fprintf refNum, "StrConstant SIDAM_CTAB = \"%s\"\r", getCtabConfig()
	
	Variable width, height, precision
	getWindowConfig(width, height, precision)
	fprintf refNum, "Constant SIDAM_WINDOW_WIDTH = %f\r", width
	fprintf refNum, "Constant SIDAM_WINDOW_HEIGHT = %f\r", height
	fprintf refNum, "Constant SIDAM_WINDOW_PRECISION = %d\r", precision
	
	STRUCT Colors clrs
	getWindowColorsConfig(clrs)
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_R = %d\r",	clrs.line.red
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_G = %d\r", clrs.line.green
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_B = %d\r", clrs.line.blue
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_R = %d\r", clrs.line2.red
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_G = %d\r", clrs.line2.green
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_B = %d\r", clrs.line2.blue
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_R = %d\r",	clrs.note.red
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_G = %d\r", clrs.note.green
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_B = %d\r", clrs.note.blue
	
	String transparent
	Variable resolution
	getWindowExportConfig(transparent, resolution)
	fprintf refNum, "StrConstant SIDAM_WINDOW_EXPORT_TRANSPARENT = \"%s\"\r", transparent
	fprintf refNum, "Constant SIDAM_WINDOW_EXPORT_RESOLUTION = %d\r", resolution
	
	String nanonis_encoding
	getNanonisEncodingConfig(nanonis_encoding)
	fprintf refNum, "StrConstant SIDAM_NANONIS_TEXTENCODING = \"%s\"\r", nanonis_encoding
End

Static Function/S getCtabConfig()
	Variable refNum = SIDAMConfig(SIDAM_CONFIG_CTAB)
	if (numtype(refNum))
		return ""
	endif
	
	String listStr = "", buffer, line
	do
		FReadLine refNum, buffer
		if (!strlen(buffer) || !CmpStr(buffer, "\r"))	//	EOF or empty line
			break
		endif
		line = removeComment(buffer)
		if (strlen(line))
			listStr += keyFromLine(line) + ";"
		endif
	while (1)
	Close refNum

	return listStr
End

Static Function getWindowConfig(Variable &width, Variable &height,
		Variable &precision)
	Variable refNum = SIDAMConfig(SIDAM_CONFIG_WINDOW)
	if (numtype(refNum))
		return 1
	endif

	String listStr = "", buffer, line
	do
		FReadLine refNum, buffer
		if (!strlen(buffer) || !CmpStr(buffer, "\r"))	//	EOF or empty line
			break
		endif
		line = removeComment(buffer)
		strswitch (keyFromLine(line))
			case "width":
				width = valueFromLine(line)
				break
			case "height":
				height = valueFromLine(line)
				break
			case "precision":
				precision = valueFromLine(line)
				break
		endswitch
	while (1)
	Close refNum
End

Static Structure Colors
	STRUCT RGBColor line
	STRUCT RGBColor line2
	STRUCT RGBColor note
EndStructure

Static Function getWindowColorsConfig(STRUCT Colors &s)
	Variable refNum = SIDAMConfig(SIDAM_CONFIG_WINDOW_COLORS)
	if (numtype(refNum))
		return 1
	endif

	String listStr = "", buffer, line
	do
		FReadLine refNum, buffer
		if (!strlen(buffer) || !CmpStr(buffer, "\r"))	//	EOF or empty line
			break
		endif
		line = removeComment(buffer)
		strswitch (keyFromLine(line))
			case "line":
				lineToRGB(line, s.line)
				break
			case "line2":
				lineToRGB(line, s.line2)
				break
			case "note":
				lineToRGB(line, s.note)
				break
		endswitch
	while (1)
	Close refNum	
End

Static Function lineToRGB(String line, STRUCT RGBColor &clr)
	Wave vw = arrayFromLine(line)
	clr.red = vw[0]
	clr.green = vw[1]
	clr.blue = vw[2]
End

Static Function getWindowExportConfig(String &transparent,
		Variable &resolution)
	Variable refNum = SIDAMConfig(SIDAM_CONFIG_WINDOW_EXPORT)
	if (numtype(refNum))
		return 1
	endif
	
	String listStr = "", buffer, line
	do
		FReadLine refNum, buffer
		if (!strlen(buffer) || !CmpStr(buffer, "\r"))	//	EOF or empty line
			break
		endif
		line = removeComment(buffer)
		strswitch (keyFromLine(line))
			case "transparent":
				transparent = stringFromLine(line)
				break
			case "resolution":
				resolution = valueFromLine(line)
				break
		endswitch
	while (1)
	Close refNum
End

Static Function getNanonisEncodingConfig(String &enc)
	Variable refNum = SIDAMConfig(SIDAM_CONFIG_NANONIS)
	if (numtype(refNum))
		return 1
	endif
	
	String listStr = "", buffer, line
	do
		FReadLine refNum, buffer
		if (!strlen(buffer) || !CmpStr(buffer, "\r"))	//	EOF or empty line
			break
		endif
		line = removeComment(buffer)
		strswitch (keyFromLine(line))
			case "text_encoding":
				enc = stringFromLine(line)
				if (!strlen(enc))
					DefaultTextEncoding
					enc = TextEncodingName(V_defaultTextEncoding, 0)
				endif
				break
		endswitch
	while (1)
	Close refNum
End


//------------------------------------------------------------------------------
//	Concise parser of toml
//
//	Functions in this file are supposed to be called with the module
//	name like SIDAMConfig#keyFromLine().
//	Functions whose name ends with "_" are intended to be used only
//	in this file.
//------------------------------------------------------------------------------
Static Function/S keyFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	return unsurrounding_(StringFromList(0, line, "="))
End

Static Function/S stringFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	//	Multi-lines are not supported.
	return unsurrounding_(StringFromList(1, line, "="))
End

Static Function valueFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	return str2num(StringFromList(1, line, "="))
End

Static Function/WAVE arrayFromLine(String line)
	//	For ease of implementation, "=" is not assumed to be included in the key.
	String str = unsurrounding_(StringFromList(1, line, "="))
	if (strsearch(str, "\"", 0) != -1 || strsearch(str, "'", 0) != -1)
		Make/T/FREE/N=(ItemsInList(str, ",")) tw = unsurrounding_(StringFromList(p, str, ","))
		return tw
	else
		Make/D/FREE/N=(ItemsInList(str, ",")) vw = str2num(StringFromList(p, str, ","))
		return vw
	endif
End

//	Start from the beginning of the configuration file, and search the table
//	specified by the tableName parameter.
Static Function proceedToTable(Variable refNum, String tableName)
	String buffer
	do
		FReadLine refNum, buffer
		if (!strlen(buffer))	//	EOF
			Close refNum
			return 1
		elseif (!CmpStr(buffer, tableName+"\r"))
			return 0
		endif
	while(1)
End

Static Function/S removeComment(String str)
	int i = strsearch(str, "#", 0)
	return SelectString(i == -1, str[0, i-1], str)
End

//------------------------------------------------------------------------------

Static Function/S unsurrounding_(String str)
	int n = strlen(str)-1
	int i0 = strsearch(str, "\"", 0), i1 = strsearch(str, "\"", n, 1)
	int j0 = strsearch(str, "'", 0), j1 = strsearch(str, "'", n, 1)
	int k0 = strsearch(str, "[", 0), k1 = strsearch(str, "]", n, 1)
	int nosurrounding = i0 == -1 && j0 == -1 && k0 == -1
	if (nosurrounding)
		return removeSpace_(str)
	elseif (i0 != -1 && i0 != i1)
		return str[i0+1, i1-1]
	elseif (j0 != -1 && j0 != j1)
		return str[j0+1, j1-1]
	elseif (k0 != -1 && k0 != k1)
		return str[k0+1, k1-1]
	else
		Abort "unmatched quotations"
	endif
End

Static Function/S removeSpace_(String str)
	return ReplaceString(" ", str, "")
End