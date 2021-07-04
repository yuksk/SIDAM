#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilMisc

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Function/S menu()
	return SelectString(defined(SIDAMshowProc), "Show", "Hide")+" SIDAM Procedures"
End

//------------------------------------------------------------------------------
//	Show or hide procedures of SIDAM in the procedure list
//	(Window > Procedure Windows)
//------------------------------------------------------------------------------
Function SIDAMShowProcedures()
	if (defined(SIDAMshowProc))
		Execute/P/Q "SetIgorOption poundUndefine=SIDAMshowProc"
	else
		Execute/P/Q "SetIgorOption poundDefine=SIDAMshowProc"
	endif
	Execute/P "COMPILEPROCEDURES "
End

//------------------------------------------------------------------------------
//	Return path to the SIDAM directory
//------------------------------------------------------------------------------
Function/S SIDAMPath()
	//	path to User Procedures
	String userpath = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"

	GetFileFolderInfo/Q/Z (userpath+SIDAM_FOLDER_MAIN+":")
	if(!V_Flag)
		return S_path
	endif

	GetFileFolderInfo/Q/Z (userpath+SIDAM_FOLDER_MAIN+".lnk")
	if(V_isAliasShortcut)
		return S_aliasPath
	endif

	Abort "SIDAM folder is not found."
End

//------------------------------------------------------------------------------
//	Add the check mark to num-th item of menuStr and return it
//------------------------------------------------------------------------------
Function/S SIDAMAddCheckmark(Variable num, String menuStr)
	if (numtype(num))
		return ""
	elseif (num < 0)
		return menuStr
	endif

	String checked = "\\M0:!" + num2char(18)+":", escCode = "\\M0"

	//	add escCode before all items
	menuStr = ReplaceString(";", menuStr, ";"+escCode)
	menuStr = escCode + RemoveEnding(menuStr, escCode)

	//	replace escCode of num-item with the check mark
	menuStr = AddListItem(checked, menuStr, ";", num)
	return ReplaceString(":;"+escCode, menuStr, ":")
End

//------------------------------------------------------------------------------
//	Return a value from the settings data folder
//------------------------------------------------------------------------------
Function/S SIDAMGetSettings(Wave/Z w, int kind)
	
	if (!WaveExists(w))
		return ""
	endif
	
	DFREF dfr = GetWavesDataFolderDFR(w):$SIDAM_DF_SETTINGS
	if (!DataFolderRefStatus(dfr))
		return ""
	endif
	
	switch (kind)
		case 1:	//	bias
			return getSettingsBias(dfr)
		case 2:	//	current
			return getSettingsCurrent(dfr)
		case 3:	//	comment
			return getSettingsComment(dfr)
		case 4:	//	angle
			return getSettingsAngle(dfr)
	endswitch
End

Static Function/S getSettingsBias(DFREF dfr)
	
	NVAR/Z/SDFR=dfr bias
	if (NVAR_Exists(bias))
		return num2str(bias)
	endif
	
	//	Nanonis
	NVAR/Z/SDFR=dfr 'bias (V)'
	if (NVAR_Exists('bias (V)'))
		return getSettingsFormatStr('bias (V)') + "V"
	endif
	if (DataFolderRefStatus(dfr:Bias))
		NVAR/Z/SDFR=dfr:Bias 'Bias (V)'
		if (NVAR_Exists('Bias (V)'))
			return getSettingsFormatStr('Bias (V)') + "V"
		endif
	endif
	
	return ""
End

Static Function/S getSettingsCurrent(DFREF dfr)
	
	NVAR/Z/SDFR=dfr current
	if (NVAR_Exists(current))
		return num2str(current)
	endif
	
	//	Nanonis
	if (DataFolderRefStatus(dfr:'Z-CONTROLLER'))
		SVAR/Z/SDFR=dfr:'Z-CONTROLLER' Setpoint
		if (SVAR_Exists(Setpoint))
			return Setpoint
		endif
		NVAR/Z/SDFR=dfr:'Z-CONTROLLER' OverwrittenSetpoint = Setpoint
		if (NVAR_Exists(OverwrittenSetpoint))
			return getSettingsFormatStr(OverwrittenSetpoint) + "A"
		endif
	elseif (DataFolderRefStatus(dfr:Current))
		NVAR/Z/SDFR=dfr:Current 'Current (A)'
		return getSettingsFormatStr('Current (A)') + "A"
	endif
	
	return ""
End

Static Function/S getSettingsComment(DFREF dfr)
	
	SVAR/Z/SDFR=dfr text, comment
	if (SVAR_Exists(text))
		return text
	elseif (SVAR_Exists(comment))	//	Nanonis
		return comment
	else
		return ""
	endif
End

Static Function/S getSettingsAngle(DFREF dfr)
	
	NVAR/Z/SDFR=dfr angle		//	RHK SM2
	if (NVAR_Exists(angle))
		return num2str(angle)
	endif
	
	//	For nanonis
	//	Reverse the sign of angle because the angle is positive
	//	for clockwise rotation.
	//	Nanonis 3ds
	SVAR/Z/SDFR=dfr grid = $SIDAMNumStrName("Grid settings", 1)
	if (SVAR_Exists(grid))
		Variable a = str2num(StringFromList(4, grid))
		return num2str(-a)
	endif
	
	//	Nanonis sxm
	NVAR/Z/SDFR=dfr anglesxm = angle_deg
	if (NVAR_Exists(anglesxm))
		return num2str(-anglesxm)
	endif
	NVAR/Z/SDFR=dfr anglesxmold = 'angle (deg)'
	if (NVAR_Exists(anglesxmold))
		return num2str(-anglesxmold)
	endif
	
	return ""
End

Static Function/S getSettingsFormatStr(Variable var)
	
	String str
	switch (floor((log(abs(var))+1)/3))
		case 1:
			sprintf str, "%.2f k", var*1e-3
			break
		case 0:
			sprintf str, "%.2f ", var
			break
		case -1:
			sprintf str, "%.2f m", var*1e3
			break
		case -2:
			sprintf str, "%.2f u", var*1e6
			break
		case -3:
			sprintf str, "%.2f n", var*1e9
			break
		case -4:
			sprintf str, "%.2f p", var*1e12
			break
		case -5:
			sprintf str, "%.2f f", var*1e15
			break
		default:
			str = num2str(var)
	endswitch
	return str
End


//------------------------------------------------------------------------------
//	Functions for absorbing a change of "Liberal object names" in Igor 9.
//	In Igor 8, liberal object names are allowed for variables and strings
//	although it is not written so in the manual. In Igor 9, they are not allowed.
//------------------------------------------------------------------------------
Function/S SIDAMNumStrName(String name, int isString)
	int objectType = isString ? 4 : 3
	#if IgorVersion() >= 9
		return CreateDataObjectName(:, name, objectType, 0, 3)
	#else
		return SelectString(CheckName(name, objectType), name, CleanupName(name, 1))
	#endif
End

Function/S SIDAMStrVarOrDefault(String name, String def)
	if (strsearch(name, ":", 0) == -1)
		return StrVarOrDefault(SIDAMNumStrName(name, 1), def)
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (movedf(name))
		return def
	endif
		
	name = ParseFilePath(0, name, ":", 1, 0)
	name = ReplaceString("'", name, "")
	String str = StrVarOrDefault(SIDAMNumStrName(name, 1), def)
	SetDataFolder dfrSav
	return str
End

Function SIDAMNumVarOrDefault(String name, Variable def)
	if (strsearch(name, ":", 0) == -1)
		return NumVarOrDefault(SIDAMNumStrName(name, 0), def)
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	if (movedf(name))
		return def
	endif
	
	name = ParseFilePath(0, name, ":", 1, 0)
	name = ReplaceString("'", name, "")
	Variable num = NumVarOrDefault(SIDAMNumStrName(name, 0), def)
	SetDataFolder dfrSav
	return num
End

Static Function movedf(String name)
	String df = ParseFilePath(1, name, ":", 1, 0)
	DFREF dfr = $ReplaceString("'", RemoveEnding(df, ":"), "")
	if (!DataFolderRefStatus(dfr))
		return 1
	endif
	SetDataFolder dfr
	return 0
End

