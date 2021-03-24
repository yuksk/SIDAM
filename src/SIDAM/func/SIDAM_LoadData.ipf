#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMLoadData

#include "SIDAM_Display"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Panel"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif


//@
//	Load data files
//
//	Parameters
//	----------
//	pathStr : string
//		Path to a file or a directory. When a path to a directory is given,
//		files under the directory are loaded recursively.
//	history : int
//		0 or !0. Set !0 to print this command in the history.
//
//	Returns
//	-------
//	wave
//		Loaded wave
//@
Function/WAVE SIDAMLoadData(String pathStr, [int history])

	history = ParamIsDefault(history) ? 0 : history

	int isFolder
	if(validatePath(pathStr, isFolder))
		return $""
	endif
	
	//	If pathStr is a folder, load all the files in the folder and subfolders
	if (isFolder)
		int i, n
		String pathName = UniqueName("path", 12, 0)
		NewPath/Q/Z $pathName, pathStr
		
		//	If a folder(s) is included in pathStr, call this function
		//	for the folder(s)
		n = ItemsInList(IndexedDir($pathName, -1, 0))
		for (i = 0; i < n; i += 1)
			SIDAMLoadData(IndexedDir($pathName, i, 1))		//	no history
		endfor

		//	If a file(s) is included in pathStr, call this function
		//	for the file(s)
		n = ItemsInList(IndexedFile($pathName, -1, "????"))
		for (i = 0; i < n; i++)
			SIDAMLoadData(ParseFilePath(2, pathStr, ":", 0, 0) \
				+ IndexedFile($pathName, i, "????"))	//	no history
		endfor
		KillPath $pathName
		
		if (history)
			printHistory(pathStr)
		endif
		return $""
	endif
	
	return loadDataFile(pathStr,history)
End

Static Function validatePath(String &pathStr, int &isFolder)
	String errMsg = PRESTR_CAUTION + "SIDAMLoadData gave error: "
	
	if (strlen(pathStr))
		GetFileFolderInfo/Q/Z pathStr
		if (V_Flag)
			printf "%sfile or folder not found.\r", errMsg
			return V_Flag
		endif
		
		if (V_isAliasShortcut)
			pathStr = S_aliasPath	//	Use path to the actual file
		endif
		
		if (V_isFolder)
			isFolder = 1
		endif
		
		return V_Flag
	endif

	//	called from the menu
	GetLastUserMenuInfo
	isFolder = V_value == 2

	if (isFolder)
		GetFileFolderInfo/D/Q/Z=2	//	display a dialog to select a folder
	else
		GetFileFolderInfo/Q/Z=2	//	display a dialog to select a file
	endif
	if (V_Flag == -1)	//	user cancel
		return V_Flag
	elseif (V_Flag)
		printf "%sfile or folder not found.\r", errMsg
	endif
	pathStr = S_path
	return V_Flag	
End

Static Function/WAVE loadDataFile(String pathStr, int history)
	String fileName = ParseFilePath(0, pathStr, ":", 1, 0)				//	file name
	String fileNameNoExt = ParseFilePath(3, pathStr, ":", 0, 0)		//	file name without extension
	String extStr = LowerStr(ParseFilePath(4, pathStr, ":", 0, 0))	//	extension
	int i, n
	
	//	Fetch function names from functions.ini (or functions.default.ini).
	String fnName = fetchFunctionName(extStr)
	if (!strlen(fnName))	//	function is not found
		if (strsearch(GetRTStackInfo(3),"SIDAMFileOpenHook",0) >= 0)		//	called by drag && drop
			AbortOnValue 1, 1
		else
			printf "%sNo file loader is found for %s\r", PRESTR_CAUTION, pathStr
			return $""
		endif
	endif
	
	//	Load a data file with the obtained function(s)
	for (i = 0, n = ItemsInList(fnName, ","); i < n; i += 1)
		DFREF dfrSav = GetDataFolderDFR()
		DFREF dfrNew = createNewDFandMove(fileNameNoExt)
		if (!DataFolderRefStatus(dfrNew))
			return $""
		endif
		FUNCREF SIDAMLoadDataPrototype fn = $StringFromList(i, fnName, ",")
		try
			Wave/Z w = fn(pathStr)
		catch
			SetDataFolder dfrSav
			KillDataFolder dfrNew
			AbortOnValue 1, 1
		endtry
		SetDataFolder dfrSav
		
		if (!WaveExists(w))
			KillDataFolder dfrNew
			return $""
		endif
		
		if (history)
			printHistory(pathStr)
		endif
		
		int isCtrlPressed = GetKeyState(1)&1
		if (isCtrlPressed)
			SIDAMDisplay(w, history=1)
		endif
		return w
	endfor
End

Static Function/S fetchFunctionName(String extStr)
	int i
	String item, key
	for (i = 0; i < ItemsInList(SIDAM_LOADER_FUNCTIONS); i++)
		item = StringFromList(i, SIDAM_LOADER_FUNCTIONS)
		key = StringFromList(0, item, ":")
		if (WhichListItem(extStr, key, ",") != -1)
			return StringFromList(1, item, ":")
		endif
	endfor

	return ""
End

Static Function printHistory(String pathStr)
	printf "%sSIDAMLoadData(\"%s\")\r", PRESTR_CMD, ReplaceString("\\",pathStr,"\\\\")
End

//	Prototype of data loading functions
Function/WAVE SIDAMLoadDataPrototype(String pathStr)
	Abort
End

//-----------------------------------------------------------------------------------------------
//	Creates a new data folder where data files will be loaded and return the data folder reference
//-----------------------------------------------------------------------------------------------
Static Function/DF createNewDFandMove(String fileName)
	//	If root:$filename already exists, show a panel to receive a new name
	int dfExist = DataFolderExists("root:"+PossiblyQuoteName(filename))

	//	Do not use String newName = SelectString(dfExist, filename, pnl(filename))
	//	because pnl(filename) is called even when dfExist is 0.
	String newName
	if (dfExist)
		newName = pnl(filename)
	else
		newName = filename
	endif
	
	//	When the cancel button in the panel was clicked	
	if (!strlen(newName))
		return $""
	endif

	NewDataFolder/S root:$newName
	return GetDataFolderDFR()
End

//	Show a panel to receive a name of a new data folder
Static Function/S pnl(String fileName)
	//	Prepare a global string to receive a new name from the panel
	String strName = UniqueName("newname", 4, 0)
	String/G $strName
	
	String pnlName = SIDAMNewPanel("Load Data...", 335, 105)
	SetWindow $pnlName userData(strName)=strName
	
	SetDrawLayer ProgBack
	DrawText 8,20,"The following name is already used as a datafolder."
	DrawText 8,37,"Enter a new name to make another datafolder."
	
	SetVariable nameV title="", pos={8,46}, size={320,16}, bodyWidth=320, focusRing=0, win=$pnlName
	SetVariable nameV value= _STR:fileName, proc=SIDAMLoadData#pnlSetVar, win=$pnlName
	Button doB title="Do It", pos={7,77}, disable=2, win=$pnlName
	Button cancelB title="Cancel", pos={259,77}, win=$pnlName
	ModifyControlList "doB;cancelB" size={70,22}, proc=SIDAMLoadData#pnlButton, focusRing=0, win=$pnlName
	
	SIDAMValidateSetVariableString(pnlName, "nameV", 0, maxlength=0)	//	maxlength=0 is to make the background red
	
	do
		PauseForUser/C $pnlName
	while (V_Flag)
	
	//	Get a name saved in the global string
	SVAR name = $strName
	String rtnStr = name
	KillStrings $strName
	
	return rtnStr
End

//	Controls
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either enter key or end edit
	if (s.eventCode != 2 && s.eventCode != 8)
		return 1
	endif
	
	int exceedLength = SIDAMValidateSetVariableString(s.win, s.ctrlName, 0, minlength=1, maxlength=MAX_OBJ_NAME)
	int alreadyExist = DataFolderExists("root:"+PossiblyQuoteName(s.sval))
	
	if (exceedLength || alreadyExist)
		Button/Z doB disable=2, win=$s.win
		//	The background does not become red somehow. Igor's bug?
		SIDAMValidateSetVariableString(s.win, "nameV", 0, maxlength=0)	//	maxlength=0 is to make the background red
	else
		Button/Z doB disable=0, win=$s.win
	endif
End

Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	SVAR name = $GetUserData(s.win,"","strName")
	strswitch (s.ctrlName)
		case "doB":
			ControlInfo/W=$s.win nameV
			name = S_Value
			break
		case "cancelB":
			name = ""
			break
	endswitch
	KillWindow $s.win
End
