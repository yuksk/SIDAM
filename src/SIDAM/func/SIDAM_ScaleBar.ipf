#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMScaleBar

#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"
#include "SIDAM_Compatibility_ScaleBar"	//	backward compatibility

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//	Default values of variable values that can be chosen by users
Static StrConstant DEFAULT_ANCHOR = "LB"	//	position, LB, LT, RB, RT
Static Constant DEFAULT_SIZE = 0				//	font size (pt)
Static Constant DEFAULT_FC = 0				//	color of characters (0,0,0)
Static Constant DEFAULT_BC = 65535			//	color of background (65535,65535,65535)
Static Constant DEFAULT_FA = 65535			//	opacity of characters
Static Constant DEFAULT_BA = 39321			//	opacity of background 65535*0.6 = 39321
Static Constant DEFAULT_PREFIX = 1			//	use a prefix

//	Fixed values
Static Constant NICEWIDTH = 20				//	Width of scale bar is about 20% of a window
Static Constant MARGIN = 0.02					//	Position from the edge
Static Constant OFFSET = 0.015				//	Space between the bar and characters
Static Constant LINETHICK = 3					//	Thickness of the bar
Static Constant DOUBLECLICK = 20				//	Interval between clicks to recognize double-click
Static StrConstant NICEVALUES = "1;2;3;5"	//	Definition of "nice" values

//	Internal use
Static StrConstant NAME = "SIDAMScalebar"

//@
//	Show a scale bar.
//
//	## Parameters
//	grfName : string, default `WinName(0,1)`
//		The name of a window.
//	anchor : string, {"LB", "LT", "RB", or "RT"}
//		The position of the scale bar. If empty, delete the scale bar.
//	size : int
//		The font size (pt).
//	fgRGBA : wave
//		The foreground color.
//	bgRGBA : wave
//		The background color.
//	prefix: int {0 or !0}, default 1
//		Set !0 to use a prefix such as k and m.
//@
Function SIDAMScalebar([String grfName, String anchor, int size,
	Wave fgRGBA, Wave bgRGBA, int prefix])
	
	grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1))
	anchor = SelectString(ParamIsDefault(anchor), anchor, "")
	if (validate(grfName, anchor))
		return 0
	endif
	
	STRUCT paramStruct s
	s.overwrite[0] = !ParamIsDefault(anchor)
	s.overwrite[1] = !ParamIsDefault(size)
	s.overwrite[2] = !ParamIsDefault(fgRGBA)
	s.overwrite[3] = !ParamIsDefault(bgRGBA)
	s.overwrite[4] = !ParamIsDefault(prefix)
	initializeParamStruct(s, grfName, anchor, size, fgRGBA, bgRGBA, prefix)

	//	If the anchor is empty, delete the scale bar
	if (!s.anchor[0] && !s.anchor[1])
		deleteBar(grfName)
		return 0
	endif

	//	Delete the scale bar if it is already shown, then
	//	show a new bar
	if (strlen(GetUserData(grfName,"",NAME))>0)
		deleteBar(grfName)
	endif
	writeBar(grfName,s)
End

Static Function validate(String grfName, String anchor)
	String errMsg = PRESTR_CAUTION + "SIDAMScalebar gave error: "
	
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
	
	String anchors = "LB;LT;RB;RT"
	if (strlen(anchor) && WhichListItem(anchor, anchors) < 0)
		printf "%sthe anchor must be one of %s.\r", errMsg, anchors
		return 1
	endif
	
	return 0
End

Static Function initializeParamStruct(STRUCT paramStruct &s, String grfName,
	String anchor, int size, Wave/Z fgRGBA, Wave/Z bgRGBA, int prefix)

	Make/B/U/N=5/FREE overwrite = s.overwrite[p]

	//	Use the present value if a scale bar is displayed.
	//	If not, use the default values.
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
		s.prefix = DEFAULT_PREFIX
	endif

	//	If a parameter is specified in the main function,
	//	overwrite with the value.
	if (overwrite[0])
		s.anchor[0] = strlen(anchor) ? char2num(anchor[0]) : 0
		s.anchor[1] = strlen(anchor) ? char2num(anchor[1]) : 0
	endif
	
	if (overwrite[1])
		s.fontsize = limit(size,0,inf)
	endif

	try
		if (overwrite[2])
			s.fgRGBA.red = fgRGBA[0]; 	AbortOnRTE
			s.fgRGBA.green = fgRGBA[1];	AbortOnRTE
			s.fgRGBA.blue = fgRGBA[2];	AbortOnRTE
			s.fgRGBA.alpha = numpnts(fgRGBA)>3 ? fgRGBA[3] : 65535
		endif
		if (overwrite[3])
			s.bgRGBA.red = bgRGBA[0]; 	AbortOnRTE
			s.bgRGBA.green = bgRGBA[1];	AbortOnRTE
			s.bgRGBA.blue = bgRGBA[2]; 	AbortOnRTE
			s.bgRGBA.alpha = numpnts(bgRGBA)>3 ? bgRGBA[3] : 65535
		endif
	catch
		Variable err = GetRTError(1)
		String msg = PRESTR_CAUTION + "SIDAMScalebar gave error: "
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
	
	if (overwrite[4])
		s.prefix = prefix
	endif
End

Static Structure paramStruct
	//	for input
	uchar	anchor[2]
	uint16	fontsize
	STRUCT	RGBAColor	fgRGBA
	STRUCT	RGBAColor	bgRGBA
	uchar	prefix
	//	for internal use
	uchar overwrite[5]
	STRUCT	RectF box
	double	xmin, xmax, ymin, ymax
	double	ticks
EndStructure

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
			//	Open the panel by double-clicking the scale bar
			if (ps.ticks == 0)
				break
			elseif (s.ticks-ps.ticks < DOUBLECLICK && isClickedInside(ps.box,s))
				pnl(s.winName)
				//	Suppress opening the panel of "Modify Trace Appearance"
				returnCode = 1
			endif
			ps.ticks = 0	//	Clear the event of the first click
			StructPut/S ps, str
			SetWindow $s.winName userData($NAME)=str
			break
			
		case 5:	//	mouseup
			//	Record the event of first click to open the panel by
			//	double-clicking the scale bar.
			if (ps.ticks == 0 && isClickedInside(ps.box,s))
				ps.ticks = s.ticks
				StructPut/S ps, str
				SetWindow $s.winName userData($NAME)=str
			endif
			break
			
		case 8: 	//	modified
			//	Do nothing unless a change is made in the displayed area
			STRUCT SIDAMAxisRange as
			SIDAMGetAxis(s.winName,StringFromList(0,ImageNameList(s.winName,";")),as)
			if (as.x.min.value==ps.xmin && as.x.max.value==ps.xmax \
				&& as.y.min.value==ps.ymin && as.y.max.value==ps.ymax)
				break
			endif
			//	*** FALLTHROUGH ***
			
		case 6:	//	resized
			SIDAMScalebar(grfName=s.winName)
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

Static Function echo(String grfName, STRUCT paramStruct &s)
	String paramStr = "grfName=\"" + grfName + "\""
	
	if (!s.anchor[0] && !s.anchor[1])
		printf "%sSIDAMScalebar(%s,anchor=\"\")\r", PRESTR_CMD, paramStr
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
	
	printf "%sSIDAMScalebar(%s)\r", PRESTR_CMD, paramStr
End

Static Function/S menuDo()
	pnl(WinName(0,1))
End


//******************************************************************************
//	Draw a scale bar
//******************************************************************************
Static Function writeBar(String grfName, STRUCT paramStruct &s)

	SetActiveSubWindow $StringFromList(0,grfName,"#")
	
	Wave w = SIDAMImageNameToWaveRef(grfName)
	
	//	If the anchor is empty, px=0 and py=1, that is LB.
	int px = s.anchor[0]==82		//	L:0, R:1
	int py = s.anchor[1]!=84		//	B:1, T:0
	
	Variable v0, v1
	String str
	
	//	The area of scale bar
	STRUCT SIDAMAxisRange as
	SIDAMGetAxis(grfName,NameOfWave(w),as)
	Variable L = as.x.max.value - as.x.min.value		//	width (scaling value)
	s.xmin = as.x.min.value
	s.xmax = as.x.max.value
	s.ymin = as.y.min.value
	s.ymax = as.y.max.value
	
	//	Decide the length of scale bar
	//	NICEWIDTH(%) of the scale bar area (scaling value)
	Variable rawwidth = L*NICEWIDTH*1e-2
	int digit = floor(log(rawwidth))		//	number of digits of rawwidth - 1
	Make/FREE/N=(ItemsInList(NICEVALUES)) nicew = str2num(StringFromList(p,NICEVALUES)), tw
	tw = abs(nicew*10^digit - rawwidth)
	WaveStats/Q/M=1 tw
	//	A "nice value" close to rawwidth (scaling value)
	Variable nicewidth = nicew[V_minloc]*10^digit
	
	//	Numbers to be displayed
	String barStr
	int existUnit = strlen(WaveUnits(w,0))
	if (existUnit && s.prefix)
		sprintf barStr, "%.0W1P%s", nicewidth, WaveUnits(w,0)
	elseif (existUnit && !s.prefix)
		barStr = num2str(nicewidth)+" "+WaveUnits(w,0)
	elseif (!existUnit && s.prefix)
		sprintf barStr, "%.0W0P", nicewidth
	else
		barStr = num2str(nicewidth)
	endif
	
	String fontname = GetDefaultFont(grfName)
	int fontsize = s.fontsize ? s.fontsize : GetDefaultFontSize(grfName,"")
	
	//	Height and width of the scale bar area
	//	Width of displayed numbers, pixel
	v0 = FontSizeStringWidth(GetDefaultFont(grfName),\
		fontsize*ScreenResolution/72,0,barStr)*getExpand(grfName)
	//	Height of displayed numbers, pixel
	v1 = FontSizeHeight(GetDefaultFont(grfName),\
		fontsize*ScreenResolution/72,0)*getExpand(grfName)
	GetWindow $grfName psizeDC
	//	The longer one of the bar and the numbers is used as the width
	Variable boxWidth = max(v0/(V_right-V_left),nicewidth/L) + MARGIN*2
	Variable boxHeight = v1/(V_bottom-V_top) + MARGIN*2 + OFFSET
	
	//	Draw the scale bar
	//	Initialize
	stopUpdateBar(grfName)
	SetDrawLayer/W=$grfName ProgFront
	SetDrawEnv/W=$grfName gname=$NAME, gstart
	
	//	Background
	SetDrawEnv/W=$grfName xcoord=prel, ycoord=prel
	SetDrawEnv/W=$grfName fillfgc=(s.bgRGBA.red,s.bgRGBA.green,s.bgRGBA.blue,s.bgRGBA.alpha), linethick=0.00
	DrawRect/W=$grfName px, py, px+boxWidth*(px?-1:1), py+boxHeight*(py?-1:1)
	
	//	Record the position of the background
	s.box.left = min(px,px+boxWidth*(px?-1:1))
	s.box.right = max(px,px+boxWidth*(px?-1:1))
	s.box.top = min(py,py+boxHeight*(py?-1:1))
	s.box.bottom = max(py,py+boxHeight*(py?-1:1))
	StructPut/S s, str
	SetWindow $grfName userData($NAME)=str
	
	//	Bar
	v0 = (px? as.x.max.value : as.x.min.value) + (L*boxWidth-nicewidth)/2*(px?-1:1)
	v1 = py + MARGIN*(py?-1:1)
	SetDrawEnv/W=$grfName xcoord=$as.xaxis, ycoord=prel
	SetDrawEnv/W=$grfName linefgc=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha), linethick=LINETHICK
	DrawLine/W=$grfName v0, v1, v0+nicewidth*(px?-1:1), v1
	
	//	Number and unit
	SetDrawEnv/W=$grfName xcoord=prel, ycoord=prel, textxjust=1, textyjust=(py?0:2), fsize=fontsize, fname=fontname
	SetDrawEnv/W=$grfName textrgb=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha)
	v0 = px + boxWidth/2*(px?-1:1)
	v1 = py + (MARGIN+OFFSET)*(py?-1:1)
	DrawText/W=$grfName v0, v1, barStr

	//	Finalize	
	SetDrawEnv/W=$grfName gstop
	SetDrawLayer/W=$grfName UserFront
	resumeUpdateBar(grfName)
End

Static Function getExpand(String grfName)
	STRUCT SIDAMWindowInfo s
	SIDAMGetWindow(grfName, s)
	return s.expand
End

Static Function deleteBar(String grfName)
	stopUpdateBar(grfName)
	DrawAction/L=ProgFront/W=$grfName getgroup=$NAME, delete
	KMScaleBar#deleteBar(grfName)	//	backward compatibility
End

Static Function stopUpdateBar(String grfName)
	SetWindow $grfName hook($NAME)=$""
	SetWindow $grfName userData($NAME)=""
	DoUpdate/W=$grfName
End

Static Function resumeUpdateBar(String grfName)
	SetWindow $grfName hook($NAME)=SIDAMScaleBar#hook
	DoUpdate/W=$grfName
End


//******************************************************************************
//	show panel
//******************************************************************************
Static Function pnl(String grfName)
	String pnlName = grfName + "#Scalebar"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,135,270)/N=Scalebar as "Scale bar"
	
	String settingStr = GetUserData(grfName,"",NAME), anchor
	Variable opacity
	int isDisplayed = strlen(settingStr) > 0
	
	//	Use the present value if a scale bar is displayed.
	//	If not, use the default values.
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
		s.prefix = DEFAULT_PREFIX
	endif
	
	CheckBox showC pos={6,9}, title="Show scale bar", win=$pnlName
	CheckBox showC value=isDisplayed, proc=SIDAMScaleBar#pnlCheck, win=$pnlName
	CheckBox prefixC pos={6,34}, title="Use a prefix (\u03bc, n, ...)", win=$pnlName
	CheckBox prefixC value=s.prefix, proc=SIDAMScaleBar#pnlCheck, win=$pnlName
	
	GroupBox anchorG pos={5,58}, size={125,70}, title="Anchor", win=$pnlName	
	CheckBox ltC pos={12,78}, title="LT", value=!CmpStr(anchor,"LT"), win=$pnlName
	CheckBox lbC pos={12,104}, title="LB", value=!CmpStr(anchor,"LB"), win=$pnlName
	CheckBox rtC pos={89,78}, title="RT", value=!CmpStr(anchor,"RT"), side=1, win=$pnlName
	CheckBox rbC pos={89,104}, title="RB", value=!CmpStr(anchor,"RB"), side=1, win=$pnlName
	
	GroupBox propG pos={5,136}, size={125,95}, title="Properties", win=$pnlName
	SetVariable sizeV pos={18,157}, size={100,18}, title="Text size:", win=$pnlName
	SetVariable sizeV bodyWidth=40, format="%d", limits={0,inf,0}, win=$pnlName
	SetVariable sizeV value=_NUM:s.fontsize, proc=SIDAMScaleBar#pnlSetVar, win=$pnlName
	PopupMenu fgRGBAP pos={24,180}, size={94,19}, win=$pnlName
	PopupMenu fgRGBAP title="Fore color:", value=#"\"*COLORPOP*\"", win=$pnlName
	PopupMenu fgRGBAP popColor=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha), win=$pnlName
	PopupMenu bgRGBAP pos={22,204}, size={96,19}, win=$pnlName
	PopupMenu bgRGBAP title="Back color:", value=#"\"*COLORPOP*\"", win=$pnlName
	PopupMenu bgRGBAP popColor=(s.bgRGBA.red,s.bgRGBA.green,s.bgRGBA.blue,s.bgRGBA.alpha), win=$pnlName

	Button doB pos={5,240}, title="Do It", size={50,22}, proc=SIDAMScaleBar#pnlButton, win=$pnlName
	Button cancelB pos={70,240}, title="Cancel", size={60,22}, proc=SIDAMScaleBar#pnlButton, win=$pnlName
	
	ModifyControlList "ltC;lbC;rtC;rbC" mode=1, proc=SIDAMScaleBar#pnlCheck, win=$pnlname
	ModifyControlList "fgRGBAP;bgRGBAP" mode=1, bodyWidth=40, proc=SIDAMScaleBar#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	Make/T/N=(2,9)/FREE helpw
	String helpstr_check = "Check to show the scale bar at the "
	helpw[][0] = {"showC", "Check to show and uncheck to remove the scale bar."}
	helpw[][1] = {"prefixC", "Check to use a prefix such as n and \\u03bc."}
	helpw[][2] = {"ltC", helpstr_check+"left-top corner."}
	helpw[][3] = {"lbC", helpstr_check+"left-bottom corner."}
	helpw[][4] = {"rtC", helpstr_check+"right-top corner."}
	helpw[][5] = {"rbC", helpstr_check+"right-bottom corner."}
	helpw[][6] = {"sizeV", "Enter the font size. When 0, the default font size is used."}
	helpw[][7] = {"fgRGBAP", "Select the foreground color of the scale bar."}
	helpw[][8] = {"bgRGBAP", "Select the background color of the scale bar."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	ctrlDisable(pnlName)
	
	SetActiveSubwindow $grfName
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Button
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
				SIDAMScalebar(grfName=grfName,\
					anchor=num2char(ps.anchor[0])+num2char(ps.anchor[1]),size=ps.fontsize,\
					fgRGBA={ps.fgRGBA.red,ps.fgRGBA.green,ps.fgRGBA.blue,ps.fgRGBA.alpha},\
					bgRGBA={ps.bgRGBA.red,ps.bgRGBA.green,ps.bgRGBA.blue,ps.bgRGBA.alpha},\
					prefix=ps.prefix)
			else
				SIDAMScalebar(grfName=grfName,anchor="")
			endif
			break
		case "doB":
			StructGet/S ps, GetUserData(grfName,"",NAME)
			echo(grfName,ps)
			break
	endswitch
	
	KillWindow $s.win
End

//	Checkbox
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	String grfName = StringFromList(0,s.win,"#")
	
	strswitch (s.ctrlName)
		case "showC":
			ctrlDisable(s.win)
			SIDAMScalebar(grfName=grfName, anchor=SelectString(s.checked,\
				"",getAnchorFromPnl(s.win)))
			break
		case "prefixC":
			SIDAMScalebar(grfName=grfName,prefix=s.checked)
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
			SIDAMScalebar(grfName=grfName,anchor=upperstr(ctrlName[0,1]))
			break
	endswitch
End

//	Setvariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "sizeV":	
			SIDAMScalebar(grfName=StringFromList(0,s.win,"#"), size=s.dval)
			break
	endswitch
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	String str = s.popStr, listStr = str[1,strlen(s.popStr)-2]
	Make/W/U/N=(ItemsInList(listStr,","))/FREE tw = str2num(StringFromList(p,listStr,","))
	
	strswitch (s.ctrlName)
		case "fgRGBAP":
			SIDAMScalebar(grfName=StringFromList(0,s.win,"#"), fgRGBA=tw)
			break
		case "bgRGBAP":
			SIDAMScalebar(grfName=StringFromList(0,s.win,"#"), bgRGBA=tw)
			break
	endswitch
End

//******************************************************************************
//	Helper funcitons for control
//******************************************************************************
Static Function ctrlDisable(String pnlName)
	ControlInfo/W=$pnlName showC
	ModifyControlList ControlNameList(pnlName,";","*") disable=(!V_Value)*2, win=$pnlName
	ModifyControlList "showC;doB;cancelB" disable=0, win=$pnlName
End

Static Function/S getAnchorFromPnl(String pnlName)
	Wave cw = SIDAMGetCtrlValues(pnlName,"ltC;lbC;rtC;rbC")
	WaveStats/Q/M=1 cw
	return StringFromList(V_maxloc,"LT;LB;RT;RB")
End
