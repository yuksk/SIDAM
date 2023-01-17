#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMTraceOffset

#include "SIDAM_Help"
#include "SIDAM_Utilities_Control"
#include "SIDAM_Utilities_Image"
#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Set offsets of traces.
//
//	## Parameters
//	grfName : string, default `WinName(0,1,1)`
//		The name of window.
//	xoffset, yoffset : variable
//		The offset value in the x- and y-direction, respectively.
//	fill : int {0 or !0}
//		Set !0 to remove hidden lines.
//@
Function SIDAMTraceOffset([String grfName, Variable xoffset,
	Variable yoffset, int fill])
	
	STRUCT paramStruct s
	s.default = ParamIsDefault(grfName) || (ParamIsDefault(xoffset) && ParamIsDefault(yoffset))
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.xoffset = ParamIsDefault(xoffset) ? 0 : xoffset
	s.yoffset = ParamIsDefault(yoffset) ? 0 : yoffset
	s.fill = ParamIsDefault(fill) ? 0 : fill
	
	if (validate(s))
		print s.errMsg
		return 1
	elseif (s.default)
		pnl(s.grfName)
		return 0
	endif
	
	setTraceOffset(s.grfName,s.xoffset,s.yoffset,s.fill)
	
	return 0
End

Static Function validate(STRUCT paramStruct &s)
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

Static Structure paramStruct
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
	DoUpdate/W=$grfName
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

Static Function menuDo()
	pnl(WinName(0,1))
End

//	Panel
Static Function pnl(String grfName)
	if (SIDAMWindowExists(grfName+"#Offset"))
		return 0
	endif
	
	NewPanel/EXT=0/HOST=$grfName/W=(0,0,140,140)/N=Offset
	String pnlname = grfName + "#Offset"

	SetWindow $pnlName hook(self)=SIDAMWindowHookClose
	
	Wave initw = initOffset(grfName)
	SetVariable xoffsetV title="x:", pos={5,5}, value=_NUM:initw[0], win=$pnlName
	SetVariable xoffsetV userData(init)=num2str(initw[0]), win=$pnlName
	SetVariable yoffsetV title="y:", pos={5,27}, value=_NUM:initw[1], win=$pnlName
	SetVariable yoffsetV userData(init)=num2str(initw[1]), win=$pnlName
	ModifyControlList "xoffsetV;yoffsetV" size={82,16}, bodyWidth=70, limits={\
		-inf,inf,SIDAMTraceOffset#setIncrement(grfName,1)}, format="%.2e", proc=SIDAMTraceOffset#pnlSetVar, win=$pnlName
	Button resetB title="Reset", pos={95,16}, size={40,20}, win=$pnlName
	CheckBox fillC title="hidden-line removal", pos={5,54}, value=initw[2], win=$pnlName
	CheckBox fillC userData(init)=num2str(initw[2]), proc=SIDAMTraceOffset#pnlCheck, win=$pnlName
	Button reverseB title="Reverse order", pos={16,80}, size={100,18}, win=$pnlName
	Button doB title="Do It", pos={5,110}, size={60,20}, win=$pnlName
	Button cancelB title="Cancel", pos={75,110}, size={60,20}, win=$pnlName
	ModifyControlList "reverseB;resetB;doB;cancelB" proc=SIDAMTraceOffset#pnlButton, win=$pnlName
	ModifyControlList ControlNameList(pnlName,";","*") focusRing=0, win=$pnlName

	Make/T/N=(2,5)/FREE helpw
	helpw[][0] = {"xoffsetV", "Enter an offset value in the x direction."}
	helpw[][1] = {"yoffsetV", "Enter an offset value in the x direction."}
	helpw[][2] = {"resetB", "Press to make the offsets zero."}
	helpw[][3] = {"fillC", "Check to remove hidden lines"}
	helpw[][4] = {"reverseB", "Press to reverse the order of traces."}
	SIDAMApplyHelpStringsWave(pnlName, helpw)
	
	SetActiveSubwindow $pnlName
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

//	Button
Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)	//	mouse up
		return 0
	endif
	
	String grfName = StringFromList(0,s.win,"#")
	strswitch (s.ctrlName)
		case "resetB":
			setTraceOffset(grfName,0,0,0)
			SetVariable xoffsetV limits={-inf,inf,SIDAMTraceOffset#setIncrement(grfName,0)}, value=_NUM:0, win=$s.win
			SetVariable yoffsetV limits={-inf,inf,SIDAMTraceOffset#setIncrement(grfName,1)}, value=_NUM:0, win=$s.win
			CheckBox fillC value=0, win=$s.win
			break
			
		case "reverseB":
			reverseTraceOrder(grfName)
			Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV;fillC")
			setTraceOffset(grfName,cvw[%xoffsetV],cvw[%yoffsetV],cvw[%fillC])
			break
			
		case "cancelB":
			String listStr = "xoffsetV;yoffsetV;fillC"
			Make/N=(ItemsInList(listStr))/FREE cvw = \
				str2num(GetUserData(s.win,StringFromList(p,listStr),"init"))
			setTraceOffset(grfName,cvw[0],cvw[1],cvw[2])
			KillWindow $s.win
			break
			
		case "doB":
			Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV;fillC")
			SetWindow $grfName, userData(SIDAMTraceOffsetX)=num2str(cvw[%xoffsetV])
			SetWindow $grfName, userData(SIDAMTraceOffsetY)=num2str(cvw[%yoffsetV])
			SetWindow $grfName, userData(SIDAMTraceOffsetFill)=num2str(cvw[%fillC])
			KillWindow $s.win
			break
	endswitch
End

//	Checkbox, fillC only
Static Function pnlCheck(STRUCT WMCheckBoxAction &s)
	if (s.eventCode != 2)
		return 1
	endif
	String grfName = StringFromList(0,s.win,"#")
	Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV")
	setTraceOffset(grfName,cvw[%xoffsetV], cvw[%yoffsetV], s.checked)
End

//	Setvariable
Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	String grfName = StringFromList(0,s.win,"#")
	Wave cvw = SIDAMGetCtrlValues(s.win, "xoffsetV;yoffsetV;fillC")
	setTraceOffset(grfName, cvw[%xoffsetV], cvw[%yoffsetV], cvw[%fillC])
	
	strswitch(s.ctrlName)
		case "xoffsetV":
			SetVariable $s.ctrlName limits={-inf,inf,SIDAMTraceOffset#setIncrement(grfName,0)}, win=$s.win
			break
		case "yoffsetV":
			SetVariable $s.ctrlName limits={-inf,inf,SIDAMTraceOffset#setIncrement(grfName,1)}, win=$s.win
			break
		default:
	endswitch
End

//	Helper functions of controls
Static Function setIncrement(String grfName, int axis)	//	0:x, 1:y
	String trcList = TraceNameList(grfName,";",1)
	Variable numOfTrc = ItemsInList(trcList)
	STRUCT SIDAMAxisRange s
	SIDAMGetAxis(grfName, StringFromList(0,trcList), s)
	return axis ? (s.y.max.value-s.y.min.value)/(numOfTrc-1)/16 \
		: (s.x.max.value-s.x.min.value)/(numOfTrc-1)/16
End

