#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMUtilHelp

#include "SIDAM_Utilities_misc"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	KMOpenHelpNote
//		ヘルプファイルを開いて、必要ならばフック関数を設定する
//******************************************************************************
Function KMOpenHelpNote(
	String noteFileName,	//	開かれるべきヘルプファイルの拡張子を除いた名前
	[
		String pnlName,		//	パネルからヘルプが呼ばれるときの、そのパネルの名前
		String title
	])
	
	//	パラメータの検証
	if (!ParamIsDefault(pnlName))
		if (!SIDAMWindowExists(pnlName))
			return 2		//	呼び出したパネルの名前が正しくない(存在しない)場合
		endif
		if (strlen(GetUserData(pnlName,"","KMOpenHelpNote")))	//	既にヘルプウインドウが開かれていたらフォーカスして終了
			DoWindow/F $GetUserData(pnlName,"","KMOpenHelpNote")
			return -1
		endif
	endif
	
	NewPath/O/Q/Z KMHelp, SIDAMPath() + SIDAM_FOLDER_HELP
	OpenNoteBook/K=1/P=KMHelp/R/Z (noteFileName+".ifn")
	if (V_flag)
		OpenNoteBook/K=1/P=KMHelp/R/Z (noteFileName+".ifn.lnk")	//	ショートカットでもいいように
	endif
	if (V_flag)
		return 3	//	ファイルが見つからない場合
	endif
	KillPath/Z KMHelp
	
	//	名前とタイトルの設定
	String noteName = WinName(0,16)
	if (!ParamIsDefault(title))
		DoWindow/T $noteName, title
	endif
	
	//	パネルから呼ばれたのでなければ、ここで終了
	if (ParamIsDefault(pnlName))
		return 0
	endif
	
	//	パネルから呼ばれた場合には、フック関数を設定して、パネルが閉じられた場合に、ヘルプパネルも
	//	閉じるようにする
	SetWindow $noteName hook(self)=KMUtilHelp#hook
	SetWindow $noteName userData(parent)=pnlName
	SetWindow $pnlName hook(KMOpenHelpNote)=KMUtilHelp#hookParent
	SetWindow $pnlName userData(KMOpenHelpNote)=noteName
End
//-------------------------------------------------------------
//	ヘルプウインドウのフック関数
//-------------------------------------------------------------
Static Function hook(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 2)	//	kill でなければ
		return 0
	endif

	String parent = GetUserData(s.winName,"","parent")
	if (!strlen(parent))	//	パネルから呼び出されたのでなければ
		return 0
	endif
	
	if(!SIDAMWindowExists(parent))
		return 0
	endif
	
	SetWindow $parent hook(KMOpenHelpNote)=$""
	SetWindow $parent userData(KMOpenHelpNote)=""
	return 0
End
//-------------------------------------------------------------
//	パネルからヘルプウインドウが呼び出された場合、パネルのフック関数
//-------------------------------------------------------------
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