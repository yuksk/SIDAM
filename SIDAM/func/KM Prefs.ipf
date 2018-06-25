#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMPrefs

#include "KM Utilities_Panel"		//	パネル表示で必要になる
#include "KM Utilities_Control"	//	同上

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant ks_PackageName = "Kohsaka Macro"
Static StrConstant ks_PrefsFileName = "KM.bin"
Static Constant k_PrefsRecordID = 0
Static Constant k_prefsVersion = 15


//******************************************************************************
//	初期設定構造体
//******************************************************************************
Structure KMPrefs
	uint32		version
	STRUCT		viewer		viewer
	STRUCT		preview	preview	//	Preview パネル
	uchar		fourier[3]			//	Fourier transform パネル, subtract, output type, window
	uint16		export[3]				//	Export Graphics の PNG resolution, transparent background
	double		last					//	最後にコンパイルされた日時
	
	//	以下は古いが残してある
	float		TopoGainFactor		//  Topometrixファイル, 分圧器
	float		TopoCorrFactor		//  Topometrixファイル, 減衰係数
EndStructure

Static Structure viewer
	float	width
	uchar	height
EndStructure

Static Structure preview
	STRUCT Rect size
	uint16	column[4]	//	コラム幅
EndStructure

//******************************************************************************
//	設定読み込み
//	無ければ、あるいは古ければ、初期値を入れる
//******************************************************************************
Function KMLoadPrefs(prefs)
	STRUCT KMPrefs &prefs
	
	LoadPackagePreferences/MIS=1 ks_PackageName, ks_PrefsFileName, k_PrefsRecordID, prefs
	
	//	設定ファイルの読み込みに失敗した場合、そもそも存在しない場合、設定ファイルのバージョンが
	//	異なっている場合には、初期値を用いて設定ファイルを作成する
	if (V_flag || !V_bytesRead || prefs.version != k_prefsVersion)
		KMSetPrefsInit(prefs, 1)
		//	新しいバージョンのファイルが古いバージョンのファイルよりも小さい場合には、正しく書き込まれないためか
		//	読み込みエラーが繰り返される。それを防ぐため、古いファイルはいったん削除する。
		DeleteFile/Z SpecialDirPath("Packages", 0, 0, 0) + ks_PackageName + ":" + ks_PrefsFileName
		KMSavePrefs(prefs)
	endif
End
//-------------------------------------------------------------
//	初期値を入れる
//	mode 0: パネルから変更可能な項目の初期値を代入
//	mode 1: 全代入
//-------------------------------------------------------------
Static Function KMSetPrefsInit(STRUCT KMPrefs &p, int mode)
	
	//	Viewers
	p.viewer.width = 0		//	auto
	p.viewer.height = 1		//	same as width
	
	//	Export Graphics
	p.export[0] = 1
	p.export[1] = 1
	
	if (!mode)
		return 0
	endif
	
	p.version = k_prefsVersion
	
	//	Previewパネル
	p.preview.size.left = 0
	p.preview.size.right = 600
	p.preview.size.top = 0
	p.preview.size.bottom = 500
	p.preview.column[0] = 140
	p.preview.column[1] = 60
	p.preview.column[2] = 65
	p.preview.column[3] = 250
	
	p.last = DateTime
	
	//	Fourier transformパネル
	p.fourier[0] = 1	//	subtract, on
	p.fourier[1] = 3	//	output, magnitude
	p.fourier[2] = 21	//	window, none
	
	//	Topometrixファイル
	p.TopoGainFactor = 10
	p.TopoCorrFactor = 1.495

End


//******************************************************************************
//	設定保存
//******************************************************************************
Function KMSavePrefs(STRUCT KMPrefs &prefs)
	SavePackagePreferences ks_PackageName, ks_PrefsFileName, k_PrefsRecordID, prefs
End


//******************************************************************************
//	設定表示
//******************************************************************************
Function KMPrintPrefs()
	STRUCT KMPrefs prefs
	KMLoadPrefs(prefs)
	print prefs
End


//******************************************************************************
//	パネル表示
//******************************************************************************
Function KMPrefsPnl()
	String pnlName = KMNewPanel("KM Preferences",350,270)
	SetWindow $pnlName hook(self)=KMClosePnl
	
	TabControl mTab pos={3,2}, size={347,230}, proc=KMTabControlProc, value=0, focusRing=0, win=$pnlName
	TabControl mTab tabLabel(0)="Window", tabLabel(1)="Export Graphics", win=$pnlName
	
	//	tab 0
	SetVariable sizeV title="width", pos={17,45}, size={104,18}, bodyWidth=70, userData(tab)="0", win=$pnlName
	SetVariable sizeV limits={0,inf,0.1}, focusRing=0, proc=KMPrefs#pnlSetVar, win=$pnlName
	PopupMenu unitsP title="units", pos={133,44}, size={99,19}, bodyWidth=70, win=$pnlName
	PopupMenu unitsP mode=1, popvalue="points", value= #"\"points;inches;cm\"", win=$pnlName
	PopupMenu heightP title="height", pos={14,76}, size={297,19}, bodyWidth=260, win=$pnlName
	PopupMenu heightP value= "Same as width;Plan, 1 * width * (left range / bottom range)"
	ModifyControlList "unitsP;heightP" userData(tab)="0", focusRing=0, proc=KMPrefs#pnlPopup, win=$pnlName
	
	TitleBox windowT title="Width 0 means \"Auto\"", pos={18,207}, win=$pnlName
	TitleBox windowT frame=0,fColor=(30000,30000,30000), userData(tab)="0", win=$pnlName
	
	//	tab 1
	Groupbox formatG title="Format", pos={13,26}, size={325,115}, userData(tab)="1", win=$pnlName
	Variable isWindows = strsearch(StringByKey("OS", IgorInfo(3)),"Windows", 0) != -1
	String formatStr = "\"" + SelectString(isWindows, "Quartz PDF", "Enhanced metafile") + "\""
	PopupMenu format1P title="Trace", pos={24,49}, size={182,20}, value=#formatStr, win=$pnlName
	PopupMenu format2P title="Image", pos={23,83}, size={183,20}, value="PNG Image", win=$pnlName
	PopupMenu resolutionP title="Resolution:", pos={47,110}, size={159,20}, bodyWidth=100, userData(tab)="1", focusRing=0, win=$pnlName
	PopupMenu resolutionP value= "Screen;2X Screen;4X Screen;5X Screen;8X Screen;Other DPI", proc=KMPrefs#pnlPopup, win=$pnlName
	PopupMenu dpiP pos={213,110}, size={60,20}, bodyWidth=60, userData(tab)="1", focusRing=0, win=$pnlName
	PopupMenu dpiP value= "72;75;96;100;120;150;200;300;400;500;600;750;800;1000;1200;1500;2000;2400;2500;3000;3500;3600;4000;4500;4800", win=$pnlName
	ModifyControlList "format1P;format2P" bodyWidth=150, mode=1, userData(tab)="1", focusRing=0, win=$pnlName
	
	GroupBox transparentG title="Transparent background(s)", pos={13,150}, size={325,45}, userData(tab)="1", win=$pnlName
	CheckBox graphC title="Graph", pos={24,171}, win=$pnlName
	CheckBox windowC title="Window", pos={90,171}, win=$pnlName
	CheckBox bothC title="Both", pos={166,171}, win=$pnlName
	ModifyControlList "graphC;windowC;bothC" mode=1, userData(tab)="1", focusRing=0, proc=KMPrefs#pnlCheckbox, win=$pnlName
	
	TitleBox exportT title="Format for exporting graphics with transparent background", pos={18,207}, win=$pnlName
	TitleBox exportT frame=0,fColor=(30000,30000,30000), userData(tab)="1", win=$pnlName
	
	//	タブ外
	Button doB title="Set Prefs", pos={10,240}, size={80,22}, win=$pnlName
	Button revertB title="Revert to Defaults", pos={105,240}, size={120,22}, win=$pnlName
	Button cancelB title="Cancel", pos={270,240}, size={70,22}, win=$pnlName
	ModifyControlList "doB;revertB;cancelB" focusRing=0, proc=KMPrefs#pnlButton, win=$pnlName
	
	STRUCT KMPrefs prefs
	KMLoadPrefs(prefs)
	pnlSetValues(prefs, pnlName)
	
	KMTabControlInitialize(pnlName,"mTab")
End

//-------------------------------------------------------------
//	設定値をパネルの表示状態に反映
//-------------------------------------------------------------
Static Function pnlSetValues(STRUCT KMPrefs &prefs, String pnlName)
	SetVariable sizeV value=_NUM:prefs.viewer.width, userData(value)=num2str(prefs.viewer.width), win=$pnlName
	PopupMenu heightP mode=prefs.viewer.height, userData(value)=num2str(prefs.viewer.height), win=$pnlName
	PopupMenu resolutionP mode=prefs.export[0], win=$pnlName
	PopupMenu dpiP mode=1, popvalue=num2str(prefs.export[1]), disable=(prefs.export[0]!=6), win=$pnlName
	CheckBox graphC value=(prefs.export[2]==0), win=$pnlName
	CheckBox windowC value=(prefs.export[2]==1), win=$pnlName
	CheckBox bothC value=(prefs.export[2]==2), win=$pnlName
End


//******************************************************************************
//	パネルコントロール
//******************************************************************************
//-------------------------------------------------------------
//	ポップアップ
//-------------------------------------------------------------
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "unitsP":
			Variable value = str2num(GetUserData(s.win, "sizeV", "value"))
			strswitch (s.popStr)
				case "points":
					SetVariable sizeV value=_NUM:value, win=$s.win
					break
				case "inches":
					SetVariable sizeV value=_NUM:value/72, win=$s.win
					break
				case "cm":
					SetVariable sizeV value=_NUM:value/72*2.54, win=$s.win
					break
			endswitch
			break
		case "resolutionP":
			PopupMenu dpiP disable=(CmpStr(s.popStr, "Other DPI")!=0), win=$s.win
			break
		default:
	endswitch
End
//-------------------------------------------------------------
//	値設定
//-------------------------------------------------------------
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	ControlInfo/W=$s.win unitsP
	strswitch (S_Value)
		case "points":
			SetVariable $s.ctrlName userData(value)=num2str(s.dval), win=$s.win
			break
		case "inches":
			SetVariable $s.ctrlName userData(value)=num2str(s.dval*72), win=$s.win
			break
		case "cm":
			SetVariable $s.ctrlName userData(value)=num2str(s.dval/2.54*72), win=$s.win
			break
	endswitch
End
//-------------------------------------------------------------
//	チェックボックス
//-------------------------------------------------------------
Static Function pnlCheckbox(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	CheckBox graphC value=0, win=$s.win
	CheckBox windowC value=0, win=$s.win
	CheckBox bothC value=0, win=$s.win
	
	CheckBox $s.ctrlName value=1, win=$s.win
End
//-------------------------------------------------------------
//		ボタン
//-------------------------------------------------------------
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	STRUCT KMPrefs prefs
	KMLoadPrefs(prefs)
	
	strswitch (s.ctrlName)
		case "revertB":
			KMSetPrefsInit(prefs, 0)
			pnlSetValues(prefs, s.win)
			break
		case "doB":
			pnlDo(prefs, s.win)
			// *** THROUGH ***
		case "cancelB":
			KillWindow $s.win
			break
		default:
	endswitch
End

//-------------------------------------------------------------
//	設定値代入実行関数
//-------------------------------------------------------------
Static Function pnlDo(STRUCT KMPrefs &prefs, String pnlName)
	
	Wave cw = KMGetCtrlValues(pnlName, "unitsP;sizeV;heightP;resolutionP")
	
	//	幅・高さ
	switch (cw[0])
		case 1:	//	point
			prefs.viewer.width = cw[1]
			break
		case 2:	//	inch
			prefs.viewer.width = cw[1] * 72
			break
		case 3:	//	cm
			prefs.viewer.width = cw[1] * 72 / 2.54
			break
	endswitch
	prefs.viewer.height = cw[2]
	
	//	解像度
	prefs.export[0] = cw[3]
	ControlInfo/W=$pnlName dpiP
	prefs.export[1] = str2num(S_Value)
	
	//	背景
	Wave cw = KMGetCtrlValues(pnlName, "graphC;windowC;bothC")
	cw *= p
	prefs.export[2] = sum(cw)
	
	KMSavePrefs(prefs)
End