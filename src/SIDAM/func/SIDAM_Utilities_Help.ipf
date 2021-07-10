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


Function/S SIDAMBrowseHelp(String kind)
	strswitch(kind)
		case "shortcuts":
			BrowseURL SIDAM_URL_SHORTCUTS
			break
		case "commands":
			BrowseURL SIDAM_URL_COMMANDS
			break
	endswitch
End

Function SIDAMAbout()
	String promptStr
	Sprintf promptStr, "SIDAM v%d.%d.%d", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH
	DoAlert 0, promptStr
End
