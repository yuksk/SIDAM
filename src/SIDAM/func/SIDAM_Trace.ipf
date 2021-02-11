#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMTrace

#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Panel"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Set offsets of traces
//
//	Parameters
//	----------
//	grfName : string, default ``WinName(0,1,1)``
//		The name of window.
//	xoffset : variable
//		The offset value in the x direction.
//	yoffset : variable
//		The offset value in the y direction.
//	fill : int
//		0 or 0!. Set !0 to eliminate hidden lines.
//@
Function SIDAMTraceOffset([String grfName,	 Variable xoffset,
	Variable yoffset, int fill])
	
	STRUCT paramStructO s
	s.default = ParamIsDefault(grfName) || (ParamIsDefault(xoffset) && ParamIsDefault(yoffset))
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.xoffset = ParamIsDefault(xoffset) ? 0 : xoffset
	s.yoffset = ParamIsDefault(yoffset) ? 0 : yoffset
	s.fill = ParamIsDefault(fill) ? 0 : fill
	
	if (validateO(s))
		print s.errMsg
		return 1
	elseif (s.default)
		pnl(s.grfName)
		return 0
	endif
	
	setTraceOffset(s.grfName,s.xoffset,s.yoffset,s.fill)
	
	return 0
End

Static Function validateO(STRUCT paramStructO &s)
	s.errMsg = PRESTR_CAUTION + "SIDAMTraceOffset gave error: "
	
	if (!strlen(s.grfName))
		s.errMsg += "graph not found."
		return 1
	elseif (!SIDAMWindowExists(s.grfName))
		s.errMsg += "a graph named \"" + s.grfName + "\" is not found."
		return 1
	endif
	
	if (ItemsInList(TraceNameList(s.grfName, ";", 1)) <= 1)
		s.errMsg += "two or more traces must be displayed on the graph."
		return 1
	endif
	
	if (numtype(s.xoffset) || numtype(s.yoffset))
		s.errMsg += "the offset value(s) must be a number."
		return 1
	endif
	
	if (s.fill !=0 && s.fill != 1)
		s.errMsg += "the fill must be 0 or 1."
		return 1
	endif
	
	return 0
End

Static Structure paramStructO
	Wave	w
	uchar	default
	String	errMsg
	String	grfName
	double	xoffset
	double	yoffset
	uchar	fill
EndStructure

Static Function setTraceOffset(String grfName, Variable xoffset,
	Variable yoffset, Variable fill)
	
	String trcName, trcList = TraceNameList(grfName, ";", 5)	//	remove hidden traces
	int n = ItemsInList(trcList), i
	
	Variable isFillOn = str2num(StringByKey("usePlusRGB(x)",TraceInfo(grfName,StringFromList(0,trcList),0),"="))
	STRUCT RGBColor gbRGB
	GetWindow $grfName, gbRGB
	gbRGB.red = V_Red ;	gbRGB.green = V_Green ;	gbRGB.blue = V_Blue
	
	if (isFillOn && fill)
		
		for (i = 0; i < n; i++)
			ModifyGraph/W=$grfName offset($StringFromList(n-1-i,trcList))={(xoffset*i),(yoffset*i)}
		endfor
		
	elseif (isFillOn && !fill)
		
		reverseTraceOrder(grfName)
		for (i = 0; i < n; i++)
			trcName = StringFromList(n-1-i,trcList)
			ModifyGraph/W=$grfName offset($trcName)={(xoffset*i),(yoffset*i)} 
			ModifyGraph/W=$grfName mode($trcName)=0, useNegRGB($trcName)=0,usePlusRGB($trcName)=0, hbFill($trcName)=0
		endfor
		ModifyGraph/W=$grfName gbRGB=(gbRGB.red,gbRGB.green,gbRGB.blue)
		
	elseif (!isFillOn && fill)
		
		reverseTraceOrder(grfName)
		for (i = 0; i < n; i++)
			trcName = StringFromList(i,trcList)
			ModifyGraph/W=$grfName offset($trcName)={(xoffset*i),(yoffset*i)}
			ModifyGraph/W=$grfName mode($trcName)=7, useNegRGB($trcName)=1,usePlusRGB($trcName)=1, hbFill($trcName)=2
		endfor
		ModifyGraph/W=$grfName gbRGB=(gbRGB.red,gbRGB.green,gbRGB.blue), negRGB=(gbRGB.red,gbRGB.green,gbRGB.blue), plusRGB=(gbRGB.red,gbRGB.green,gbRGB.blue)
		
	else
		
		for (i = 0; i < n; i++)
			ModifyGraph/W=$grfName offset($StringFromList(i,trcList))={(xoffset*i),(yoffset*i)}
		endfor
		
	endif
End

Static Function reverseTraceOrder(String grfName)
	String trcList = TraceNameList(grfName, ";", 5)
	Variable numOfTraces = ItemsInList(trcList)
	String anchortrace = StringFromList(0,trcList)
	
	int i
	for (i = numOfTraces-1; i > 0; i--)
		ReorderTraces/W=$grfName $anchortrace, {$StringFromList(i,trcList)}
	endfor
End


//=====================================================================================================


//@
//	Set a color(s) of traces
//
//	Parameters
//	----------
//	grfName : string, default ``WinName(0,1,1)``
//		The name of window.
//	clrTab : string, default ""
//		Name of a color table.
//	clr : STRUCT RGBColor, default clr.red = 0, clr.green = 0, clr.blue = 0
//		Color of traces.
//@
Function SIDAMTraceColor([String grfName, String clrTab, STRUCT RGBColor &clr])
	
	STRUCT paramStructC s
	s.default = ParamIsDefault(grfName)
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.clrTab = SelectString(ParamIsDefault(clrTab), clrTab, "")
	s.clrDefault = ParamIsDefault(clr)
	if (s.clrDefault)
		s.clr.red = 0 ;	s.clr.green = 0 ;	s.clr.blue = 0
	else
		s.clr = clr
	endif
	
	if (validateC(s))
		print s.errMsg
		return 1
	elseif (s.default)
		pnl(s.grfName)
		return 0
	endif
	
	setTraceColor(s)
	
	return 0
End

Static Function validateC(STRUCT paramStructC &s)
	s.errMsg = PRESTR_CAUTION + "SIDAMTraceColor gave error: "
	
	if (!strlen(s.grfName))
		s.errMsg += "graph not found."
		return 1
	elseif (!SIDAMWindowExists(s.grfName))
		s.errMsg += "a graph named \"" + s.grfName + "\" is not found."
		return 1
	endif
	
	if (ItemsInList(TraceNameList(s.grfName, ";", 1)) <= 1)
		s.errMsg += "two or more traces must be displayed on the graph."
		return 1
	endif
	
	if (s.default)
		return 0
	endif
	
	if (s.clrDefault)
		if(!strlen(s.clrTab))
			s.errMsg += "color is not specifed."
			return 1
		elseif (WhichListItem(s.clrTab,CtabList()) == -1)
			s.errMsg += "no color table"
			return 1
		endif
	endif
	
	return 0
End

Static Structure paramStructC
	String	errMsg
	uchar	default
	String	grfName
	String	clrTab
	STRUCT	RGBColor	clr
	uchar	clrDefault
EndStructure

Static Function setTraceColor(STRUCT paramStructC &s)
	String trcList = TraceNameList(s.grfName, ";", 5)	//	remove hidden traces
	int i, n = ItemsInList(trcList)
	
	if (strlen(s.clrTab))
		DFREF dfrSav = GetDataFolderDFR()
		SetDataFolder NewFreeDataFolder()
		ColorTab2Wave $s.clrTab
		Wave w = M_colors	
		SetDataFolder dfrSav
		
		SetScale/I x 0, 1, "", w
		for (i = 0; i < n; i++)
			ModifyGraph/W=$s.grfName rgb($StringFromList(i, trcList))=(w(i/(n-1))[0],w(i/(n-1))[1],w(i/(n-1))[2])
		endfor
	else		//	single color
		for (i = 0; i < n; i++)
			ModifyGraph/W=$s.grfName rgb($StringFromList(i, trcList))=(s.clr.red,s.clr.green,s.clr.blue)
		endfor
	endif
End

Static Function menuDo()
	pnl(WinName(0,1))
End

//******************************************************************************
//	Show the panel
//******************************************************************************
Static Function pnl(String grfName)
	if (SIDAMWindowExists(grfName+"#Traces"))
		return 0
	endif
	
	Variable panelHeight = 240, buttonTop = 215
	
	NewPanel/EXT=0/HOST=$StringFromList(0, grfName, "#")/W=(0,0,207,panelHeight)/N=Traces
	String pnlname = StringFromList(0, grfName, "#") + "#Traces"
	SetWindow $pnlName userData(grf)=grfName
	
	Wave initw = initOffset(grfName)
	GroupBox offsetG title="offset", pos={3,3}, size={200,100}, win=$pnlName
	SetVariable xoffsetV title="x:", pos={12,26}, value=_NUM:initw[0], userData(init)=num2str(initw[0]), win=$pnlName
	SetVariable yoffsetV title="y:", pos={108,26}, value=_NUM:initw[1], userData(init)=num2str(initw[1]), win=$pnlName
	ModifyControlList "xoffsetV;yoffsetV" size={82,16}, bodyWidth=70, limits={-inf,inf,SIDAMTrace#setIncrement(grfName,1)}, format="%.2e", proc=SIDAMTrace#pnlSetVar, win=$pnlName
	CheckBox fillC title="hidden line elimination", pos={23,53}, value=initw[2], userData(init)=num2str(initw[2]), win=$pnlName
	Button reverseB title="reverse order", pos={22,76}, size={95,18}, win=$pnlName
	Button resetB title="reset", pos={129,76}, size={60,18}, win=$pnlName
	
	GroupBox colorG title="color", pos={3,108}, size={200,100}, win=$pnlName
	CheckBox noneC title="none", pos={13,131}, value=1, mode=1, win=$pnlName
	CheckBox singleC title="single color", pos={13,156}, value=0, mode=1, win=$pnlName
	CheckBox tableC title="color table", pos={13,182}, value=0, mode=1, win=$pnlName
	PopupMenu singleP pos={96,153},size={50,20}, mode=1, proc=SIDAMTrace#pnlPopup, win=$pnlName
	PopupMenu singleP popColor= (0,0,0), value= #"\"*COLORPOP*\"", win=$pnlName
	PopupMenu tableP pos={96,179}, size={100,20}, bodyWidth=100, proc=SIDAMTrace#pnlPopup, win=$pnlName
	PopupMenu tableP mode=1, popvalue="", value= #"\"*COLORTABLEPOPNONAMES*\"", win=$pnlName
	
	Button doB title="Do It", pos={5,buttonTop}, size={60,20}, win=$pnlName
	Button cancelB title="Cancel", pos={142,buttonTop}, size={60,20}, win=$pnlName
	
	ModifyControlList "reverseB;resetB;doB;cancelB" proc=SIDAMTrace#pnlButton, win=$pnlName
	ModifyControlList "fillC;noneC;singleC;tableC" proc=SIDAMTrace#pnlCheck, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName
	
	String trcList = TraceNameList(grfName,";",1), str = ""
	Variable i, n = ItemsInList(trcList)
	for (i = 0; i < n; i += 1)
		str += RemoveEnding(StringByKey("rgb(x)=",TraceInfo(grfName,StringFromList(i,trcList),0),"(")) + ";"
	endfor
	SetWindow $pnlName userData(initclr)=str
End

Static Function/WAVE initOffset(String grfName)
	Variable ox = str2num(GetUserData(grfName, "", "SIDAMTraceOffsetX"))
	Variable oy = str2num(GetUserData(grfName, "", "SIDAMTraceOffsetY"))
	Variable fill = str2num(GetUserData(grfName, "", "SIDAMTraceOffsetFill"))
	
	if (numtype(ox) || numtype(oy) || numtype(fill))
		String trcList = TraceNameList(grfName, ";", 5)
		Variable n = ItemsInList(trcList)
		sscanf StringByKey("offset(x)", TraceInfo(grfName,StringFromList(n-1,trcList),0), "=", ";"), "{%f,%f}", ox, oy	
		if (ox || oy)
			sscanf StringByKey("offset(x)", TraceInfo(grfName,StringFromList(1,trcList),0), "=", ";"), "{%f,%f}", ox, oy	
		else
			sscanf StringByKey("offset(x)", TraceInfo(grfName,StringFromList(n-2,trcList),0), "=", ";"), "{%f,%f}", ox, oy	
		endif
		
		fill = NumberByKey("mode(x)",TraceInfo(grfName,StringFromList(0,trcList),0),"=")==7
	endif

	Make/N=2/FREE rw = {ox, oy, fill}
	return rw
End

//******************************************************************************
//	Controls
//******************************************************************************
//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)	//	mouse up
		return 0
	endif
	
	String grfName = GetUserData(s.win, "", "grf")
	strswitch (s.ctrlName)
		case "resetB":
			setTraceOffset(grfName,0,0,0)
			DoUpdate/W=$grfName
			SetVariable xoffsetV limits={-inf,inf,SIDAMTrace#setIncrement(grfName,0)}, value=_NUM:0, win=$s.win
			SetVariable yoffsetV limits={-inf,inf,SIDAMTrace#setIncrement(grfName,1)}, value=_NUM:0, win=$s.win
			CheckBox fillC value=0, win=$s.win
			break
			
		case "reverseB":
			reverseTraceOrder(grfName)
			Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV;fillC")
			setTraceOffset(grfName,cvw[0],cvw[1],cvw[2])
			DoUpdate/W=$grfName
			break
			
		case "cancelB":
			String listStr = "xoffsetV;yoffsetV;fillC"
			Make/N=(ItemsInList(listStr))/FREE cvw = \
				str2num(GetUserData(s.win,StringFromList(p,listStr),"init"))
			setTraceOffset(grfName,cvw[0],cvw[1],cvw[2])
			revertColor(s.win)
			KillWindow $s.win
			break
			
		case "doB":
			Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV;fillC")
			SetWindow $grfName, userData(SIDAMTraceOffsetX)=num2str(cvw[0])
			SetWindow $grfName, userData(SIDAMTraceOffsetY)=num2str(cvw[1])
			SetWindow $grfName, userData(SIDAMTraceOffsetFill)=num2str(cvw[2])
			KillWindow $s.win
			break
	endswitch
End

//	Checkbox
Static Function pnlCheck(STRUCT WMCheckBoxAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	String grfName = GetUserData(s.win, "", "grf")
	strswitch (s.ctrlName)
		case "fillC":
			Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV")
			setTraceOffset(grfName,cvw[0], cvw[1], s.checked)
			break
			
		case "noneC":
			CheckBox singleC value=0, win=$s.win
			CheckBox tableC value=0, win=$s.win
			revertColor(s.win)
			break
			
		case "singleC":
			CheckBox noneC value=0, win=$s.win
			CheckBox tableC value=0, win=$s.win
			ControlInfo/W=$s.win singleP
			STRUCT RGBColor clr
			clr.red = V_Red ;	clr.green = V_Green ;	clr.blue = V_Blue
			SIDAMTraceColor(grfName=grfName, clr=clr)
			break
			
		case "tableC":
			CheckBox noneC value=0, win=$s.win
			CheckBox singleC value=0, win=$s.win
			ControlInfo/W=$s.win tableP
			SIDAMTraceColor(grfName=grfName, clrTab=S_value)
			break
	endswitch
End

//	Popup
Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	
	strswitch (s.ctrlName)
		case "singleP":
			CheckBox singleC value=0, win=$s.win
			SIDAMClickCheckBox(s.win,"singleC")
			break
		case "tableP":
			CheckBox tableC value=0, win=$s.win
			SIDAMClickCheckBox(s.win,"tableC")
			break
	endswitch
End

//	Setvariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	String grfName = GetUserData(s.win, "", "grf")
	Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV;fillC")
	setTraceOffset(grfName, cvw[0], cvw[1], cvw[2])
	DoUpdate/W=grfName
	
	strswitch(s.ctrlName)
		case "xoffsetV":
			SetVariable $s.ctrlName limits={-inf,inf,SIDAMTrace#setIncrement(grfName,0)}, win=$s.win
			break
		case "yoffsetV":
			SetVariable $s.ctrlName limits={-inf,inf,SIDAMTrace#setIncrement(grfName,1)}, win=$s.win
			break
		default:
	endswitch
End


//******************************************************************************
//	Helper functions of controls
//******************************************************************************
Static Function setIncrement(String grfName, int axis)	//	0:x, 1:y
	String trcList = TraceNameList(grfName,";",1)
	Variable numOfTrc = ItemsInList(trcList)
	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(grfName, StringFromList(0,trcList), s)
	return axis ? (s.ymax-s.ymin)/(numOfTrc-1)/16 : (s.xmax-s.xmin)/(numOfTrc-1)/16
End

Static Function revertColor(String pnlName)
	String grfName = GetUserData(pnlName, "", "grf")
	String initClrStr = GetUserData(pnlName,"","initclr")
	int c0, c1, c2, i, n = ItemsInList(initClrStr)
	for (i = 0; i < n; i++)
		sscanf StringFromList(i, initClrStr), "%d,%d,%d", c0, c1, c2
		ModifyGraph/W=$grfName rgb[i]=(c0,c1,c2)
	endfor
End
