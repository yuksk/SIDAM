#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	KMSuffixStr:	入力番号をdigit桁の文字列として返す
//******************************************************************************
Function/S KMSuffixStr(num,[digit])
	int num, digit
	
	if (ParamIsDefault(digit))
		digit = 3
	endif
	
	String rtnStr = num2str(num)
	int digitOfNum = abs(num) ? floor(log(num))+1 : 1
	int i
	
	for (i = digitOfNum; i < digit; i++)
		rtnStr = "0"+rtnStr
	endfor
	
	return rtnStr
End


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
//	KMUniqueName
//		UniqueNameの拡張版。隠されているウインドウ等まで名前の重複がないかどうか調べる。
//		type = 6-10に対して機能する。それ以外の場合はUniqueNameの結果を返す。
//******************************************************************************
Function/S KMUniqueName(baseName,type,start)
	String baseName
	int type, start
	
	if (type < 6 || type > 10)
		return UniqueName(baseName,type,start)
	endif
	
	String winStr
	switch (type)
		case 6:	//	Graph
			winStr = "WIN:1"
			break
		case 7:	//	Table
			winStr = "WIN:2"
			break
		case 8:	//	Layout
			winStr = "WIN:4"
			break
		case 9:	//	Panel
			winStr = "WIN:64"
			break
		case 10:	//	Notebook
			winStr = "WIN:16"
			break
	endswitch
	
	int i = start
	String winListStr = WinList(baseName+"*",";",winStr), pnlName
	do
		pnlName = UniqueName(baseName, type, i++)
	while(WhichListItem(pnlName,winListStr)>=0)
	
	return pnlName
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
	GetFileFolderInfo/Q/Z (path+"KM:")
	if(V_Flag)
		GetFileFolderInfo/Q/Z (path+"KM.lnk")
		if(V_isAliasShortcut)
			NewPath/O/Q/Z KMMain, S_aliasPath
		else
			Abort "KM folder is not found."
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


//******************************************************************************
//	KMMakeLog
//		pathStr 以下の拡張子 extStr を持つファイルについてログをcsvファイルで出力する
//******************************************************************************
Static StrConstant ks_logfn = "3ds:LoadNanonis3dsLog;"

Function KMMakeLog(sourceFolderPath, extStr, [destination])
	String sourceFolderPath, extStr, destination
	
	GetFileFolderInfo/Q/Z sourceFolderPath
	if (V_Flag || !V_isFolder)
		print "**KMMakeLog gave error: source folder is not found."
		return 1
	endif
	
	//	データ列取得
	FUNCREF KMMakeLogPrototype fn = $StringByKey(extStr, ks_logfn)
	Wave/T w = KMMakeLogRecursive(sourceFolderPath, "."+extStr, fn)
	Variable numOfData = DimSize(w,0) ? limit(DimSize(w,1),1,inf) : 0
	if (!numOfData)
		return 0
	endif
	
	//	ソート
	Make/N=(DimSize(w,1))/T/FREE key = w[17][p]	//	17 は start
	Make/N=(DimSize(w,1))/FREE index = p
	Sort/R key, index		//	start が後のものが上に来る
	
	//	出力ファイルを用意する
	//	destinationが指定されていない場合には、保存先はデスクトップ, 保存名はソースフォルダの名前
	//	フォルダが指定されている場合には、保存先はそのフォルダ、保存名はソースフォルダの名前
	//	ファイルまで指定されているようであれば、そのフォルダと名前で保存
	String destFolderPath, destFileName
	if (ParamIsDefault(destination))
		destFolderPath = SpecialDirPath("Desktop", 0, 0, 0)				//	デスクトップ
		destFileName = ParseFilePath(0, sourceFolderPath, ":", 1, 0)+".csv"	//	ソースフォルダの名前を出力ファイル名にする
	else
		GetFileFolderInfo/Q/Z destination
		if (V_Flag)
			print "**KMMakeLog gave error: destination not found."
			return 1
		elseif (V_isFolder)
			destFolderPath = destination
			destFileName = ParseFilePath(0, sourceFolderPath, ":", 1, 0)+".csv"	//	ソースフォルダの名前を出力ファイル名にする
		elseif (V_isFile)
			destFolderPath = ParseFilePath(1, destination, ":", 1, 0)
			destFileName = ParseFilePath(0, destination, ":", 1, 0)
		endif
	endif
	destination = destFolderPath + destFileName
	Variable refNum
	Open/Z refNum as destination
	
	//	ラベル列出力
	wfprintf refNum, "%s,", fn("")
	fprintf refNum, "\r"
	
	//	データ列出力
	Make/N=(DimSize(w,0))/T/FREE tw
	int i
	for (i = 0; i < numOfData; i++)
		tw = w[p][index[i]]
		wfprintf refNum, "%s,", tw
		fprintf refNum, "\r"
	endfor
	
	Close refNum
End

//	pathStr以下のextStrを持つファイルにfnを再帰的に実行するための関数
Static Function/WAVE KMMakeLogRecursive(pathStr, extStr, fn)
	String pathStr, extStr
	FUNCREF KMMakeLogPrototype fn
	
	int i, n
	String str
	Make/N=0/T/FREE w
	
	GetFileFolderInfo/Q/Z pathStr
	
	if (V_isFolder)
		String pathName = UniqueName("path", 12, 0)
		NewPath/Q/Z $pathName, pathStr
		//	フォルダを含む場合は、それらのフォルダへのパスを引数として自身を呼び出す
		n = ItemsInList(IndexedDir($pathName, -1, 0))
		for (i = 0; i < n; i++)
			Wave tw = KMMakeLogRecursive(IndexedDir($pathName, i, 1), extStr, fn)
			if (!numpnts(tw))
				continue
			elseif (numpnts(w))
				Concatenate/T {tw}, w
			else
				Duplicate/T/FREE/O tw w
			endif
		endfor
		//	ファイルを含む場合は、それらのファイルへのパスを引数として自身を呼び出す
		n = ItemsInList(IndexedFile($pathName, -1, extStr))
		for (i = 0; i < n; i++)
			str = ParseFilePath(2, pathStr, ":", 0, 0) + IndexedFile($pathName, i, extStr)
			Concatenate/T {KMMakeLogRecursive(str, extStr, fn)}, w
		endfor
		KillPath $pathName
		return w
	endif
	
	if (V_isFile)
		return fn(pathStr)
	endif
End

//	データ出力を扱う関数のプロトタイプ
Function/WAVE KMMakeLogPrototype(String str)
	return $""
End

