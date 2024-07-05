#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMConfig

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Path"
#include "SIDAM_TOML"

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
	Variable axthick
	STRUCT windowformatS format
	STRUCT windowcolorsS colors
	STRUCT windowexportS export
	STRUCT windowctabS ctab
EndStructure

Static Structure windowformatS
	String xy
	String z
	String theta
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

Static Structure windowctabS
	String table
	Variable reverse
	Variable log
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

Static Function/S mainMenuItem()
	return SelectString(strlen(configFile(USER)), "", "Open user config file")
End

Static Function mainMenuDo(int kind)
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
	s.window.format.theta = ""
	s.window.export.transparent = ""
	s.window.ctab.table = ""
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

Static Function readConfig(STRUCT SIDAMConfigStruct &s, int kind)
	Variable refNum
	Open/R/Z refNum as configFile(kind)
	if (V_flag)
		return 1
	endif

	String str = SIDAMTOMLListFromTable(refNum, "[window]")
	s.window.width = strOverwrite(s.window.width, StringByKey("width", str))
	s.window.height = strOverwrite(s.window.height, StringByKey("height", str))
	s.window.axthick = numOverwrite(s.window.axthick, NumberByKey("axthick", str))

	str = SIDAMTOMLListFromTable(refNum, "[window.format]")
	s.window.format.xy = strOverwrite(s.window.format.xy, StringByKey("xy", str))
	s.window.format.z = strOverwrite(s.window.format.z, StringByKey("z", str))
	s.window.format.theta = strOverwrite(s.window.format.theta, StringByKey("theta", str))
	s.window.format.show_units = \
		numOverwrite(s.window.format.show_units, NumberByKey("show_units", str))
	
	str = SIDAMTOMLListFromTable(refNum, "[window.colors]")
	parseColors(s.window.colors.line, StringByKey("line", str))
	parseColors(s.window.colors.line2, StringByKey("line2", str))
	parseColors(s.window.colors.note, StringByKey("note", str))

	str = SIDAMTOMLListFromTable(refNum, "[window.export]")
	s.window.export.transparent = \
		strOverwrite(s.window.export.transparent, StringByKey("transparent", str))
	s.window.export.resolution = \
		numOverwrite(s.window.export.resolution, NumberByKey("resolution", str))

	str = SIDAMTOMLListFromTable(refNum, "[window.ctab]")
	s.window.ctab.table = \
		strOverwrite(s.window.ctab.table, StringByKey("table", str))
	s.window.ctab.reverse = \
		numOverwrite(s.window.ctab.reverse, NumberByKey("reverse", str))
	s.window.ctab.log = numOverwrite(s.window.ctab.log, NumberByKey("log", str))

	s.ctab.path = strOverwrite(s.ctab.path, \
		parsePath(SIDAMTOMLListFromTable(refNum, "[ctab]", usespecial=1), kind))
	s.ctab.keys = parseCtabKeys(s.ctab.path)

	s.loader.path = strOverwrite(\
	    s.loader.path,\
	    StringByKey("path",\
	                parsePath(SIDAMTOMLListFromTable(refNum, "[loader]", usespecial=1), kind),\
	                SIDAM_CHAR_KEYSEP, SIDAM_CHAR_ITEMSEP)\
	   )
	s.loader.functions = strOverwrite(s.loader.functions,\
		SIDAMTOMLListFromTable(refNum, "[loader.functions]"))

	str = SIDAMTOMLListFromTable(refNum, "[nanonis]")
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
	                parsePath(SIDAMTOMLListFromTable(refNum, "[extension]", usespecial=1), kind),\
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
	Wave vw = SIDAMTOMLWaveFromValue(str)
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
