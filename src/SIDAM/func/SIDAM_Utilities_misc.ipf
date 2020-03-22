#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Return path to the SIDAM directory
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

//	Add the check mark to num-th item of menuStr and return it
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
