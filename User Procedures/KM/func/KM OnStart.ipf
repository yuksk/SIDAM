#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3

#include "KM Constants"
#include "KM Utilities_Str"	//	for KMGetPath
#include "KM Hook"				//	for KMAfterCompiledHook

//	マクロ起動時に、上記のファイルをincludeして行われる作業をまとめたもの
//	このファイルを include して不要になったら外すことにより、上記ファイルを一時的に読み込む部分がすっきりとと記述できる

Function KMonStart()
	//	バージョン表示
	print "\r Kohsaka Macro\t(rev. " + num2str(KM_REVISION) + ")\r\r"
	
	//	パス設定
	KMSetPath()
	
	//	関数読み込みのためファイルを作成する
	KMMakeLoadProcedureFile()
	Execute/P "INSERTINCLUDE \"" + KM_FILE_INCLUDE + "\""
	
	//	コンパイル
	Execute/P "COMPILEPROCEDURES "
	
	//	フック関数設定
	SetIgorHook BeforeFileOpenHook = KMFileOpenHook
	SetIgorHook BeforeExperimentSaveHook = KMBeforeExperimentSaveHook
	SetIgorHook AfterCompiledHook = KMAfterCompiledHook	//	更新チェックが行われる
End


Static Function KMMakeLoadProcedureFile()
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	//	ファイルリスト作成
	Concatenate/NP {fnList(KM_FOLDER_FUNC), fnList(KM_FOLDER_LOADER), fnList(KM_FOLDER_EXT)}, listwave
	Wave/T lw = listwave
	
	//	ファイルリストからこのファイルは除く
	String filePath = FunctionPath(GetRTStackInfo(1))
	String fileName = ParseFilePath(0, filePath, ":", 1, 0)
	FindValue/TEXT=fileName lw
	Deletepoints V_Value, 1, lw
	
	//	#includeを含むファイルの作成
	//	ファイルリストを一つの文字列にまとめると長くなりすぎる可能性がある
	//	そのため、ウエーブから一つ一つ書き込むことにしている
	Variable refNum, i
	String pathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	String pathName = UniqueName("path",12,0)
	NewPath/Q $pathName, pathStr
	Open/P=$pathName/Z refNum, as KM_FILE_INCLUDE+".ipf"
	if (!V_flag)
		fprintf refNum,  "#ifndef KMshowProcedures\r#pragma hide = 1\r#endif\r"
		for(i = 0; i < numpnts(lw); i += 1)
			fprintf refNum, "#include \""+RemoveEnding(lw[i],".ipf")+"\"\r"
		endfor
		Close refNum
	endif
	KillPath $pathName
	
	SetDataFolder dfrSav
	
	return 1
End

Static Function/WAVE fnList(subFolder)
	String subFolder
	
	//	subFolder内にあるipfファイルのリスト作成
	String pathName = UniqueName("tmpPath",12,0)
	NewPath/O/Q/Z $pathName, KMGetPath()+subFolder
	String listStr = IndexedFile($pathName,-1,".ipf")
	KillPath $pathName
	
	Make/FREE/T/N=(ItemsInList(listStr)) w = StringFromList(p,listStr)
	return w
End
