#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = KMScaleBar

#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	設定可能な値のデフォルト値
Static StrConstant DEFAULT_ANCHOR = "LB"	//	位置, LB, LT, RB, RT
Static Constant DEFAULT_SIZE = 0				//	フォントの大きさ (pt)
Static Constant DEFAULT_FC = 0				//	文字色 (0,0,0)
Static Constant DEFAULT_BC = 65535			//	背景色 (65535,65535,65535)
Static Constant DEFAULT_FA = 65535			//	文字の不透明度
Static Constant DEFAULT_BA = 39321			//	背景の不透明度 65535*0.6 = 39321

//	固定値
Static Constant NICEWIDTH = 20				//	画面の20%程度になるように
Static Constant MARGIN = 0.02					//	画面の端からの位置, 画面に対する比率
Static Constant OFFSET = 0.015				//	スケールバーと文字の間
Static Constant LINETHICK = 3					//	スケールバーの太さ
Static Constant OVERRIDENM = 1				//	Åをnmに変更して表示する(1), しない(0)
Static Constant DOUBLECLICK = 20				//	ダブルクリックの基準
Static StrConstant NICEVALUES = "1;2;3;5"	//	キリのいい値の定義
Static StrConstant NAME = "KMScalebar"

//=====================================================================================================

Function KMScalebar(
	[
		String grfName,		//	スケールバーを表示するグラフの名前, 省略時は一番上のグラフ
		String anchor,		//	スケールバーの表示位置, LB,LT,RB,RT,空文字 のいずれか。
								//	空文字の時はスケールバーを削除
		int size,				//	フォントサイズ(pt)
		Wave fgRGBA,			//	表示色
		Wave bgRGBA,			//	背景色
		int history			//	履歴欄にコマンドを出力する(1), しない(0), 省略時は0
	])
	
	grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1))
	if (isInvalidWindow(grfName))
		return 0
	endif
	
	STRUCT paramStruct s
	initializeParamStruct(s,grfName)
	
	//	引数で指定されているものについては上書きする
	if (!ParamIsDefault(anchor))
		s.anchor[0] = strlen(anchor) ? char2num(anchor[0]) : 0
		s.anchor[1] = strlen(anchor) ? char2num(anchor[1]) : 0
	endif
	if (!ParamIsDefault(size))
		s.fontsize = limit(size,0,inf)
	endif
	try
		if (!ParamIsDefault(fgRGBA))
			s.fgRGBA.red = fgRGBA[0]; 	AbortOnRTE
			s.fgRGBA.green = fgRGBA[1];	AbortOnRTE
			s.fgRGBA.blue = fgRGBA[2];	AbortOnRTE
			s.fgRGBA.alpha = numpnts(fgRGBA)>3 ? fgRGBA[3] : 65535
		endif
		if (!ParamIsDefault(bgRGBA))
			s.bgRGBA.red = bgRGBA[0]; 	AbortOnRTE
			s.bgRGBA.green = bgRGBA[1];	AbortOnRTE
			s.bgRGBA.blue = bgRGBA[2]; 	AbortOnRTE
			s.bgRGBA.alpha = numpnts(bgRGBA)>3 ? bgRGBA[3] : 65535
		endif
	catch
		Variable err = GetRTError(1)
		String msg = PRESTR_CAUTION + "KMScalebar gave error: "
		switch (err)
			case 1321:
				print msg + "out of index"
				break
			case 330:
				print msg + "wave not found"
				break
			default:
				print msg + "error code ("+num2str(err)+")"
		endswitch
		return 0
	endtry
	
	//	履歴欄
	if (!ParamIsDefault(history) && history)
		echo(grfName, s)
	endif
	
	//	表示されているスケールバーを消去する場合
	if (!s.anchor[0] && !s.anchor[1])	//	引数で空文字を与えた場合
		SetWindow $grfName hook($NAME)=$""
		SetWindow $grfName userData($NAME)=""
		deleteBar(grfName)
		return 0
	endif
	
	//	以降はスケールバーを表示する場合
	String str
	
	//	既に表示されている場合にはいったん消去する
	if (strlen(GetUserData(grfName,"",NAME))>0)
		s.stop = 1
		StructPut/S s, str
		SetWindow $grfName userData($NAME)=str	//	stop on
		deleteBar(grfName)							//	stop off
	endif
	
	//	スケールバー表示
	s.stop = 1
	StructPut/S s, str
	SetWindow $grfName userData($NAME)=str		//	stop on
	writeBar(grfName,s)								//	フック関数が既に設定されていれば stop off
	
	//	更新のためのフック関数が設定されていなければ、設定する
	GetWindow $grfName hook($NAME)
	if (strlen(S_Value)==0)
		SetWindow $grfName hook($NAME)=KMScaleBar#hook	//	フック関数が実行されて stop off
	endif

End

//-------------------------------------------------------------
//	パラメータチェック用関数
//-------------------------------------------------------------
Static Function isInvalidWindow(String grfName)
	String errMsg = PRESTR_CAUTION + "KMScalebar gave error: "
	
	if (!strlen(grfName))
		printf "%sgraph not found.\r", errMsg
		return 1
	elseif (!SIDAMWindowExists(grfName))
		printf "%sa graph named %s is not found.\r", errMsg, grfName
		return 1
	elseif (!strlen(ImageNameList(grfName,";")))
		printf "%s%s has no image.\r", errMsg, grfName
		return 1
	endif
	
	return 0
End


//-------------------------------------------------------------
//	パラメータ構造体を初期化する
//-------------------------------------------------------------
Static Function initializeParamStruct(STRUCT paramStruct &s, String grfName)
	//	スケールバーが既に表示されている場合、表示に用いられているパラメータを構造体に代入する
	//	表示されていない場合、デフォルト値を入れる
	String settingStr = GetUserData(grfName,"",NAME)
	if (strlen(settingStr))
		StructGet/S s, settingStr
	else
		s.anchor[0] = char2num(DEFAULT_ANCHOR[0])
		s.anchor[1] = char2num(DEFAULT_ANCHOR[1])
		s.fontsize = DEFAULT_SIZE
		s.fgRGBA.red = DEFAULT_FC
		s.fgRGBA.green = DEFAULT_FC
		s.fgRGBA.blue = DEFAULT_FC
		s.fgRGBA.alpha = DEFAULT_FA
		s.bgRGBA.red = DEFAULT_BC
		s.bgRGBA.green = DEFAULT_BC
		s.bgRGBA.blue = DEFAULT_BC
		s.bgRGBA.alpha = DEFAULT_BA
	endif
End

Static Structure paramStruct
	//	パラメータ入力用
	uchar	anchor[2]
	uint16	fontsize
	STRUCT	RGBAColor	fgRGBA
	STRUCT	RGBAColor	bgRGBA
	//	内部処理用
	uchar	stop
	STRUCT	RectF box
	double	xmin, xmax, ymin, ymax
	double	ticks
EndStructure

//-------------------------------------------------------------
//	更新用フック関数
//-------------------------------------------------------------
Static Function hook(STRUCT WMWinHookStruct &s)
	switch (s.eventCode)
		case 3:	//	mousedown
		case 5:	//	mouseup
		case 6:	//	resized
		case 8:	//	modified
			break
		default:
			return 0
	endswitch
	
	int returnCode = 0
	String str
	STRUCT paramStruct ps
	StructGet/S ps, GetUserData(s.winName,"",NAME)
	
	switch (s.eventCode)
		case 3:	//	mousedown
			//	スケールバーエリアの中でダブルクリックしたらパネルを開く
			if (ps.ticks == 0)
				break
			elseif (s.ticks-ps.ticks < DOUBLECLICK && isClickedInside(ps.box,s))
				pnl(s.winName)
				returnCode = 1		//	Modify Trace Appearanceパネルが開くのを抑制する
			endif
			ps.ticks = 0	//	クリックに関する情報をクリアする
			StructPut/S ps, str
			SetWindow $s.winName userData($NAME)=str
			break
			
		case 5:	//	mouseup
			//	スケールバーエリアの中でダブルクリックしたらパネルを開く。
			//	そのために、1回目のクリックの情報を記録しておく
			if (ps.ticks == 0 && isClickedInside(ps.box,s))
				ps.ticks = s.ticks
				StructPut/S ps, str
				SetWindow $s.winName userData($NAME)=str
			endif
			break
			
		case 8: 	//	modified
			//	表示領域に変更がなければ動作しない
			STRUCT SIDAMAxisRange as
			SIDAMGetAxis(s.winName,StringFromList(0,ImageNameList(s.winName,";")),as)
			if (as.xmin==ps.xmin && as.xmax==ps.xmax && as.ymin==ps.ymin && as.ymax==ps.ymax)
				break
			endif
			//	*** FALLTHROUGH ***
			
		case 6:	//	resized
			if (ps.stop)
				ps.stop = 0
				StructPut/S ps, str
				SetWindow $s.winName userData($NAME)=str
			else
				KMScaleBar(grfName=s.winName)
			endif
			break
	endswitch
	return returnCode
End

Static Function isClickedInside(STRUCT RectF &box, STRUCT WMWinHookStruct &s)
	GetWindow $s.winName, psizeDC
	Variable x0 = V_left+(V_right-V_left)*box.left
	Variable x1 = V_left+(V_right-V_left)*box.right
	Variable y0 = V_top+(V_bottom-V_top)*box.top
	Variable y1 = V_top+(V_bottom-V_top)*box.bottom
	return (x0 < s.mouseLoc.h && s.mouseLoc.h < x1 && y0 < s.mouseLoc.v && s.mouseLoc.v < y1)
End

//-------------------------------------------------------------
//	履歴欄出力
//-------------------------------------------------------------
Static Function echo(String grfName, STRUCT paramStruct &s)
	String paramStr = "grfName=\"" + grfName + "\""
	
	if (!s.anchor[0] && !s.anchor[1])
		printf "%sKMScalebar(%s,anchor=\"\")\r", PRESTR_CMD, paramStr
		return 0
	elseif (s.anchor[0] != char2num(DEFAULT_ANCHOR[0]) || s.anchor[1] != char2num(DEFAULT_ANCHOR[1]))
		sprintf paramStr, "%s,anchor=\"%s\"", paramStr, s.anchor
	endif
	
	if (s.fontsize != DEFAULT_SIZE)
		sprintf paramStr, "%s,size=%d", paramStr, s.fontsize
	endif
	
	if (s.fgRGBA.red != DEFAULT_FC || s.fgRGBA.green != DEFAULT_FC || s.fgRGBA.blue != DEFAULT_FC || s.fgRGBA.alpha != DEFAULT_FA)
		sprintf paramStr, "%s,fgRGBA={%d,%d,%d,%d}", paramStr, s.fgRGBA.red, s.fgRGBA.green, s.fgRGBA.blue, s.fgRGBA.alpha
	endif
	
	if (s.bgRGBA.red != DEFAULT_BC || s.bgRGBA.green != DEFAULT_BC || s.bgRGBA.blue != DEFAULT_BC || s.bgRGBA.alpha != DEFAULT_BA)
		sprintf paramStr, "%s,bgRGBA={%d,%d,%d,%d}", paramStr, s.bgRGBA.red, s.bgRGBA.green, s.bgRGBA.blue, s.bgRGBA.alpha
	endif
	
	printf "%sKMScalebar(%s)\r", PRESTR_CMD, paramStr
End


//-------------------------------------------------------------
//	右クリックから
//-------------------------------------------------------------
Static Function/S rightclickDo()
	pnl(WinName(0,1))
End


//=====================================================================================================
//	実行関数
//=====================================================================================================
//	スケールバーを書き込む
Static Function writeBar(String grfName, STRUCT paramStruct &s)

	SetActiveSubWindow $StringFromList(0,grfName,"#")	//	パネルからの実行に備えて
	
	Wave w = SIDAMImageWaveRef(grfName)
	
	//	anchorが空文字の時には、px=0, py=1 になる。つまり、LBが選ばれる。
	int px = s.anchor[0]==82		//	L:0, R:1
	int py = s.anchor[1]!=84		//	B:1, T:0
	
	Variable v0, v1		//	一時使用
	String str
	
	//	表示領域
	STRUCT SIDAMAxisRange as
	SIDAMGetAxis(grfName,NameOfWave(w),as)
	Variable L = as.xmax-as.xmin		//	横幅　(Å)
	s.xmin = as.xmin
	s.xmax = as.xmax
	s.ymin = as.ymin
	s.ymax	 = as.ymax	
	
	//	実際にスケールバーとして表示する長さを求める、単位はÅ
	Variable rawwidth = L*NICEWIDTH*1e-2	//	表示領域のNICEWIDTH(%)の長さ (Å)
	int digit = floor(log(rawwidth))			//	rawwidthの桁数 - 1
	Make/FREE/N=(ItemsInList(NICEVALUES)) nicew = str2num(StringFromList(p,NICEVALUES)), tw
	tw = abs(nicew*10^digit - rawwidth)
	WaveStats/Q/M=1 tw
	Variable nicewidth = nicew[V_minloc]*10^digit	//	rawwidthに近いキリのいい長さ (Å)
	
	//	表示文字列
	String barStr
	if (OVERRIDENM && !CmpStr(WaveUnits(w,0),"\u00c5"))
		barStr = num2str(nicewidth/10)+" nm"
	elseif (strlen(WaveUnits(w,0)))
		barStr = num2str(nicewidth)+" "+WaveUnits(w,0)
	else
		barStr = num2str(nicewidth)
	endif
	
	String fontname = GetDefaultFont(grfName)
	int fontsize = s.fontsize ? s.fontsize : GetDefaultFontSize(grfName,"")
	
	//	表示領域の幅と高さ, 幅は表示文字列幅とスケールバーの長い方
	v0 = FontSizeStringWidth(GetDefaultFont(grfName),\
		fontsize*ScreenResolution/72,0,barStr)*getExpand(grfName)	//	表示文字列の幅, pixel
	v1 = FontSizeHeight(GetDefaultFont(grfName),\
		fontsize*ScreenResolution/72,0)*getExpand(grfName)			//	表示文字列の高さ, pixel
	GetWindow $grfName psizeDC
	Variable boxWidth = max(v0/(V_right-V_left),nicewidth/L) + MARGIN*2
	Variable boxHeight = v1/(V_bottom-V_top) + MARGIN*2 + OFFSET
	
	//	描く
	//	初期化
	SetDrawLayer/W=$grfName ProgFront
	SetDrawEnv/W=$grfName gname=$NAME, gstart
	
	//	背景
	SetDrawEnv/W=$grfName xcoord=prel, ycoord=prel
	SetDrawEnv/W=$grfName fillfgc=(s.bgRGBA.red,s.bgRGBA.green,s.bgRGBA.blue,s.bgRGBA.alpha), linethick=0.00
	DrawRect/W=$grfName px, py, px+boxWidth*(px?-1:1), py+boxHeight*(py?-1:1)
	
	//	背景領域の位置を記録する
	s.box.left = min(px,px+boxWidth*(px?-1:1))
	s.box.right = max(px,px+boxWidth*(px?-1:1))
	s.box.top = min(py,py+boxHeight*(py?-1:1))
	s.box.bottom = max(py,py+boxHeight*(py?-1:1))
	StructPut/S s, str
	SetWindow $grfName userData($NAME)=str
	
	//	棒
	v0 = (px? as.xmax : as.xmin) + (L*boxWidth-nicewidth)/2*(px?-1:1)
	v1 = py + MARGIN*(py?-1:1)
	SetDrawEnv/W=$grfName xcoord=$as.xaxis, ycoord=prel
	SetDrawEnv/W=$grfName linefgc=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha), linethick=LINETHICK
	DrawLine/W=$grfName v0, v1, v0+nicewidth*(px?-1:1), v1
	
	//	数字と単位
	SetDrawEnv/W=$grfName xcoord=prel, ycoord=prel, textxjust=1, textyjust=(py?0:2), fsize=fontsize, fname=fontname
	SetDrawEnv/W=$grfName textrgb=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha)
	v0 = px + boxWidth/2*(px?-1:1)
	v1 = py + (MARGIN+OFFSET)*(py?-1:1)
	DrawText/W=$grfName v0, v1, barStr
	
	//	終了処理
	SetDrawEnv/W=$grfName gstop
	SetDrawLayer/W=$grfName UserFront
End

Static Function getExpand(String grfName)
	STRUCT SIDAMWindowInfo s
	SIDAMGetWindow(grfName, s)
	return s.expand
End

//	スケールバーを消す
Static Function deleteBar(String grfName)
	DrawAction/L=ProgFront/W=$grfName getgroup=$NAME, delete
End


//=====================================================================================================


//******************************************************************************
//	設定用パネル
//******************************************************************************
Static Function pnl(String grfName)
	if (SIDAMWindowExists(grfName+"#Scalebar"))
		return 0
	endif
	
	//  パネル表示
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,135,245)/N=Scalebar as "Scale bar"
	String pnlName = grfName + "#Scalebar"
	
	String settingStr = GetUserData(grfName,"",NAME), anchor
	Variable opacity
	int isDisplayed = strlen(settingStr) > 0
	
	//	コントロールに反映させるために、現在のスケールバー設定値を取得する
	//	スケールバーが表示されていなければデフォルト値を用いる
	STRUCT paramStruct s
	if (isDisplayed)
		StructGet/S s, settingStr
		anchor = num2char(s.anchor[0])+num2char(s.anchor[1])
		SetWindow $pnlName userData(init)=settingStr
	else
		anchor = DEFAULT_ANCHOR
		s.fontsize = DEFAULT_SIZE
		s.fgRGBA.red = DEFAULT_FC;	s.fgRGBA.green = DEFAULT_FC;	s.fgRGBA.blue = DEFAULT_FC;	s.fgRGBA.alpha = DEFAULT_FA
		s.bgRGBA.red = DEFAULT_BC;	s.bgRGBA.green = DEFAULT_BC;	s.bgRGBA.blue = DEFAULT_BC;	s.bgRGBA.alpha = DEFAULT_BA
	endif
	
	//	コントロール
	CheckBox showC pos={6,10}, title="Show scale bar", value=isDisplayed, proc=KMScaleBar#pnlCheck, win=$pnlName
	
	GroupBox anchorG pos={5,33}, size={125,70}, title="Anchor", win=$pnlName	
	CheckBox ltC pos={12,53}, title="LT", value=!CmpStr(anchor,"LT"), help={"Left bottom"}, win=$pnlName
	CheckBox lbC pos={12,79}, title="LB", value=!CmpStr(anchor,"LB"), helP={"Left top"}, win=$pnlName
	CheckBox rtC pos={89,53}, title="RT", value=!CmpStr(anchor,"RT"), side=1, helP={"Right top"}, win=$pnlName
	CheckBox rbC pos={89,79}, title="RB", value=!CmpStr(anchor,"RB"), side=1, helP={"Right bottom"}, win=$pnlName
	
	GroupBox propG pos={5,111}, size={125,95}, title="Properties", win=$pnlName
	SetVariable sizeV pos={18,132}, size={100,18}, title="Text size:", bodyWidth=40, format="%d", win=$pnlName
	SetVariable sizeV value=_NUM:s.fontsize, limits={0,inf,0}, proc=KMScaleBar#pnlSetVar, win=$pnlName
	SetVariable sizeV help={"A value of 0 means the font size of the default font of the graph."}, win=$pnlName
	PopupMenu fgRGBAP pos={24,155}, size={94,19}, title="Fore color:", value=#"\"*COLORPOP*\"", win=$pnlName
	PopupMenu fgRGBAP popColor=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha), win=$pnlName
	PopupMenu fgRGBAP help={"Color for the scale bar"}, win=$pnlName
	PopupMenu bgRGBAP pos={22,179}, size={96,19}, title="Back color:", value=#"\"*COLORPOP*\"", win=$pnlName
	PopupMenu bgRGBAP popColor=(s.bgRGBA.red,s.bgRGBA.green,s.bgRGBA.blue,s.bgRGBA.alpha), win=$pnlName
	PopupMenu bgRGBAP help={"Color for the background of the scale bar"}, win=$pnlName
	Button doB pos={5,215}, title="Do It", size={50,22}, proc=KMScaleBar#pnlButton, win=$pnlName
	Button cancelB pos={70,215}, title="Cancel", size={60,22}, proc=KMScaleBar#pnlButton, win=$pnlName
	
	ModifyControlList "ltC;lbC;rtC;rbC" mode=1, proc=KMScaleBar#pnlCheck, win=$pnlname
	ModifyControlList "fgRGBAP;bgRGBAP" mode=1, bodyWidth=40, proc=KMScaleBar#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	ctrlDisable(pnlName)
	
	SetActiveSubwindow ##
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
	
	String grfName = StringFromList(0,s.win,"#")
	STRUCT paramStruct ps
	
	strswitch (s.ctrlName)
		case "cancelB":
			if (strlen(GetUserData(s.win,"","init")))
				StructGet/S ps, GetUserData(s.win,"","init")
				KMScalebar(grfName=grfName,anchor=num2char(ps.anchor[0])+num2char(ps.anchor[1]),size=ps.fontsize,\
					fgRGBA={ps.fgRGBA.red,ps.fgRGBA.green,ps.fgRGBA.blue,ps.fgRGBA.alpha},\
					bgRGBA={ps.bgRGBA.red,ps.bgRGBA.green,ps.bgRGBA.blue,ps.bgRGBA.alpha})
			else
				KMScalebar(grfName=grfName,anchor="")
			endif
			break
		case "doB":
			StructGet/S ps, GetUserData(grfName,"",NAME)
			echo(grfName,ps)
			break
	endswitch
	
	KillWindow $s.win
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	String grfName = StringFromList(0,s.win,"#")
	
	strswitch (s.ctrlName)
		case "showC":
			ctrlDisable(s.win)
			KMScalebar(grfName=grfName, anchor=SelectString(s.checked,"",getAnchorFromPnl(s.win)))
			break
			
		case "ltC":
		case "lbC":
		case "rtC":
		case "rbC":
			CheckBox ltC value=CmpStr(s.ctrlName,"ltC")==0, win=$s.win
			CheckBox lbC value=CmpStr(s.ctrlName,"lbC")==0, win=$s.win
			CheckBox rtC value=CmpStr(s.ctrlName,"rtC")==0, win=$s.win
			CheckBox rbC value=CmpStr(s.ctrlName,"rbC")==0, win=$s.win
			String ctrlName = s.ctrlName
			KMScaleBar(grfName=grfName,anchor=upperstr(ctrlName[0,1]))
			break
	endswitch
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "sizeV":	
			KMScalebar(grfName=StringFromList(0,s.win,"#"), size=s.dval)
			break
	endswitch
End
//-------------------------------------------------------------
//	ポップアップメニュー
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	String str = s.popStr, listStr = str[1,strlen(s.popStr)-2]
	Make/W/U/N=(ItemsInList(listStr,","))/FREE tw = str2num(StringFromList(p,listStr,","))
	
	strswitch (s.ctrlName)
		case "fgRGBAP":
			KMScalebar(grfName=StringFromList(0,s.win,"#"), fgRGBA=tw)
			break
		case "bgRGBAP":
			KMScalebar(grfName=StringFromList(0,s.win,"#"), bgRGBA=tw)
			break
	endswitch
End

//******************************************************************************
//	パネルコントロール補助
//******************************************************************************
//	各コントロールの表示状態を変更する
Static Function ctrlDisable(String pnlName)
	//	showCの選択状態に応じて一度 disable=0 or 2 を全部に適用してから、適用外のものを直す
	ControlInfo/W=$pnlName showC
	ModifyControlList ControlNameList(pnlName,";","*") disable=(!V_Value)*2, win=$pnlName
	ModifyControlList "showC;doB;cancelB" disable=0, win=$pnlName
End

//	パネルの内容からアンカー位置を返す
Static Function/S getAnchorFromPnl(String pnlName)
	Wave cw = SIDAMGetCtrlValues(pnlName,"ltC;lbC;rtC;rbC")
	WaveStats/Q/M=1 cw
	return StringFromList(V_maxloc,"LT;LB;RT;RB")
End
