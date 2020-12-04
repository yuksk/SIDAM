#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilHelp

#include "SIDAM_Utilities_Panel"
#include "SIDAM_Utilities_misc"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Function SIDAMOpenHelpNote(
	String noteFileName,	//	name of a help file without its extension
	String pnlName,			//	name of the parent panel
	String title				//	title given to a help window
	)
	
	//	Check parameters
	if (!SIDAMWindowExists(pnlName))
		return 2
	endif
	String helpWinName = GetUserData(pnlName,"","KMOpenHelpNote")
	if (SIDAMWindowExists(helpWinName))
		DoWindow/F $helpWinName
		return -1
	endif
	
	//	Open a help file
	NewPath/O/Q/Z KMHelp, SIDAMPath() + SIDAM_FOLDER_HELP
	OpenNoteBook/K=1/P=KMHelp/R/Z (noteFileName+".ifn")
	if (V_flag)
		OpenNoteBook/K=1/P=KMHelp/R/Z (noteFileName+".ifn.lnk")		//	for shortcuts
	endif
	if (V_flag)
		return 3	//	file not found
	endif
	KillPath/Z KMHelp
	
	//	Set a title, hook functions, and user data.
	String noteName = WinName(0,16)
	DoWindow/T $noteName, title
	SetWindow $noteName hook(self)=SIDAMUtilHelp#hook
	SetWindow $noteName userData(parent)=pnlName
	SetWindow $pnlName hook(KMOpenHelpNote)=SIDAMUtilHelp#hookParent
	SetWindow $pnlName userData(KMOpenHelpNote)=noteName
End

Static Function hook(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 2)	//	not kill
		return 0
	endif

	String parent = GetUserData(s.winName,"","parent")
	if(SIDAMWindowExists(parent))
		SetWindow $parent hook(KMOpenHelpNote)=$""
		SetWindow $parent userData(KMOpenHelpNote)=""
	endif
	return 0
End

Static Function hookParent(STRUCT WMWinHookStruct &s)
	if (s.eventCode == 17)	//	killVote
		KillWindow/Z $GetUserData(s.winName,"","KMOpenHelpNote")
	endif
	return 0
End


//******************************************************************************
//	Open a help file specified by filename
//******************************************************************************
Function/S SIDAMOpenExternalHelp(String filename)
	String pathStr = SIDAMPath() + SIDAM_FOLDER_HELP + ":" + filename
	//	This should be only for Windows. I don't know how to do it for Macintosh.
	BrowseURL "file:///"+ParseFilePath(5,pathStr,"\\",0,0)
End


//******************************************************************************
//	Check new version
//******************************************************************************
Function SIDAMCheckUpdate()
	PutScrapText FetchURL(SIDAM_URL_FEED)
	
	Make/T/N=1/FREE txtw
	Grep/E="<title>v" "Clipboard" as txtw
	
	Variable major, minor, patch
	String str = txtw[0]
	sscanf str[strsearch(str,"v",0),inf], "v%d%*[.]%d%*[.]%d</title>", major, minor, patch

	if (!major && !minor && !patch)
		DoAlert 0, "Version info is unavailable."
		return 1
	endif
	
	int isNewerMajor = SIDAM_VERSION_MAJOR < major
	int isNewerMinor = SIDAM_VERSION_MINOR < minor
	int isNewerPatch = SIDAM_VERSION_PATCH < patch
	int isNewerAvailable = isNewerMajor || isNewerMinor || isNewerPatch
	String promptStr

	if (isNewerAvailable)
		Sprintf promptStr, "New version (v%d.%d.%d) is available.", major, minor, patch
	else
		Sprintf promptStr, "You are using the latest version."
	endif
	DoAlert 0, promptStr
	return 0
End

Function SIDAMAbout()
	String promptStr
	Sprintf promptStr, "SIDAM v%d.%d.%d", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH
	DoAlert 0, promptStr
End
