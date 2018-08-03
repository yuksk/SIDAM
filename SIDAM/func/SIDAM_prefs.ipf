#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMPrefs

#include "KM Utilities_Panel"		//	For panel
#include "KM Utilities_Control"	//	For panel

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static StrConstant PACKAGE = "SIDAM"
Static StrConstant FILENAME = "SIDAM.bin"
Static Constant ID = 0
Static Constant VERSION = 16


//******************************************************************************
//	Preference structure
//	meaning of each member is written in setInitialValues()
//******************************************************************************
Structure SIDAMPrefs
	uint32		version
	STRUCT		viewer		viewer
	STRUCT		preview	preview
	uchar		fourier[3]
	uint16		export[3]
	double		last
	uchar		precision
	
	float		TopoGainFactor
	float		TopoCorrFactor
EndStructure

Static Structure viewer
	float	width
	uchar	height
EndStructure

Static Structure preview
	STRUCT Rect size
	uint16	column[4]
EndStructure


//******************************************************************************
//	Load preference from the file
//	If it does not exist, set initial values
//******************************************************************************
Function SIDAMLoadPrefs(STRUCT SIDAMPrefs &prefs)
	LoadPackagePreferences/MIS=1 PACKAGE, FILENAME, ID, prefs
	
	//	If correctly loaded, nothing to do is left
	if (!V_flag && V_bytesRead && prefs.version == VERSION)
		return 0
	endif
	
	//	Failed to load or preference file is not found
	if (V_flag || !V_bytesRead)
		putInitialValues(prefs, 1)
		
	//	Older version is found
	elseif (prefs.version < VERSION)
		updatePreference(prefs)
		
	endif
	
	//SIDAMSavePrefs(prefs)
End
//-------------------------------------------------------------
//	Put initial values of the preference to the structure
//	mode 0: put values which can be changed by the panel
//	mode 1: put all
//-------------------------------------------------------------
Static Function putInitialValues(STRUCT SIDAMPrefs &p, int mode)
	
	//	Viewers
	p.viewer.width = 0		//	auto
	p.viewer.height = 1		//	same as width
	
	//	Export Graphics
	p.export[0] = 1
	p.export[1] = 1
	
	if (!mode)
		return 0
	endif
	
	p.version = VERSION
	
	//	For panel of Preview
	p.preview.size.left = 0
	p.preview.size.right = 600
	p.preview.size.top = 0
	p.preview.size.bottom = 500
	p.preview.column[0] = 140		//	width of columns
	p.preview.column[1] = 60
	p.preview.column[2] = 65
	p.preview.column[3] = 250
	
	//	For panel of Fourier transform
	p.fourier[0] = 1		//	subtract, on
	p.fourier[1] = 3		//	output, magnitude
	p.fourier[2] = 21	//	window, none
	
	//	Date and time of last compile
	p.last = DateTime
	
	//	For precision of coordinates in the info bar
	//	0: low (2), 1: height (4)
	p.precision = 0
	
	//	For Topometrix format, this is old
	p.TopoGainFactor = 10		//	divider
	p.TopoCorrFactor = 1.495	//	attenuation factor

End


//******************************************************************************
//	Save, Print
//******************************************************************************
Function SIDAMSavePrefs(STRUCT SIDAMPrefs &prefs)
	SavePackagePreferences PACKAGE, FILENAME, ID, prefs
End

Function SIDAMPrintPrefs()
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	print prefs
End


//******************************************************************************
//	Display panel to set preference values
//******************************************************************************
Function SIDAMPrefsPnl()
	String pnlName = KMNewPanel("KM Preferences",350,270)
	SetWindow $pnlName hook(self)=KMClosePnl
	
	TabControl mTab pos={3,2}, size={347,230}, proc=KMTabControlProc, value=0, focusRing=0, win=$pnlName
	TabControl mTab tabLabel(0)="Window", tabLabel(1)="Export Graphics", win=$pnlName
	
	//	tab 0
	SetVariable sizeV title="width", pos={17,45}, size={104,18}, bodyWidth=70, userData(tab)="0", win=$pnlName
	SetVariable sizeV limits={0,inf,0.1}, focusRing=0, proc=SIDAMPrefs#pnlSetVar, win=$pnlName
	PopupMenu unitsP title="units", pos={133,44}, size={99,19}, bodyWidth=70, win=$pnlName
	PopupMenu unitsP mode=1, popvalue="points", value= #"\"points;inches;cm\"", win=$pnlName
	PopupMenu heightP title="height", pos={14,76}, size={297,19}, bodyWidth=260, win=$pnlName
	PopupMenu heightP value= "Same as width;Plan, 1 * width * (left range / bottom range)"
	ModifyControlList "unitsP;heightP" userData(tab)="0", focusRing=0, proc=SIDAMPrefs#pnlPopup, win=$pnlName
	
	TitleBox windowT title="Width 0 means \"Auto\"", pos={18,207}, win=$pnlName
	TitleBox windowT frame=0,fColor=(30000,30000,30000), userData(tab)="0", win=$pnlName
	
	//	tab 1
	Groupbox formatG title="Format", pos={13,26}, size={325,115}, userData(tab)="1", win=$pnlName
	Variable isWindows = strsearch(StringByKey("OS", IgorInfo(3)),"Windows", 0) != -1
	String formatStr = "\"" + SelectString(isWindows, "Quartz PDF", "Enhanced metafile") + "\""
	PopupMenu format1P title="Trace", pos={24,49}, size={182,20}, value=#formatStr, win=$pnlName
	PopupMenu format2P title="Image", pos={23,83}, size={183,20}, value="PNG Image", win=$pnlName
	PopupMenu resolutionP title="Resolution:", pos={47,110}, size={159,20}, bodyWidth=100, win=$pnlName
	PopupMenu resolutionP value= "Screen;2X Screen;4X Screen;5X Screen;8X Screen;Other DPI", win=$pnlName
	PopupMenu resolutionP userData(tab)="1", focusRing=0, proc=SIDAMPrefs#pnlPopup, win=$pnlName
	PopupMenu dpiP pos={213,110}, size={60,20}, bodyWidth=60, userData(tab)="1", focusRing=0, win=$pnlName
	PopupMenu dpiP value= "72;75;96;100;120;150;200;300;400;500;600;750;800;1000;1200;1500;2000;2400;2500;3000;3500;3600;4000;4500;4800", win=$pnlName
	ModifyControlList "format1P;format2P" bodyWidth=150, mode=1, userData(tab)="1", focusRing=0, win=$pnlName
	
	GroupBox transparentG title="Transparent background(s)", pos={13,150}, size={325,45}, userData(tab)="1", win=$pnlName
	CheckBox graphC title="Graph", pos={24,171}, win=$pnlName
	CheckBox windowC title="Window", pos={90,171}, win=$pnlName
	CheckBox bothC title="Both", pos={166,171}, win=$pnlName
	ModifyControlList "graphC;windowC;bothC" mode=1, userData(tab)="1", focusRing=0, proc=SIDAMPrefs#pnlCheckbox, win=$pnlName
	
	TitleBox exportT title="Format for exporting graphics with transparent background", pos={18,207}, win=$pnlName
	TitleBox exportT frame=0,fColor=(30000,30000,30000), userData(tab)="1", win=$pnlName
	
	//	outside of tabs
	Button doB title="Set Prefs", pos={10,240}, size={80,22}, win=$pnlName
	Button revertB title="Revert to Defaults", pos={105,240}, size={120,22}, win=$pnlName
	Button cancelB title="Cancel", pos={270,240}, size={70,22}, win=$pnlName
	ModifyControlList "doB;revertB;cancelB" focusRing=0, proc=SIDAMPrefs#pnlButton, win=$pnlName
	
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	setPresentValues(prefs, pnlName)
	
	KMTabControlInitialize(pnlName,"mTab")
End

Static Function setPresentValues(STRUCT SIDAMPrefs &prefs, String pnlName)
	SetVariable sizeV value=_NUM:prefs.viewer.width, userData(value)=num2str(prefs.viewer.width), win=$pnlName
	PopupMenu heightP mode=prefs.viewer.height, userData(value)=num2str(prefs.viewer.height), win=$pnlName
	PopupMenu resolutionP mode=prefs.export[0], win=$pnlName
	PopupMenu dpiP mode=1, popvalue=num2str(prefs.export[1]), disable=(prefs.export[0]!=6), win=$pnlName
	CheckBox graphC value=(prefs.export[2]==0), win=$pnlName
	CheckBox windowC value=(prefs.export[2]==1), win=$pnlName
	CheckBox bothC value=(prefs.export[2]==2), win=$pnlName
End


//******************************************************************************
//	Controls
//******************************************************************************
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

Static Function pnlCheckbox(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	CheckBox graphC value=0, win=$s.win
	CheckBox windowC value=0, win=$s.win
	CheckBox bothC value=0, win=$s.win
	
	CheckBox $s.ctrlName value=1, win=$s.win
End

Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	STRUCT SIDAMPrefs prefs
	SIDAMLoadPrefs(prefs)
	
	strswitch (s.ctrlName)
		case "revertB":
			putInitialValues(prefs, 0)
			setPresentValues(prefs, s.win)
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
//	"Do" button 
//-------------------------------------------------------------
Static Function pnlDo(STRUCT SIDAMPrefs &prefs, String pnlName)

	//	width and height of viewer	
	Wave cw = KMGetCtrlValues(pnlName, "unitsP;sizeV;heightP;resolutionP")
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
	
	//	export
	prefs.export[0] = cw[3]
	ControlInfo/W=$pnlName dpiP
	prefs.export[1] = str2num(S_Value)
	
	Wave cw = KMGetCtrlValues(pnlName, "graphC;windowC;bothC")
	cw *= p
	prefs.export[2] = sum(cw)
	
	SIDAMSavePrefs(prefs)
End


//******************************************************************************
//	Backward compatibility
//******************************************************************************
Static Function updatePreference(STRUCT SIDAMPrefs &prefs)
	switch (prefs.version)
		case 15:
			update15to16(prefs)
			break
		default:
			putInitialValues(prefs, 1)
	endswitch
End

Static Function update15to16(STRUCT SIDAMPrefs &p)
	putInitialValues(p, 1)
	
	STRUCT SIDAMPrefs15 old
	LoadPackagePreferences PACKAGE, FILENAME, ID, old
	
	p.viewer.width = old.viewer.width
	p.viewer.height = old.viewer.height
	p.export[0] = old.export[0]
	p.export[1] = old.export[1]
	p.preview.size.left = old.preview.size.left
	p.preview.size.right = old.preview.size.right 
	p.preview.size.top = old.preview.size.top
	p.preview.size.bottom = old.preview.size.bottom
	p.preview.column[0] = old.preview.column[0]
	p.preview.column[1] = old.preview.column[1]
	p.preview.column[2] = old.preview.column[2]
	p.preview.column[3] = old.preview.column[3]
	p.fourier[0] = old.fourier[0]
	p.fourier[1] = old.fourier[1]
	p.fourier[2] = old.fourier[2]
End

Static Structure SIDAMPrefs15
	uint32		version
	STRUCT		viewer		viewer
	STRUCT		preview	preview
	uchar		fourier[3]
	uint16		export[3]
	double		last
	
	float		TopoGainFactor
	float		TopoCorrFactor
EndStructure