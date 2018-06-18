#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3	
#pragma ModuleName=KMSaveMovie


#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//-------------------------------------------------------------
//	右クリックメニュー表示用
//-------------------------------------------------------------
Static Function/S rightclickMenu()
	int isWindows = stringmatch(IgorInfo(2),"Windows")
	
	Wave/Z w = KMGetImageWaveRef(WinName(0,1))
	if (!WaveExists(w))
		return ""
	endif
	int is3D = WaveDims(w)==3
	
	return SelectString(isWindows && is3D, "", "\\M0Save Graphics (Movie)...")
End

//-------------------------------------------------------------
//	右クリックメニューから実行される関数
//-------------------------------------------------------------
Static Function rightclickDo()
	pnl(WinName(0,1))
End

//******************************************************************************
//	パネル
//******************************************************************************
Static Function pnl(String grfName)
	//  パネル表示
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,320,270)
	RenameWindow $grfName#$S_name, SaveMovie
	String pnlName = grfName + "#SaveMovie"
	Wave w = KMGetImageWaveRef(grfName)
	
	//	layer
	GroupBox layerG title="Layer", pos={5,4}, size={310,50}, win=$pnlName
	CheckBox all_rC title="all", pos={16,28}, value=1, proc=KMSaveCommon#pnlCheck, win=$pnlName
	CheckBox select_rC title="", pos={78,28}, value=0, proc=KMSaveCommon#pnlCheck, win=$pnlName
	SetVariable from_f_V title="from:", pos={97,26}, size={79,15}, value=_NUM:0, win=$pnlName
	SetVariable to_f_V title="to:", pos={186,26}, size={66,15}, value=_NUM:DimSize(w,2)-1, win=$pnlName
	ModifyControlList "from_f_V;to_f_V" bodyWidth=50, limits={0,DimSize(w,2)-1,1}, format="%d", proc=KMSaveCommon#pnlSetVar, win=$pnlName
	
	//	parameters
	GroupBox formatG title="Parameters:", pos={5,60}, size={310,75}, win=$pnlName
	CheckBox compressionC title="Change the compression settings", pos={16,83}, value=1, win=$pnlName
	SetVariable rateV title="Frames per second", pos={18,107}, size={151,15}, bodyWidth=50, value=_NUM:2, limits={1,60,1}, format="%d", win=$pnlName

	//	file
	GroupBox fileG title="File:", pos={5,141}, size={310,96}, win=$pnlName	
	SetVariable filenameV title="Filename:", pos={12,164}, size={295,18}, bodyWidth=241, win=$pnlName
	SetVariable filenameV value=_STR:NameOfWave(w), proc=KMSaveCommon#pnlSetVar, win=$pnlName
	PopupMenu pathP title="Path:", pos={12,189}, size={180,20}, bodyWidth=150, mode=1, win=$pnlName
	PopupMenu pathP value="_Use Dialog_;_Specify Path_;"+PathList("*",";",""), proc=KMSaveCommon#pnlPopup, win=$pnlName
	CheckBox overwriteC title="Force Overwrite", pos={206,191}, win=$pnlName	
	SetVariable pathV pos={10,215}, size={300,15}, bodyWidth=300, value=_STR:"", format="", frame=0, noedit=1, labelBack=(56797,56797,56797), win=$pnlName

	//	button
	Button saveB title="Save", pos={4,243}, size={70,20}, proc=KMSaveCommon#pnlButton, userData(fn)="KMSaveMovie#saveMovie", win=$pnlName
	Button closeB title="Close", pos={245,243}, size={70,20}, proc=KMSaveCommon#pnlButton, win=$pnlName
	
	//	一律設定
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End

//******************************************************************************
//	ムービー作成・保存 (saveBの実行関数)
//******************************************************************************
Static Function saveMovie(String pnlName)

	String grfName = StringFromList(0,pnlName,"#")

	//	範囲取得
	Wave lw = KMSaveCommon#getLayers(pnlName)
	int i, initIndex = KMLayerViewerDo(grfName)	//	現在の表示レイヤー

	//	ファイル名取得
	ControlInfo/W=$pnlName filenameV
	String filename = RemoveEnding(S_Value, ".avi")	//	.avi 付きでファイル名が指定されていた場合に備えて(後でつける)
	
	//	ムービーファイル作成	
	String cmd	
	sprintf cmd, "%s as \"%s.avi\"", createCmdStr(pnlName), filename
	Execute/Z cmd
	
	//	ムービーフレーム追加	
	for (i = lw[0]; i <= lw[1]; i++)
		KMLayerViewerDo(grfName, index=i)
		DoUpdate/W=$grfName
		AddMovieFrame
	endfor
	
	CloseMovie
	KMLayerViewerDo(grfName, index=initIndex)
End
//-------------------------------------------------------------
//	createCmdExtStr
//		パネルコントロールの選択状態から実行コマンド文字列を構成する
//-------------------------------------------------------------
Static Function/S createCmdStr(String pnlName)

	String cmdStr = "NewMovie"
	
	ControlInfo/W=$pnlName overwriteC
	cmdStr += SelectString(V_Value, "", "/O")
	
	ControlInfo/W=$pnlName compressionC
	cmdStr += SelectString(V_Value, "", "/I")
	
	ControlInfo/W=$pnlName rateV
	cmdStr += "/F="+num2istr(V_Value)
	
	//	パス名取得
	ControlInfo/W=$pnlName pathP
	if (V_Value > 2)
		cmdStr += "/P="+S_Value
	elseif (V_Value == 2)
		ControlInfo/W=$pnlName pathV
		if (strlen(S_value))
			GetFileFolderInfo/Q/Z S_value
			if (!V_Flag) 	//	file or folder was found
				cmdStr += "/P="+KMSaveCommon#getPathName(StringFromList(1,pnlName,"#"))
			endif
		endif
	endif
	
	return cmdStr
End