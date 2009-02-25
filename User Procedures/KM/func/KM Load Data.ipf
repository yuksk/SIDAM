#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=KMLoadData

#ifndef KMshowProcedures
#pragma hide = 1
#endif


//******************************************************************************
//	フォルダ選択のダイアログを表示して、得たフォルダへのパスをKMLoadDataへ渡します
//******************************************************************************
Function KMLoadDataFromFolder()
	
	GetFileFolderInfo/D/Q/Z=2		//	データフォルダ選択ダイアログを出す
	if (V_Flag == -1)	//	キャンセル
		return 1
	elseif (V_Flag > 0)	//	指定したフォルダが見つからない
		print "**KMLoadDataFromFolder gave error: folder not found."
		return 1
	endif
	
	KMLoadData(S_path, history=1)
	
	return 0
End

//******************************************************************************
//	ファイル・フォルダへの絶対パスを受け取って、拡張子を元に各読み出し関数を呼び出します
//	引数がフォルダである場合には、そのフォルダ以下にあるファイルすべてを読み込みます
//******************************************************************************
Function/WAVE KMLoadData(String pathStr,[int history])
	int i, n
	
	if (strlen(pathStr))	//	パスが渡された場合
		GetFileFolderInfo/Q/Z pathStr
		if (V_Flag)
			print "**KMLoadData gave error: file or folder not found."
			return $""
		endif
	else		//	メニューからの実行などの場合
		GetFileFolderInfo/Q/Z=2	//	ファイル選択ダイアログを表示する
		if (V_Flag == -1)	//	キャンセル
			return $""
		elseif (V_Flag) //	ファイルが見つからない場合
			print "**KMLoadData gave error: file not found."
			return $""
		endif
		pathStr = S_path
	endif
	
	if (ParamIsDefault(history))
		history = 0
	endif
	
	//	渡されたパスがショートカットの場合には、実体を読み込む
	if (V_isAliasShortcut)
		KMLoadData(S_aliasPath, history=history)
		return $""
	endif
	
	//	渡されたパスがフォルダである場合、そのフォルダ以下にあるファイルをすべて読み込む
	if (V_isFolder)
		String pathName = UniqueName("path", 12, 0)
		NewPath/Q/Z $pathName, pathStr
		//	フォルダを含む場合は、それらのフォルダへのパスを引数として自身を呼び出す
		n = ItemsInList(IndexedDir($pathName, -1, 0))
		for (i = 0; i < n; i += 1)
			KMLoadData(IndexedDir($pathName, i, 1))	//	履歴欄表示なし
		endfor
		//	ファイルを含む場合は、それらのファイルへのパスを引数として自身を呼び出す
		n = ItemsInList(IndexedFile($pathName, -1, "????"))
		for (i = 0; i < n; i++)
			KMLoadData(ParseFilePath(2, pathStr, ":", 0, 0) + IndexedFile($pathName, i, "????"))	//	履歴欄表示なし
		endfor
		KillPath $pathName
		//	履歴欄表示
		if (history)
			printf "%sKMLoadData(\"%s\")\r", PRESTR_CMD, pathStr
		endif
		return $""
	endif
	
	//	渡されたパスがファイルである場合、そのファイルを読み込む
	if (V_isFile)
		return KMLoadDataFile(pathStr,history)
	endif
End
//-------------------------------------------------------------
//	渡されたパスがファイルである場合の読み込み
//-------------------------------------------------------------
Static Function/WAVE KMLoadDataFile(String pathStr, int history)
	String fileName = ParseFilePath(0, pathStr, ":", 1, 0)	//	ファイル名
	String fileNameNoExt = ParseFilePath(3, pathStr, ":", 0, 0)	//	拡張子抜きのファイル名
	String extStr = LowerStr(ParseFilePath(4, pathStr, ":", 0, 0))	//	拡張子
	Variable i, n
	
	//	読み込み関数(リスト)を得る
	String fnName = KMLoadDataGetFunction(extStr)
	if (!strlen(fnName))	//	読み込み関数が見つからない場合
		if (strsearch(GetRTStackInfo(3),"KMFileOpenHook",0) >= 0)		//	ドラッグ & ドロップから来た場合
			AbortOnValue 1, 1
		else
			printf "%sNo file loader is found for %s\r", PRESTR_CAUTION, pathStr
			return $""
		endif
	endif
	
	//	得られた関数でファイルを読み込む. 複数ある場合は前から順番に試す
	for (i = 0, n = ItemsInList(fnName, ","); i < n; i += 1)
		DFREF dfrSav = GetDataFolderDFR()
		DFREF dfrNew = KMLoadDataNewDF(fileNameNoExt)	//	入力されれば新しいデータフォルダが作られてそこへ移動する、キャンセルなら空
		if (!DataFolderRefStatus(dfrNew))
			return $""
		endif
		FUNCREF KMLoadDataPrototype fn = $StringFromList(i, fnName, ",")
		try
			Wave/Z w = fn(pathStr)
		catch
			SetDataFolder dfrSav
			KillDataFolder dfrNew
			AbortOnValue 1, 1
		endtry
		SetDataFolder dfrSav
		//	ファイル読み込み後処理
		if (!WaveExists(w))
			KillDataFolder dfrNew
			return $""
		endif
		//	履歴欄表示
		if (history)
			printf "%sKMLoadData(\"%s\")\r", PRESTR_CMD, pathStr
		endif
		//	ctrlが押されていれば読み込まれたウエーブを表示
		if (GetKeyState(1)&1)
			KMDisplay(w=w)
		endif
		return w
	endfor
End
//-------------------------------------------------------------
//	ファイル形式判別->読み込み関数名設定
//-------------------------------------------------------------
Static Function/S KMLoadDataGetFunction(String extStr)
	Variable refNum
	String listStr = "", buffer = ""
	
	Open/R/T="????" refNum as (KMGetPath()+KM_FOLDER_LOADER+":"+KM_FILE_LOADERLIST)
	do
		FReadLine refNum, buffer
		if (strlen(buffer) == 0)	//	ファイルの最後まで読み込んだ場合
			break
		elseif (!stringmatch(buffer[0,1],"//"))	//	コメント行は除く
			listStr += buffer
		endif
	while (1)
	Close refNum
	
	String fnName = StringFromList(1, GrepList(liststr,extStr,0,"\r"), ":")
	return SelectString(strlen(fnName), "", fnName[0,strlen(fnName)-2])	//	改行文字を除いて返す
End
//-------------------------------------------------------------
//	読み込み関数のプロトタイプ
//-------------------------------------------------------------
Function/WAVE KMLoadDataPrototype(String pathStr)
	Abort
End


//******************************************************************************
//	データが読み込まれるデータフォルダを作成してそれへのパスを返す
//******************************************************************************
Static Function/DF KMLoadDataNewDF(String fileName)
	Variable dfExist = DataFolderExists("root:"+PossiblyQuoteName(filename))
	String newName
	if (dfExist)
		newName = newDFPnl(fileName)
	else
		newName = filename
	endif
	
	if (strlen(newName))
		NewDataFolder/S root:$newName
		return GetDataFolderDFR()
	else
		return $""
	endif
End
//-------------------------------------------------------------
//	シンプルな名前入力パネルを表示する
//-------------------------------------------------------------
Static Function/S newDFPnl(String fileName)
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	パネルからの入力を受け取るための変数
	String/G name
	
	String pnlName = KMNewPanel("Load Data...", 335, 105)
	
	SetDrawLayer ProgBack
	DrawText 8,20,"The following name is already used as a datafolder."
	DrawText 8,37,"Enter a new name to make another datafolder."
	
	SetVariable nameV title="", pos={8,46}, size={320,16}, bodyWidth=320, focusRing=0, win=$pnlName
	SetVariable nameV value= _STR:fileName, proc=KMLoadData#newDFPnlSetVar, win=$pnlName
	Button doB title="Do It", pos={7,77}, disable=2, win=$pnlName
	Button cancelB title="Cancel", pos={259,77}, win=$pnlName
	ModifyControlList "doB;cancelB" size={70,22}, proc=KMLoadData#newDFPnlButton, focusRing=0, win=$pnlName
	
	KMCheckSetVarString(pnlName, "nameV", 0, maxlength=0)	//	赤く表示するため
	
	//	ユーザーからの入力を待つ
	PauseForUser $pnlName
	
	//	フリーデータフォルダを出る前に入力内容を受け渡す
	String rtnStr = name
	
	SetDataFolder dfrSav
	return rtnStr
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function newDFPnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode == -1)
		return 1
	endif
	
	Variable length = KMCheckSetVarString(s.win, s.ctrlName, 0, minlength=1, maxlength=MAX_OBJ_NAME)
	Variable name = DataFolderExists("root:"+PossiblyQuoteName(s.sval))
	
	if (length || name)
		Button doB disable=2, win=$s.win
		KMCheckSetVarString(s.win, s.ctrlName, 0, maxlength=0)	//	赤く表示するため
	else
		Button doB disable=0, win=$s.win
	endif
End
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function newDFPnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	SVAR/Z name
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