#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMUtilHelp

#include "KM Utilities_Compatibility"
#include "KM Utilities_Panel"

#ifndef KMshowProcedures
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
		if (!KMWindowExists(pnlName))
			return 2		//	呼び出したパネルの名前が正しくない(存在しない)場合
		endif
		if (strlen(GetUserData(pnlName,"","KMOpenHelpNote")))	//	既にヘルプウインドウが開かれていたらフォーカスして終了
			DoWindow/F $GetUserData(pnlName,"","KMOpenHelpNote")
			return -1
		endif
	endif
	
	NewPath/O/Q/Z KMHelp, KMGetPath() + KM_FOLDER_HELP
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
	
	if(!KMWindowExists(parent))
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
//	KMGetFunction
//		fnStrで指定された関数を含むファイルの絶対パスと関数そのものの定義文字列を返す
//******************************************************************************
Function/S KMGetFunction(fnStr,[sepStr, pathStr])
	String fnStr		//	関数の名前 ex. KMGetFunction
	String sepStr		//	絶対パスと定義文字列を区切る文字、デフォルトはセミコロン
	String pathStr	//	再帰時に使用
	
	if ( ParamIsDefault(pathStr) )
		PathInfo KMMain
		pathStr = S_path
	endif
	
	if ( ParamIsDefault(sepStr) )
		sepStr = ";"
	endif
	
	String tmpPath = UniqueName("tmpPath", 12, 0)
	NewPath/Q $tmpPath, pathStr
	if ( V_flag )
		return ""
	endif
	
	int i, n
	String listStr, rtnStr
	
	//	最初にディレクトリの中にあるipfファイルを探す
	listStr = IndexedFile($tmpPath, -1, ".ipf")
	for ( i = 0, n = ItemsInList(listStr); i < n; i++ )
		Grep/E=("(?i)function "+fnStr+"[^a-zA-Z0-9]")/Q/LIST/P=$tmpPath StringFromList(i, listStr)
		if ( V_value )	//	見つかったら
			KillPath $tmpPath
			KillStrings/Z S_fileName
			return pathStr + ":" + StringFromList(i, listStr) + sepStr + S_value[9,strlen(S_value)-2]
		endif
	endfor 
	
	//	ipfファイルの中に目的のものが見つからなければ、含まれているディレクトリの中を再帰的に探す
	listStr = IndexedDir($tmpPath, -1, 1)
	KillPath $tmpPath
	for ( i = 0, n = ItemsInList(listStr); i < n; i++ )
		rtnStr = KMGetFunction(fnStr, sepStr=sepStr, pathStr=StringFromList(i, listStr))
		if ( strlen(rtnStr) )
			return rtnStr
		endif
	endfor
	
	return ""
End


//******************************************************************************
//	KMCheckUpdate
//		更新チェック
//******************************************************************************
Function KMCheckUpdate()
	Variable alert = CmpStr(GetRTStackInfo(2), "KMCheckUpdateBackground")	//	バックグラウンドで呼ばれた場合でなければ真
	String titleStr = "Updates for KM rev. "+num2str(KM_REVISION)
	
	String xml = FetchURL(KM_URL_LOG)
	Variable error =GetRTError(1)
	if (error)
		if (alert)
			DoAlert/T=titleStr 0, "Log file not found."
		endif
		return 2
	endif

	Variable rev = KMCheckUpdateGetRev(xml)
	
	if (rev > KM_REVISION)
		//	新しいバージョンがある時にはバックグラウンドで呼ばれた場合にでもアラートを出す
		int numOfUpdates = KMCheckUpdateCountUpdates(xml,KM_REVISION)
		String promptStr = "New version is available (rev. " + num2istr(rev) + ", "
		promptStr += num2istr(numOfUpdates) + " update"
		promptStr += SelectString(numOfUpdates > 1, "", "s") + "). "
		promptStr += "Do you want to open the change log?"
		DoAlert/T=titleStr 1, promptStr
		if (V_flag == 1)
			BrowseURL KM_URL_LOG;
		endif
	elseif (alert)
		if (!rev)
			DoAlert/T=titleStr 0, "Log file not found."
		else
			DoAlert/T=titleStr 0, "You are using the latest version of KM."
		endif
	endif
	
	return 1
End

Static Function KMCheckUpdateGetRev(String xml, [int &start])
	
	int index = ParamIsDefault(start) ? 0 : start
	int v0 = strsearch(xml, "<up", index)
	int v1 = strsearch(xml, "rev=\"", v0)
	int v2 = strsearch(xml, "\">", v1)
	
	if (!ParamIsDefault(start))
		start = v2 + 2
	endif
	return str2num(xml[v1+5,v2-1]	)
End

Static Function KMCheckUpdateCountUpdates(String xml, int rev)
	int count = 0,index = 0
	do
		count++
	while (KMCheckUpdateGetRev(xml,start=index) > rev)
	return count-1
End

Function/S KMCheckUpdateMenu()
	return "Updates for KM rev. " + num2str(KM_REVISION)
End

//	バックグラウンドで更新チェックを行う関数
Function KMCheckUpdateBackground(s)
	STRUCT WMBackgroundStruct &s
	KMCheckUpdate()
	return 1
End