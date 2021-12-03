#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName=SIDAMStartExit

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include "SIDAM_Config"
#include "SIDAM_Constants"

//******************************************************************************
//	Start SIDAM
//******************************************************************************
Function SIDAMStart()
	printf "\r SIDAM %d.%d.%d\r", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH

	//	Construct SIDAM_Procedures.ipf and complie
	createProcFile()
	Execute/P "INSERTINCLUDE \"" + SIDAM_FILE_INCLUDE + "\""
	Execute/P "COMPILEPROCEDURES "
	
	SetIgorHook BeforeFileOpenHook = SIDAMFileOpenHook
	SetIgorHook BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	SetIgorHook AfterCompiledHook = SIDAMAfterCompiledHook
End

#if IgorVersion() >= 9
Function SIDAMSource()
	Execute/P/Q "SIDAMStartExit#createProcFile()"
	Execute/P "RELOAD CHANGED PROCS "
	Execute/P "COMPILEPROCEDURES "
End
#else
Function SIDAMSource()
	Execute/P/Q "SIDAMStartExit#createProcFile()"
	Execute/P "COMPILEPROCEDURES "
End
#endif

Static Function createProcFile()
	STRUCT SIDAMConfigStruct s
	SIDAMConfigRead(s)
	
	//	Make a list of ipf files
	//	The core files
	Make/T/FREE lw = {"SIDAM_Menus.ipf", "SIDAM_Constants.ipf", "SIDAM_Hook.ipf"}
	//	file loaders
	appendIpf(lw, s.loader.path)
	//	extensions
	appendIpf(lw, s.extension.path)
	
	// Open SIDAM_Procedures.ipf
	Variable refNum
	String pathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	Open/P=$pathName/Z refNum, as SIDAM_FILE_INCLUDE+".ipf"
	KillPath $pathName
	if (V_flag)
		return 0
	endif
	
	//	write the hide pragma
	fprintf refNum, "//This file was automatically generated by SIDAM.\r"
	fprintf refNum, "#ifndef SIDAMshowProc\r#pragma hide = 1\r#endif\r"
	//	write #include ...
	int i
	for(i = 0; i < numpnts(lw); i++)
		fprintf refNum, "#include \"%s\"\r", RemoveEnding(lw[i],".ipf")
	endfor
	writeConstants(refNum, s)
	
	Close refNum
End

Static Function appendIpf(Wave/T listw, String str)
	int i
	for (i = 0; i < ItemsInList(str); i++)
		Wave/T/Z w1 = ipfList(StringFromList(i, str))
		if (WaveType(w1,1) == 2)
			Concatenate/NP/T/FREE {w1}, listw
		endif
	endfor
End

//	make a list of ipf files under a folder
Static Function/WAVE ipfList(String folderpath)
	folderpath = ParseFilePath(2, folderpath, ":", 0, 0)
	String pathName = UniqueName("tmpPath",12,0)
	NewPath/O/Q/Z $pathName, folderpath
	if (V_flag)	//	the folder is not found
		print folderpath + " is not found."
		return $""
	endif

	String listStr = IndexedFile($pathName,-1,".ipf")
	Make/FREE/T/N=(ItemsInList(listStr)) w
	
	String userprocfolder = SpecialDirPath("Igor Pro User Files", 0, 0, 0) \
		+ "User Procedures:"
	int isInUserProc = stringmatch(folderpath, userprocfolder+"*")
	if (isInUserProc)
		w = StringFromList(p,listStr)
	else
		w = folderpath + StringFromList(p,listStr)
	endif
	
	String dirListStr = IndexedDir($pathName,-1,0)
	int i, n = ItemsInList(dirListStr)
	for (i = 0; i < n; i++)
		Concatenate/T {ipfList(folderpath+StringFromList(i,dirListStr))}, w
	endfor

	KillPath $pathName

	return w
End

//	Write configuration as constants
Static Function writeConstants(Variable refNum, STRUCT 	SIDAMConfigStruct &s)
	fprintf refNum, "StrConstant SIDAM_CTAB = \"%s\"\n", s.ctab.keys
	fprintf refNum, "StrConstant SIDAM_CTAB_PATH = \"%s\"\n", s.ctab.path
	
	fprintf refNum, "StrConstant SIDAM_LOADER_FUNCTIONS = \"%s\"\n", s.loader.functions
	
	fprintf refNum, "StrConstant SIDAM_WINDOW_WIDTH = \"%s\"\n", s.window.width
	fprintf refNum, "StrConstant SIDAM_WINDOW_HEIGHT = \"%s\"\n", s.window.height
	fprintf refNum, "Constant SIDAM_WINDOW_AXTHICK = %f\n", s.window.axthick

	fprintf refNum, "StrConstant SIDAM_WINDOW_FORMAT_XY = \"%s\"\n", s.window.format.xy
	fprintf refNum, "StrConstant SIDAM_WINDOW_FORMAT_Z = \"%s\"\n", s.window.format.z
	fprintf refNum, "Constant SIDAM_WINDOW_FORMAT_SHOWUNIT = %d\n", s.window.format.show_units
	
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_R = %d\n", s.window.colors.line.red
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_G = %d\n", s.window.colors.line.green
	fprintf refNum, "Constant SIDAM_WINDOW_LINE_B = %d\n", s.window.colors.line.blue
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_R = %d\n", s.window.colors.line2.red
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_G = %d\n", s.window.colors.line2.green
	fprintf refNum, "Constant SIDAM_WINDOW_LINE2_B = %d\n", s.window.colors.line2.blue
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_R = %d\n", s.window.colors.note.red
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_G = %d\n", s.window.colors.note.green
	fprintf refNum, "Constant SIDAM_WINDOW_NOTE_B = %d\n", s.window.colors.note.blue
	
	fprintf refNum, "StrConstant SIDAM_WINDOW_EXPORT_TRANSPARENT = \"%s\"\n", s.window.export.transparent
	fprintf refNum, "Constant SIDAM_WINDOW_EXPORT_RESOLUTION = %d\n", s.window.export.resolution

	fprintf refNum, "StrConstant SIDAM_WINDOW_CTAB_TABLE = \"%s\"\n", s.window.ctab.table
	fprintf refNum, "Constant SIDAM_WINDOW_CTAB_REVERSE = %d\n", s.window.ctab.reverse
	fprintf refNum, "Constant SIDAM_WINDOW_CTAB_LOG = %d\n", s.window.ctab.log
	
	String nanonis_encoding = s.nanonis.text_encoding
	if (!strlen(nanonis_encoding))
		DefaultTextEncoding
		nanonis_encoding = TextEncodingName(V_defaultTextEncoding, 0)
	endif
	fprintf refNum, "StrConstant SIDAM_NANONIS_TEXTENCODING = \"%s\"\n", nanonis_encoding
	fprintf refNum, "StrConstant SIDAM_NANONIS_LENGTHUNIT = \"%s\"\n", s.nanonis.length.unit
	fprintf refNum, "Constant SIDAM_NANONIS_LENGTHSCALE = %f\n", s.nanonis.length.scale
	fprintf refNum, "StrConstant SIDAM_NANONIS_CURRENTUNIT = \"%s\"\n", s.nanonis.current.unit
	fprintf refNum, "Constant SIDAM_NANONIS_CURRENTSCALE = %f\n", s.nanonis.current.scale
	fprintf refNum, "StrConstant SIDAM_NANONIS_VOLTAGEUNIT = \"%s\"\n", s.nanonis.voltage.unit
	fprintf refNum, "Constant SIDAM_NANONIS_VOLTAGESCALE = %f\n", s.nanonis.voltage.scale
	fprintf refNum, "StrConstant SIDAM_NANONIS_CONDUCTANCEUNIT = \"%s\"\n", s.nanonis.conductance.unit
	fprintf refNum, "Constant SIDAM_NANONIS_CONDUCTANCESCALE = %f\n", s.nanonis.conductance.scale
End


//******************************************************************************
//	Exit SIDAM
//******************************************************************************
Function SIDAMExit()
	SetIgorHook/K BeforeFileOpenHook = SIDAMFileOpenHook
	SetIgorHook/K AfterCompiledHook = SIDAMAfterCompiledHook
	SetIgorHook/K BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	Execute/P/Q/Z "DELETEINCLUDE \""+SIDAM_FILE_INCLUDE+"\""
	Execute/P/Q/Z "SetIgorOption poundUndefine=SIDAMshowProc"
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "BuildMenu \"All\""
End

Static Function/S mainMenuItem()
	//	"Restart" when the shift key is pressed
	return SelectString(GetKeyState(0) && 0x04, "Exit", "Restart") + " SIDAM"
End

Static Function mainMenuDo()
	GetLastUserMenuInfo
	int isRestart = !CmpStr(S_value, "Restart SIDAM")

	SIDAMExit()

	if (isRestart)
		sidam()
	endif
End
