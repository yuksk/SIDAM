#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = KMLayerViewer

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

//******************************************************************************
//	viewer本体パネル
//******************************************************************************
Function/S KMLayerViewerPnl(Wave w)
	
	//  パネル表示
	Display/K=1/HIDE=1 as NameOfWave(w)	//	表示中にチラチラするのを防ぐために、HIDE=1にしておく
	String pnlName = S_name
	AppendImage/W=$pnlName/G=1 w
	ModifyImage/W=$pnlName $NameOfWave(w) ctabAutoscale=3
	
	//  表示詳細
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	ModifyGraph/W=$pnlName width=prefs.viewer.width
	if (prefs.viewer.height == 1)		//	same as width
		ModifyGraph/W=$pnlName height=prefs.viewer.width
	else	//	2: plan
		ModifyGraph/W=$pnlName height={Plan,1,left,bottom}
	endif
	ModifyGraph/W=$pnlName standoff=0,tick=3,noLabel=2,axThick=0,margin=1
	
	//  コントロールバー
	KMInfoBar(pnlName)
	
	DoUpdate/W=$pnlName
	
	//	表示する大きさが適正ではない場合への対処
	GetWindow kwTopWin wsizeDC ;			Variable collapsed = V_bottom <= 0
	GetWindow kwFrameInner wsizeDC ;		Variable frameHeight = V_bottom
	GetWindow kwTopWin wsizeOuterDC ;	Variable winHeight = V_bottom
	if (collapsed)					//	つぶれている場合 (linecut)
		ModifyGraph height = 20
		DoUpdate/W=$pnlName
		ModifyGraph/W=$pnlName height=0
	elseif (winHeight > frameHeight && frameHeight)	//	画面からはみ出た場合, Macでは frameHeight は常に0であることに注意
		ModifyGraph height = (frameHeight - 136) * 72 / screenresolution
		DoUpdate/W=$pnlName
		ModifyGraph/W=$pnlName height=0
	endif
	
	SetWindow $pnlName hide=0		//	表示時に隠しておいたものを表示する
	
	return pnlName
End

//******************************************************************************
//	KMLayerViewerDo
//		レイヤー処理に関するまとめ
//		indexを指定したらそのindexに表示を変更
//		directionを指定したら一つ隣のレイヤーに表示を変更
//		返り値は変更後のレイヤーの値
//		indexもdirectionも指定しない場合には何もしないので、現在のレイヤーの値が返される
//******************************************************************************
Function KMLayerViewerDo(String grfName, [Wave/Z w, int index, int direction])
	
	if (ParamIsDefault(w))
		Wave/Z w =  KMGetImageWaveRef(grfName)
	endif
	if (!WaveExists(w) || WaveDims(w) != 3)
		return NaN
	endif
	
	int plane = NumberByKey("plane", ImageInfo(grfName, NameOfWave(w), 0), "=")	//	現在の表示レイヤー
	
	if (ParamIsDefault(index) && ParamIsDefault(direction))	//	index も direction も指定されていない
		//	何もしない, planeは現在の表示レイヤーのまま
	else
		if (!ParamIsDefault(index))
			plane = limit(round(index), 0, DimSize(w,2)-1)		//	index が指定されている (両方指定されている場合はindex優先)
		else
			plane = limit(plane+direction, 0, DimSize(w,2)-1)	//	direction が指定されている
		endif
		ModifyImage/W=$grfName $NameOfWave(w) plane=plane
	endif
	return plane
End


//******************************************************************************
//	メニュー項目
//******************************************************************************
Static Function/S rightclickMenu(int menuitem)
	
	Wave/Z w = KMGetImageWaveRef(WinName(0,1))
	if (!WaveExists(w) || WaveDims(w) != 3)
		return ""
	endif
	
	switch (menuitem)
		case 0:	//
			return "Extract Layers..."
		case 1:	//
			return "Auto Annotation..."
	endswitch
End

Static Function/S rightclickDo(int mode)
	switch (mode)
		case 0:	//	
			extractPnl(WinName(0,1))
			break
	endswitch
End


//=====================================================================================================


//******************************************************************************
//	ウエーブ出力用パネル
//******************************************************************************
Static Function extractPnl(String LVName)
	
	if (WhichListItem("ExtractLayers",ChildWindowList(StringFromList(0, LVName, "#"))) != -1)
		return 0
	endif
	
	Wave w = KMGetImageWaveRef(LVName)
	Variable plane = NumberByKey("plane", ImageInfo(LVName, NameOfWave(w), 0), "=")	//	現在の表示レイヤー
	
	//  パネル表示
	NewPanel/HOST=$LVName/EXT=0/W=(0,0,290,195)
	RenameWindow $LVName#$S_name, ExtractLayers
	String pnlName = LVName + "#ExtractLayers"
	
	//	フック関数・ユーザデータ
	SetWindow $pnlName hook(self)=KMClosePnl
	
	//	layer
	GroupBox layer0G title="Layer", pos={11,4}, size={268,70}, win=$pnlName
	CheckBox thisC title="this ("+num2str(plane)+")", pos={23,26}, size={66,14}, value=1, mode=1, proc=KMLayerViewer#extractPnlCheck, win=$pnlName
	CheckBox fromC title="", pos={23,49}, size={16,14}, value=0, mode=1, proc=KMLayerViewer#extractPnlCheck, win=$pnlName
	SetVariable from_w_V title="from:", pos={41,48}, size={79,15}, bodyWidth=50, proc=KMLayerViewer#extractPnlSetVar, win=$pnlName
	SetVariable from_w_V value=_NUM:0, limits={0,DimSize(w,2)-1,1}, format="%d", win=$pnlName
	SetVariable to_w_V title="to:", pos={131,48}, size={66,15}, bodyWidth=50, proc=KMLayerViewer#extractPnlSetVar, win=$pnlName
	SetVariable to_w_V value=_NUM:DimSize(w,2)-1, limits={0,DimSize(w,2)-1,1}, format="%d", win=$pnlName
	//	wave
	GroupBox waveG title="Wave", pos={11,80}, size={268,70}, win=$pnlName
	TitleBox resultT title="output name:", pos={30,101}, frame=0, win=$pnlName
	SetVariable resultV title=" ", pos={28,121}, size={235,15}, bodyWidth=235, proc=KMLayerViewer#extractPnlSetVar, win=$pnlName
	SetVariable resultV value=_STR:NameOfWave(w)[0,30-strlen("_r"+num2str(plane))]+"_r"+num2str(plane), win=$pnlName
	//	buttonなど
	Button doB title="Do It", pos={8,165}, size={70,20}, proc=KMLayerViewer#extractPnlButton, win=$pnlName
	Button closeB title="Close", pos={214,165}, size={70,20}, proc=KMLayerViewer#extractPnlButton, win=$pnlName
	CheckBox displayC title="display", pos={87,168}, value=1, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
End


//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function extractPnlButton(STRUCT WMButtonAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "doB":
			extractPnlSave(s.win)
			// *** FALLTHROUGH ***
		case "closeB":
			KillWindow $s.win
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function extractPnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 1
	endif
	
	CheckBox thisC value=stringmatch(s.ctrlName,"thisC"), win=$s.win
	CheckBox fromC value=stringmatch(s.ctrlName,"fromC"), win=$s.win
	CheckBox displayC disable=stringmatch(s.ctrlName,"fromC")*2, win=$s.win
	TitleBox resultT title=SelectString(WhichListItem(s.ctrlName,"thisC;fromC;"),"output name:","basename"), win=$s.win
	
	String parentWin = StringFromList(0, s.win, "#")
	Wave w = KMGetImageWaveRef(parentWin)
	int plane = NumberByKey("plane", ImageInfo(parentWin, NameOfWave(w), 0), "=")	//	現在の表示レイヤー
	
	String name = NameOfWave(w)+"_r"
	ControlInfo/W=$s.win resultV
	if (stringmatch(S_value[0,strlen(NameOfWave(w))+1], name))	//	名前の付け方が初期設定のままなら
		if (stringmatch(s.ctrlName,"thisC"))
			SetVariable resultV value=_STR:name+num2str(plane), win=$s.win
		elseif (stringmatch(s.ctrlName,"fromC"))
			SetVariable resultV value=_STR:name, win=$s.win
		endif
	endif
	Button doB disable=CheckResultStrLength(s.win)*2, win=$s.win
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function extractPnlSetVar(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode == -1)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "from_w_V" :
		case "to_w_V" :
			KMClickCheckBox(s.win,"fromC")
			break
		case "resultV" :
			Button doB disable=CheckResultStrLength(s.win)*2, win=$s.win
			break
		default:
	endswitch
End

//******************************************************************************
//	パネルコントロール補助関数
//******************************************************************************
//-------------------------------------------------------------
//	出力文字列の長さを判定
//-------------------------------------------------------------
Static Function CheckResultStrLength(String pnlName)
	int maxLength = MAX_OBJ_NAME
	
	ControlInfo/W=$pnlName fromC
	if (V_Value)
		Wave cvw = KMGetCtrlValues(pnlName, "from_w_V;to_w_V")
		maxLength -= floor(log(WaveMax(cvw)))+1	//	from と to の大きな方の数字の桁数を引いている
	endif
	
	return KMCheckSetVarString(pnlName,"resultV", 0, maxlength=maxLength)
End
//-------------------------------------------------------------
//	doBの実行関数
//-------------------------------------------------------------
Static Function extractPnlSave(String pnlName)
	
	String LVName = StringFromList(0, pnlName, "#")
	Wave w = KMGetImageWaveRef(LVName)
	
	ControlInfo/W=$pnlName resultV
	String result = S_value
	
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder GetWavesDataFolderDFR(w)
	
	ControlInfo/W=$pnlName thisC
	if (V_Value)

		int plane = NumberByKey("plane", ImageInfo(LVName, NameOfWave(w), 0), "=")	//	現在の表示レイヤー
		Duplicate/O/R=[][][plane] w, $result
		Redimension/N=(-1,-1) $result
		ControlInfo/W=$pnlName displayC
		if (V_Value && !V_Disable)
			extractPnlDisplay($result, LVName)
		endif

	else

		Wave cw = KMGetCtrlValues(pnlName,"from_w_V;to_w_V")
		int digit = WaveMin(cw) ? floor(log(WaveMax(cw)))+1 : 1
		String name
		int i
		for (i = WaveMin(cw); i <= WaveMax(cw); i++)
			sprintf name, "%s%0"+num2istr(digit)+"d", result, i
			Duplicate/O/R=[][][i] w, $name
			Redimension/N=(-1,-1) $name
		endfor

	endif
	
	SetDataFolder dfrSav
End
//-------------------------------------------------------------
//	displayCにチェックが入っている場合の動作
//-------------------------------------------------------------
Static Function extractPnlDisplay(Wave extw, String LVName)
	
	//	ウエーブを表示する
	String grfName = KMDisplay(w=extw)
	
	//	LayerViewerでのz表示範囲を適用する
	Wave srcw = KMGetImageWaveRef(LVName)
	Wave rw = KM_GetColorTableMinMax(LVName, NameOfWave(srcw))
	KMRange(grfName=grfName,imgList=NameOfWave(extw),zmin=rw[0],zmax=rw[1])
	
	//	LayerViewerでのカラーテーブルを適用する
	String ctab = WM_ColorTableForImage(LVName, NameOfWave(srcw))
	int rev = WM_ColorTableReversed(LVName, NameOfWave(srcw))
	int log = KM_ColorTableLog(LVName,NameOfWave(srcw))
	Wave minRGB = makeRGBWave(LVName, NameOfWave(srcw), 0)
	Wave maxRGB = makeRGBWave(LVName, NameOfWave(srcw), 1)
	KMColor(grfName=grfName,imgList=NameOfWave(extw),ctable=ctab,rev=rev,log=log,minRGB=minRGB,maxRGB=maxRGB)
	
	//	expand, axis, textboxをコピーする
	String cmd, recStr = WinRecreation(LVName, 4)
	//		subwindowの情報は不要なのでカットする
	Variable v0 = strsearch(recStr, "NewPanel",0)
	v0 = (v0 == -1) ? strlen(recStr)-1 : v0
	recStr = recStr[0,v0]
	
	cmd = ReplaceString("\r\t", GrepList(recStr,"\tModifyGraph",0,"\r"), ";")
	cmd = ReplaceString("expand=-", cmd, "expand=")	//	なぜか expand=-2 のように記録されるので、それを修正する
	Execute/Z cmd
	cmd = ReplaceString("\r\t", GrepList(recStr,"\tSetAxis",0,"\r"), ";")
	Execute/Z cmd
	cmd = ReplaceString("\r\t", GrepList(recStr,"\tTextBox",0,"\r"), ";")
	Execute/Z cmd
End

Static Function/WAVE makeRGBWave(String grfName, String imgName, int minOrMax)
	
	int mode = (minOrMax==0) ? KM_ImageColorMinRGBMode(grfName,imgName) : KM_ImageColorMaxRGBMode(grfName,imgName)
	
	switch (mode)
		case 0:
			Make/FREE rgbw = {0}
			break
		case 1:
			STRUCT RGBColor s
			if (minOrMax==0)
				KM_ImageColorMinRGBValues(grfName,imgName,s)
			else
				KM_ImageColorMaxRGBValues(grfName,imgName,s)
			endif
			Make/FREE rgbw = {s.red,s.green,s.blue}
			break
		case 2:
			Make/FREE rgbw = {NaN}
			break	
	endswitch
	
	return rgbw
End

//=====================================================================================================

//-------------------------------------------------------------
//	古いバージョンからの変更点を反映させる
//	SyncLayerの動作を問題なく行うために、この関数が呼ばれたら全てのウインドウに
//	ついて変更点を反映させるようにする
//-------------------------------------------------------------
Function KMLayerViewerPnlHook(STRUCT WMWinHookStruct &s)	//	古い(名前の)フック関数は後方互換性確保に用いる
	String listStr = WinList("*",";","WIN:1")
	Variable i, n = ItemsInList(listStr)
	
	for (i = 0; i < n; i += 1)
		String grfName = StringFromList(i, listStr)
		//	rev. 671まではsrcWaveを使用していた
		Wave/Z w = $GetUserData(grfName,"","srcWave")
		if (WaveExists(w) && WaveDims(w)==3)
			KMLayerViewerPnlBackComp231(grfName)	//	rev. 127 - > rev. 231 への変更
			KMLayerViewerPnlBackComp700(grfName)	//	rev. 231 -> rev. 700 への変更
			printf "%s was updated.\r", grfName
		endif
	endfor
End

//	rev. 231 -> rev. 700 への変更
Static Function KMLayerViewerPnlBackComp700(String pnlName)
	
	Wave w = $GetUserData(pnlName,"","srcWave")
	DFREF dfrTmp = $GetUserData(pnlName, "", "dfTmp")
	
	//	フック関数の交換
	SetWindow $pnlName hook(self)=KMDisplayCtrlBarHook
	
	//	userDataの削除
	SetWindow $pnlName userData(this)=""
	SetWindow $pnlName userData(srcWave)=""
	SetWindow $pnlName userData(dfTmp)=""
	
	//	index, valueの処理
	NVAR/SDFR=dfrTmp index, value
	SetVariable layerindexV rename=indexV, value=_NUM:index, proc=KMDisplayCtrlBarSetVar2, win=$pnlName
	SetVariable layerenergyV rename=energyV, value=_NUM:value, proc=KMDisplayCtrlBarSetVar2, win=$pnlName
	
	//	AutoAnnotationの処理
	NVAR/SDFR=dfrTmp legendOn
	if (legendOn)
		SVAR/SDFR=dfrTmp legendStr ;		SetWindow $pnlName userData(AAstr)=legendStr
		NVAR/SDFR=dfrTmp legendDigit ;	SetWindow $pnlName userData(AAdigit)=num2str(legendDigit)
		SetWindow $pnlName userData(AAname)="KMLegendText"
		SetWindow $pnlName hook(AA)=KMLayerViewer#aaHook
	endif
	
	//	イメージの更新前に情報を取得しておく
	Wave rw = KM_GetColorTableMinMax(pnlName, NameOfWave(w))			//	z表示範囲
	String ctab = WM_ColorTableForImage(pnlName,NameOfWave(w))			//	Igor標準カラーテーブル
	Variable rev = WM_ColorTableReversed(pnlName,NameOfWave(w))			//	反転
	Wave/Z cindexw = $WM_ImageColorIndexWave(pnlName,NameOfWave(w))	//	カラーインデックスウエーブ
	
	//	イメージの更新
	AppendImage/W=$pnlName w
	RemoveImage/W=$pnlName $NameOfWave(w)		//	古いほうが削除されて、新しいほうが残る
	ModifyImage/W=$pnlName $NameOfWave(w), plane=index
	
	//	complexの処理、イメージを更新してから実行する必要がある
	NVAR/SDFR=dfrTmp complex
	if (WaveType(w) & 0x01)
		KillControl/W=$pnlName cmplxP
		DoWindow/T $pnlName NameOfWave(w)
		if (complex == 1)			//	phase
			ModifyImage/W=$pnlName $NameOfWave(w) imCmplxMode=3
		elseif (complex >= 2)	//	real, imaginary
			ModifyImage/W=$pnlName $NameOfWave(w) imCmplxMode=complex-1
		endif
		DoUpdate/W=$pnlName
	endif
	
	//	z表示範囲とカラーテーブルをコピーする
	if (!(WaveType(w) & 0x01) || !complex)
		if (strlen(ctab))
			ModifyImage/W=$pnlName $NameOfWave(w) ctab= {rw[0],rw[1],$ctab,rev}
		else
			DFREF dfrSrc = GetWavesDataFolderDFR(w)
			Duplicate/O cindexw dfrSrc:$("c_"+NameOfWave(w))/WAVE=cindexw2
			ModifyImage/W=$pnlName $NameOfWave(w) cindex=cindexw2
		endif
	endif
	
	//	一時データフォルダの削除
	KMonClosePnlKillDF(dfrTmp)
End

//	rev. 127 - > rev. 231 への変更
Static Function KMLayerViewerPnlBackComp231(String pnlName)
	ControlInfo/W=$pnlName pointB
	if (V_Flag)
		KillControl/W=$pnlName pointB
		KillControl/W=$pnlName lineB
		KillControl/W=$pnlName extractB
		KillControl/W=$pnlName optionB
	endif
End

//-------------------------------------------------------------
//	rev. 1073より前で使われていたフック関数
//-------------------------------------------------------------
Function KMLayerViewerAAHook(STRUCT WMWinHookStruct &s)
	SetWindow $s.winName hook(AA)=KMLayerViewer#aaHook
End

//-------------------------------------------------------------
//	v8.0.2以前で使われていたフック関数
//-------------------------------------------------------------
Static Function aaHook(STRUCT WMWinHookStruct &s)
	SIDAMLayerAnnotation#backCompFromLayerViewerAA(s.winName)
End