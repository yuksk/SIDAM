#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMColor

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>


//	カラーテーブル参照先
//	Wolfram
//	http://reference.wolfram.com/language/guide/ColorSchemes.ja.html
//
//	Matplotlib
//	http://matplotlib.org/examples/color/colormaps_reference.html
//
//	IDL
//	https://www.harrisgeospatial.com/docs/loadingdefaultcolortables.html
//	http://www.paraview.org/Wiki/Colormaps
//
//	CET Perceptually Uniform Colour Maps
//	http://peterkovesi.com/projects/colourmaps/

//******************************************************************************
//	KMColor
//		入力変数のチェックと内容に応じた実行関数の呼び出し
//******************************************************************************
Function KMColor(
	[
		String grfName,	//	表示されているグラフの名前、省略時は一番上のグラフ
		String imgList,	//	そのグラフ内で表示されているイメージのリスト、省略時は全てのイメージ
		String ctable,	//	Igorカラーテーブルの名前、もしくは、カラーテーブルウエーブへのパス、省略時は現在のカラーテーブル
		int rev,			//	逆順、省略時は現在の値
		int log,			//	対数、省略時は現在の値
		Wave minRGB,		//	Before first Color、省略時は現在の値
		Wave maxRGB,		//	After last Color、省略時は現在の値
		int history		//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	])
	
	//	パラメータチェック
	STRUCT paramStruct s
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.imgList = SelectString(ParamIsDefault(imgList), imgList, ImageNameList(s.grfName,";"))
	s.ctable = SelectString(ParamIsDefault(ctable), ctable, "")	
	s.rev = ParamIsDefault(rev) ? NaN : rev
	s.log = ParamIsDefault(log) ? NaN : log
	
	if (ParamIsDefault(minRGB))
		Wave/Z s.minRGB = $""
	else
		Wave/Z s.minRGB = minRGB
	endif
	if (ParamIsDefault(maxRGB))
		Wave/Z s.maxRGB = $""
	else
		Wave/Z s.maxRGB = maxRGB
	endif
	
	if (!CmpStr(GetRTStackInfo(2),"SIDAMBeforeExperimentSaveHook"))
		killUnusedWaves()
		return 0
	elseif (!isValidArguments(s))
		print s.errMsg
		return 1
	endif
	
	if (ParamIsDefault(ctable) && ParamIsDefault(rev) && ParamIsDefault(log) && ParamIsDefault(minRGB) && ParamIsDefault(maxRGB))
		pnl(s.grfName)
		return 0
	endif
	
	//  履歴
	if (!ParamIsDefault(history) && history == 1)
		String paramStr = ""
		paramStr += SelectString(ParamIsDefault(grfName),"grfName=\""+s.grfName+"\",","")
		paramStr += SelectString(ParamIsDefault(imgList),"imgList=\""+s.imgList+"\",","")
		paramStr += SelectString(ParamIsDefault(ctable),"ctable=\""+s.ctable+"\",","")
		paramStr += SelectString(ParamIsDefault(rev),"rev="+num2istr(rev)+",","")
		paramStr += SelectString(ParamIsDefault(log),"log="+num2istr(log)+",","")
		paramStr += SelectString(ParamIsDefault(minRGB),"minRGB="+KMWaveToString(s.minRGB)+",","")
		paramStr += SelectString(ParamIsDefault(maxRGB),"maxRGB="+KMWaveToString(s.maxRGB)+",","")
		printf "%sKMColor(%s)\r", PRESTR_CMD, RemoveEnding(paramStr)	//	最後のコンマを取る
	endif
	
	//  実行関数へ
	int i, n
	for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
		applyColorTable(s.grfName,StringFromList(i,s.imgList),s.ctable,s.rev,s.log,s.minRGB,s.maxRGB)
	endfor
	
	return 0
End
//-------------------------------------------------------------
//	isValidArguments : チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMColor gave error: "
	
	if (!strlen(s.grfName))
		s.errMsg += "graph not found."
		return 0
	elseif (!KMWindowExists(s.grfName))
		s.errMsg += "a graph named " + s.grfName + " is not found."
		return 0
	elseif (!strlen(ImageNameList(s.grfName,";")))
		s.errMsg += s.grfName + " has no image."
		return 0
	endif
	
	int i, n
	for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
		if (WhichListItem(StringFromList(i,s.imgList),ImageNameList(s.grfName,";")) < 0)
			s.errMsg += "an image named " + StringFromList(i,s.imgList) + " is not found."
			return 0
		endif
	endfor
	
	//	カラーテーブルウエーブへのパスが指定された場合、対応するウエーブがあるかどうか確認する
	//	なければすべてのカラーテーブルウエーブを一度読み込み、再び確認して、なければエラーを返す
	if (strlen(s.ctable) && WhichListItem(s.ctable,CTabList()) < 0 && !WaveExists($s.ctable))
		loadColorTableWaves()
		if (!WaveExists($s.ctable))
			killUnusedWaves()	//	確認用に読み込まれたものを削除する
			s.errMsg += "a color table " + s.ctable + " is not found."
			return 0
		endif
	endif
	
	if (s.rev < 0 || s.rev > 1)
		s.errMsg += "rev must be 0 or 1."
		return 0
	endif
	
	if (s.log < 0 || s.log > 1)
		s.errMsg += "log must be 0 or 1."
		return 0
	endif
	
	return 1
End

Static Structure paramStruct
	String grfName
	String imgList
	String ctable
	Variable rev
	Variable log
	Wave	minRGB
	Wave 	maxRGB
	String errMsg
EndStructure


//******************************************************************************
//	1つのイメージに対しての実行関数
//******************************************************************************
Static Function applyColorTable(String grfName, String imgName, String ctab, Variable rev, Variable log, Wave/Z minRGB, Wave/Z maxRGB)
	
	Wave rw = KM_GetColorTableMinMax(grfName, imgName)
	Variable zmin = isFirstZAuto(grfName, imgName) ? NaN : rw[0]
	Variable zmax = isLastZAuto(grfName, imgName) ? NaN : rw[1]
	
	//	省略されていたら(空文字)、現在のカラーテーブルを使用する
	if (!strlen(ctab))
		ctab = WM_ColorTableForImage(grfName,imgName)
	endif
	
	//	省略されていたら(NaN)、現在の値を用いる
	if (numtype(rev)==2)
		rev = WM_ColorTableReversed(grfName,imgName)
	endif
	
	if (numtype(zmin)==2 && numtype(zmax)==2)
		ModifyImage/W=$grfName $imgName ctab={*,*,$ctab,rev}
	elseif (numtype(zmin)==2)
		ModifyImage/W=$grfName $imgName ctab={*,zmax,$ctab,rev}
	elseif (numtype(zmax)==2)
		ModifyImage/W=$grfName $imgName ctab={zmin,*,$ctab,rev}
	else
		ModifyImage/W=$grfName $imgName ctab={zmin,zmax,$ctab,rev}
	endif
	
	//	省略されていなかったら設定する
	if (numtype(log)!=2)
		ModifyImage/W=$grfName $imgName log=log
	endif
	
	//	省略されていなかったら設定する
	if (WaveExists(minRGB))
		if (numpnts(minRGB)==1)
			if (minRGB[0]==0)
				ModifyImage/W=$grfName $imgName minRGB=0
			elseif (numtype(minRGB[0])==2)	//	NaN
				ModifyImage/W=$grfName $imgName minRGB=NaN
			endif
		elseif (numpnts(minRGB)==3)	//	(r,g,b)
			ModifyImage/W=$grfName $imgName minRGB=(minRGB[0],minRGB[1],minRGB[2])
		endif
	endif
	
	//	省略されていなかったら設定する
	if (WaveExists(maxRGB))
		if (numpnts(maxRGB)==1)
			if (maxRGB[0]==0)
				ModifyImage/W=$grfName $imgName maxRGB=0
			elseif (numtype(maxRGB[0])==2)	//	NaN
				ModifyImage/W=$grfName $imgName maxRGB=NaN
			endif
		elseif (numpnts(maxRGB)==3)	//	(r,g,b)
			ModifyImage/W=$grfName $imgName maxRGB=(maxRGB[0],maxRGB[1],maxRGB[2])
		endif
	endif
	
End


//=====================================================================================================
//	パネル関係
//=====================================================================================================
//	コントロールタブのためのスペース
Static Constant leftMargin = 10
Static Constant topMargin = 165

//	1つのカラーテーブルの大きさ
Static Constant ctabHeight = 14
Static Constant ctabWidth = 90
Static Constant ctabMargin = 2

//	1つのカラム内に縦に並べるカラーテーブルの個数
Static Constant ctabsInColumn = 30

//	カラーテーブルとチェックボックスのための幅
Static Constant columnWidth = 270

//	カラーテーブルとチェックボックスの間の幅
Static Constant checkBoxMargin = 5

//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(String grfName)
	
	//	重複チェック
	if (WhichListItem("Color",ChildWindowList(StringFromList(0, grfName, "#"))) != -1)
		return 0
	endif
	
	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	int i, n
	int needUpdate = DataFolderExists(SIDAM_DF_CTAB) ? NumVarOrDefault(SIDAM_DF_CTAB+"needUpdate",1) : 1
	
	//	カラーテーブルを読み込む必要がある場合、読み込みに少し時間がかかる
	//	そのため、まずはパネルの概観を表示し、必要に応じて読み込み中の表示をする
	
	//	パネル作成
	NewPanel/EXT=0/HOST=$StringFromList(0, grfName, "#")/W=(0,0,560,655)/K=1
	RenameWindow $StringFromList(0, grfName, "#")#$S_name, Color
	String pnlName = StringFromList(0, grfName, "#") + "#Color"
	saveImageColorInfo(pnlName)
	
	//	タブ
	String tabNameList = "Igor;" + SIDAM_CTABGROUPS
	TabControl mTab pos={3,topMargin-30}, size={557,520}, proc=KMColor#pnlTab, win=$pnlName
	for (i = 0, n = ItemsInList(tabNameList); i < n; i++)
		TabControl mTab tabLabel(i)=StringFromList(i,tabNameList), win=$pnlName
	endfor
	
	//	カラーテーブルを表示するためのサブウインドウ用ガイド定義
	DefineGuide/W=$pnlname ctab0L = {FL, leftMargin}
	DefineGuide/W=$pnlName ctab0R = {FL, leftMargin+ctabWidth}
	DefineGuide/W=$pnlname ctab1L = {FL, leftMargin+columnWidth}
	DefineGuide/W=$pnlName ctab1R = {FL, leftMargin+columnWidth+ctabWidth}
	DefineGuide/W=$pnlName ctabT = {FT, topMargin}
	DefineGuide/W=$pnlName ctabB = {FT, topMargin+(ctabHeight+ctabMargin)*ctabsInColumn-ctabMargin}
	
	//	タブ外共通要素
	PopupMenu imageP pos={7,5},size={235,19},bodyWidth=200,title="image",win=$pnlName
	CheckBox allC pos={265,7},title=" all images",value=0,win=$pnlName
	
	GroupBox optionsG pos={5,35},size={130,90},title="Color Table Options",win=$pnlName
	CheckBox revC pos={14,56},title=" Reverse Colors",win=$pnlName
	CheckBox logC pos={14,80},title=" Log Colors",win=$pnlName
	
	GroupBox beforeG pos={140,35},size={130,90},title="Before First Color"	,win=$pnlName
	CheckBox beforeUseC pos={149,55},title=" Use First Color",mode=1,win=$pnlName
	CheckBox beforeClrC pos={149,79},title="",mode=1,win=$pnlName
	CheckBox beforeTransC pos={149,101},title=" Transparent",mode=1,win=$pnlName
	PopupMenu beforeClrP pos={167,77},size={40,19},bodyWidth=40,value= #"\"*COLORPOP*\"",win=$pnlName
	
	GroupBox lastG pos={275,35},size={130,90},title="After Last Color",win=$pnlName
	CheckBox lastUseC pos={284,55},title=" Use Last Color",mode=1,win=$pnlName
	CheckBox lastClrC pos={284,79},title="",mode=1,win=$pnlName
	CheckBox lastTransC pos={284,101},title=" Transparent",mode=1,win=$pnlName
	PopupMenu lastClrP pos={302,77},size={40,19},bodyWidth=40,value= #"\"*COLORPOP*\"",win=$pnlName
	
	Button doB pos={456,49},size={70,22},title="Do It",proc=KMColor#pnlButton,win=$pnlName
	Button cancelB pos={456,85},size={70,22},title="Cancel",proc=KMColor#pnlButton,win=$pnlName
	
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0,win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*P") mode=1, proc=KMColor#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*C") proc=KMColor#pnlCheck, win=$pnlName
	CheckBox allC proc=KMColor#pnlCheckAllC, win=$pnlName
	
	//	カラーテーブルが読み込まれていなければ読み込む
	if (needUpdate)
		loading(pnlName)
		loadColorTableWaves()
		Variable/G $(SIDAM_DF_CTAB+"needUpdate") = 0
		//	読み込まれていなかったということは、旧バージョンでのカラーインデックスウエーブが
		//	使われている可能性がある。存在を調べて、新形式に変換する。
		cindexWave2ctabWave()
	endif
	
	//	適切なタブを選択する
	Variable activeTab = findTabForPresentCtab(grfName,imgName)
	TabControl mTab value=activeTab, win=$pnlName
	
	//	各タブの中の要素を配置する
	for (i = 0, n = getNumberOfTabs(pnlName, "mTab"); i < n; i++)
		pnlTabComponents(pnlName, i, i!=activeTab)
	endfor
	SetActiveSubwindow ##
	
	SetWindow $grfName hook(KMColorPnl)=KMColor#pnlHookParent
	SetWindow $pnlName hook(self)=KMColor#pnlHook
	SetWindow $pnlName userData(grf)=grfName, activeChildFrame=0
	
	//	ユーザーデータ等の設定が全て終わってから実行すべき項目
	PopupMenu imageP proc=KMColor#pnlPopup,value=#"KMColor#imageListForImageP()",win=$pnlName
	
	//	現在選択されているカラーテーブルに対応するチェックボックスを1にする
	String selected = findCheckBox(pnlName,imgName)
	if (strlen(selected))
		CheckBox $selected value=1, win=$pnlName
	endif
	
	//	rev, log, mixRGB, maxRGBに関するコントロールの状態を更新
	updateOptionControls(pnlName,imgName)
	
	if (needUpdate)
		loading(pnlName)
	endif
End

//-----------------------------------------------------------------------
//	読み込み中表示
//-----------------------------------------------------------------------
Static Function loading(String pnlName)
	String name = "loading"
	
	DrawAction/L=Overlay/W=$pnlName getgroup=$name
	
	//	読み込み中表示がなければ表示、あれば消去
	if (V_flag)
		DrawAction/L=Overlay/W=$pnlName getgroup=$name, delete
	else
		SetDrawLayer/W=$pnlName Overlay
		SetDrawEnv/W=$pnlName gname=$name, gstart
		
		SetDrawEnv/W=$pnlName fillfgc=(0,0,0,32768),linethick=0
		DrawRect/W=$pnlName 5,155,555,650
		
		SetDrawEnv/W=$pnlName textrgb=(65535,65535,65535), textxjust=1, textyjust=1
		DrawText/W=$pnlName 275,400,"Now loading..."
		
		SetDrawEnv/W=$pnlName gstop
		SetDrawLayer/W=$pnlName UserBack
	endif
	
	DoUpdate/W=$pnlName
End

//-----------------------------------------------------------------------
//	カラーテーブルとチェックボックスを表示する
//-----------------------------------------------------------------------
Static Function pnlTabComponents(String pnlName, int tab, int hide)
	
	String list
	if (tab == 0)	//	Igor標準
		list = CTabList()
	else				//	カラーテーブルウエーブ
		list = fetchWavepathList($(SIDAM_DF_CTAB+StringFromList(tab-1,SIDAM_CTABGROUPS)))
	endif
	int i, n
	
	//	カラーテーブル表示用グラフ領域
	Display/HOST=$pnlName/HIDE=(hide)
	MoveSubWindow/W=$pnlName#G0 fguide=(ctab0L, ctabT, ctab0R, ctabB)
	RenameWindow $pnlName#G0 $("G_"+num2istr(tab)+"_0")
	
	Display/HOST=$pnlName/HIDE=(hide)
	MoveSubWindow/W=$pnlName#G0 fguide=(ctab1L, ctabT, ctab1R, ctabB)
	RenameWindow $pnlName#G0 $("G_"+num2istr(tab)+"_1")
	
	for (i = 0, n = ItemsInList(list); i < n; i++)
		//	カラーテーブルはサブグラフ中に表示される
		String csName = "cs_"+num2istr(tab)+"_"+num2istr(i)
		String ctabName = StringFromList(i, list)
		String subWinName = "G_"+num2istr(tab)+"_"+num2istr(floor(i/ctabsInColumn))
		ColorScale/W=$pnlName#$subWinName/C/N=$csName/F=0/A=LT/X=0/Y=(mod(i,ctabsInColumn)/ctabsInColumn*100) widthPct=100,height=ctabHeight,vert=0,ctab={0,100,$ctabName,0},nticks=0,tickLen=0.00
		
		//	チェックボックスはパネル中に表示される。タイトルは以下の通り。
		//	listの内容がIgor標準カラーテーブル名リストの際にはStringFromList(i,list)がそのまま入る。
		//	カラーテーブルウエーブへのパスのリストのときはウエーブ名が入る。
		String cbName = "cb_"+num2istr(tab)+"_"+num2istr(i)
		String titleName = ParseFilePath(0, StringFromList(i, list), ":", 1, 0)
		Variable left = leftMargin+ctabWidth+checkBoxMargin+columnWidth*floor(i/ctabsInColumn)
		Variable top = topMargin+((ctabHeight+ctabMargin)*mod(i,ctabsInColumn))
		CheckBox $cbName pos={left,top}, title=" "+titleName, disable=(hide), mode=1, proc=KMColor#pnlCheck, win=$pnlName
	endfor
End

//	Return a string containing a list of absolulte paths of all waves
//	under dfr including subdatafolder
Static Function/S fetchWavepathList(DFREF dfr)
	
	int i, n
	String list = ""
	
	for (i = 0, n = CountObjectsDFR(dfr, 4); i < n; i++)
		list += fetchWavepathList(dfr:$GetIndexedObjNameDFR(dfr, 4, i))
	endfor
	
	//	Sort by name, instead of order added to parent datafolder of GetIndexedObjNameDFR
	n = CountObjectsDFR(dfr,1)
	Make/N=(n)/T/FREE namew = GetIndexedObjNameDFR(dfr,1,p)
	Sort namew, namew
	
	for (i = 0, n = CountObjectsDFR(dfr, 1); i < n; i++)
		Wave/SDFR=dfr w = $namew[i]
		list += GetWavesDataFolder(w,2) + ";"
	endfor
	
	return list
End

//	Return tab number where the present color scale is included
Static Function findTabForPresentCtab(String grfName, String imgName)
	String ctabName = WM_ColorTableForImage(grfName,imgName)
	if (strsearch(ctabName,":",0) == -1)	//	Igor
		return 0
	endif
	String abspath = GetWavesDataFolder($ctabName,2)
	String groupName = StringFromList(ItemsInList(SIDAM_DF,":")+1,abspath,":")
	return WhichListItem(groupName,SIDAM_CTABGROUPS)+1
End

//	Return name of checkbox corresponding to the color scale
//	used for imgName in pnlName
Static Function/S findCheckBox(String pnlName, String imgName)
	
	String grfName = GetUserData(pnlName,"","grf")
	String ctabName = WM_ColorTableForImage(grfName,imgName)
	String chdWinName, chdWinList = ChildWindowList(pnlName)
	String clrscaleList, clrscaleName, scaleStr, name
	
	int i, j, n0, n1
	for (i = 0; i < ItemsInList(chdWinList); i++)
		chdWinName = pnlName+"#"+StringFromList(i,chdWinList)
		clrscaleList = AnnotationList(chdWinName)
		for (j = 0; j < ItemsInList(clrscaleList); j++)
			clrscaleName = StringFromList(j,clrscaleList)
			scaleStr = StringByKey("COLORSCALE", AnnotationInfo(chdWinName,clrscaleName))
			n0 = strsearch(scaleStr,"ctab={",0)
			n1 = strsearch(scaleStr,"}",n0)
			name = StringFromList(2,scaleStr[n0+6,n1-1],",")
			if (!CmpStr(ctabName,name) || WaveRefsEqual($ctabName,$name))
				return ReplaceString("cs_", clrscaleName ,"cb_")
			endif
		endfor
	endfor
	return ""
End

//	Return name of color scale or path to color table wave
//	by giving name of checkbox
Static Function/S findColorScale(String pnlName, String cbName)
	String chdWinName, chdWinList = ChildWindowList(pnlName)
	String clrscaleList, clrscaleName, scaleStr, name
	
	int i, j, n0, n1
	for (i = 0; i < ItemsInList(chdWinList); i++)
		chdWinName = pnlName+"#"+StringFromList(i,chdWinList)
		clrscaleList = AnnotationList(chdWinName)
		for (j = 0; j < ItemsInList(clrscaleList); j++)
			clrscaleName = StringFromList(j,clrscaleList)
			if (CmpStr(ReplaceString("cs_",clrscaleName,"cb_",0,1),cbName))
				continue
			endif
			scaleStr = StringByKey("COLORSCALE", AnnotationInfo(chdWinName,clrscaleName))
			n0 = strsearch(scaleStr,"ctab={",0)
			n1 = strsearch(scaleStr,"}",n0)
			name = StringFromList(2,scaleStr[n0+6,n1-1],",")
			return SelectString(CmpStr(name[0],":"),"root","")+name
		endfor
	endfor	
	return ""
End

//-----------------------------------------------------------------------
//	パネル表示時の初期カラーテーブル状態を保存する
//	imgName@ctab=***,rev=***,log=***,m0=***,r0=***,g0=***,b0=***,m1=***,r1=***,g1=***,b1=***;
//-----------------------------------------------------------------------
Static StrConstant MODEKEY = "SIDAMColorSettings"

Static Function saveImageColorInfo(String pnlName)
	
	String grfName = GetUserData(pnlName,"","grf")
	String imgList = ImageNameList(grfName,";"), imgName, str, name
	int i, n
	STRUCT RGBColor s
	
	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		imgName = StringFromList(i,imgList)
		str = ""
		
		name = WM_ColorTableForImage(grfName,imgName)
		if (strsearch(name,":",0) < 0)
			str += "ctab=" + name + ","
		else
			str += "ctab=" + GetWavesDataFolder($name,2) + ","
		endif
		str += "rev=" + num2istr(WM_ColorTableReversed(grfName,imgName)) + ","
		str += "log=" + num2istr(KM_ColorTableLog(grfName,imgName)) + ","
		
		int minMode = KM_ImageColorMinRGBMode(grfName,imgName)
		str += "m0=" + num2istr(minMode) + ","
		if (minMode == 1)	//	(r,g,b)
			KM_ImageColorMinRGBValues(grfName,imgName,s)
			str += "r0=" + num2istr(s.red) + ","
			str += "g0=" + num2istr(s.green) + ","
			str += "b0=" + num2istr(s.blue) + ","
		endif
		
		int maxMode = KM_ImageColorMaxRGBMode(grfName,imgName)
		str += "m1=" + num2istr(maxMode) + ","
		if (maxMode == 1)	//	(r,g,b)
			KM_ImageColorMaxRGBValues(grfName,imgName,s)
			str += "r1=" + num2istr(s.red) + ","
			str += "g1=" + num2istr(s.green) + ","
			str += "b1=" + num2istr(s.blue) + ","
		endif
		
		//	ctabにコロンが使われる可能性があるので、keySepStrは@を用いる
		SetWindow $pnlName userData($MODEKEY)=ReplaceStringByKey(imgName,GetUserData(pnlName,"",MODEKEY),str,"@")
	endfor
	
End


//******************************************************************************
//	フック関数
//******************************************************************************
//-------------------------------------------------------------
//	パネル用
//-------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)	
	switch (s.eventCode)
		case 0:	//	activate
			//	bug fix for issue #1
			String oldList = GetUserData(s.winName,"",MODEKEY), newList="", item
			int i, n0, n1
			for (i = 0; i < ItemsInList(oldList); i++)
				item = StringFromList(i,oldList)
				n0 = strsearch(item,"ctab=",0)
				n1 = strsearch(item,":ctable:",n1)
				newList += ReplaceString(item[n0+5,n1+7],item,SIDAM_DF_CTAB)+";"
			endfor
			SetWindow $s.winName userData($MODEKEY)=newList
			break
			
		case 2:	//	kill
			SetWindow $GetUserData(s.winName,"","grf") hook(KMColorPnl)=$""
			break
			
		case 11:	//	keyboard
			switch (s.keycode)
				case 27:	//	esc
					SetWindow $GetUserData(s.winName,"","grf") hook(KMColorPnl)=$""
					KillWindow $s.winName
					break
				case 28:	//	left
				case 29:	//	right
				case 30:	//	up
				case 31:	//	down
					pnlHookArrows(s.winName, s.keycode)
					break
			endswitch
			break
			
		case 22:	//	mouseWheel
			//	マウスポインタがタブ内に入っている時には、表示タブを変更する
			pnlHookWheel(s)
			break
	endswitch
End

Static Function pnlHookArrows(String pnlName, int keycode)
	//	get selected tab and checkbox
	Variable tab0, box0
	String list = ControlNameList(pnlName,";","cb_*")
	Wave cw = KMGetCtrlValues(pnlName,list)
	WaveStats/Q/M=1 cw
	if (V_max)
		sscanf StringFromList(V_maxloc,list), "cb_%d_%d", tab0, box0
	else	//	no checkbox is checked
		return 0
	endif
	int isInLeftColumn = box0 < ctabsInColumn
	
	//	get new tab and checkbox
	Variable tab1, box1
	switch (keycode)
		case 28:	//	left
			tab1 = isInLeftColumn ? tab0-1 : tab0
			if (isInLeftColumn)
				box1 = box0 + ctabsInColumn*bothColumnsExist(pnlName,tab1)
			else
				box1 = box0 - ctabsInColumn
			endif
			break
		case 29:	//	right
			tab1 = !isInLeftColumn || !bothColumnsExist(pnlName,tab0) ? tab0+1 : tab0
			if (isInLeftColumn)
				box1 = box0 + ctabsInColumn*bothColumnsExist(pnlName,tab0)
			else
				box1 = box0 - ctabsInColumn
			endif
			break
		case 30:	//	up
			tab1 = tab0
			box1 = box0 - (mod(box0,ctabsInColumn)!=0)
			break
		case 31:	//	down
			tab1 = tab0
			box1 = box0 + (mod(box0,ctabsInColumn)!=ctabsInColumn-1)
	endswitch
	
	if (tab1 < 0 || tab1 > ItemsInList(SIDAM_CTABGROUPS))
		return 0
	endif
	box1 = limit(box1,0,ItemsInList(ControlNameList(pnlName,";","cb_"+num2istr(tab1)+"_*"))-1)
	
	if (tab1 == tab0 && box1 == box0)
		return 0
	endif
		
	String cbName = "cb_"+num2istr(tab1)+"_"+num2istr(box1)
	KMClickCheckBox(pnlName, cbName)
	clickTab(pnlName, tab1)
End

Static Function bothColumnsExist(String pnlName, int tab)
	if (tab < 0 || tab > ItemsInList(SIDAM_CTABGROUPS))
		return 0
	else
		return ItemsInList(ControlNameList(pnlName,";","cb_"+num2istr(tab)+"_*")) > ctabsInColumn
	endif
End

Static Function pnlHookWheel(STRUCT WMWinHookStruct &s)
	String pnlName = s.winName
	if (ItemsInList(pnlName,"#") == 3)	//	ポインタがカラースケール表示のサブウインドウ内にある場合
		pnlName = RemoveEnding(RemoveListItem(2,pnlName,"#"),"#")
	endif
	ControlInfo/W=$pnlName mTab
	if (s.mouseLoc.h < V_left || s.mouseLoc.h > V_left+V_Width || s.mouseLoc.v < V_top || s.mouseLoc.v > V_top+V_Height)
		return 0
	endif
	int newTab = V_Value-sign(s.wheelDy)		//	下向きに回すと右のタブへ移動
	if (newTab >= 0 && newTab <= ItemsInList(SIDAM_CTABGROUPS))
		clickTab(pnlName, newTab)
	endif
End

//-------------------------------------------------------------
//	親ウインドウ用
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	//	modified だけを扱う
	if (s.eventCode != 8)
		return 0
	endif
	
	//	パネルで選択されているイメージのカラーテーブルが変更された場合に備えて、
	//	イメージのカラーテーブルの現状をパネルに反映する
	String pnlName = s.winName + "#Color"
	ControlInfo/W=$pnlName imageP
	String imgName = S_Value
	
	//	現在選択されているカラーテーブルに対応するタブを開く
	clickTab(pnlName, findTabForPresentCtab(s.winName, imgName))
	
	//	現在選択されているカラーテーブルに対応するチェックボックスを1にする
	selectCheckBox(pnlName, findCheckBox(pnlName,imgName))
	
	//	rev, log, mixRGB, maxRGBに関するコントロールの状態を更新
	updateOptionControls(pnlName,imgName)
End


//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	タブ
//-------------------------------------------------------------
Static Function pnlTab(STRUCT WMTabControlAction &s)
	if (s.eventCode == 2)
		clickTab(s.win, s.tab)
	endif
	return 0
End

//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode == -1)
		return 0
	endif
	
	//	同じグループに属する他のチェックボックスは0にする
	if (CmpStr(s.ctrlName,"revC") && CmpStr(s.ctrlName,"logC"))
		selectCheckBox(s.win, s.ctrlName)
	endif
	
	//	以下、各チェックボックスごとの動作
	String grfName = GetUserData(s.win,"","grf")
	String imgList = targetImageList(s.win)
	strswitch (s.ctrlName)
		case "revC":
			KMColor(grfName=grfName, imgList=imgList, rev=s.checked)
			updateColorscales(s.win)
			break
		case "logC":
			KMColor(grfName=grfName, imgList=imgList, log=s.checked)
			updateColorscales(s.win)
			break
		case "beforeUseC":
			KMColor(grfName=grfName, imgList=imgList, minRGB={0})
			break
		case "beforeClrC":
			ControlInfo/W=$s.win beforeClrP
			KMColor(grfName=grfName, imgList=imgList, minRGB={V_Red,V_Green,V_Blue})
			break
		case "beforeTransC":
			KMColor(grfName=grfName, imgList=imgList, minRGB={NaN})
			break
		case "lastUseC":
			KMColor(grfName=grfName, imgList=imgList, maxRGB={0})
			break
		case "lastClrC":
			ControlInfo/W=$s.win lastClrP
			KMColor(grfName=grfName, imgList=imgList, maxRGB={V_Red,V_Green,V_Blue})
			break
		case "lastTransC":
			KMColor(grfName=grfName, imgList=imgList, maxRGB={NaN})
			break
		default:	//	"cb_*"
			KMColor(grfName=grfName, imgList=imgList, ctable=findColorScale(s.win,s.ctrlName))
	endswitch
	
	return 0
End

//-------------------------------------------------------------
//	allCがクリックされた場合の動作
//		チェックが入れられたときは、パネルの内容をすべてのイメージに反映
//		チェックが外されたときは、imagePの状態を変えただけで終了
//-------------------------------------------------------------
Static Function pnlCheckAllC(STRUCT  WMCheckboxAction &s)
	
	if (s.eventCode == -1)
		return 0
	endif
	
	PopupMenu imageP disable=s.checked*2, win=$s.win
	
	//	チェックが外されたときは以降の動作は不要
	if (!s.checked)
		return 0
	endif
	
	String grfName = GetUserData(s.win,"","grf")
	String imgList = ImageNameList(grfName,";")
	
	String cbList = ControlNameList(s.win,";","cb_*")
	Wave cw = KMGetCtrlValues(s.win, cbList)
	cw *= p
	String cbName = StringFromList(sum(cw),cbList)	//	チェックが入っているチェックボックスの名前
	String ctable = findColorScale(s.win,cbName)
	
	ControlInfo/W=$s.win revC
	int rev = V_Value
	
	ControlInfo/W=$s.win logC
	int log = V_Value
	
	Wave cw = KMGetCtrlValues(s.win, "beforeUseC;beforeClrC;beforeTransC")
	cw *= p
	switch (sum(cw))
		case 0:
			Make/FREE minRGB={0}
			break
		case 1:
			ControlInfo/W=$s.win beforeClrP
			Make/FREE minRGB={V_Red,V_Green,V_Blue}
			break
		case 2:
			Make/FREE minRGB={NaN}
			break
	endswitch
	
	Wave cw = KMGetCtrlValues(s.win, "lastUseC;lastClrC;lastTransC")
	cw *= p
	switch (sum(cw))
		case 0:
			Make/FREE maxRGB={0}
			break
		case 1:
			ControlInfo/W=$s.win lastClrP
			Make/FREE maxRGB={V_Red,V_Green,V_Blue}
			break
		case 2:
			Make/FREE maxRGB={NaN}
			break
	endswitch
		
	KMColor(grfName=grfName,imgList=imgList,ctable=ctable,rev=rev,log=log,minRGB=minRGB,maxRGB=maxRGB)
End

//-------------------------------------------------------------
//	ポップアップメニュー
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode == -1)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "imageP":
			//	選択されたイメージのカラーテーブルに対応するチェックボックスを1にする
			String cbName = findCheckBox(s.win,s.popStr)
			selectCheckBox(s.win, cbName)
			
			//	上のチェックボックスが属するタブをアクティブにする
			clickTab(s.win, str2num(StringFromList(1,cbName,"_")))
			
			//	rev, log, mixRGB, maxRGBに関するコントロールの状態を更新
			updateOptionControls(s.win,s.popStr)
			break
			
		case "beforeClrP":
		case "lastClrP":
			//	対応してカラーテーブルを変更する
			String grfName = GetUserData(s.win,"","grf")
			String imgList = targetImageList(s.win)
			int red, green, blue
			sscanf s.popStr, "(%d,%d,%d)", red, green, blue
			if (stringmatch(s.ctrlName,"beforeClrP"))
				KMColor(grfName=grfName,imgList=imgList, minRGB={red,green,blue})
			else
				KMColor(grfName=grfName,imgList=imgList, maxRGB={red,green,blue})
			endif
			break
	endswitch
End

//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch (s.ctrlName)
		case "cancelB":
			//	パネルを開いた時の元の状態に戻す
			restoreImageColor(s.win)
			//	*** FALLTHROUGH ***
		case "doB":
			KillWindow $(s.win)
			DoUpdate/W=$StringFromList(0,s.win,"#")
			DoWindow/F $StringFromList(0,s.win,"#")
			break
		default:
	endswitch
	
	return 0
End


//******************************************************************************
//	パネルコントロール補助関数
//******************************************************************************
//-------------------------------------------------------------
//	imagePの内容を与える
//-------------------------------------------------------------
Static Function/S imageListForImageP()
	String pnlName = GetUserData(WinName(0,1)+"#Color","","grf")
	return ImageNameList(pnlName, ";")
End

//-------------------------------------------------------------
//	allCの選択状態に合わせて、操作対象となるイメージのリストを返す
//-------------------------------------------------------------
Static Function/S targetImageList(String pnlName)
	String grfName = GetUserData(pnlName,"","grf")
	ControlInfo/W=$pnlName allC
	if (V_Value)
		return ImageNameList(grfName,";")
	else
		ControlInfo/W=$pnlName imageP
		return S_Value
	endif
End

//-------------------------------------------------------------
//	タブをクリックしたときの動作
//-------------------------------------------------------------
Static Function clickTab(String pnlName, int tab)
	TabControl mTab value=tab, win=$pnlName
	
	int i, n
	
	for (i = 0, n = getNumberOfTabs(pnlName, "mTab"); i < n; i++)
		SetWindow $pnlName#$("G_"+num2istr(i)+"_0") hide=(i!=tab)
		SetWindow $pnlName#$("G_"+num2istr(i)+"_1") hide=(i!=tab)
	endfor
	
	ModifyControlList ControlNameList(pnlName, ";", "cb_*") disable=1, win=$pnlName
	ModifyControlList ControlNameList(pnlName, ";", "cb_"+num2istr(tab)+"*") disable=0, win=$pnlName
	
	DoUpdate/W=$pnlName	//	これを入れないと表示が乱れることがある
End

//-------------------------------------------------------------
//	タブの個数
//-------------------------------------------------------------
Static Function getNumberOfTabs(String pnlName, String ctrlName)
	ControlInfo/W=$pnlName $ctrlName
	int v0 = strsearch(S_recreation,"tabLabel(",Inf,1)
	int v1 = strsearch(S_recreation,")",v0)
	return str2num(S_recreation[v0+9,v1-1])+1
End

//-------------------------------------------------------------
//	rev, log, mixRGB, maxRGBに関するコントロールの状態を選択されたイメージに
//	対応するように更新する
//-------------------------------------------------------------
Static Function updateOptionControls(String pnlName, String imgName)
	String grfName = GetUserData(pnlName,"","grf")
	CheckBox revC value=WM_ColorTableReversed(grfName,imgName),win=$pnlName
	CheckBox logC value=KM_ColorTableLog(grfName,imgName),win=$pnlName
	
	int minMode = KM_ImageColorMinRGBMode(grfName,imgName)
	STRUCT RGBColor s
	KM_ImageColorMinRGBValues(grfName,imgName,s)
	CheckBox beforeUseC value=(minMode==0),win=$pnlName
	CheckBox beforeClrC value=(minMode==1),win=$pnlName
	CheckBox beforeTransC value=(minMode==2),win=$pnlName
	PopupMenu beforeClrP popColor=(s.red,s.green,s.blue),win=$pnlName
	
	int maxMode = KM_ImageColorMaxRGBMode(grfName,imgName)
	KM_ImageColorMaxRGBValues(grfName,imgName,s)
	CheckBox lastUseC value=(maxMode==0),win=$pnlName
	CheckBox lastClrC value=(maxMode==1),win=$pnlName
	CheckBox lastTransC value=(maxMode==2),win=$pnlName
	PopupMenu lastClrP popColor=(s.red,s.green,s.blue),win=$pnlName
	
	updateColorscales(pnlName)
End

//-------------------------------------------------------------
//	rev, log のコントロールの状態を表示されているカラースケールに反映する
//-------------------------------------------------------------
Static Function updateColorscales(String pnlName)
	//	e.g., pnlName = Graph0#Color
	Wave cw = KMGetCtrlValues(pnlName,"revC;logC")
	String columnList = ChildWindowList(pnlName), column
	String csNameList, csName, cbName, ctabName

	int i, j

	for (i = 0; i < ItemsInList(columnList); i++)
		column = StringFromList(i,columnList)
		csNameList = AnnotationList(pnlName+"#"+column)
		for (j = 0; j < ItemsInList(csNameList); j++)
			csName = StringFromList(j,csNameList)			//	e.g., cs_0_0
			cbName = ReplaceString("cs",csName,"cb")		//	e.g., cb_0_0
			ctabName = findColorScale(pnlName,cbName)
			ColorScale/W=$(pnlName+"#"+column)/C/N=$csName ctab={0,100,$ctabName,cw[0]}, log=cw[1]
		endfor
	endfor	
End

//-------------------------------------------------------------
//	指定されたチェックボックスの値を1にし、同じグループに属する他のチェックボックスの値を0にする
//-------------------------------------------------------------
Static Function selectCheckBox(String pnlName, String ctrlName)
	if (!strlen(ctrlName))
		return 0
	endif
	CheckBox $ctrlName value=1, win=$pnlName
	
	String ctrlList = ""
	if (stringmatch(ctrlName,"cb_*"))
		ctrlList = ControlNameList(pnlName,";","cb_*")
	elseif (stringmatch(ctrlName,"before*C"))
		ctrlList = ControlNameList(pnlName,";","before*C")
	elseif (stringmatch(ctrlName,"last*C"))
		ctrlList = ControlNameList(pnlName,";","last*C")
	endif
	ctrlList = RemoveFromList(ctrlName,ctrlList)
	
	int i, n = ItemsInList(ctrlList)
	for (i = 0; i < n; i++)
		Checkbox $StringFromList(i,ctrlList) value=0, win=$pnlName
	endfor
End

//-------------------------------------------------------------
//	パネルを開いた時の元の状態に戻す
//-------------------------------------------------------------
Static Function restoreImageColor(String pnlName)
	
	String grfName = GetUserData(pnlName,"","grf")
	String initList = GetUserData(pnlName,"",MODEKEY)
	
	int i, n
	for (i = 0, n = ItemsInList(initList); i < n; i++)
		String initStr = StringFromList(i,initList)
		String imgName = StringFromList(0,initStr,"@")
		String info = StringFromList(1,initStr,"@")
		String ctab = StringByKey("ctab",info,"=",",")
		int rev = NumberByKey("rev",info,"=",",")
		int log = NumberByKey("log",info,"=",",")
		switch (NumberByKey("m0",info,"=",","))
			case 0:
				Make/FREE minRGB = {0}
				break
			case 1:
				Make/FREE minRGB = {NumberByKey("r0",info,"=",","),NumberByKey("g0",info,"=",","),NumberByKey("b0",info,"=",",")}
				break
			case 2:
				Make/FREE minRGB = {NaN}
				break
		endswitch
		switch (NumberByKey("m1",info,"=",","))
			case 0:
				Make/FREE maxRGB = {0}
				break
			case 1:
				Make/FREE maxRGB = {NumberByKey("r1",info,"=",","),NumberByKey("g1",info,"=",","),NumberByKey("b1",info,"=",",")}
				break
			case 2:
				Make/FREE maxRGB = {NaN}
				break
		endswitch
		KMColor(grfName=grfName,imgList=imgName,ctable=ctab,rev=rev,log=log,minRGB=minRGB,maxRGB=maxRGB)
	endfor
End

//=====================================================================================================
//	カラーテーブル読み込みに関する関数
//=====================================================================================================
//-----------------------------------------------------------------------
//	すべてのカラーテーブルウエーブファイルを読み込む
//-----------------------------------------------------------------------
Static Function loadColorTableWaves()
	
	int i, n
	String all = ""
	
	//	ctabフォルダ以下
	String path0 = SIDAMPath() + SIDAM_FOLDER_COLOR + ":"
	for (i = 0, n = ItemsInList(SIDAM_CTABGROUPS); i < n; i++)
		all += ctabWavePathList(path0+StringFromList(i,SIDAM_CTABGROUPS))
	endfor
	
	for (i = 0, n = ItemsInList(all); i < n; i++)
		//	loadColorTableWave中で使われているLoadWaveによって新しいパスが作られる。
		//	loadColorTableWaveはそのパス名を返すので、削除する。
		String pathName = loadColorTableWave(StringFromList(i,all))
		KillPath/Z $pathName
	endfor
	
End

//-----------------------------------------------------------------------
//	カラーテーブルウエーブのibwファイルを読みこむ。読み込んだウエーブは一時データフォルダ内へ保存する。
//	ibwFilePath = ***:User Procedures:SIDAM:ctab:NistView:Autumn.ibw
//	の場合、ウエーブは
//	root:Packages:SIDAM:ctable:NistView:Autumn
//	となる。
//-----------------------------------------------------------------------
Static Function/S loadColorTableWave(String ibwFilePath)
	
	//	ibwFilePath = ***:User Procedures:SIDAM:ctab:NistView:Autumn.ibw
	//	colorFDpath = ***:User Procedures:SIDAM:ctab
	//	wPath       = :NistView:Autumn.ibw
	String colorFDpath = SIDAMPath() + SIDAM_FOLDER_COLOR
	String wPath = ReplaceString(colorFDpath, ibwFilePath, "")
	
	//	既に読み込まれたものがあれば、終了
	Wave/Z ctabw = $(RemoveEnding(SIDAM_DF_CTAB,":")+wPath)
	if (WaveExists(ctabw))
		return ""
	endif
	
	DFREF dfrSav = GetDataFolderDFR()
	int i, n
	
	//	カラーテーブルウエーブを収めるデータフォルダを作る
	SetDataFolder root:
	//	root:Packages:SIDAM:ctable　まで作成
	for (i = 1, n = ItemsInList(SIDAM_DF_CTAB,":"); i < n; i++)
		NewDataFolder/O/S $ReplaceString("'",StringFromLIst(i,SIDAM_DF_CTAB,":"),"")
	endfor
	//	ctable以下を作成
	for (i = 1, n = ItemsInList(wPath,":"); i < n-1; i++)	//	wPathは : から始まるので最初は除外する。最後はファイル名なのでやはり除外する。
		NewDataFolder/O/S $StringFromList(i,wPath,":")
	endfor
	
	//	ウエーブ読み込み
	LoadWave/H/O/Q ibwFilePath
	
	SetDataFolder dfrSav
	
	//	LoadWaveで作られたパス名を返す
	return CleanupName(ParseFilePath(0, S_path, ":", 1, 0),0)
End

//-----------------------------------------------------------------------
//	pathStrフォルダ以下(サブフォルダを含む)にある全てのカラーテーブルウエーブへの絶対パスリストを返す
//-----------------------------------------------------------------------
Static Function/S ctabWavePathList(String pathStr)
	
	String pathName = UniqueName("path", 12, 0)
	NewPath/Q/Z $pathName, pathStr
	
	int i, n
	String rtnStr = ""
	
	String folderList = IndexedDir($pathName, -1, 1), tmpStr
	for (i = 0, n = ItemsInList(folderList); i < n; i++)
		tmpStr = ctabWavePathList(StringFromList(i, folderList))
		rtnStr += SelectString(strlen(tmpStr), "", tmpStr)
	endfor
	
	String fileList = IndexedFile($pathName, -1, ".ibw"), fileName
	for (i = 0, n = ItemsInList(fileList); i < n; i++)
		fileName = StringFromList(i, fileList)
		if (isCtabWave(pathName, fileName))
			rtnStr += pathStr+":"+fileName + ";"
		endif
	endfor	
	
	KillPath $pathName
	
	return rtnStr
End

//-----------------------------------------------------------------------
//	ibwファイルの先頭を読み込んで、カラーテーブルウエーブであるかどうかを判定する
//-----------------------------------------------------------------------
Static Function isCtabWave(String pathName, String wName)
	
	Variable refNum
	Open/R/P=$pathName refNum, as wName
	
	Variable var
	FBinRead/F=1 refNum, var		//	最初の1バイトが 0 なら big-endian, 0 でないなら little-endian
	Variable endian = var ? 3 : 2
	
	STRUCT WaveHeader5 s
	FSetPos refNum, 0
	FBinRead/B=(endian) refNum, s
	
	Close refNum
	
	//	type が 80 (0x10 : 16 bit integer, 0x40 : unsigned)
	//	2次元ウエーブで、2次元目の大きさは 3
	return (s.type & (0x10 + 0x40)) && s.nDim[1] == 3 && s.nDim[2] == 0 && s.nDim[3] == 0
End
//	Igorバイナリのフォーマットの必要部分
Static Constant MAXDIMS = 4
Static Constant MAX_WAVE_NAME5 = 31
Static Structure WaveHeader5
	char space[80]
	int16 type				// See types (e.g. NT_FP64) above. Zero for text waves.
	char space2[50]
	int32 nDim[MAXDIMS]		// Number of of items in a dimension -- 0 means no data.
EndStructure


//-----------------------------------------------------------------------
//	使われていないウエーブをすべて削除する
//-----------------------------------------------------------------------
//	SIDAM_DF_CTAB以下の使われていないウエーブを削除する
Static Function killUnusedWaves()
	
	//	SIDAM_DF_CTAB が存在していなければ何もする必要がなく、終了
	if (!DataFolderExists(SIDAM_DF_CTAB))
		return 0
	endif
	
	//	SIDAM_DF_CTAB　以下の使われていないウエーブ・データフォルダを削除する
	killUnusedWavesHelper($SIDAM_DF_CTAB)
	
	//	SIDAM_DF_CTAB 以下に使われているデータフォルダが残っていなければ SIDAM_DF_CTAB を削除して、終了
	if (!CountObjectsDFR($SIDAM_DF_CTAB,4))
		KillDataFolder $SIDAM_DF_CTAB
		//	SIDAM_DF_CTAB を削除した結果 SIDAM_DF 以下にデータフォルダが含まれないようになったら SIDAM_DF を削除する
		if (!CountObjectsDFR($SIDAM_DF,4))
			KillDataFolder $SIDAM_DF
		endif
		return 0
	endif
	
	//	SIDAM_DF_CTAB 以下にデータフォルダが残っている、つまり、使われているウエーブが残っている場合には、
	//	次回にカラーテーブルを選ぶパネルを開くときにウエーブを読み込む必要があるフラグを残しておく
	NVAR/SDFR=$SIDAM_DF_CTAB/Z needUpdate
	if (NVAR_Exists(needUpdate))
		needUpdate = 1
	else
		Variable/G $(SIDAM_DF_CTAB+"needUpdate") = 1
	endif
End

Static Function killUnusedWavesHelper(DFREF dfr)
	int i, n
	DFREF dfrSav = GetDataFolderDFR()
	SetDataFolder dfr
	
	//	カレントデータフォルダにある使われていないウエーブをすべて削除する
	KillWaves/A/Z
	
	//	カレントデータフォルダにあるデータフォルダを可能ならば削除する
	//	使われているウエーブを含むデータフォルダが残る
	for (i = CountObjectsDFR(dfr,4)-1; i >= 0; i--)
		KillDataFolder/Z $GetIndexedObjNameDFR(dfr,4,i)
	endfor
	
	//	使われているウエーブを含むデータフォルダに対しこの関数を再帰的に実行する
	for (i = 0, n = CountObjectsDFR(dfr,4); i < n; i++)
		killUnusedWavesHelper($GetIndexedObjNameDFR(dfr,4,i))
	endfor
	
	SetDataFolder dfrSav
End


//=====================================================================================================
//	後方互換性
//	rev. 944への変更に伴いカラーインデックスウエーブをカラーテーブルウエーブへ変換する
//=====================================================================================================
Static Function cindexWave2ctabWave()
	
	//	旧バージョンではこの3つ
	String list0 = fetchWavepathList($(SIDAM_DF_CTAB+"SIDAM"))
	String list1 = fetchWavepathList($(SIDAM_DF_CTAB+"NistView"))
	String list2 = fetchWavepathList($(SIDAM_DF_CTAB+"Wolfram"))
	String ctabWaveList = list0 + ";" + list1 + ";" + list2
	
	String winNameList = WinList("*",";","WIN:1")
	int i, j, k, ni, nj, nk
	
	for (i = 0, ni = ItemsInList(winNameList); i < ni; i++)
		
		String win = StringFromList(i,winNameList)
		String imgList = ImageNameList(win,";")
		
		for (j = 0, nj = ItemsInList(imgList); j < nj; j++)
			
			String imgName = StringFromList(j,imgList)
			Wave/Z cindexw = $WM_ImageColorIndexWave(win,imgName)
			if (!WaveExists(cindexw))
				continue
			endif
			String ctabName = StringByKey("name",note(cindexw))
			
			for (k = 0, nk = ItemsInList(ctabWaveList); k < nk; k++)
				
				String ctabWavePath = StringFromList(k,ctabWaveList)
				if (CmpStr(ParseFilePath(0,ctabWavePath,":",1,0),ctabName))
					continue
				endif
				
				//	以下、新形式への変換
				int rev = NumberByKey("rev",note(cindexw)) & 1	//	逆順のみ扱う、反転は扱わない
				KMColor(grfName=win,imgList=imgName,ctable=ctabWavePath,rev=rev)
				
				//	他に使われていなければ削除する
				CheckDisplayed/A cindexw
				if (!V_flag)
					KillWaves cindexw
				endif
				
			endfor
		endfor
	endfor
End

//=====================================================================================================
//	http://www.paraview.org/Wiki/Colormaps にあるxmlファイルをウエーブに読み込むための関数
//=====================================================================================================
//Function xml2ibw()
//	Variable refNum
//	Open/R refNum
//	if (!refNum)
//		return 0
//	endif
//	
//	String buffer, name
//	
//	do
//		FReadLine refNum, buffer
//		if (!strlen(buffer))
//			break
//		elseif (strsearch(buffer, "<ColorMap ",0)>=0)
//			name = StringByKey("name", buffer,"="," ")
//			name = CleanupName(name[1,strlen(name)-2],1)
//			if (WaveExists($name))
//				print name
//				Duplicate xml2wave(refNum) $UniqueName(name,1,0)
//			else
//				Duplicate xml2wave(refNum) $name
//			endif
//		endif
//	while(1)
//	
//	Close refNum
//End
//
//Static Function/WAVE xml2wave(Variable refNum)
//	String buffer
//	int n
//	
//	Make/N=0/FREE xw, rw, gw, bw
//	do
//		FReadLine refNum, buffer
//		if (strsearch(buffer,"</ColorMap>",0)>=0)
//			break
//		endif
//		Redimension/N=(numpnts(xw)+1) xw, rw, gw, bw
//		xw[inf] = getValue("x", buffer)
//		rw[inf] = getValue("r", buffer)
//		gw[inf] = getValue("g", buffer)
//		bw[inf] = getValue("b", buffer)
//	while(1)
//	
//	Make/N=(numpnts(xw))/FREE rw2, gw2, bw2
//	Setscale/I x WaveMin(xw), WaveMax(xw), "", rw2, gw2, bw2
//	Interpolate2/T=1/Y=rw2/I=3 xw,rw
//	Interpolate2/T=1/Y=gw2/I=3 xw,gw
//	Interpolate2/T=1/Y=bw2/I=3 xw,bw
//	
//	Make/W/U/N=(numpnts(xw),3)/FREE rtnw
//	rtnw[][0] = round(rw2[p]*65535)
//	rtnw[][1] = round(gw2[p]*65535)
//	rtnw[][2] = round(bw2[p]*65535)
//	return rtnw
//End
//
//Static Function getValue(String key, String buffer)
//	String str = StringByKey(key, buffer, "=", " ")
//	return str2num(str[1,strlen(str)-2])
//End