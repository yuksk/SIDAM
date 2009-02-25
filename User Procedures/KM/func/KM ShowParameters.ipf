#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMShowParameters

#ifndef KMshowProcedures
#pragma hide = 1
#endif

//******************************************************************************
//	変数リストとその値を表示する
//******************************************************************************
Function KMShowParameters()
	String grfName = WinName(0,1)
	
	DFREF dfr = getSettingDFR(grfName)	//	settingデータフォルダ
	if (!DataFolderRefStatus(dfr))
		return 0
	endif
	
	//	notebookをgraphのサブウインドウにすることはできない
	//	したがって、panelをgraphのサブウインドウにし、notebookはそのpanelのサブウインドウにする
	STRUCT KMPrefs prefs
	KMLoadPrefs(prefs)
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,10,10) as "properties"	//	大きさはとりあえずのもの
	String pnlName = S_name, nbName = "nb"
	ModifyPanel/W=$grfName#$pnlName fixedSize=0
	NewNotebook/F=0/K=1/N=$nbName/V=0/W=(0,0,1,1)/HOST=$grfName#$pnlName
	
	//	表示するリストを作成する
	String noteStr = ""		//	notebookに書き込まれる文字列
	Make/N=0/FREE strwidth	//	変数名文字列の幅を入れる
	makeList(dfr, GetDefaultFont(nbName), noteStr, "", strwidth)
	
	//	適切なタブの幅を求める
	Variable tabSize = WaveMax(strwidth)+10
	
	//	表示
	Notebook $grfName#$pnlName#$nbName text=noteStr, fSize=10, defaultTab=tabSize, statusWidth=0, writeProtect=1
	Notebook $grfName#$pnlName#$nbName selection={startOfFile, startOfFile}, text="", visible=1	//	先頭にスクロールする
	Variable width = tabSize*screenresolution/72+100, height = prefs.viewer.width*screenresolution/72
	MoveSubWindow/W=$grfName#$pnlName fnum=(0,0,width,height)
End

//-------------------------------------------------------------
//	settingデータフォルダへの参照を返す
//-------------------------------------------------------------
Static Function/DF getSettingDFR(String grfName)
	Wave/Z srcw = KMGetImageWaveRef(grfName)
	if (!WaveExists(srcw))
		Wave/Z srcw = TraceNameToWaveRef(grfName,StringFromList(0,TraceNameList(grfName,";",1)))
	endif
	if (!WaveExists(srcw))
		return $""
	endif
	
	return GetWavesDataFolderDFR(srcw):$(KM_DF_SETTINGS)
End

//-------------------------------------------------------------
//	表示する文字列を作成する
//	"変数名\t変数値\r"を繰り返す
//-------------------------------------------------------------
Static Function makeList(dfr, fName, noteStr, preStr, strwidth)
	DFREF dfr
	String fName, &noteStr, preStr
	Wave strwidth
	
	String vName
	Variable objType, i, n
	
	//	数値変数と文字変数については、ノート文字列にその内容を加える
	for (objType = 2; objType <= 3; objType += 1)
		for (i = 0; i < CountObjectsDFR(dfr, objType); i += 1)
			vName = GetIndexedObjNameDFR(dfr, objType, i)
			if (objType == 2)	//	数値変数
				NVAR/SDFR=dfr var = $vName
				noteStr += preStr+vName+"\t"+num2str(var)+"\r"
			else				//	文字変数
				SVAR/SDFR=dfr str = $vName
				noteStr += preStr+vName+"\t"+str+"\r"
			endif
			n = numpnts(strwidth)
			Redimension/N=(n+1) strwidth
			strwidth[n] = FontSizeStringWidth(fName,10,0,preStr+vName)
		endfor
	endfor
	
	//	データフォルダについてはこの関数を再帰的に実行する
	for (i = 0; i < CountObjectsDFR(dfr, 4); i += 1)
		vName = GetIndexedObjNameDFR(dfr, 4, i)
		makeList(dfr:$vName, fName, noteStr, preStr+vName+">", strwidth)
	endfor
End

//-------------------------------------------------------------
//	メニュー項目
//-------------------------------------------------------------
Static Function/S rightclickMenu()
	String grfName = WinName(0,1)
	if (!strlen(grfName))
		return ""
	else
		DFREF dfr = getSettingDFR(grfName)	//	settingデータフォルダ
		return SelectString(DataFolderRefStatus(dfr),"(","") + "Data Parameters..."
	endif
End
