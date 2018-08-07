#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//  文字列がシングルクォーテーションで挟まれていたら、それを除く
//******************************************************************************
Function/S KMUnquoteName(String str)
	if (!CmpStr("'",str[strlen(str)-1]))
		str = str[0,strlen(str)-2]
	endif
	if (!CmpStr("'",str[0]))
		str = str[1,strlen(str)-1]
	endif
	return str
End


//******************************************************************************
//	KMMain へのパス文字列を返す
//	KMMain が見つからなければ作成してパス文字列を返す
//	(異なるPCでpxpファイルを開くと KMMain パスが見つからなくなってしまう)
//******************************************************************************
Function/S KMGetPath()
	PathInfo/S KMMain
	if (!V_flag)		//	存在しない
		try
			KMSetPath()
		catch
			Abort
		endtry
		PathInfo/S KMMain
	endif
	return S_path
End

//******************************************************************************
//	KMMain パス設定
//******************************************************************************
Function KMSetPath()
	String path = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	GetFileFolderInfo/Q/Z (path+SIDAM_FOLDER_MAIN+":")
	if(V_Flag)
		GetFileFolderInfo/Q/Z (path+SIDAM_FOLDER_MAIN+".lnk")
		if(V_isAliasShortcut)
			NewPath/O/Q/Z KMMain, S_aliasPath
		else
			Abort "SIDAM folder is not found."
		endif
	else
		NewPath/O/Q/Z KMMain, S_path
	endif
	return 0
End


//******************************************************************************
//	KMAddCheckmark
//		右クリック用メニュー文字列作成補助関数
//		num番目の項目にチェックマークを付けて返す, numが負だったらチェックマークなし
//******************************************************************************
Function/S KMAddCheckmark(Variable num, String menuStr)
	
	if (numtype(num))
		return ""
	elseif (num < 0)
		return menuStr
	endif
	
	String checked = "\\M0:!" + num2char(18)+":", escCode = "\\M0"
	
	//	全ての項目の前にescCodeを付ける
	menuStr = ReplaceString(";", menuStr, ";"+escCode)
	menuStr = escCode + RemoveEnding(menuStr, escCode)
	
	//	選択項目の最初をチェックマークで置き換える
	menuStr = AddListItem(checked, menuStr, ";", num)
	return ReplaceString(":;"+escCode, menuStr, ":")
End
