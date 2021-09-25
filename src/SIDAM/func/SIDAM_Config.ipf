#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMConfig

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Utilities_misc"

Static Constant DEFAULT = 0
Static Constant USER = 1

Structure SIDAMConfigStruct
	STRUCT windowS window
	STRUCT ctabS ctab
	STRUCT loaderS loader
	STRUCT nanonisS nanonis
	STRUCT extensionS extension
EndStructure

Static Structure windowS
	String width
	String height
	STRUCT windowformatS format
	STRUCT windowcolorsS colors
	STRUCT windowexportS export
EndStructure

Static Structure windowformatS
	String xy
	String z
	Variable show_units
EndStructure

Static Structure windowcolorsS
	STRUCT RGBColor line
	STRUCT RGBColor line2
	STRUCT RGBColor note
EndStructure

Static Structure windowexportS
	String transparent
	Variable resolution
EndStructure

Static Structure ctabS
	String keys
	String path
EndStructure

Static Structure loaderS
	String path
	String functions
EndStructure

Static Structure nanonisS
	String text_encoding
	STRUCT nanonisscaleS length
	STRUCT nanonisscaleS current
	STRUCT nanonisscaleS voltage
	STRUCT nanonisscaleS conductance
EndStructure

Static Structure nanonisscaleS
	String unit
	Variable scale
EndStructure

Static Structure extensionS
	String path
EndStructure

Static Function/S menu()
	return SelectString(strlen(configFile(USER)), "", "Open user config file")
End

Static Function menuDo(int kind)
	if (kind == 0)
		OpenNoteBook/ENCG=1/K=1/R/Z configFile(kind)
	elseif (kind == 1)
		OpenNoteBook/ENCG=1/Z configFile(kind)
	endif
End

Function SIDAMConfigRead(STRUCT SIDAMConfigStruct &s)
	s.window.width = ""
	s.window.height = ""
	s.window.format.xy = ""
	s.window.format.z = ""
	s.window.export.transparent = ""
	s.ctab.path = ""
	s.ctab.keys = ""
	s.loader.path = ""
	s.loader.functions = ""
	s.nanonis.text_encoding = ""
	s.nanonis.length.unit = ""
	s.nanonis.current.unit = ""
	s.nanonis.voltage.unit = ""
	s.nanonis.conductance.unit = ""
	s.extension.path = ""

	readConfig(s, DEFAULT)
	readConfig(s, USER)
End

Function readConfig(STRUCT SIDAMConfigStruct &s, int kind)
	Variable refNum
	Open/R/Z refNum as configFile(kind)
	if (V_flag)
		return 1
	endif

	String str = configItems(refNum, "[window]")
	s.window.width = strOverwrite(s.window.width, StringByKey("width", str))
	s.window.height = strOverwrite(s.window.height, StringByKey("height", str))

	str = configItems(refNum, "[window.format]")
	s.window.format.xy = strOverwrite(s.window.format.xy, StringByKey("xy", str))
	s.window.format.z = strOverwrite(s.window.format.z, StringByKey("z", str))
	s.window.format.show_units = \
		numOverwrite(s.window.format.show_units, NumberByKey("show_units", str))
	
	str = configItems(refNum, "[window.colors]")
	parseColors(s.window.colors.line, StringByKey("line", str))
	parseColors(s.window.colors.line2, StringByKey("line2", str))
	parseColors(s.window.colors.note, StringByKey("note", str))

	str = configItems(refNum, "[window.export]")
	s.window.export.transparent = \
		strOverwrite(s.window.export.transparent, StringByKey("transparent", str))
	s.window.export.resolution = \
		numOverwrite(s.window.export.resolution, NumberByKey("resolution", str))
	
	s.ctab.path = strOverwrite(s.ctab.path, \
		parsePath(configItems(refNum, "[ctab]", usespecial=1), kind))
	s.ctab.keys = parseCtabKeys(s.ctab.path)

	s.loader.path = strOverwrite(\
	    s.loader.path,\
	    StringByKey("path",\
	                parsePath(configItems(refNum, "[loader]", usespecial=1), kind),\
	                SIDAM_CHAR_KEYSEP, SIDAM_CHAR_ITEMSEP)\
	   )
	s.loader.functions = strOverwrite(s.loader.functions,\
		configItems(refNum, "[loader.functions]"))

	str = configItems(refNum, "[nanonis]")
	s.nanonis.text_encoding = strOverwrite(s.nanonis.text_encoding, StringByKey("text_encoding", str))
	s.nanonis.length.unit = strOverwrite(s.nanonis.length.unit, StringByKey("length_unit", str))
	s.nanonis.length.scale = numOverwrite(s.nanonis.length.scale, NumberByKey("length_scale", str))
	s.nanonis.current.unit = strOverwrite(s.nanonis.current.unit, StringByKey("current_unit", str))
	s.nanonis.current.scale = numOverwrite(s.nanonis.current.scale, NumberByKey("current_scale", str))
	s.nanonis.voltage.unit = strOverwrite(s.nanonis.voltage.unit, StringByKey("voltage_unit", str))
	s.nanonis.voltage.scale = numOverwrite(s.nanonis.voltage.scale, NumberByKey("voltage_scale", str))
	s.nanonis.conductance.unit = strOverwrite(s.nanonis.conductance.unit, StringByKey("conductance_unit", str))
	s.nanonis.conductance.scale = numOverwrite(s.nanonis.conductance.scale, NumberByKey("conductance_scale", str))

	s.extension.path = strOverwrite(\
	    s.extension.path, \
	    StringByKey("path",\
	                parsePath(configItems(refNum, "[extension]", usespecial=1), kind),\
	                SIDAM_CHAR_KEYSEP, SIDAM_CHAR_ITEMSEP))

	Close refNum
End

Static Function numOverwrite(Variable original, Variable new)
	//	if no value is yet put in the variable, use the new one
	if (numtype(original))
		return new
	//	if the variable has a value, use the new one if it has a value.
	elseif (!numtype(new))
		return new
	//	otherwise use the original value
	else
		return original
	endif
End

Static Function/S strOverwrite(String original, String new)
	//	if no value is yet put in the variable, use the new one
	if (!strlen(original))
		return new
	//	if the variable has a value, use the new one if it has a value.
	elseif (strlen(new))
		return new
	//	otherwise use the original value
	else
		return original
	endif
End

//	Return contents of a table as a key:value; list
Static Function/S configItems(Variable refNum, String tableName, [int usespecial])
	usespecial = ParamIsDefault(usespecial) ? 0 : usespecial
	
	String listsep = SelectString(usespecial, ";", SIDAM_CHAR_ITEMSEP)
	String keysep = SelectString(usespecial, ":", SIDAM_CHAR_KEYSEP)

	int status = fastforward(refNum, tableName)
	if (status)
		return ""
	endif
	
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

	return listStr
End

Static Function removeReturn(String &buffer)
	buffer = RemoveEnding(RemoveEnding(buffer, num2char(10)), num2char(13))
End

Static Function/S parseCtabKeys(String str)
	Wave/T ctabw = ListToTextWave(str, SIDAM_CHAR_ITEMSEP)
	Make/T/N=(numpnts(ctabw))/FREE keysw = StringFromList(0, ctabw[p], SIDAM_CHAR_KEYSEP)
	String keys = ""
	int i
	for (i = 0; i < numpnts(keysw); i++)
		keys += keysw[i] + ";"
	endfor
	return keys
End

Static Function/S parsePath(String str, Variable kind)
	Wave/T itemsw = ListToTextWave(str, SIDAM_CHAR_ITEMSEP)
	Make/T/N=(numpnts(itemsw))/FREE keysw = StringFromList(0, itemsw[p], SIDAM_CHAR_KEYSEP)
	Make/T/N=(numpnts(itemsw))/FREE valuesw = StringFromList(1, itemsw[p], SIDAM_CHAR_KEYSEP)

	String folder = RemoveEnding(ParseFilePath(1, configFile(kind), ":", 1, 0), ":")
	String rtnstr = "", path

	int i
	for (i = 0; i < numpnts(valuesw); i++)
		path = valuesw[i]
		if (CmpStr(path[0],":"))
			rtnstr += itemsw[i] + SIDAM_CHAR_ITEMSEP
		else
			rtnstr += keysw[i] + SIDAM_CHAR_KEYSEP + folder + path + SIDAM_CHAR_ITEMSEP
		endif
	endfor
	return rtnstr
End

Static Function parseColors(STRUCT RGBColor &s, String str)
	Wave vw = arrayFromValue(str)
	s.red = numOverwrite(s.red, vw[0])
	s.green = numOverwrite(s.green, vw[1])
	s.blue = numOverwrite(s.blue, vw[2])
End

//	Return a path to the config file
//
//	The config file is searched in the following order.
//	1. User Procedures:SIDAM.toml
//	2. User Procedures:SIDAM:SIDAM.toml
//	3. User Procedures:SIDAM:SIDAM.default.toml
Static Function/S configFile(int kind)
	String path0 = SpecialDirPath("Igor Pro User Files", 0, 0, 0) \
			+ "User Procedures:" + SIDAM_FILE_CONFIG
	String path1 = SIDAMPath() + SIDAM_FILE_CONFIG
	String path2 = SIDAMPath() + SIDAM_FILE_CONFIG_DEFAULT
	
	String str
	if (kind == USER)
		str = SIDAMResolvePath(path0)
		if (strlen(str))
			return str
		endif
		return SIDAMResolvePath(path1)
	elseif (kind == DEFAULT)
		str = SIDAMResolvePath(path2)
		if (strlen(str))
			return str
		else
			Abort "The config file not found."
		endif
	endif
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
Static Function fastforward(Variable refNum, String tableName)
	String buffer
	FSetPos refNum, 0
	do
		FReadLine refNum, buffer
		if (!strlen(buffer))	//	EOF
			return 1
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
