#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=KMPreview

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant ks_columntitile = "wave;bias;current;comment"		//	ウエーブリストの項目タイトル
Static StrConstant ks_popupStr = "Display;Plane Subtraction;Select All"	//	ウエーブリストの右クリックメニュー項目

//******************************************************************************
//	KMPreviewPnl
//		パネル表示
//******************************************************************************
Function KMPreviewPnl()
	
	//	既にパネルが表示されていれば、それにフォーカスして終了
	String pnlList = WinList("*",";","WIN:64")
	int i, n = ItemsInList(pnlList)
	for (i = 0; i < n; i++)
		if (stringmatch(GetUserData(StringFromList(i,pnlList),"","this"),"Previewer"))
			DoWindow/F $StringFromList(i,pnlList)
			return 0
		endif
	endfor
	
	String dfTmp = pnlInit()
	STRUCT KMPrefs p
	KMLoadPrefs(p)
	
	NewPanel/K=1/W=(p.preview.size.left, p.preview.size.top, p.preview.size.right, p.preview.size.bottom) as "Preview"
	String pnlName = S_name
	
	DefineGuide/W=$pnlName gh1={FT, 230}				//	プレビュー領域と変数リスト領域の上端位置
	DefineGuide/W=$pnlName gv1={FR, -255}				//	プレビュー領域と変数リスト領域の境界位置 (変数リスト領域の幅)
	DefineGuide/W=$pnlName gv2={FR,-150}, gh2={FT, 30}	//	チェックボックス領域、右から幅150, 上から高さ30
	DefineGuide/W=$pnlName gh3={FB, -36}				//	ボタン領域, 下から36
	
	//	プレビュー領域	, 表示領域を正方形にするために、サブウインドウ内にサブウインドウを入れる
	Display/FG=(FL,gh1,gv1,FB)/HOST=$pnlName
	Display/HOST=#
	//	変数リスト領域
	NewPanel/FG=(gv1,gh1,FR,gh3)/HOST=$pnlName
	ModifyPanel/W=$pnlName#P0 frameStyle=0
	//	チェックボックス領域
	NewPanel/FG=(gv2,FT,FR,gh2)/HOST=$pnlName
	ModifyPanel/W=$pnlName#P1 frameStyle=0
	//	ボタン領域
	NewPanel/FG=(gv1,gh3,FR,FB)/HOST=$pnlName
	ModifyPanel/W=$pnlName#P2 frameStyle=0
	//	検索窓に重ねて表示する文字列領域
	NewPanel/HOST=$pnlName/W=(8,10,80,24)
	ModifyPanel/W=$pnlName#P3 frameStyle=0, cbRGB=(65534,65534,65534)
	TitleBox queryT pos={1,1}, title="enter a query", frame=0, fColor=(34816,34816,34816), win=$pnlName#P3
	DoUpdate
	
	//	フック関数
	SetWindow $pnlName hook(self)=KMPreview#pnlHook
	SetWindow $pnlName userData(this)="Previewer"
	SetWindow $pnlName userData(dfTmp)=dfTmp
	
	//  各要素	
	SetVariable queryV pos={5,8}, size={300,18}, bodyWidth=300, fSize=14, value=_STR:"", focusRing=0, proc=KMPreview#pnlSetVar, win=$pnlName
	ListBox waveL pos={5,35}, frame=2, mode=9, userColumnResize=1, clickEventModifiers=4, focusRing=0, proc=KMPreview#pnlListWave, win=$pnlName
	ListBox waveL listWave=$(dfTmp+KM_WAVE_LIST), colorWave=$(dfTmp+KM_WAVE_COLOR), selWave=$(dfTmp+KM_WAVE_SELECTED), win=$pnlName
	Titlebox itemsT pos={315,11}, frame=0, win=$pnlName
	//		プレビュー領域	
	ControlInfo/W=$pnlName kwBackgroundColor
	ModifyGraph/W=$pnlName#G0 gbRGB=(V_Red,V_Green,V_Blue), wbRGB=(V_Red,V_Green,V_Blue)
	//		変数リスト領域
	ListBox varL pos={10,0}, frame=2, mode=1, selRow=-1, listWave=$(dfTmp+"vlist"), focusRing=0, proc=KMPreview#pnlListVar, win=$pnlName#P0
	//		チェックボックス領域
	CheckBox allC title="all", pos={0, 9}, value=1, win=$pnlName#P1
	CheckBox oneC title="1D", pos={37,9}, value=0, win=$pnlName#P1
	CheckBox twoC title="2D", pos={74,9}, fColor=(0,0,65280), value=0, win=$pnlName#P1
	CheckBox threeC title="3D", pos={111,9}, fColor=(65280,0,0), value=0, win=$pnlName#P1
	ModifyControlList "allC;oneC;twoC;threeC" mode=1, focusRing=0, proc=KMPreview#pnlCheck, win=$pnlName#P1
	//		ボタン領域
	Button doB title="Display", pos={10,9}, win=$pnlName#P2
	Button helpB title="Help", pos={90,9}, win=$pnlName#P2
	Button closeB title="Close", pos={180,9}, win=$pnlName#P2
	ModifyControlList "doB;helpB;closeB" size={70,20}, focusRing=0, proc=KMPreview#pnlButton, win=$pnlName#P2
	
	SetActiveSubWindow $pnlName
	
	updateList(pnlName)
	updateWindowSize(pnlName)
End
//-------------------------------------------------------------
//	パネル初期設定
//-------------------------------------------------------------
Static Function/S pnlInit()
	
	String dfSav = KMNewTmpDf("","KMPreviewPnl"), str
	String dfTmp = GetDataFolder(1)
	int i
	
	//	リストアップされるウエーブへの参照保存用ウエーブ
	Make/N=1/O/WAVE ref
	
	//	ウエーブリスト用 listWave
	Make/N=(1,ItemsInlist(ks_columntitile))/O/T $KM_WAVE_LIST/WAVE=listw
	for (i = 0; i < ItemsInList(ks_columntitile); i++)
		SetDimLabel 1, i, $StringFromList(i,ks_columntitile), listw
	endfor
	
	//	ウエーブリスト用 selWave
	Make/B/U/N=(1,ItemsInList(ks_columntitile),3)/O $KM_WAVE_SELECTED/WAVE=selw
	SetDimLabel 2, 1, foreColors, selw
	SetDimLabel 2, 2, backColors, selw
	
	//	ウエーブリスト用 colorWave
	//	順番に、(未使用), 1D文字用, 2D文字用, 3D文字用, 4D文字用
	Make/O/W/U $KM_WAVE_COLOR/WAVE=colorw = {{65535,65535,65535}, {0,0,0}, {0,0,65280}, {65280,0,0}, {0,0,65280}}
	MatrixTransPose colorw
	
	//	変数リスト用 listWave
	Make/N=(0,2)/O/T vlist
	
	SetDataFolder $dfSav
	return dfTmp
End

//******************************************************************************
//	フック関数
//******************************************************************************
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 2:	//	kill
			pnlHookClose(s.winName)
			return 0
		case 6:	//	resize
			updateWindowSize(s.winName)
			return 0
		case 11:	//	keyboard
			switch (s.keycode)
				case 11:		//	page up
					updateLayers(s.winName+"#G0#G0", 1)
					break
				case 12:		//	page down
					updateLayers(s.winName+"#G0#G0", -1)
					break
				case 27:		//	esc
					pnlHookClose(s.winName)
					KillWindow $s.winName
					break
			endswitch
			return 1
		case 22:	//	mouseWheel
			if (strsearch(s.winName, "#G0#G0",0) != -1)
				int direction = (s.wheelDy > 0) ? 1 : -1
				updateLayers(s.winName, direction)
			endif
			return 0
		default:
			return 0
	endswitch
End
//------------------------------------------------------------*
//	パネルを閉じる前の処理
//------------------------------------------------------------
Static Function pnlHookClose(String pnlName)
	
	STRUCT KMPrefs p
	KMLoadPrefs(p)
	
	GetWindow $pnlName wsizeDC
	p.preview.size.left = V_left
	p.preview.size.right = V_right
	p.preview.size.top = V_top
	p.preview.size.bottom = V_bottom
	
	KMSavePrefs(p)
	
	KMonClosePnl(pnlName)
End
//------------------------------------------------------------
//	ウインドウサイズの更新
//------------------------------------------------------------
Static Function updateWindowSize(String pnlName)
	
	GetWindow $pnlName wsizeDC
	Variable listWidth = V_right-V_left-10
	ListBox waveL size={listWidth,185}, win=$pnlName
	ListBox waveL widths={180, 70, 70, listWidth-(180+70*2)-25}, win=$pnlName
	
	GetWindow $pnlName#P0 wsizeDC
	ListBox varL size={240,V_bottom-V_top}, win=$pnlName#P0
	
	GetWindow $pnlName#G0 wsizeDC
	Variable pnlWidth = V_right-V_left, pnlHeight = V_bottom-V_top
	Variable a = abs(pnlWidth-pnlHeight)/(max(pnlWidth,pnlHeight)*2)
	Variable b = (pnlWidth+pnlHeight)/(max(pnlWidth,pnlHeight)*2)
	if (pnlWidth > pnlHeight)
		MoveSubWindow/W=$pnlName#G0#G0 fnum=(a,0,b,1)
	else
		MoveSubWindow/W=$pnlName#G0#G0 fnum=(0,a,1,b)
	endif
End
//------------------------------------------------------------
//	表示レイヤーの更新
//------------------------------------------------------------
Static Function updateLayers(
	String grfName,	//		pnlName+"#G0#G0"
	int direction	//	1:up, -1:down
	)
	
	Wave/Z iw =  KMGetImageWaveRef(grfName)
	if (WaveExists(iw) && WaveDims(iw) == 3)
		KMLayerViewerDo(grfName, direction=direction)
		//	0.5%表示　ウエーブ変更時に設定してあるが、サブウインドウのへフック関数を設定してもイベントを拾うことが
		//	できないので、レイヤー変更後に再び実行する
		KMRange(grfName=grfName,zmin=0.5,zminmode=3,zmax=99.5,zmaxmode=3)
	endif
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	String pnlName = StringFromList(0,s.win,"#")	//	ホストパネルの名前を得る
	
	strswitch (s.ctrlName)
		case "doB":
			dipslayWaves(pnlName)
			break
		case "helpB":
			KMOpenHelpNote("preview",pnlName=pnlName,title="Preview")
			break
		case "closeB":
			KillWindow $pnlName
			break
	endswitch
End
//-------------------------------------------------------------
//	リストボックス (ウエーブリスト)
//-------------------------------------------------------------
Static Function pnlListWave(STRUCT WMListboxAction &s)
	
	if (s.eventCode == -1)		//	being killed
		return 0
	endif
	
	switch (s.eventCode)
		case 1:	//	mouse down
			if (s.eventMod&16)	//	right-click
				PopupContextualMenu pnlListWavePopStr(s)
				switch(WhichListItem(S_selection, ks_popupStr))
					case 0:	//	Display
						dipslayWaves(s.win)
						break
					case 1:	//	Plane Subtraction
						doSubtraction(s)
						break
					case 2:	//	Select All
						s.selWave[][0][0] = 1
						break
					default:
				endswitch
			endif
			break
		case 3:	//	double click
			Wave/WAVE/SDFR=$GetWavesDataFolder(s.selWave,1) ref
			KMDisplay(w=ref[s.row])
			break
		case 4:	//	cell selection
		case 5:	//	cell selection + shift
			updateImage(s)			//	イメージ更新
			updateVariablesList(s)	//	変数リスト更新
			break
	endswitch
End
//-------------------------------------------------------------
//	リストボックス (変数リスト)
//-------------------------------------------------------------
Static Function pnlListVar(STRUCT WMListboxAction &s)
	
	if (s.eventCode == -1)		//	being killed
		return 0
	endif
	
	Wave/T lw = s.listWave
	if (s.row >= DimSize(lw,0))	//	範囲外選択
		return 0
	endif
	
	switch (s.eventCode)
		case 1:	//	mouse down
			if (s.eventMod&16)	//	right-click
				PopupContextualMenu "Copy"
				if (V_flag == 1)
					PutScrapText lw[s.row][1]
				endif
			endif
			break
		case 3:		//	double click
			printf "%s: %s\r", lw[s.row][0], lw[s.row][1]
			break
	endswitch
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckBoxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	CheckBox allC value=0, win=$s.win
	CheckBox oneC value=0, win=$s.win
	CheckBox twoC value=0, win=$s.win
	CheckBox threeC value=0, win=$s.win
	CheckBox $s.ctrlName value=1, win=$s.win
	
	updateList(StringFromList(0,s.win,"#"))
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode != 2 && s.eventCode != 1)
		return 1
	endif
	
	updateList(s.win)
	SetWindow $s.win#P3 hide=(strlen(s.sval)>0) 	//	"enter a query"を消したり出したり
End

//******************************************************************************
//	パネルコントロール補助関数
//******************************************************************************
//------------------------------------------------------------
//	ウエーブリスト右クリック時のポップアップ文字列を返す
//------------------------------------------------------------
Static Function/S pnlListWavePopStr(STRUCT WMListboxAction &s)
	
	Wave/SDFR=$GetWavesDataFolder(s.selWave,1)/WAVE ref
	
	Make/N=(DimSize(s.selWave,0))/FREE tw = s.selWave[p][0][0] && WaveDims(ref[p]) != 2	//	選択されている行のウエーブが2次元でないと 1
	Variable only2D = !WaveMax(tw)
	
	if (s.row < DimSize(s.selWave, 0) && s.selWave[s.row][0][0])	//	範囲内、かつ、選択されている行の上でクリックがされた場合
		return StringFromList(0, ks_popupStr) + SelectString(only2D, "", ";"+StringFromList(1, ks_popupStr))
	else
		return StringFromList(2, ks_popupStr)
	endif
End

//------------------------------------------------------------
//	ウエーブを表示する
//------------------------------------------------------------
Static Function dipslayWaves(String pnlName)
	
	DFREF dfrTmp = $GetUserData(pnlName,"","dfTmp")
	Wave/SDFR=dfrTmp selw = $KM_WAVE_SELECTED
	Wave/SDFR=dfrTmp/WAVE ref
	
	int i, n
	Make/N=0/WAVE/FREE tw
	for (i = 0; i < DimSize(selw,0); i++)
		if (selw[i][0][0])
			n = numpnts(tw)
			Redimension/N=(n+1) tw
			tw[n] = ref[i]
		endif
	endfor
	KMDisplay(w=tw)	
End

//------------------------------------------------------------
//	平面除去を行う
//------------------------------------------------------------
Static Function doSubtraction(STRUCT WMListboxAction &s)
	
	Wave/SDFR=$GetWavesDataFolder(s.selWave,1)/WAVE ref
	
	Variable i
	for (i = 0; i < DimSize(s.selWave,0); i += 1)
		if (s.selWave[i][0][0])
			KMSubtraction(ref[i])
			KMRange(grfName=s.win+"#G0#G0",zmin=0.5,zminmode=3,zmax=99.5,zmaxmode=3)	//	0.5%表示
		endif
	endfor
End

//------------------------------------------------------------
//	ウエーブリストを更新する
//------------------------------------------------------------
Static Function updateList(String pnlName)
	
	DFREF dfrTmp = $GetUserData(pnlName, "", "dfTmp")	
	int i, n
	
	//	ルート以下のウエーブをリストアップする
	Wave cw = KMGetCtrlValues(pnlName+"#P1", "allC;oneC;twoC;threeC;")
	cw *= p
	String optStr = "UNSIGNED:0,TEXT:0,DF:0,WAVE:0"	//	UNSIGNEDを除くのは、カラーインデックスウエーブを除くため
	if (sum(cw))
		optStr += ",DIMS:"+num2str(sum(cw))
	endif
	Wave/WAVE allrefw = getWaveRefList(root:, "*", optStr)
	
	//	query を適切に分割する
	ControlInfo/W=$pnlName queryV
	String query =  splitQueryStr(S_Value)
	
	//	grep によりウエーブを絞り込む
	n = ItemsInList(query)
	Make/N=(numpnts(allrefw))/FREE/WAVE grepw = allrefw[p]
	for (i = 0; i < n; i++)
		String regExp = StringFromList(i, query)
		filterWaves(grepw, regExp)
	endfor
	n = numpnts(grepw)
	
	//	絞り込んだウエーブをリスト表示用ウエーブへ代入する
	//	参照ウエーブ
	WAVE/SDFR=dfrTmp/WAVE refw = ref
	Redimension/N=(n) refw
	refw = grepw[p]
	//	リスト用・名前ウエーブ
	Wave/SDFR=dfrTmp/T lw = $KM_WAVE_LIST
	Redimension/N=(n,ItemsInList(ks_columntitile)) lw		//  -1 を使わないのは、nが0になることがあるため
	lw[][0] = NameOfWave(refw[p])
	lw[][1,3] = KMGetSettings(refw[p], q)
	//	リスト用・色設定
	Wave/SDFR=dfrTmp sw = $KM_WAVE_SELECTED
	Redimension/N=(n,ItemsInList(ks_columntitile),3) sw	//  -1 を使わないのは、nが0になることがあるため
	sw[][][0] = 0
	sw[][][1] = WaveDims(refw[p])
	sw[][][2] = 0					//	0 の選択はデフォルト色を選択することになるようだ
	
	//	リストアップされたウエーブの個数の表示
	TitleBox itemsT title=num2str(n)+SelectString(n>1, " wave",  " waves"), win=$pnlName
	
	//  ウエーブリストが更新される際はリストの選択状態がクリアされるので、既に表示されているグラフ、イメージがあれば削除する
	clearImage(pnlName+"#G0#G0")
End
//	データフォルダdfr以下に再帰的に WaveList を実行し、全てのウエーブへの参照を持つウエーブを返す
//	ただし、いくつかの指定するデータフォルダ内は探索しない
Static Function/WAVE getWaveRefList(dfr, str, option)
	DFREF dfr
	String str, option
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder dfr
	
	String list = WaveList(str,";",option)
	Make/FREE/N=(ItemsInList(list))/WAVE tw = $StringFromList(p,list)
	
	int n = CountObjectsDFR(dfr, 4), i
	for (i = 0; i < n; i += 1)
		String dfName = GetIndexedObjNameDFR(dfr, 4, i)
		if (WhichListItem(dfName, "_KM;pos;Packages;"+SIDAM_DF_SETTINGS) != -1)	//	探索しないデータフォルダの名前
			Continue
		endif
		Concatenate/NP=0 {getWaveRefList(dfr:$dfName, str,option)}, tw
	endfor
	
	SetDataFolder dfrSav
	return tw
End
//	query文字列を;区切りにする
Static Function/S splitQueryStr(String str)
	//	スペースをセミコロンに単純に置き換える
	String rtnStr = ReplaceString(" ", str, ";")
	
	//	""で囲まれている部分についてはセミコロンをスペースに戻す
	//	""で囲まれている部分がなければ終了
	int a0 = strsearch(rtnStr, "\"", 0)
	if (a0 == -1)
		return rtnStr
	endif
	int a1 = strsearch(rtnStr, "\"", a0+1)
	if (a1 == -1)
		return rtnStr
	endif
	
	String str1 = ReplaceString(";", rtnStr[a0+1, a1-1], " ")	//	ダブルクオーテーション間のセミコロンをスペースに戻す
	rtnStr = ReplaceString(str[a0,a1], rtnStr, str1, 1, 1)		//	ダブルクオーテーションも含め置換する
	return splitQueryStr(rtnStr)							//	処理すべき部分が無くなるまで繰り返す
End
//	refw に入っている参照先のウエーブについて、名前について grep を実行し、refw の内容を絞る
//	(grepの実行結果を refw へ入れる)
Static Function filterWaves(Wave/WAVE refw, String regExp)
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Make/N=(numpnts(refw))/T namew = NameOfWave(refw[p])
	
	//	regExp が - から始まる時には、regExpに当てはまらないものを残す
	if (CmpStr(regExp[0], "-"))
		Grep/INDX/Q/E=regExp namew
	else
		Grep/INDX/Q/E={regExp[1,strlen(regExp)-1], 1} namew
	endif
	
	Wave indxw = W_Index
	int n = numpnts(indxw)
	if (n)
		Make/N=(n)/WAVE refw2 = refw[indxw[p]]
		Redimension/N=(n) refw
		refw = refw2[p]
	else		//	n == 0 つまり、条件に合うものがない場合
		Redimension/N=0 refw
	endif
	
	SetDataFolder dfrSav
End
//	既に表示されているグラフ、イメージがあれば削除する
Static Function clearImage(String grfName)	//	pnlName + "#G0#G0"
	RemoveFromGraph/W=$grfName/Z $StringFromList(0,TraceNameList(grfName,";",1))
	RemoveImage/W=$grfName/Z $StringFromList(0,ImageNameList(grfName,";"))
End

//------------------------------------------------------------
//	変数リストを更新する
//------------------------------------------------------------
Static Function updateVariablesList(STRUCT WMListboxAction &s)
	
	String pnlName = s.win+"#P0"		//	サブウインドウを含めた名前
	DFREF dfrTmp = $GetWavesDataFolder(s.selWave,1)
	
	Wave/Z/WAVE/SDFR=dfrTmp ref
	Wave/T/SDFR=dfrTmp vlist
	Redimension/N=(0,2) vlist			//	一旦初期化
	
	if (!WaveExists(ref))				//  リストをクリアするときには空が使用される
		ListBox varL selRow=-1, win=$pnlName
		return 0
	elseif (s.row >= numpnts(ref))		//  範囲外の選択であれば、初期化して終わり
		return 0
	endif
	
	DFREF dfr = GetWavesDataFolderDFR(ref[s.row]):$SIDAM_DF_SETTINGS
	if (!DataFolderRefStatus(dfr))		//  設定値データフォルダがない
		return 0
	endif
	updateVariablesListAddVariables(dfr,"", vlist)
	
	return 0
End
//	データフォルダ dfr にあるグローバル変数リストを lw に加える
Static Function updateVariablesListAddVariables(DFREF dfr, String preStr, Wave/T lw)
	
	int objType, i, n
	
	//	数値変数と文字変数については、内容をlwに加える
	for (objType = 2; objType <= 3; objType++)
		for (i = 0; i < CountObjectsDFR(dfr, objType); i++)
			n = DimSize(lw, 0)
			Redimension/N=(n+1,-1) lw
			lw[n][0] = preStr+GetIndexedObjNameDFR(dfr, objType, i)
			if (objType == 2)	//	数値変数
				NVAR/SDFR=dfr var = $GetIndexedObjNameDFR(dfr, objType, i)
				lw[n][1] = num2str(var)
			else				//	文字変数
				SVAR/SDFR=dfr str = $GetIndexedObjNameDFR(dfr, objType, i)
				lw[n][1] = str
			endif
		endfor
	endfor
	
	//	データフォルダについてはこの関数を再帰的に実行する
	for (i = 0; i < CountObjectsDFR(dfr, 4); i++)
		String dfName = GetIndexedObjNameDFR(dfr, 4, i)
		updateVariablesListAddVariables(dfr:$dfName, preStr+dfName+">", lw)
	endfor
End

//------------------------------------------------------------
//	イメージを更新する
//------------------------------------------------------------
Static Function updateImage(STRUCT WMListboxAction &s)
	
	Wave/Z/WAVE/SDFR=$GetWavesDataFolder(s.selWave,1) ref
	String grfName = s.win + "#G0#G0"
	
	clearImage(grfName)		//	既に表示されているグラフ、イメージがあれば削除する
	
	if (!WaveExists(ref))			//  イメージをクリアするときには空が使用される
		return 0 
	elseif (s.row >= numpnts(ref))	//  範囲外の選択であれば、イメージを削除した状態で終わり
		return 0
	elseif (WaveDims(ref[s.row]) == 1)
		AppendToGraph/W=$grfName ref[s.row]
	else
		AppendImage/W=$grfName ref[s.row]
	endif
	
	ModifyGraph/W=$grfName gFont=Arial, gfSize=10, standoff=0, btlen=4, lblMargin=2
	ModifyGraph/W=$grfName margin(left)=40,margin(top)=12,margin(right)=12,margin(bottom)=40
	
	//	ウエーブが2D,3Dならば、0.5%表示をする
	if (WaveDims(ref[s.row]) != 1)
		DoUpdate/W=$grfName	//	これがないと次行がうまく動作しない
		KMRange(grfName=grfName,zmin=0.5,zminmode=3,zmax=99.5,zmaxmode=3)	//	0.5%表示
	endif
End

//******************************************************************************
//	KMGetSettings
//		Settingフォルダの中から指定する値を取り出して返す
//******************************************************************************
Function/S KMGetSettings(Wave/Z w, int kind)
	
	if (!WaveExists(w))
		return ""
	endif
	
	DFREF dfr = GetWavesDataFolderDFR(w):$SIDAM_DF_SETTINGS
	if (!DataFolderRefStatus(dfr))
		return ""
	endif
	
	switch (kind)
		case 1:	//	bias
			return KMGetSettingsBias(dfr)
		case 2:	//	current
			return KMGetSettingsCurrent(dfr)
		case 3:	//	comment
			return KMGetSettingsComment(dfr)
		case 4:	//	angle
			return KMGetSettingsAngle(dfr)
	endswitch
End

Static Function/S KMGetSettingsBias(DFREF dfr)
	
	NVAR/Z/SDFR=dfr bias
	if (NVAR_Exists(bias))
		return num2str(bias)
	endif
	
	//	Nanonis
	NVAR/Z/SDFR=dfr 'bias (V)'
	if (NVAR_Exists('bias (V)'))
		return KMGetSettingsFormatStr('bias (V)') + "V"
	endif
	if (DataFolderRefStatus(dfr:Bias))
		NVAR/Z/SDFR=dfr:Bias 'Bias (V)'
		if (NVAR_Exists('Bias (V)'))
			return KMGetSettingsFormatStr('Bias (V)') + "V"
		endif
	endif
	
	return ""
End

Static Function/S KMGetSettingsCurrent(DFREF dfr)
	
	NVAR/Z/SDFR=dfr current
	if (NVAR_Exists(current))
		return num2str(current)
	endif
	
	//	Nanonis
	if (DataFolderRefStatus(dfr:'Z-CONTROLLER'))
		SVAR/Z/SDFR=dfr:'Z-CONTROLLER' Setpoint
		if (SVAR_Exists(Setpoint))
			return Setpoint
		endif
		NVAR/Z/SDFR=dfr:'Z-CONTROLLER' OverwrittenSetpoint = Setpoint
		if (NVAR_Exists(OverwrittenSetpoint))
			return KMGetSettingsFormatStr(OverwrittenSetpoint) + "A"
		endif
	elseif (DataFolderRefStatus(dfr:Current))
		NVAR/Z/SDFR=dfr:Current 'Current (A)'
		return KMGetSettingsFormatStr('Current (A)') + "A"
	endif
	
	return ""
End

Static Function/S KMGetSettingsComment(DFREF dfr)
	
	SVAR/Z/SDFR=dfr text, comment
	if (SVAR_Exists(text))
		return text
	elseif (SVAR_Exists(comment))	//	Nanonis
		return comment
	else
		return ""
	endif
End

Static Function/S KMGetSettingsAngle(DFREF dfr)
	
	NVAR/Z/SDFR=dfr angle		//	RHK SM2
	if (NVAR_Exists(angle))
		return num2str(angle)
	endif
	
	//	以下、Nanonis対応
	//	Nanonisでは時計回りを正として角度が記録されているので、正負を逆転して返す
	SVAR/Z/SDFR=dfr grid = 'Grid settings'	//	Nanonis 3ds
	if (SVAR_Exists(grid))
		Variable a = str2num(StringFromList(4, grid))
		return num2str(-a)
	endif
	
	NVAR/Z/SDFR=dfr anglesxm = 'angle (deg)'	//	Nanonis sxm
	if (NVAR_Exists(anglesxm))
		return num2str(-anglesxm)
	endif
	
	return ""
End

Static Function/S KMGetSettingsFormatStr(Variable var)
	
	String str	
	switch (floor((log(abs(var))+1)/3))
		case 1:
			sprintf str, "%.2f k", var*1e-3
			break
		case 0:
			sprintf str, "%.2f ", var
			break
		case -1:
			sprintf str, "%.2f m", var*1e3
			break
		case -2:
			sprintf str, "%.2f u", var*1e6
			break
		case -3:
			sprintf str, "%.2f n", var*1e9
			break
		case -4:
			sprintf str, "%.2f p", var*1e12
			break
		case -5:
			sprintf str, "%.2f f", var*1e15
			break
		default:
			str = num2str(var)
	endswitch
	return str
End
