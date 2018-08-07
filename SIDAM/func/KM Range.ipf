#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=KMRange

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

#include <WMImageInfo>

Static Constant k_bins = 36			//  ヒストグラムのbin数
Static StrConstant ks_name = "hist"	//	パネルで用いるヒストグラムウエーブの名前


//******************************************************************************
//	KMRange
//******************************************************************************
Function KMRange([grfName, imgList, zmin, zmax, zminmode, zmaxmode, history])
	String grfName			//	表示されているグラフの名前、省略時は一番上のグラフ
	String imgList			//	対象とするイメージの名前のリスト、省略時は grfName にあるイメージ全て (ImageNameList(grfName,";"))
	int zminmode, zmaxmode	//	z範囲の値のモード, 0: auto, 1: fix, 2: sigma, 3: cut, 省略時は1
	Variable zmin, zmax		//	カラースケールのz範囲の最低値・最高値、省略時はモードによって値が異なる
								//	モード0,1: NaN, 2: -3/3, 3: 0.5/99.5
	int history				//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	
	//	パラメータのチェック
	STRUCT paramStruct s
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.imgList = SelectString(ParamIsDefault(imgList), imgList, ImageNameList(s.grfName,";"))
	s.zminmode = ParamIsDefault(zminmode) ? 1 : zminmode
	s.zmaxmode = ParamIsDefault(zmaxmode) ? 1 : zmaxmode
	
	//	zmin, zmaxが省略されていたらパネル表示
	if (!isValidArguments(s))
		print s.errMsg
		return 1
	elseif (ParamIsDefault(zmin) && ParamIsDefault(zmax))
		pnl(s.grfName)
		return 0
	endif
	
	//	履歴欄出力
	if (!ParamIsDefault(history) && history == 1)
		String paramStr = "grfName=\"" + s.grfName + "\""
		paramStr += ",imgList=\"" + s.imgList + "\""
		paramStr += SelectString(ParamIsDefault(zmin), ",zmin="+num2str(zmin), "")
		paramStr += SelectString(ParamIsDefault(zmax), ",zmax="+num2str(zmax), "")
		paramStr += SelectString(ParamIsDefault(zminmode), ",zminmode="+num2istr(s.zminmode), "")
		paramStr += SelectString(ParamIsDefault(zmaxmode), ",zmaxmode="+num2istr(s.zmaxmode), "")
		printf "%sKMRange2(%s)\r", PRESTR_CMD, paramStr
	endif
	
	//	zminmode, zmaxmodeの値に応じたzmin, zmaxのデフォルト値の設定
	if (ParamIsDefault(zmin))
		Make/D/N=4/FREE tw0 = {NaN, NaN, -3, 0.5}
		zmin = tw0[s.zminmode]
	endif
	
	if (ParamIsDefault(zmax))
		Make/D/N=4/FREE tw1 = {NaN, NaN, 3, 99.5}
		zmax = tw1[s.zmaxmode]
	endif
		
	//	実行
	if (s.zminmode <= 1 && s.zmaxmode <= 1)	//	共に auto もしくは fix
		
		int i, n
		for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
			applyZRange(s.grfName,StringFromList(i,s.imgList), zmin, zmax)
		endfor
		
	else	//	片方でも sigma もしくは cut の場合
		
		if (s.zminmode >= 2)
			setZmodeValue(s.grfName, s.imgList, "m0", s.zminmode)
			setZmodeValue(s.grfName, s.imgList, "v0", zmin)
		endif
		if (s.zmaxmode >= 2)
			setZmodeValue(s.grfName, s.imgList, "m1", s.zmaxmode)
			setZmodeValue(s.grfName, s.imgList, "v1", zmax)
		endif
		//	設定内容に応じて更新したのちに、フック関数を設定しておく
		updateZRange(s.grfName)
		SetWindow $s.grfName hook(KMRangePnl)=KMRange#pnlHookParent
		
	endif
End
//-------------------------------------------------------------
//	isValidArguments : チェック用関数
//-------------------------------------------------------------
Static Function isValidArguments(STRUCT paramStruct &s)
	
	s.errMsg = PRESTR_CAUTION + "KMRange gave error: "
	
	if (!strlen(s.grfName))
		s.errMsg += "graph not found."
		return 0
	elseif (!KMWindowExists(s.grfName))
		s.errMsg += "an window named \"" + s.grfName + "\" is not found."
		return 0
	elseif (!strlen(ImageNameList(s.grfName,";")))
		s.errMsg += s.grfName + " has no image."
		return 0
	endif
	
	String list = ImageNameList(s.grfName,";")
	int i, n
	for (i = 0, n = ItemsInList(s.imgList); i < n; i++)
		if (WhichListItem(StringFromList(i,s.imgList),list) < 0)
			s.errMsg += "an image named \"" + StringFromList(i,s.imgList) + "\" is not found."
			return 0
		endif
	endfor
	
	if (s.zminmode < 0 || s.zminmode > 3)
		s.errMsg += "zminmode must be an integer between 0 and 3."
		return 0
	endif
	
	if (s.zmaxmode < 0 || s.zmaxmode > 3)
		s.errMsg += "zmaxmode must be an integer between 0 and 3."
		return 0
	endif
	
	return 1
End

Static Structure paramStruct
	String	grfName
	String	imgList
	uchar	zminmode
	uchar	zmaxmode
	String	errMsg
EndStructure

//******************************************************************************
//	applyZRange
//		実際に first z, last z を設定する関数
//		zmin, zmax に NaN が渡された場合は auto に対応する
//******************************************************************************
Static Function applyZRange(String grfName, String imgName, Variable zmin, Variable zmax)
	
	String cindexStr = WM_ImageColorIndexWave(grfName,imgName)
	
	if (strlen(cindexStr))	//  インデックスウエーブが使われている場合
		
		Wave tw = KMGetImageWaveRef(grfName, imgName=imgName, displayed=1)
		zmin = (numtype(zmin) == 2) ? WaveMin(tw) : zmin
		zmax = (numtype(zmax) == 2) ? WaveMin(tw) : zmax
		SetScale/I x zmin, zmax, "", $cindexStr
		
	else		//  カラーテーブルが使われている場合
	
		String ctab = WM_ColorTableForImage(grfName, imgName)
		Variable rev = WM_ColorTableReversed(grfName, imgName)
		if (numtype(zmin)==2 && numtype(zmax)==2)
			ModifyImage/W=$grfName $imgName ctab={*,*,$ctab,rev}
		elseif (numtype(zmin)==2)
			ModifyImage/W=$grfName $imgName ctab={*,zmax,$ctab,rev}
		elseif (numtype(zmax)==2)
			ModifyImage/W=$grfName $imgName ctab={zmin,*,$ctab,rev}
		else
			ModifyImage/W=$grfName $imgName ctab={zmin,zmax,$ctab,rev}
		endif
		
	endif
End

//=====================================================================================================
//	右クリックメニューに関して
//=====================================================================================================
//-------------------------------------------------------------
//	右クリックメニューで表示される文字列
//-------------------------------------------------------------
Static Function/S rightclickMenu(int mode)	//	mode 2: sigma, 3, cut
	
	String grfName = WinName(0,1)
	String menuStr = "3\u03c3;0.5%", checkmark = "!"+num2char(18)
	return SelectString(isAllImagesInMode(grfName, mode), "",checkmark) + StringFromList(mode-2,menuStr)
	
End

//-------------------------------------------------------------
//	右クリックメニューから実行される関数
//-------------------------------------------------------------
Static Function rightclickDo(int mode)	//	mode 2: sigma, 3, cut
	
	String grfName = WinName(0,1)
	if (isAllImagesInMode(grfName, mode))	//	メニュー文字列にはチェックマークが入っている状態
		deleteZmodeValues(grfName)
		SetWindow $grfName hook(KMRangePnl)=$""		
	elseif (mode==2)
		KMRange(imgList=ImageNameList("",";"),zminmode=2,zmin=-3,zmaxmode=2,zmax=3)
	elseif (mode==3)
		KMRange(imgList=ImageNameList("",";"),zminmode=3,zmin=0.5,zmaxmode=3,zmax=99.5)
	endif
End

//-------------------------------------------------------------
//	表示されているイメージのすべてが"3sigma"または"0.5%"のモードであれば1を返す
//-------------------------------------------------------------
Static Function isAllImagesInMode(String grfName, int mode)	//	mode 2: sigma, 3, cut
	
	String imgList = ImageNameList(grfName,";"), imgName
	Variable m0, m1, v0, v1
	int i, n
	
	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		
		imgName = StringFromList(i,imgList)
		m0 = getZmodeValue(grfName, imgName, "m0")
		m1 = getZmodeValue(grfName, imgName, "m1")
		if (m0!=mode || m1!=mode)
			return 0
		endif
		//	mode は 2 または 3　で呼ばれるので、以下は m0=m1=2 または m0=m1=3 の場合のみ
		//	上記の m0, m1 に関するチェックをしないで以下を直接調べると、KM_GetColorTableMinMax が呼ばれて
		//	複素数ウエーブの時に不要な速度低下をもたらすことに注意
		v0 = getZmodeValue(grfName, imgName, "v0")
		v1 = getZmodeValue(grfName, imgName, "v1")
		if (mode==2 && !(v0==-3 && v1==3))
			return 0
		elseif (mode==3 && !(v0==0.5 && v1==99.5))
			return 0
		endif
		
	endfor
	
	return 1
End


//=====================================================================================================
//	パネルに関して
//=====================================================================================================
Static Constant CTRLHEIGHT = 170
Static Constant PNLHEIGHT = 295
Static Constant PNLWIDTH = 265

//******************************************************************************
//	パネル表示
//******************************************************************************
Static Function pnl(String grfName)
	
	//	重複チェック
	if (WhichListItem("Range",ChildWindowList(StringFromList(0, grfName, "#"))) != -1)
		return 0
	endif
	
	//	一番上のイメージの現在の表示範囲を取得
	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	Wave rw = KM_GetColorTableMinMax(grfName,imgName)
	Variable zmin = rw[0], zmax = rw[1]		
	
	String dfTmp = pnlInit(grfName, imgName, zmin, zmax)
	
	//	表示
	NewPanel/EXT=0/HOST=$StringFromList(0, grfName, "#")/W=(0,0,PNLWIDTH,PNLHEIGHT)/N=Range
	String pnlName = StringFromList(0, grfName, "#") + "#Range"
	
	//	パネルコントロール
	PopupMenu imageP title="image",pos={3,7},size={218,19},bodyWidth=180,focusRing=0,win=$pnlName
	CheckBox allC title="all",pos={233,9},proc=KMRange#pnlCheck,focusRing=0,win=$pnlName
	
	GroupBox zminG pos={4,30},size={128,114},title="first Z",fColor=(65280,32768,32768),win=$pnlName
	
	CheckBox zminC      pos={9,53},win=$pnlName
	CheckBox zminAutoC  pos={9,74},win=$pnlName
	CheckBox zminSigmaC pos={9,98},win=$pnlName
	CheckBox zminCutC   pos={9,121},win=$pnlName
	
	SetVariable zminV      pos={27,51},format="%g",win=$pnlName
	SetVariable zminSigmaV pos={27,96},value=_NUM:-3,limits={-inf,inf,0.1},win=$pnlName
	SetVariable zminCutV   pos={27,120},value=_NUM:0.5,limits={0,100,0.1},win=$pnlName
	
	TitleBox zminSigmaT pos={91,97},title="\u03c3",win=$pnlName
	TitleBox zminCutT   pos={92,120},title="%",win=$pnlName
	
	GroupBox zmaxG pos={134,30},size={128,114},title="last Z",fColor=(32768,40704,65280),win=$pnlName
	
	CheckBox zmaxC      pos={139,53},win=$pnlName
	CheckBox zmaxAutoC  pos={139,74},win=$pnlName
	CheckBox zmaxSigmaC pos={139,98},win=$pnlName
	CheckBox zmaxCutC   pos={139,121},win=$pnlName
	
	SetVariable zmaxV      pos={157,51},format="%g",win=$pnlName
	SetVariable zmaxSigmaV pos={157,96},value=_NUM:3,limits={-inf,inf,0.1},win=$pnlName
	SetVariable zmaxCutV   pos={157,120},value=_NUM:99.5,limits={0,100,0.1},win=$pnlName
	
	TitleBox zmaxSigmaT pos={221,98},title="\u03c3",win=$pnlName
	TitleBox zmaxCutT   pos={222,121},title="%",win=$pnlName
	
	TitleBox histogramT pos={6,150},title="adjust histogram",win=$pnlName
	Button presentB pos={102,147},title="present z",win=$pnlName
	Button fullB pos={170,147},title="full z",win=$pnlName
	
	//	パネルコントロール・まとめて表示設定
	//	チェックボックス
	ModifyControlList ControlNameList(pnlName,";","zm*C") size={13,13},focusRing=0, mode=1, title="", proc=KMRange#pnlCheck, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","zm*AutoC") size={42,15}, title=" auto", focusRing=0, win=$pnlName
	//	値設定
	ModifyControlList ControlNameList(pnlName,";","zm*V") size={60,18}, bodyWidth=60, focusRing=0, proc=KMRange#pnlSetvalue, win=$pnlName
	ModifyControlList "zminV;zmaxV" size={100,18}, bodyWidth=100, focusRing=0, win=$pnlName
	//	タイトルボックス
	ModifyControlList ControlNameList(pnlName,";","*T") frame=0,win=$pnlName
	//	ボタン
	ModifyControlList ControlNameList(pnlName,";","*B") size={65,20},focusRing=0,proc=KMRange#pnlButton,win=$pnlName
	
	//	ヒストグラム表示領域
	DefineGuide/W=$pnlName KMFT={FT, CTRLHEIGHT}
	Display/FG=(FL,KMFT,FR,FB)/HOST=$pnlName
	String subGrfName = pnlName + "#" + S_name
	
	//	ヒストグラム表示
	AppendToGraph/W=$subGrfName $(dfTmp+ks_name)
	DoUpdate/W=$subGrfName		//	これがないとカーソルが正しく表示されない
	Cursor/C=(65280,32768,32768)/F/H=2/N=1/S=2/T=2/W=$subGrfName I $ks_name zmin, 0
	Cursor/C=(32768,40704,65280)/F/H=2/N=1/S=2/T=2/W=$subGrfName J $ks_name zmax, 0
	
	//	ウインドウ調整
	ModifyGraph/W=$subGrfName margin(top)=8,margin(right)=12,margin(bottom)=32,margin(left)=40, gfSize=10
	ModifyGraph/W=$subGrfName tick=2,btlen=5,mirror=1,lblMargin=2,prescaleExp(left)=2
	ModifyGraph/W=$subGrfName mode($ks_name)=6
	ModifyGraph/W=$subGrfName rgb($ks_name)=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B)
	ModifyGraph/W=$subGrfName axRGB=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B), tlblRGB=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B), alblRGB=(SIDAM_CLR_LINE_R, SIDAM_CLR_LINE_G, SIDAM_CLR_LINE_B)
	ModifyGraph/W=$subGrfName gbRGB=(SIDAM_CLR_BG_R, SIDAM_CLR_BG_G, SIDAM_CLR_BG_B), wbRGB=(SIDAM_CLR_BG_R, SIDAM_CLR_BG_G, SIDAM_CLR_BG_B)
	Label/W=$subGrfName bottom "z (\u\M)"
	Label/W=$subGrfName left "Probability (\u#2%)"
	SetActiveSubwindow ##
	
	//	フック関数
	//	カーソル表示前にフック関数を設定すると、カーソル移動(7)が働いてしまうので、ここに置く
	SetWindow $grfName hook(KMRangePnl)=KMRange#pnlHookParent, userData(KMRangePnl)=pnlName
	SetWindow $pnlName hook(self)=KMRange#pnlHook
	SetWindow $pnlName userData(grf)=grfName
	SetWindow $pnlName userData(dfTmp)=dfTmp
	SetWindow $pnlName userData(subGrfName)=subGrfName, activeChildFrame=0
	
	//	ユーザーデータ等の設定が全て終わってから実行すべき項目
	PopupMenu imageP proc=KMRange#pnlPopup,value=#"KMRange#imageListForImageP()",win=$pnlName
	updatePnlCheckBoxAndSetVar(pnlName)
End
//-------------------------------------------------------------
//	パネル初期設定, 表示用ヒストグラム作成
//-------------------------------------------------------------
Static Function/S pnlInit(String grfName, String imgName, Variable zmin, Variable zmax)
	
	String dfSav = KMNewTmpDf(StringFromList(0, grfName, "#"),"KMRangePnl")
	String dfTmp = GetDataFolder(1)
	
	//	ヒストグラムウエーブ
	Wave w = KMGetImageWaveRef(grfName, imgName=imgName, displayed=1)
	KMHistogram(w, startz=zmin-(zmax-zmin)*0.05, endz=zmax+(zmax-zmin)*0.05, bins=k_bins, result=ks_name, dfr=GetDataFolderDFR())
	
	SetDataFolder $dfSav
	return dfTmp
End

//******************************************************************************
//	フック関数
//******************************************************************************
//-------------------------------------------------------------
//	親ウインドウ用
//-------------------------------------------------------------
Static Function pnlHookParent(STRUCT WMWinHookStruct &s)
	
	//	この項目は
	//	(1) Igor標準のダイアログからz表示範囲が変更された場合
	//	(2) 3Dウエーブの表示レイヤーが変更された場合
	//	(3) ソースウエーブが変更された場合
	//	(4) イメージが削除された場合
	//	に動作する。
	
	//	modified だけを扱う
	if (s.eventCode != 8)
		return 0
	endif
	
	//	Rangeパネルからの変更の際には動作を抑制するため、RangeパネルからZ範囲の変更を行う際には 
	//	"pauseHook" というユーザーデータを記述しておく。
	//	これが記録されている場合には、"pauseHook"を解除するだけで、それ以降の動作は行わない。
	if (strlen(GetUserData(s.winName, "", "pauseHook")))
		SetWindow $s.winName userData(pauseHook)=""
		return 0
	endif
	
	String imgList = ImageNameList(s.winName,";"), imgName
	Variable recorded, present
	int i, n, needUpdateZ = 0, needUpdatePnl = 0
	
	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		imgName = StringFromList(i,imgList)
		
		//	(1) Igor標準のダイアログからのZ範囲の変更を調べる
		//	前回のupdateZRangeの実行に記録されたZ範囲と現在のZ範囲が異なっている場合を変更とみなす
		//	現状に合わせてZモードを変更する
		Variable z0 = getZmodeValue(s.winName, imgName, "z0")
		Variable z1 = getZmodeValue(s.winName, imgName, "z1")
		//	z0,z1がNaN(auto)の時には、下の不等式が常に偽になってしまう
		//	したがってautoの時には別に調べる
		int isRecordedFirstAuto = getZmodeValue(s.winName, imgName, "m0")==0//(numtype(z0)==2)
		int isRecordedLastAuto  = getZmodeValue(s.winName, imgName, "m1")==0//(numtype(z1)==2)
		int isPresentFirstAuto  = isFirstZAuto(s.winName, imgName)
		int isPresentLastAuto   = isLastZAuto(s.winName, imgName)
		int needFirstSet = isRecordedFirstAuto %^ isPresentFirstAuto	//	記録と現状が食い違っていたら真
		int needLastSet  = isRecordedLastAuto  %^ isPresentLastAuto	//	記録と現状が食い違っていたら真
		Wave rw = KM_GetColorTableMinMax(s.winName,imgName)
		if (abs(rw[0]-z0) > 1e-13 || needFirstSet)
			setZmodeValue(s.winName, imgName, "m0", !isPresentFirstAuto)
			setZmodeValue(s.winName, imgName, "v0", rw[0])
			needUpdatePnl = 1
		endif	
		if (abs(rw[1]-z1) > 1e-13 || needLastSet)
			setZmodeValue(s.winName, imgName, "m1", !isPresentLastAuto)
			setZmodeValue(s.winName, imgName, "v1", rw[1])
			needUpdatePnl = 1
		endif
		
		//	(2) 3Dウエーブの表示レイヤーが変更された場合
		recorded = getZmodeValue(s.winName, imgName, "layer")	//	記録がまだなければnanが返る
		present = KMLayerViewerDo(s.winName)						//	現在の表示レイヤー, 2Dならnan
		if (numtype(present)==0 && recorded!=present)
			setZmodeValue(s.winName, imgName, "layer", present)
			needUpdateZ = 1
		endif
		
		//	(3) ソースウエーブが変更された場合
		recorded = getZmodeValue(s.winName, imgName, "modtime")		//	記録がまだなければnanが返る
		present = NumberByKey("MODTIME",WaveInfo(ImageNameToWaveRef(s.winName,imgName),0))
		if (recorded != present)
			setZmodeValue(s.winName, imgName, "modtime", present)
			needUpdateZ = 1
		endif
	endfor
	
	//	(4) イメージが削除された場合にそなえて
	cleanZmodeValue(s.winName)
	
	if (needUpdateZ)
		SetWindow $s.winName userData(pauseHook)="1"
		updateZRange(s.winName)
	endif
	
	//	パネルが表示されているときには、現在のZモードの内容をパネル表示に反映する
	//	表示されていないときは、Zモード設定内容を調べる
	//	全てのイメージのZモード0または1であればこのフック関数が不要となる
	String pnlName = GetUserData(s.winName, "", "KMRangePnl")	//	s.winName + "#Range"
	if (strlen(pnlName))
		
		//	パネルで現在選択されているウエーブがグラフから削除された場合には、新たなウエーブを選択状態にしておく
		ControlInfo/W=$pnlName imageP
		Wave/Z w = KMGetImageWaveRef(s.winName, imgName=S_Value)
		if (!WaveExists(w))		//	表示されていないときには、ウエーブへの参照は無効となる
			PopupMenu imageP value=#"KMRange#imageListForImageP()", mode=1, win=$pnlName
		endif
		
		//	表示されているイメージが1つだけの場合には allC は不要
		if (ItemsInList(ImageNameList(s.winName,";")) < 2)
			CheckBox allC value=0, disable=1, win=$pnlName
		endif
		
		//	Zモードの表示状態の更新
		if (needUpdatePnl)
			updatePnlCheckBoxAndSetVar(pnlName)
		endif
		//	ヒストグラムの更新
		updateHistogram(pnlName, 0)
		//	カーソル位置を更新する
		updatePnlCursorsPos(pnlName)
		
	elseif(isAllZmodeAutoOrFix(s.winName))
		
		deleteZmodeValues(s.winName)
		SetWindow $s.winName hook(KMRangePnl)=$""
		
	endif
	
	return 0
End

//----------------------------------------------------------------------
//	パネル用
//----------------------------------------------------------------------
Static Function pnlHook(STRUCT WMWinHookStruct &s)
	
	switch (s.eventCode)
		
		case 2:	//	kill
		case 14:	//	subwindowKill	親ウインドウが閉じられた場合
			pnlHookClose(s.winName)
			break
			
		case 3:	//	mousedown
			if (s.eventMod&16)	//	右クリック
				PopupContextualMenu/N "KMRangepnlMenu"
			endif
			return 1
			
		case 5:	//	mouseup
			pnlHookMouseup(s)
			break
			
		case 7:	//	cursor moved
			//	この項目はユーザーによりカーソルが動かされた場合に動作することを想定しており、チェックボックスやポップアップメニューなどの
			//	選択により、カーソルを現状に合わせる際の変更では動作しないようにしたい。
			//	そのため updatePnlCursors では pauseHook が設定されている。
			if (strlen(GetUserData(s.winName, "", "pauseHook")))
				SetWindow $s.winName userData(pauseHook)=""
				return 0
			endif
			pnlHookCursor(s)	//	これが呼ばれる時には s.winName = Graph0#Range#G0 となっている
			break
			
		case 11:	//	keyboard
			if (s.keycode == 27)		//	27: esc
				pnlHookClose(s.winName)
				KillWindow $s.winName
			endif
			break
			
		default:
	endswitch
	return 0
End

//	各レイヤーごとにZ範囲を設定するためのメニュー
Menu "KMRangePnlMenu", dynamic, contextualmenu
	KMRange#pnlrightClickMenu(), KMRange#pnlrightClickMenuDo()
End

Static Function/S pnlrightClickMenu()
	int isCalledByRightclick = strsearch(GetRTStackInfo(3),"pnlHook,KM Range.ipf",0) != -1
	if (!isCalledByRightclick)
		return ""
	endif
	
	String grfName = WinName(0,1)
	Wave/Z zw = extractManualZvalues(grfName)
	return SelectString(WaveExists(zw),"set manual Z wave","reset manual Z mode")
End

Static Function pnlrightClickMenuDo()
	String grfName = WinName(0,1)
	String imgList = ImageNameList(grfName,";")
	Wave/Z zw = extractManualZvalues(grfName)
	int mode
	
	//	各レイヤーごとにz範囲を設定するためのウエーブがある場合には、それを解除する
	//	ない場合にはウエーブ選択パネルを出して、設定する
	if (WaveExists(zw))
		clearManualZvalues(grfName)
		mode = 1
	else
		String listStr = KMWaveList(GetDataFolderDFR(),2,ny=4)
		int num = KMWaveSelector("Select a wave", listStr)
		if (num)
			setManualZvalues(grfName, $StringFromList(num-1, listStr))
			mode = -1
		else
			return 0
		endif
	endif
	
	setZmodeValue(grfName, imgList, "m0", mode)
	setZmodeValue(grfName, imgList, "m1", mode)
	updateZRange(grfName)
	String pnlName = GetUserData(grfName, "", "KMRangePnl")	//	s.winName + "#Range"
	updatePnlCheckBoxAndSetVar(pnlName)	
End

//-------------------------------------------------------------
//	パネルが閉じられた場合の動作
//-------------------------------------------------------------
Static Function pnlHookClose(String pnlName)
	
	String grfName = StringFromList(0, pnlName, "#")
	
	DoWindow $grfName
	if (V_Flag)
		SetWindow $grfName userdata(KMRangePnl)=""
		if(isAllZmodeAutoOrFix(grfName))
			deleteZmodeValues(grfName)
			SetWindow $grfName hook(KMRangePnl)=$""
		endif
	endif
		
	KMonClosePnl(pnlName)
End

//-------------------------------------------------------------
//	マウスクリック時の動作
//-------------------------------------------------------------
Static Function pnlHookMouseup(STRUCT WMWinHookStruct &s)
	
	//	タイトルボックスがクリックされたときに、対応するチェックボックスの状態を変更する
	String list = "zminSigmaT;zminCutT;zmaxSigmaT;zmaxCutT", ctrl
	int i, n = ItemsInList(list)
	for (i = 0; i < n; i++)
		ctrl = StringFromList(i,list)
		ControlInfo/W=$s.winName $ctrl
		if (V_left < s.mouseLoc.h && s.mouseLoc.h < V_left + V_width && V_top < s.mouseLoc.v && s.mouseLoc.v < V_top + V_height)
			KMClickCheckBox(s.winName, ctrl[0,strlen(ctrl)-2]+"C")
		endif
	endfor
End

//-------------------------------------------------------------
//	カーソルが動かされた時の動作
//		Zモードを fix にする
//		パネルコントロールに値を代入してから対応するチェックボックスを呼び出すと
//		updateZRangeが呼び出されてZ範囲が更新される
//-------------------------------------------------------------
Static Function pnlHookCursor(STRUCT WMWinHookStruct &s)
	
	//	カーソルの値は表示領域に対して0-1で与えられる。したがって、xの値に変換するためには軸範囲を取得する必要がある
	String xAxis = StringByKey("XAXIS",TraceInfo(s.winName, s.traceName, 0))
	GetAxis/W=$s.winName/Q $xAxis
	Variable xmin = V_min, xmax = V_max
	Variable xvalue = xmin + (xmax-xmin)*s.pointNumber
	
	//	変更を受けるパネルコントロールの名前
	String pnlName = (s.winName)[0,strsearch(s.winName,"#",inf,1)-1]
	String setVarName = StringByKey(s.cursorName, "I:zminV;J:zmaxV;")
	String checkBoxName = StringByKey(s.cursorName, "I:zminC;J:zmaxC;")
	
	//	zminV または zmaxV の値を変更する
	SetVariable $setVarName value=_NUM:xvalue, win=$pnlName
	
	//	チェックボックスをクリックする -> updataZRangeが呼び出されてZ範囲が更新される
	KMClickCheckBox(pnlName,checkBoxName)
	
	//	z範囲がヒストグラム表示範囲の外側になった場合には、ヒストグラムを更新する
	if (xvalue < xmin || xvalue > xmax)
		updateHistogram(pnlName, 0)
	endif
End

//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetvalue(STRUCT WMSetVariableAction &s)
	
	if (s.eventCode == -1)
		return 0
	endif
	
	strswitch (s.ctrlName)
		//	zminV, zmaxVの場合は、以前の値と変更があるときにのみ処理をする。
		//	したがって変更の有無を調べて、無ければ何もせずに終わる。
		case "zminV":
		case "zmaxV":
			Variable pv = str2num(GetUserData(s.win, s.ctrlName, "previous"))
			if (numtype(pv) == 2)
				SetVariable $s.ctrlName userData(previous)=num2str(s.dval), win=$s.win
				KMClickCheckBox(s.win,(s.ctrlName)[0,strlen(s.ctrlName)-2]+"C")
				return 0
			elseif (pv == s.dval)
				KMClickCheckBox(s.win,(s.ctrlName)[0,strlen(s.ctrlName)-2]+"C")
				return 0
			endif	
			break
			
		default:
			KMClickCheckBox(s.win,(s.ctrlName)[0,strlen(s.ctrlName)-2]+"C")
			return 0
	endswitch
	
	//	以下は zminV　と zmaxV の場合のみ
	//	zminV, zmaxVの変更に応じてカーソル位置を変更し、それによってpnlHookCursorが呼び出される
	//	Z範囲の変更、およびチェックボックスの状態変更はpnlHookCursorに経由で行われる	
	if (stringmatch(s.ctrlName,"zminV"))
		Cursor/F/W=$GetUserData(s.win, "", "subGrfName") I $ks_name s.dval, 0
	else
		Cursor/F/W=$GetUserData(s.win, "", "subGrfName") J $ks_name s.dval, 0
	endif
	SetVariable $s.ctrlName limits={-inf,inf,10^(floor(log(abs(s.dval)))-1)}, userData(previous)=num2str(s.dval), win=$s.win
	
	return 0
End
//-------------------------------------------------------------
//	ポップアップメニュー
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	strswitch(s.ctrlName)
		case "imageP":
			//	モードに関する表示を更新する
			updatePnlCheckBoxAndSetVar(s.win)
			//	選択されたイメージの現在のz範囲でヒストグラムを作製する
			updateHistogram(s.win, 0)
			//	カーソル位置を更新する
			updatePnlCursorsPos(s.win)
			break
	endswitch
	
	return 0
End
//-------------------------------------------------------------
//	ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)	
	
	if (s.eventCode != 2)
		return 0
	endif
	
	//	ボタン内容に応じてヒストグラムを更新する
	strswitch (s.ctrlName)
		case "presentB":
			updateHistogram(s.win, 0)
			break
		case "fullB":
			updateHistogram(s.win, 1)
			break
	endswitch
	
	//	カーソル位置を更新する
	updatePnlCursorsPos(s.win)
	
	return 0
End
//-------------------------------------------------------------
//	チェックボックス
//		パネルコントロールに対する操作によってZ範囲が変更される場合、
//		この関数を経由してupdateZRangeが呼ばれる
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	
	if (s.eventCode != 2)
		return 0
	endif
	
	int i, n
	
	//	チェックボックスるがクリックされたときのパネルの表示状態の変更
	if (CmpStr(s.ctrlName,"allC"))
		//	zmin*C, zmax*C の場合
		//	同じグループ（zmin*** or zmax***)に属するチェックボックスの値を、自分自身のものを除き0にする
		String ctrlList = ControlNameList(s.win, ";", (s.ctrlName)[0,3]+"*C")
		ctrlList = RemoveFromList(s.ctrlName, ctrlList)
		for (i = 0, n = ItemsInList(ctrlList); i < n; i++)
			CheckBox $StringFromList(i,ctrlList) value=0, win=$s.win
		endfor
	else
		//	allC の場合
		Variable height = s.checked ? CTRLHEIGHT-22 : PNLHEIGHT
		MoveSubWindow/W=$s.win fnum=(0,0,PNLWIDTH,height)
		ModifyControlList "imageP;histogramT;presentB;fullB;" disable=(s.checked*2), win=$s.win
	endif
	
	//	updateZRangeを呼ぶ前にパネルで選択されているZモードに関する設定値を親ウインドウのZモード文字列に記録する
	//	まずは、パネルから設定を読み込む
	//	first ZのZモード
	int m0 = findSelectedRadiobutton(s.win, "min")
	//	first ZのZモードの設定値, autoの時は0
	Wave minValuew = KMGetCtrlValues(s.win, "zminV;zminSigmaV;zminCutV")
	Variable v0 = m0 ? minValuew[m0-1] : 0
	//	last ZのZモード
	int m1 = findSelectedRadiobutton(s.win, "max")
	//	last ZのZモードの設定値, autoの時は0
	Wave maxValuew = KMGetCtrlValues(s.win, "zmaxV;zmaxSigmaV;zmaxCutV")
	Variable v1 = m1 ? maxValuew[m1-1] : 0
	
	//	allCがチェックされている場合には、表示されているすべてのイメージについてZモード文字列を記録し、
	//	チェックされていない場合には、パネルで選択されているイメージのみ
	String grfName = GetUserData(s.win,"","grf")
	String imgNameList
	
	ControlInfo/W=$s.win allC
	if (V_Value)
		imgNameList = ImageNameList(grfName,";")
	else
		ControlInfo/W=$s.win imageP
		imgNameList = S_Value + ";"
	endif
	
	setZmodeValue(grfName, imgNameList, "m0", m0)
	setZmodeValue(grfName, imgNameList, "v0", v0)
	setZmodeValue(grfName, imgNameList, "m1", m1)
	setZmodeValue(grfName, imgNameList, "v1", v1)
	
	//	記録された設定値に応じてZ範囲を変更する
	SetWindow $grfName userData(pauseHook)="1"		//	親グラフのフック関数による循環動作防止
	updateZRange(grfName)
	
	//	変更されたZ範囲に応じてカーソル位置を変更する
	//	allCの場合には隠されているが、allCのチェックが外れた場合に備えて実行しておく
	updatePnlCursorsPos(s.win)
	
	return 0
End

//******************************************************************************
//	パネルコントロール補助関数
//******************************************************************************
//-------------------------------------------------------------
//	imagePの内容を与える
//-------------------------------------------------------------
Static Function/S imageListForImageP()
	String pnlName = GetUserData(WinName(0,1)+"#Range","","grf")
	return ImageNameList(pnlName, ";")
End

//-------------------------------------------------------------
//	現在のz表示範囲に合わせるように、カーソル位置を変更する
//-------------------------------------------------------------
Static Function updatePnlCursorsPos(String pnlName)
	
	String grfName = GetUserData(pnlName, "", "grf")
	String subGrfName = GetUserData(pnlName, "", "subGrfName")
	ControlInfo/W=$pnlName imageP
	Wave rw = KM_GetColorTableMinMax(grfName, S_Value)
	
	//	カーソルを更新する
	//	カーソル位置更新後の循環動作防止は各カーソル更新前にその都度実行する必要がある
	SetWindow $subGrfName userData(pauseHook)="1"	
	Cursor/F/W=$subGrfName I $ks_name rw[0], 0
	
	SetWindow $subGrfName userData(pauseHook)="1"	
	Cursor/F/W=$subGrfName J $ks_name rw[1], 0	
End

//-------------------------------------------------------------
//	・最初にパネルを表示したとき (pnl)
//	・ポップアップメニューにより操作対象となるイメージが変更されたとき (pnlPopup)
//	・表示レイヤーの変更など親ウインドウに変更があったとき (pnlHookParent)
//	にZモードに関するパネルの変更を行う
//-------------------------------------------------------------
Static Function updatePnlCheckBoxAndSetVar(String pnlName)
	
	//	パネルで選択されているイメージに対応する設定値を親ウインドウの記録から得る
	String grfName = GetUserData(pnlName,"","grf")
	ControlInfo/W=$pnlName imageP
	String imgName = S_Value	
	int m0 = getZmodeValue(grfName, imgName, "m0")
	int m1 = getZmodeValue(grfName, imgName, "m1")
		
	//	すべてのチェックボックスを一度0にする
	String checkBoxList = ControlNameList(pnlName,";","zm*C")
	int i, n
	for (i = 0, n = ItemsInList(checkBoxList); i < n; i++)
		CheckBox $StringFromList(i,checkBoxList) value=0, win=$pnlName
	endfor
	
	//	選択されているモードのチェックボックスを1にする
	CheckBox/Z $StringFromList(m0,"zminAutoC;zminC;zminSigmaC;zminCutC") value=1, win=$pnlName
	CheckBox/Z $StringFromList(m1,"zmaxAutoC;zmaxC;zmaxSigmaC;zmaxCutC") value=1, win=$pnlName
	
	//	zminV と zmaxV には現在のZ範囲を代入する
	Wave rw = KM_GetColorTableMinMax(grfName, imgName)
	SetVariable/Z zminV value=_NUM:rw[0], limits={-inf,inf,10^(floor(log(abs(rw[0])))-1)}, win=$pnlName
	SetVariable/Z zmaxV value=_NUM:rw[1], limits={-inf,inf,10^(floor(log(abs(rw[1])))-1)}, win=$pnlName
	
	//	sigma か cut が選択されている場合には、対応する値設定に値を設定する
	if (m0 >= 2)
		Variable v0 = getZmodeValue(grfName, imgName, "v0")
		SetVariable/Z $StringFromList(m0-2,"zminSigmaV;zminCutV") value=_NUM:v0, win=$pnlName
	endif
	
	if (m1 >= 2)
		Variable v1 = getZmodeValue(grfName, imgName, "v1")
		SetVariable/Z $StringFromList(m1-2,"zmaxSigmaV;zmaxCutV") value=_NUM:v1, win=$pnlName
	endif
End

//-------------------------------------------------------------
//	ヒストグラムを作成する
//	mode 0: 現在の表示レンジを上下5%ずつ広げた範囲に対して作成
//	mode 1: ウエーブの(表示されている領域の)最大・最小に対して作成
//-------------------------------------------------------------
Static Function updateHistogram(String pnlName, int mode)
	
	ControlInfo/W=$pnlName imageP
	String imgName = S_Value	
	String grfName = GetUserData(pnlName, "", "grf")
	DFREF dfrTmp = $GetUserData(pnlName, "", "dfTmp")
	Wave w = KMGetImageWaveRef(grfName, imgName=imgName, displayed=1)
	
	Variable zmin, zmax
	if ( mode == 0 )
		Wave rw = KM_GetColorTableMinMax(grfName, imgName)
		zmin = rw[0] - (rw[1]-rw[0])*0.05
		zmax = rw[1] + (rw[1]-rw[0])*0.05
	else
		zmin = WaveMin(w)
		zmax = WaveMax(w)
	endif
	
	KMHistogram(w, startz=zmin, endz=zmax, bins=k_bins, result=ks_name, dfr=dfrTmp)
	
	DoUpdate/W=$pnlName
End

//-------------------------------------------------------------
//	パネルで選択されているラジオボタンを返す
//	返り値は 0: auto; 1: fix; 2: sigma; 3: cut
//-------------------------------------------------------------
Static Function findSelectedRadiobutton(String pnlName, String minOrMax)
	String str
	Sprintf str, "z%sAutoC;z%sC;z%sSigmaC;z%sCutC", minOrMax, minOrMax, minOrMax, minOrMax
	Wave cw = KMGetCtrlValues(pnlName, str)
	cw *= p
	return sum(cw)
End

//-------------------------------------------------------------
//	Zモードの設定に合わせてZ範囲を設定する
//-------------------------------------------------------------
Static Function updateZRange(String grfName)
	
	String listStr = ImageNameList(grfName,";"), imgName
	int i, n, m0, m1
	Variable v0, v1
	
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		imgName = StringFromList(i,listStr)
		
		m0 = getZmodeValue(grfName, imgName, "m0") ;	v0 = getZmodeValue(grfName, imgName, "v0")
		m1 = getZmodeValue(grfName, imgName, "m1") ;	v1 = getZmodeValue(grfName, imgName, "v1")	
		
		if (m0 == -1 || m1 == -1)
			Wave/Z mw = extractManualZvalues(grfName)
			int layer = KMLayerViewerDo(grfName)
			m0 = mw[layer][%m0] ;	v0 = mw[layer][%v0]
			m1 = mw[layer][%m1] ;	v1 = mw[layer][%v1]
		endif
		
		Wave zw = updateZRange_getValues(grfName, imgName, m0, v0, m1, v1)
		applyZRange(grfName, imgName, zw[0], zw[1])
		
		//	設定したZ範囲をユーザーデータに書き込んでおく
		//	これにより、パネルを経ないZ範囲の変更(つまり、Igor標準のやり方で)を検出できる
		setZmodeValue(grfName, imgName, "z0", zw[0])
		setZmodeValue(grfName, imgName, "z1", zw[1])
	endfor
End

Static Function/WAVE updateZRange_getValues(String grfName, String imgName, int m0, Variable v0, int m1, Variable v1)
	
	if (m0 >= 2 || m1 >= 2)		//	sigma or cut
		Wave tw = KMGetImageWaveRef(grfName, imgName=imgName, displayed=1)
		if (m0 == 2 || m1 == 2)	//	sigma
			WaveStats/Q tw
			Variable avg = V_avg, sdev = V_sdev
		endif
		if (m0 == 3 || m1 == 3)	//	cut
			Wave hw = KMHistogram(tw,bins=256,cumulative=1,normalize=1,dfr=NewFreeDataFolder())
		endif
	endif
	
	Variable zmin, zmax
	switch (m0)
		case 0:	//	auto
			zmin = NaN
			break
		case 2:	//	sigma
			zmin = avg + sdev * v0
			break
		case 3:	//	cut
			FindLevel/Q hw, v0/100
			zmin = V_flag ? WaveMin(tw) : V_LevelX
			break
		default:	//	1 (fix) or -1 (manual)
			zmin = v0
	endswitch
	
	switch (m1)
		case 0:	//	auto
			zmax = NaN
			break
		case 2:	//	sigma
			zmax = avg + sdev * v1
			break
		case 3:	//	cut
			FindLevel/Q hw, v1/100
			zmax = V_flag ? WaveMax(tw) : V_LevelX
			break
		default:	//	1 (fix) or -1 (manual)
			zmax = v1
	endswitch
	
	Make/D/N=2/FREE rtnw = {zmin, zmax}
	return rtnw
End


//=====================================================================================================
//	Zモード関する設定内容を読み書きする
//=====================================================================================================
//-------------------------------------------------------------
//	保存文字列は
//	imgName:m0=xxx,v0=xxx,z0=xxx,m1=xxx,v1=xxx,z1=xxx;layer=xxx;modtime=xxx
//	がイメージの数だけ繰り返されたものになっている
//	m0,m1 は Zモードの種類 (0: auto, 1:fix, 2:sigma, 3:cut, -1:manual)
//	v0,v1 は Zモードの設定値 (例えば 3sigma の 3)
//	(z0,z1 は　updateZRange によって実際に使用された値を入れる)
//-------------------------------------------------------------
Static StrConstant MODEKEY = "KMRangeSettings"
Static StrConstant VALUEKEY = "KMRangeValues"
//	値の書き込み
Static Function setZmodeValue(String grfName, String imgList, String key, Variable var)
	
	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	String str
	int i, n
	
	for (i = 0, n = ItemsInList(imgList); i < n; i++)
		String imgName = StringFromList(i,imgList)
		String setting = StringByKey(imgName, allImagesSettings)
		Sprintf str "%.14e", var
		setting = ReplaceStringByKey(key,setting,str,"=",",")
		allImagesSettings = ReplaceStringByKey(imgName,allImagesSettings,setting)
	endfor
	
	SetWindow $grfName userData($MODEKEY)=allImagesSettings
End

//	値の読み込み
Static Function getZmodeValue(String grfName, String imgName, String key)
	
	//	グラフがない、イメージがない、場合には
	if (WhichListItem(imgName, ImageNameList(grfName,";")) == -1)
		return NaN
	endif
	
	//	Zモードに関する設定文字列
	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	String setting = StringByKey(imgName, allImagesSettings)
	Variable num = NumberByKey(key, setting, "=" , ",")		//	記録がない場合には NaN が入る
	
	//	記録がある場合にはその値を返す
	if (!numtype(num))
		return num
	endif
	
	strswitch (key)
		case "m0":
			//	記録がない場合には、、Zモードを使ってはおらず、具体的な値かautoが設定されている
			return !isFirstZAuto(grfName, imgName)
			
		case "m1":
			//	記録がない場合には、、Zモードを使ってはおらず、具体的な値かautoが設定されている
			return !isLastZAuto(grfName, imgName)
			
		case "v0":
		case "z0":
			Wave rw = KM_GetColorTableMinMax(grfName,imgName)
			return rw[0]
			
		case "v1":
		case "z1":
			Wave rw = KM_GetColorTableMinMax(grfName,imgName)
			return rw[1]
			
	endswitch
End

//	表示されていない(削除された)イメージに関する情報を消去する
Static Function cleanZmodeValue(String grfName)
	
	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	String imgList = ImageNameList(grfName,";")
	int i, n0 = ItemsInList(allImagesSettings)
	
	for (i = ItemsInList(allImagesSettings)-1; i >= 0; i--)
		String setting = StringFromList(i, allImagesSettings)
		String imgName = StringFromList(0, setting, ":")
		if (WhichListItem(imgName,imgList) == -1)
			allImagesSettings = RemoveByKey(imgName,allImagesSettings)
		endif
	endfor
	
	SetWindow $grfName userData($MODEKEY)=allImagesSettings
	
	return n0 > ItemsInList(allImagesSettings)		//	削除されたものがあれば真
End

//	Zモードに関するすべての情報を削除する
Static Function deleteZmodeValues(String grfName)
	SetWindow $grfName userdata($MODEKEY)=""
End

//	記録されている全てのイメージについて、Zモードが0または1であれば1を返す
Static Function isAllZmodeAutoOrFix(String grfName)
	
	//	表示されていないイメージに関する情報は消去する
	cleanZmodeValue(grfName)
	
	String allImagesSettings = GetUserData(grfName, "", MODEKEY)
	int i, n
	for (i = 0, n = ItemsInList(allImagesSettings); i < n; i++)
		String setting = StringFromList(1,StringFromList(i, allImagesSettings),":")
		Variable m0 = NumberByKey("m0", setting, "=" , ",")		//	記録がない場合には NaN が入る
		Variable m1 = NumberByKey("m1", setting, "=" , ",")		//	記録がない場合には NaN が入る
		if (m0 >= 2 || m0 < 0 || m1 >= 2 || m1 < 0)
			return 0
		endif
	endfor
	
	return 1
End

//	z範囲を各レイヤーごとに設定する場合の設定値をuserDataに書き込む
//	書き込む値を持っているウエーブは2Dで、適切なDimLabelが設定されていなければならない
Static Function setManualZvalues(String grfName, Wave zw)
	
	//	ウエーブに関するチェック
	if (WaveDims(zw) != 2 || DimSize(zw,1) != 4 || DimSize(zw,0) > 128)
		return 1
	elseif (WaveType(zw) < 2)	//	0 (non-numeric) or 1 (complex)
		return 1
	else
		String dimLabelStr = "m0;m1;v0;v1"
		Make/N=4/FREE tw = FindDimLabel(zw,1,StringFromList(p,dimLabelStr))
		if (WaveMin(tw) == -2)
			return 1
		endif
	endif
	
	STRUCT zValues s
	s.layers = DimSize(zw,0)
	int i
	for (i = 0; i < s.layers; i++)
		s.m0[i] = zw[i][%m0]
		s.v0[i] = zw[i][%v0]
		s.m1[i] = zw[i][%m1]
		s.v1[i] = zw[i][%v1]
	endfor
	
	String str
	StructPut/S s str
	SetWindow $grfName userData($VALUEKEY)=str
	
	return 0
End

//	各レイヤーごとの設定値をuserDataから読み込んでウエーブとして返す
Static Function/WAVE extractManualZvalues(String grfName)
	
	String str = GetUserData(grfName, "", VALUEKEY)
	if (!strlen(str))
		return $""
	endif
	
	STRUCT zValues s
	StructGet/S s str
	
	Make/D/N=(s.layers,4)/FREE vw
	SetDimlabel 1, 0, m0, vw
	SetDimlabel 1, 1, v0, vw
	SetDimlabel 1, 2, m1, vw
	SetDimlabel 1, 3, v1, vw
	
	int i
	for (i = 0; i < s.layers; i++)
		vw[i][%m0] = s.m0[i] 
		vw[i][%v0] = s.v0[i]
		vw[i][%m1] = s.m1[i]
		vw[i][%v1] = s.v1[i]
	endfor
	
	return vw
End

Static Function clearManualZvalues(String grfName)
	SetWindow $grfName userData($VALUEKEY)=""
End

Static Structure zValues
	char m0[128]		//	128は設定可能な最大レイヤー数
	char m1[128]
	double v0[128]
	double v1[128]
	uchar layers
EndStructure


//=====================================================================================================
//	後方互換性
//	rev. 937への変更時に用いる
//=====================================================================================================
Override Function KMRangePnlHook(STRUCT WMWinHookStruct &s)
	
	//	パネルを閉じる処理
	String grfName = StringFromList(0, s.winName, "#")
	DoWindow $grfName
	if (V_Flag)
		SetWindow $grfName hook(KMRangePnl)=$"", userdata(KMRangePnl)=""
	endif
	KMKillWinGlobals(StringFromList(0, s.winName, "#")+"RangeGraph","Share_KMRangePnl")
	KMonClosePnl(s.winName)
	KillWindow/Z $s.winName
	
	pnl(grfName)
End

//	WinGlobalsの削除に関する処理
Static Function KMKillWinGlobals(grfName,shareName)
	String grfName, shareName
	
	DFREF dfrSav = GetDataFolderDFR()
	
	if (!DataFolderExists("root:WinGlobals:"+PossiblyQuoteName(grfName)))
		return 1
	endif
	SetDataFolder root:WinGlobals:$(grfName)
	
	//  share変数の削除
	if (exists(shareName) != 2)
		SetDataFolder dfrSav
		return 1
	endif
	KillVariables $shareName
	
	//  データフォルダの削除
	if (!ItemsInList(VariableList("Share_*",";",4+2)))	//  他にこのグラフのWinGlobalsを共有しているものがなければ
		KillDataFolder root:WinGlobals:$(grfName)
		if (!CountObjects("root:WinGlobals",4))		//  WinGlobals内に他のデータフォルダがなければ
			KillDataFolder root:WinGlobals
		endif
	endif
	
	SetdataFolder dfrSav
	return 0
End

Override Function KMRangePnlHookParent(STRUCT WMWinHookStruct &s)	
	//	自分自身を無効化する
	SetWindow $s.winName hook(KMRangePnl)=$"", userdata(KMRangePnl)=""
End

Override Function KMRangeAutoHook(STRUCT WMWinHookStruct &s)
	
	String pnlName = GetUserData(s.winName,"","KMRangePnl")	//	古いパネルの名前
	if (strlen(pnlName))
		KillWindow/Z $pnlName		//	古いフック関数が働く
	endif
	
	STRUCT KMRangeAutoStruct ars
	StructGet/S ars GetUserData(s.winName, "", "KMRangeAutoData")
	
	SetWindow $s.winName userData(KMRangeAutoData)=""
	SetWindow $s.winName userData(KMRangeAutoDataImg)=""	//	backward compatibility
	SetWindow $s.winName hook(KMRangeAuto)=$""
	
	if (ars.mode==0 && ars.firstmode==2 && ars.firstValue==-3 && ars.lastmode==2 && ars.lastValue==3)
		//	3 sigma
		rightclickDo(2)
	elseif (ars.mode==1 && ars.cutvalue==0.5)
		//	0.5%
		rightclickDo(3)
	endif
	
	return 0
End

Static Structure KMRangeAutoStruct
	uchar	mode			//	0: prefix, 1: cut, 2: level
	uchar	firstmode		//	0: min, 1: max, 2: avg+xsigma, 3: mode, 4: median, 5: fix
	float	firstvalue
	uchar	lastmode		//	0: min, 1: max, 2: avg+xsigma, 3: mode, 4: median, 5: fix
	float	lastvalue
	float	cutvalue
	float	levelvalue
EndStructure