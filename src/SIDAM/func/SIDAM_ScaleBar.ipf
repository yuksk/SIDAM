#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMScaleBar

#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Wave"
#include "SIDAM_Utilities_Window"

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
Static Constant DEFAULT_LENGTH = 0			//	length of scale bar

//	Fixed values
Static Constant NICEWIDTH = 20					//	Width of scale bar is about 20% of a window
Static Constant MARGINPX = 7					//	Position from the edge
Static Constant OFFSETPX = 3					//	Space between the bar and characters
Static Constant LINETHICK = 3					//	Thickness of the bar
Static Constant DOUBLECLICK = 20				//	Interval between clicks to recognize double-click
Static StrConstant NICEVALUES = "1;2;3;5"	//	Definition of "nice" values
Static Constant PARAMVERSION = 1				//	Version of the parameter structure

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
//	fsize : int, default 0
//		The font size (pt).
//	length : variable, default 0
//		The length of scale bar in the physical unit. If 0, a nice value is used.
//	fgRGBA : wave
//		The foreground color.
//	bgRGBA : wave
//		The background color.
//	prefix: int {0 or !0}, default 1
//		Set !0 to use a prefix such as k and m.
//@
Function SIDAMScalebar([String grfName, String anchor, int fsize, Variable length,
	Wave fgRGBA, Wave bgRGBA, int prefix])
	
	grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1))
	anchor = SelectString(ParamIsDefault(anchor), anchor, "")
	if (validate(grfName, anchor))
		return 0
	endif
	
	STRUCT paramStruct s
	s.overwrite[0] = !ParamIsDefault(anchor)
	s.overwrite[1] = !ParamIsDefault(fsize)
	s.overwrite[2] = !ParamIsDefault(fgRGBA)
	s.overwrite[3] = !ParamIsDefault(bgRGBA)
	s.overwrite[4] = !ParamIsDefault(prefix)
	s.overwrite[5] = !ParamIsDefault(length)
	if (initializeParamStruct(s, grfName, anchor, fsize, fgRGBA, bgRGBA, prefix, length))
		return 0
	endif

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
	String anchor, int fsize, Wave/Z fgRGBA, Wave/Z bgRGBA, int prefix, Variable length)

	Make/B/U/N=6/FREE overwrite = s.overwrite[p]
	
	//	Use the present value if a scale bar is displayed.
	//	If not, use the default values.
	String settingStr = GetUserData(grfName,"",NAME)
	if (strlen(settingStr))
		StructGet/S s, settingStr
	else
		s.anchor[0] = char2num(DEFAULT_ANCHOR[0])
		s.anchor[1] = char2num(DEFAULT_ANCHOR[1])
		s.fontsize = DEFAULT_SIZE
		WaveToRGBAColor({DEFAULT_FC,DEFAULT_FC,DEFAULT_FC,DEFAULT_FA}, s.fgRGBA)
		WaveToRGBAColor({DEFAULT_BC,DEFAULT_BC,DEFAULT_BC,DEFAULT_BA}, s.bgRGBA)
		s.prefix = DEFAULT_PREFIX
		s.length = DEFAULT_LENGTH
		s.version = PARAMVERSION
	endif

	//	If a parameter is specified in the main function,
	//	overwrite with the value.
	if (overwrite[0])
		s.anchor[0] = strlen(anchor) ? char2num(anchor[0]) : 0
		s.anchor[1] = strlen(anchor) ? char2num(anchor[1]) : 0
	endif
	
	if (overwrite[1])
		s.fontsize = limit(fsize,0,inf)
	endif

	try
		if (overwrite[2])
			WaveToRGBAColor(fgRGBA, s.fgRGBA)
		endif
		if (overwrite[3])
			WaveToRGBAColor(bgRGBA, s.bgRGBA)
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
		return 1
	endtry
	
	if (overwrite[4])
		s.prefix = prefix
	endif
	
	if (overwrite[5])
		s.length = length
	endif
	
	return 0
End

Static Function/WAVE RGBAColorToWave(STRUCT RGBAColor &s)
	Make/W/U/N=4/FREE w = {s.red, s.green, s.blue, s.alpha}
	return w
End

Static Function WaveToRGBAColor(Wave w, STRUCT RGBAColor &s)
	s.red = w[0]; s.green = w[1]; s.blue = w[2]; s.alpha = w[3]; AbortOnRTE
End

Static Structure paramStruct
	//	for input
	uchar	anchor[2]
	uint16	fontsize
	STRUCT	RGBAColor	fgRGBA
	STRUCT	RGBAColor	bgRGBA
	uchar	prefix
	double	length
	//	for internal use
	uint32	version
	uchar	overwrite[6]
	STRUCT	RectF box
	double	xmin, xmax, ymin, ymax
	double	ticks
EndStructure

Static Structure paramStructOld
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
	getInfoFromStruct(s.winName, ps)
	
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

Static Function getInfoFromStruct(String grfName, STRUCT paramStruct &s)
	StructGet/S s, GetUserData(grfName,"",NAME)
	if (s.version != PARAMVERSION)
		s.length = 0
		s.version = 1
		STRUCT paramStructOld os
		StructGet/S os, GetUserData(grfName,"",NAME)
		s.box = os.box
		s.xmin = os.xmin
		s.xmax = os.xmax
		s.ymin = os.ymin
		s.ymax = os.ymax
		s.ticks = os.ticks
	endif
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
	int isRight = s.anchor[0]==82		//	L:0, R:1
	int isBottom = s.anchor[1]!=84		//	B:1, T:0
	
	Variable expand = getExpand(grfName)
	Variable margin = MARGINPX*expand, offset = OFFSETPX*expand
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
	//	barwidth(%) of the scale bar area (scaling value)
	Variable barwidth = s.length ? s.length : calcNiceWidth(L)
	
	//	Numbers to be displayed
	String barStr
	int existUnit = strlen(WaveUnits(w,0))
	if (existUnit && s.prefix)
		sprintf barStr, "%.0W1P%s", barwidth, WaveUnits(w,0)
	elseif (existUnit && !s.prefix)
		barStr = num2str(barwidth)+" "+WaveUnits(w,0)
	elseif (!existUnit && s.prefix)
		sprintf barStr, "%.0W0P", barwidth
	else
		barStr = num2str(barwidth)
	endif
	
	String fontname = GetDefaultFont(grfName)
	int fontsize = s.fontsize ? s.fontsize : GetDefaultFontSize(grfName,"")
	
	//	Height and width of the scale bar area
	//	Width of displayed numbers, pixel
	v0 = FontSizeStringWidth(GetDefaultFont(grfName),\
		fontsize*ScreenResolution/72,0,barStr)*expand
	//	Height of displayed numbers, pixel
	v1 = FontSizeHeight(GetDefaultFont(grfName),\
		fontsize*ScreenResolution/72,0)*expand
	GetWindow $grfName psizeDC
	Variable winWidth = V_right - V_left, winHeight = V_bottom - V_top
	//	The longer one of the bar and the numbers is used as the width
	Variable boxWidth = max(v0/winWidth, barwidth/L) + margin*2/winWidth
	Variable boxHeight = (v1+margin*2+offset)/winHeight
	
	//	Draw the scale bar
	//	Initialize
	stopUpdateBar(grfName)
	SetDrawLayer/W=$grfName ProgFront
	SetDrawEnv/W=$grfName gname=$NAME, gstart
	
	//	Background
	SetDrawEnv/W=$grfName xcoord=prel, ycoord=prel
	SetDrawEnv/W=$grfName fillfgc=(s.bgRGBA.red,s.bgRGBA.green,s.bgRGBA.blue,s.bgRGBA.alpha), linethick=0.00
	DrawRect/W=$grfName isRight, isBottom, isRight+boxWidth*(isRight?-1:1), isBottom+boxHeight*(isBottom?-1:1)
	
	//	Record the position of the background
	s.box.left = min(isRight,isRight+boxWidth*(isRight?-1:1))
	s.box.right = max(isRight,isRight+boxWidth*(isRight?-1:1))
	s.box.top = min(isBottom,isBottom+boxHeight*(isBottom?-1:1))
	s.box.bottom = max(isBottom,isBottom+boxHeight*(isBottom?-1:1))
	StructPut/S s, str
	SetWindow $grfName userData($NAME)=str
	
	//	Bar
	v0 = (isRight? as.x.max.value : as.x.min.value) + (L*boxWidth-barwidth)/2*(isRight?-1:1)
	v1 = isBottom + margin/winHeight*(isBottom?-1:1)
	SetDrawEnv/W=$grfName xcoord=$as.xaxis, ycoord=prel
	SetDrawEnv/W=$grfName linefgc=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha), linethick=LINETHICK
	DrawLine/W=$grfName v0, v1, v0+barwidth*(isRight?-1:1), v1
	
	//	Number and unit
	SetDrawEnv/W=$grfName xcoord=prel, ycoord=prel, textxjust=1, textyjust=(isBottom?0:2), fsize=fontsize, fname=fontname
	SetDrawEnv/W=$grfName textrgb=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha)
	v0 = isRight + boxWidth/2*(isRight?-1:1)
	v1 = isBottom + (margin+offset)/winHeight*(isBottom?-1:1)
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

Static Function calcNiceWidth(Variable L)
	Variable rawwidth = L*NICEWIDTH*1e-2
	int digit = floor(log(rawwidth))		//	number of digits of rawwidth - 1
	Make/FREE/N=(ItemsInList(NICEVALUES)) nicew = str2num(StringFromList(p,NICEVALUES)), tw
	tw = abs(nicew*10^digit - rawwidth)
	WaveStats/Q/M=1 tw
	//	A "nice value" close to rawwidth (scaling value)
	return nicew[V_minloc]*10^digit
End


//******************************************************************************
//	show panel
//******************************************************************************
Static Function pnl(String grfName)
	String pnlName = grfName + "#Scalebar"
	if (SIDAMWindowExists(pnlName))
		return 0
	endif
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,225,170)/N=Scalebar as "Scale bar"
	
	String settingStr = GetUserData(grfName,"",NAME), anchor
	Variable opacity
	int isDisplayed = strlen(settingStr) > 0
	
	//	Use the present value if a scale bar is displayed.
	//	If not, use the default values.
	STRUCT paramStruct s
	if (isDisplayed)
		getInfoFromStruct(grfName, s)
		anchor = num2char(s.anchor[0])+num2char(s.anchor[1])
		SetWindow $pnlName userData(init)=settingStr
	else
		anchor = DEFAULT_ANCHOR
		s.fontsize = DEFAULT_SIZE
		WaveToRGBAColor({DEFAULT_FC,DEFAULT_FC,DEFAULT_FC,DEFAULT_FA}, s.fgRGBA)
		WaveToRGBAColor({DEFAULT_BC,DEFAULT_BC,DEFAULT_BC,DEFAULT_BA}, s.bgRGBA)
		s.prefix = DEFAULT_PREFIX
		s.length = DEFAULT_PREFIX
	endif

	Wave w = SIDAMImageNameToWaveRef(grfName)
	
	SetVariable lengthV pos={8,3}, size={84,18}, title="Length:", bodyWidth=40, win=$pnlName
	SetVariable lengthV limits={0,inf,0}, value=_NUM:s.length, proc=SIDAMScaleBar#pnlSetVar, win=$pnlName
	TitleBox unitT pos={95,4}, frame=0, title=WaveUnits(w,0), win=$pnlName
	SetVariable sizeV pos={128,3}, size={90,18}, title="Text size:", win=$pnlName
	SetVariable sizeV bodyWidth=40, format="%d", limits={0,inf,0}, win=$pnlName
	SetVariable sizeV value=_NUM:s.fontsize, proc=SIDAMScaleBar#pnlSetVar, win=$pnlName

	CheckBox prefixC pos={10,30}, title="Use a prefix (\u03bc, n, ...)", win=$pnlName
	CheckBox prefixC value=s.prefix, proc=SIDAMScaleBar#pnlCheck, win=$pnlName
	
	GroupBox anchorG pos={135,58}, size={85,70}, title="Anchor", win=$pnlName
	CheckBox ltC pos={143,80}, title="LT", value=!CmpStr(anchor,"LT"), win=$pnlName
	CheckBox lbC pos={143,104}, title="LB", value=!CmpStr(anchor,"LB"), win=$pnlName
	CheckBox rtC pos={187,80}, title="RT", value=!CmpStr(anchor,"RT"), side=1, win=$pnlName
	CheckBox rbC pos={187,104}, title="RB", value=!CmpStr(anchor,"RB"), side=1, win=$pnlName

	GroupBox clrG pos={5,58}, size={125,70}, title="Colors", win=$pnlName
	PopupMenu fgRGBAP pos={24,79}, size={94,19}, win=$pnlName
	PopupMenu fgRGBAP title="Fore color:", value=#"\"*COLORPOP*\"", win=$pnlName
	PopupMenu fgRGBAP popColor=(s.fgRGBA.red,s.fgRGBA.green,s.fgRGBA.blue,s.fgRGBA.alpha), win=$pnlName
	PopupMenu bgRGBAP pos={22,102}, size={96,19}, win=$pnlName
	PopupMenu bgRGBAP title="Back color:", value=#"\"*COLORPOP*\"", win=$pnlName
	PopupMenu bgRGBAP popColor=(s.bgRGBA.red,s.bgRGBA.green,s.bgRGBA.blue,s.bgRGBA.alpha), win=$pnlName

	Button doB pos={5,140}, title="Do It", size={60,22}, proc=SIDAMScaleBar#pnlButton, win=$pnlName
	Button deleteB pos={75,140}, title="Delete", size={60,22}, proc=SIDAMScaleBar#pnlButton, win=$pnlName
	Button cancelB pos={160,140}, title="Cancel", size={60,22}, proc=SIDAMScaleBar#pnlButton, win=$pnlName
	
	ModifyControlList "ltC;lbC;rtC;rbC" mode=1, proc=SIDAMScaleBar#pnlCheck, win=$pnlname
	ModifyControlList "fgRGBAP;bgRGBAP" mode=1, bodyWidth=40, proc=SIDAMScaleBar#pnlPopup, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	Make/T/N=(2,9)/FREE helpw
	String helpstr_check = "Check to show the scale bar at the "
	helpw[][0] = {"prefixC", "Check to use a prefix such as n and \\u03bc."}
	helpw[][1] = {"ltC", helpstr_check+"left-top corner."}
	helpw[][2] = {"lbC", helpstr_check+"left-bottom corner."}
	helpw[][3] = {"rtC", helpstr_check+"right-top corner."}
	helpw[][4] = {"rbC", helpstr_check+"right-bottom corner."}
	helpw[][5] = {"sizeV", "Enter the font size. When 0, the default font size is used."}
	helpw[][6] = {"fgRGBAP", "Select the foreground color of the scale bar."}
	helpw[][7] = {"bgRGBAP", "Select the background color of the scale bar."}
	helpw[][8] = {"lengthV", "Enter the length of bar. When 0, a nice value is used."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	SIDAMScalebar(grfName=grfName, anchor=getAnchorFromPnl(pnlName))
	
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
	String statusInOpeningPanel = GetUserData(s.win,"","init")
	
	strswitch (s.ctrlName)
		case "cancelB":
			if (strlen(statusInOpeningPanel))
				StructGet/S ps, statusInOpeningPanel
				SIDAMScalebar(grfName=grfName,\
					anchor=num2char(ps.anchor[0])+num2char(ps.anchor[1]),fsize=ps.fontsize,\
					fgRGBA=RGBAColorToWave(ps.fgRGBA), bgRGBA=RGBAColorToWave(ps.bgRGBA),\
					prefix=ps.prefix)
			else
				SIDAMScalebar(grfName=grfName,anchor="")
			endif
			break
		case "deleteB":
			SIDAMScalebar(grfName=grfName,anchor="")
			if (!strlen(statusInOpeningPanel))
				break
			endif
			// ** FALLTHOUGH **
		case "doB":
			StructGet/S ps, GetUserData(grfName,"",NAME)
			echo(s.win, ps)
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
		case "lengthV":
			SIDAMScalebar(grfName=StringFromList(0,s.win,"#"), length=s.dval)
			break
		case "sizeV":
			SIDAMScalebar(grfName=StringFromList(0,s.win,"#"), fsize=s.dval)
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
	
	if (numpnts(tw) == 3)
		Redimension/N=4 tw
		tw[3] = 65535
	endif
	
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
//	Helper functions for control
//******************************************************************************
Static Function/S getAnchorFromPnl(String pnlName)
	Wave cw = SIDAMGetCtrlValues(pnlName,"ltC;lbC;rtC;rbC")
	WaveStats/Q/M=1 cw
	return StringFromList(V_maxloc,"LT;LB;RT;RB")
End

Static Function echo(String pnlName, STRUCT paramStruct &s)
	STRUCT paramStruct init
	StructGet/S init, GetUserData(pnlName, "", "init")
	
	String paramStr = ""
	
	if (!s.anchor[0] && !s.anchor[1])
		printf "%sSIDAMScalebar(grfName=\"%s\",anchor=\"\")\r", PRESTR_CMD, StringFromList(0, pnlName, "#")
		return 0
	elseif (s.anchor[0] != init.anchor[0] || s.anchor[1] != init.anchor[1])
		sprintf paramStr, "%s,anchor=\"%s\"", paramStr, s.anchor
	endif
	
	if (s.length != init.length)
		sprintf paramStr, "%s,length=%s", paramStr, num2str(s.length)
	endif
	
	if (s.fontsize != init.fontsize)
		sprintf paramStr, "%s,size=%d", paramStr, s.fontsize
	endif
	
	Wave fg = RGBAColorToWave(s.fgRGBA), fginit = RGBAColorToWave(init.fgRGBA)
	if (!EqualWaves(fg, fginit, 1))
		sprintf paramStr, "%s,fgRGBA=%s", paramStr, SIDAMWaveToString(fg)
	endif
	
	Wave bg = RGBAColorToWave(s.bgRGBA), bginit = RGBAColorToWave(init.bgRGBA)
	if (!EqualWaves(bg, bginit, 1))
		sprintf paramStr, "%s,bgRGBA=%s", paramStr, SIDAMWaveToString(bg)
	endif
	
	if (s.prefix != init.prefix)
		sprintf paramStr, "%s,prefix=%d", paramStr, s.prefix
	endif
	
	if (strlen(paramStr))
		printf "%sSIDAMScalebar(grfName=\"%s\"%s)\r", PRESTR_CMD, StringFromList(0, pnlName, "#"), paramStr
	endif
End
