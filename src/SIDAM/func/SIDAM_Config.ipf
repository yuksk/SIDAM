#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMConfig

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Utilities_misc"

//	Return keys of a table as a list
Function/S SIDAMConfigKeys(String tableName)
	Variable refNum
	Open/R/Z refNum as SIDAMConfigPath()
	proceedToTable(refNum, tableName)
	
	String listStr = "", buffer
	do
		FReadLine refNum, buffer
		removeReturn(buffer)
		if (!strlen(buffer))	//	EOF, empty line
			break
		elseif (GrepString(buffer, "^\[.*?\]"))	//	next table
			break
		endif
		removeComment(buffer)
		if (strlen(buffer))
			listStr += keyFromLine(buffer) + ";"
		endif
	while (1)
	Close refNum

	return listStr
End

//	Return contents of a table as a key:value; list
Function/S SIDAMConfigItems(String tableName, [int usespecial])
	usespecial = ParamIsDefault(usespecial) ? 0 : usespecial
	
	String listsep = SelectString(usespecial, ";", SIDAM_CHAR_ITEMSEP)
	String keysep = SelectString(usespecial, ":", SIDAM_CHAR_KEYSEP)

	Variable refNum
	Open/R/Z refNum as SIDAMConfigPath()
	proceedToTable(refNum, tableName)
	
	String listStr = "", buffer
	do
		FReadLine refNum, buffer
		removeReturn(buffer)
		if (!strlen(buffer))	//	EOF, empty line
			break
		elseif (GrepString(buffer, "^\[.*?\]"))	//	next table
			break
		endif
		removeComment(buffer)
		if (strlen(buffer))
			listStr += keyFromLine(buffer) + keysep + stringFromLine(buffer) + listsep
		endif
	while (1)
	Close refNum

	return listStr
End

Static Function removeReturn(String &buffer)
	buffer = RemoveEnding(RemoveEnding(buffer, num2char(10)), num2char(13))
End

//	Return a path to the config file.
//	The config file is searched in the following order.
//	1. User Procedures:SIDAM.toml
//	2. User Procedures:SIDAM:SIDAM.toml
//	3. User Procedures:SIDAM:SIDAM.default.toml
Function/S SIDAMConfigPath()
	Variable refNum
	String path
	
	path = SpecialDirPath("Igor Pro User Files", 0, 0, 0) \
		+ "User Procedures:" + SIDAM_FILE_CONFIG
	if (isConfigExist(path))
		return path
	endif
	
	path = SIDAMPath()+SIDAM_FILE_CONFIG
	if (isConfigExist(path))
		return path
	endif
	
	path = SIDAMPath()+SIDAM_FILE_CONFIG_DEFAULT
	if (isConfigExist(path))
		return path
	endif

	Abort "The config file not found."
End

Static Function isConfigExist(String path)
	Variable refNum
	Open/R/Z refNum as path
	if (V_flag)
		return 0
	else
		Close refNum
		return 1
	endif
End

//	Write configuration as constants
Function SIDAMConfigToProc(Variable refNum)
	fprintf refNum, "StrConstant SIDAM_CTAB = \"%s\"\n", SIDAMConfigKeys("[ctab]")
	fprintf refNum, "StrConstant SIDAM_CTAB_PATH = \"%s\"\n", SIDAMConfigItems("[ctab]", usespecial=1)
	
	fprintf refNum, "StrConstant SIDAM_LOADER_FUNCTIONS = \"%s\"\n", SIDAMConfigItems("[loader.functions]")
	
	String items = SIDAMConfigItems("[window]")
	fprintf refNum, "StrConstant SIDAM_WINDOW_WIDTH = \"%s\"\n", StringByKey("width", items)
	fprintf refNum, "StrConstant SIDAM_WINDOW_HEIGHT = \"%s\"\n", StringByKey("height", items)
	
	items = SIDAMConfigItems("[window.format]")
	fprintf refNum, "StrConstant SIDAM_WINDOW_FORMAT_XY = \"%s\"\n", StringByKey("xy", items)
	fprintf refNum, "StrConstant SIDAM_WINDOW_FORMAT_Z = \"%s\"\n", StringByKey("z", items)
	fprintf refNum, "Constant SIDAM_WINDOW_FORMAT_SHOWUNIT = %d\n", NumberByKey("show_units", items)
	
	items = SIDAMConfigItems("[window.colors]")
	Wave vw = arrayFromValue(StringByKey("line", items))
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_R = %d\n", vw[0]
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_G = %d\n", vw[1]
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_B = %d\n", vw[2]
	Wave vw = arrayFromValue(StringByKey("line2", items))
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_R = %d\n", vw[0]
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_G = %d\n", vw[1]
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_B = %d\n", vw[2]
	Wave vw = arrayFromValue(StringByKey("note", items))
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_R = %d\n", vw[0]
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_G = %d\n", vw[1]
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_B = %d\n", vw[2]
	
	items = SIDAMConfigItems("[window.export]")
	fprintf refNum, "StrConstant SIDAM_WINDOW_EXPORT_TRANSPARENT = \"%s\"\n", StringByKey("transparent", items)
	fprintf refNum, "Constant SIDAM_WINDOW_EXPORT_RESOLUTION = %d\n", NumberByKey("resolution", items)
	
	items = SIDAMConfigItems("[nanonis]")
	String nanonis_encoding = StringByKey("text_encoding", items)
	if (!strlen(nanonis_encoding))
		DefaultTextEncoding
		nanonis_encoding = TextEncodingName(V_defaultTextEncoding, 0)
	endif
	fprintf refNum, "StrConstant SIDAM_NANONIS_TEXTENCODING = \"%s\"\n", nanonis_encoding
	fprintf refNum, "StrConstant SIDAM_NANONIS_LENGTHUNIT = \"%s\"\n", StringByKey("length_unit", items)
	fprintf refNum, "Constant SIDAM_NANONIS_LENGTHSCALE = %f\n", NumberByKey("length_scale", items)
	fprintf refNum, "StrConstant SIDAM_NANONIS_CURRENTUNIT = \"%s\"\n", StringByKey("current_unit", items)
	fprintf refNum, "Constant SIDAM_NANONIS_CURRENTSCALE = %f\n", NumberByKey("current_scale", items)
	fprintf refNum, "StrConstant SIDAM_NANONIS_VOLTAGEUNIT = \"%s\"\n", StringByKey("voltage_unit", items)
	fprintf refNum, "Constant SIDAM_NANONIS_VOLTAGESCALE = %f\n", NumberByKey("voltage_scale", items)
	fprintf refNum, "StrConstant SIDAM_NANONIS_CONDUCTANCEUNIT = \"%s\"\n", StringByKey("conductance_unit", items)
	fprintf refNum, "Constant SIDAM_NANONIS_CONDUCTANCESCALE = %f\n", NumberByKey("conductance_scale", items)
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

Static Function/WAVE arrayFromValue(String value)
	String str = unsurrounding_(value)
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
			Abort "Error in finding a table ("+tableName+") in the config file."
		elseif (!CmpStr(buffer, tableName+"\r"))
			return 0
		endif
	while(1)
End

Static Function removeComment(String &str)
	int i = strsearch(str, "#", 0)
	str = SelectString(i == -1, str[0, i-1], str)
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