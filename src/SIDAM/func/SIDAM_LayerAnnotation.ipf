#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMLayerAnnotation

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant LISTSEP = 29
Static Constant KEYSEP = 30
Static Constant ITEMSEP =31
Static StrConstant USERDATANAME = "SIDAMLayerAnnotation"


Function/S SIDAMLayerAnnotation(
	String grfName,		//	Name of window. Use the name of the top window if empty. 
	String imgName,		//	Name of image. Use the name of the top image if empty.
	String legendStr,	//	Legend string. If empty, stop updating the layer annotation.
	[
		int digit,		//	Number of digits after the decimal point, default is 0
		int unit,			//	Use the unit of wave, 1: yes (default), 0: no
		int sign,			//	Put "+" before the number when positive, 1: yes (default), 0: no
		int prefix,		//	Use prefix such as k and m, 1: yes, 0: no (default)
		int history		//	Print the command string in the history window, 1: yes, 0: no (default)
	])
	
	if (verifyVariables(grfName, imgName, legendStr))
		return ""
	endif
	
	STRUCT paramStruct s
	
	Make/N=4/W/U/FREE defaultvalues
	if (getData(grfName, "", imgName, s))
		defaultvalues = {s.digit, s.unit, s.sign, s.prefix}
	else
		defaultvalues = {0, 1, 1, 0}
		s.legendName = UniqueName("Text", 14, 0, grfName)
	endif

	s.legendStr = legendStr		
	s.digit = ParamIsDefault(digit) ? defaultvalues[0] : digit
	s.unit = ParamIsDefault(unit) ? defaultvalues[1] : unit
	s.sign = ParamIsDefault(sign) ? defaultvalues[2] : sign
	s.prefix = ParamIsDefault(prefix) ? defaultvalues[3] : prefix
	s.layer = -1		//	force updating
	
	if (strlen(legendStr))
		setLegend(grfName, imgName, s)
	else
		clearLegend(grfName,imgName)
	endif
	
	if (!ParamIsDefault(history) && history)
		String paramStr
		sprintf paramStr, "\"%s\",\"%s\",\"%s\"", grfName, imgName, legendStr
		if (strlen(legendStr))
			paramStr += SelectString(s.digit!=defaultvalues[0],"",",digit="+num2istr(s.digit))
			paramStr += SelectString(s.unit!=defaultvalues[1],"",",unit="+num2istr(s.unit))
			paramStr += SelectString(s.sign!=defaultvalues[2],"",",sign="+num2istr(s.sign))
			paramStr += SelectString(s.prefix!=defaultvalues[3],"",",prefix="+num2istr(s.prefix))
		endif
		printf "%sSIDAMLayerAnnotation(%s)\r", PRESTR_CMD, paramStr
	endif
	
	return s.legendName
End

Static Function verifyVariables(String &grfName, String &imgName, String legendStr)
	String errMsg = PRESTR_CAUTION + "SIDAMLayerAnnotation gave error: "
	
	if (strlen(grfName))
		if (!SIDAMWindowExists(grfName))
			printf "%s\"%s\" is not found.\r", errMsg, grfName
			return 1
		endif
	elseif (strlen(WinName(0,1)))
		grfName = WinName(0,1)
	else
		printf "%sno graph.\r", errMsg
		return 1
	endif
	
	String imgList = ImageNameList(grfName,";")
	if (!strlen(imgList))
		printf "%sno image.\r", errMsg
		return 1
	elseif (strlen(imgName))
		if (WhichListItem(imgName,imgList) < 0)
			printf "%s\"%s\" is not found.\r", errMsg, imgName
			return 1
		endif
	else
		imgName = StringFromList(0,imgList)
	endif
	
	if (WaveDims(ImageNameToWaveRef(grfName,imgName)) != 3)
		printf "%s\an image of a 3D wave must be given.\r", errMsg
		return 1
	endif
	
	if (strlen(legendStr) && (strsearch(legendStr, "$value$", 0) < 0))
		printf "%sinvalid legend string.\r", errMsg
		return 1
	endif
	
	return 0
End

Static Structure paramStruct
	String	legendStr
	String	legendName
	uint16	digit
	uchar	unit
	uchar	sign
	uchar	prefix
	int16	layer
EndStructure


//-------------------------------------------------------------
//	Function called by the right-click menu
//-------------------------------------------------------------
Static Function/S rightclickDo()
	pnl(WinName(0,1))
End


//---------------------------------------------------------------------------------------------------
//	Information necessary for making a legend string is stored in userData as string.
//	
//	setData: receive the parameter structure and save it as userData.
//	getData: get values from userData and put them to the parameter structure.
//	updateLegend: getData and actually update the legend.
//	setLegend: setData, updateLegend, and set the hook function to call updateLegend.
//	clearLegend: delete the legend textbox, delete data, and delete the hook function if necessary.
//---------------------------------------------------------------------------------------------------
Static Function getData(String grfName, String ctrlName, String imgName, STRUCT paramStruct &s)
	String dataStr = GetUserData(grfName,ctrlName,USERDATANAME)
	if (!strlen(dataStr))
		return 0
	endif
	
	String content = StringByKey(imgName,dataStr,num2char(KEYSEP),num2char(LISTSEP))
	if (!strlen(content))
		return 0
	endif
	
	Make/N=7/T/FREE tw = StringFromList(p,content,num2char(ITEMSEP))
	s.legendStr = tw[0]
	s.legendName = tw[1]
	s.digit = str2num(tw[2])
	s.unit = str2num(tw[3])
	s.sign = str2num(tw[4])
	s.prefix = str2num(tw[5])
	s.layer = str2num(tw[6])
	return 1
End

//---------------------------------------------------------------------------------------------------
//	Store the param structure as userData of grfName or ctrlName
//	The userData is like
//	imgName0:***,***,***;imgName1:***,***,***;
//	but ",", ":", and ";" are num2char(ITEMSEP), num2char(KEYSEP), and num2char(LISTSEP), respectively.
//	These separation characters are chosen because they are not included in the legend string.
//---------------------------------------------------------------------------------------------------
Static Function setData(String grfName, String ctrlName, String imgName, STRUCT paramStruct &s)
	if (strlen(ctrlName))
		Wave w = ImageNameToWaveRef(StringFromList(0,grfName,"#"),imgName)
	else
		Wave w = ImageNameToWaveRef(grfName,imgName)
	endif
	if (WaveDims(w) != 3)
		return 0
	endif

	Make/N=5/W/U/FREE tw0 = {s.digit, s.unit, s.sign, s.prefix, s.layer}
	Make/N=7/T/FREE tw1
	tw1[0] = {s.legendStr, s.legendName}
	tw1[2,6] = num2istr(tw0[p-2])
	String paramStr = join(tw1,num2char(ITEMSEP))
	
	String dataStr
	
	if (strlen(ctrlName))
		//	When the ctrlName is given, it's intended to save data as userData of the cancel button
		//	to restore data used when the button is pressed
		ControlInfo/W=$grfName $ctrlName
		if (V_flag != 1)
			Abort "A button must be passed to the ctrlName"
		endif
		dataStr = GetUserData(grfName,ctrlName,USERDATANAME)
		Button $ctrlName win=$grfName, userData($USERDATANAME)=\
		ReplaceStringByKey(imgName,dataStr,paramStr,num2char(KEYSEP),num2char(LISTSEP))

	else
		//	This function is mostly used to save data as userData of the window
		dataStr = GetUserData(grfName,"",USERDATANAME)
		SetWindow $grfName userData($USERDATANAME)=\
		ReplaceStringByKey(imgName,dataStr,paramStr,num2char(KEYSEP),num2char(LISTSEP))
	
	endif
End

Static Function/S join(Wave/T txtw, String str)
	String rtnStr = ""
	int i
	for (i = 0; i < numpnts(txtw); i++)
		rtnStr += txtw[i] + str
	endfor
	return rtnStr
End

Static Function updateLegend(String grfName, String imgName)
	STRUCT paramStruct s
	if (!getData(grfName, "", imgName, s))
		return 0
	endif
	
	int layer = NumberByKey("plane", ImageInfo(grfName,imgName,0), "=")	//	present layer
	if (s.layer == layer)	// if the present layer is the same as before, do nothing
		return 0
	endif
	
	Wave w = ImageNameToWaveRef(grfName,imgName)
	if (WaveDims(w) != 3)
		return 0
	endif
	
	String formatStr = SelectString(s.sign, "%.*", "%+.*")
	if (s.prefix)
		formatStr += "W1P" + SelectString(s.unit, "", WaveUnits(w,2))
	else
		formatStr += "f" + SelectString(s.unit, "", " "+WaveUnits(w,2))
	endif
	String str
	sprintf str, ReplaceString("$value$", s.legendStr, formatStr), s.digit, SIDAMIndexToScale(w,layer,2)
	
	TextBox/C/N=$s.legendName/W=$grfName str

	s.layer = layer	//	record the present layer for next time
	setData(grfName, "", imgName, s)
	return 1
End

Static Function setLegend(String grfName, String imgName, STRUCT paramStruct &s)
	if (WaveDims(ImageNameToWaveref(grfName,imgName)) != 3)
		return 0
	endif
	
	setData(grfName, "", imgName, s)
	updateLegend(grfName, imgName)
	
	GetWindow $grfName hook($USERDATANAME)
	if (!strlen(S_Value))
		SetWindow $grfName hook($USERDATANAME) = SIDAMLayerAnnotation#hook
	endif
End

Static Function hook(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 8)	//	modified
		return 0
	endif
	
	int i, n
	
	//	update existing legends
	String listStr = ImageNameList(s.winName,";")
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		updateLegend(s.winName,StringFromList(i,listStr))
	endfor
	
	//	clean legends of non-existing images
	String dataStr = GetUserData(s.winName,"",USERDATANAME)
	if (!strlen(dataStr))
		SetWindow $s.winName hook($USERDATANAME)=$""
		return 0
	endif
	
	String imgName
	for (i = 0, n = ItemsInList(dataStr,num2char(LISTSEP)); i < n; i++)
		imgName = StringFromList(0,StringFromList(i,dataStr,num2char(LISTSEP)),num2char(KEYSEP))
		if (WhichListItem(imgName,listStr) < 0)
			clearLegend(s.winName, imgName, force=1)
		endif
	endfor
	
	return 0
End

Static Function clearLegend(String grfName, String imgName, [int force])
	if (ParamIsDefault(force) && WaveDims(ImageNameToWaveref(grfName,imgName)) != 3)
		return 0
	endif
	
	//	remove legend textbox
	STRUCT paramStruct s
	if (getData(grfName, "", imgName, s))
		TextBox/W=$grfName/K/N=$s.legendName
	endif
	
	//	remove data
	String dataStr = GetUserData(grfName,"",USERDATANAME)
	SetWindow $grfName userData($USERDATANAME)=\
	RemoveByKey(imgName,dataStr,num2char(KEYSEP),num2char(LISTSEP))
	
	//	remove hook function
	if (!strlen(GetUserData(grfName,"",USERDATANAME)))
		SetWindow $grfName hook($USERDATANAME) = $""
	endif
End


//=====================================================================================================


//-------------------------------------------------------------
//	Show panel to set parameters
//-------------------------------------------------------------
Static Function pnl(String grfName)
	
	if (SIDAMWindowExists(grfName+"#SIDAM_LA"))
		return 0
	endif
	
	NewPanel/HOST=$grfName/EXT=0/W=(0,0,255,200)/N=SIDAM_LA as "Layer annotation"
	String pnlName = grfName + "#SIDAM_LA"
	
	SetWindow $pnlName hook(self)=SIDAMLayerAnnotation#pnlHook
	
	PopupMenu imageP title="image", pos={6,8}, size={240,19}, bodyWidth=205, win=$pnlName
	PopupMenu imageP mode=1, value=#("SIDAMLayerAnnotation#ImageNameList3D(\""+grfName+"\")"), win=$pnlName
	PopupMenu imageP proc=SIDAMLayerAnnotation#pnlPopup, win=$pnlName
		
	SetVariable stringV title="text", pos={17,34}, size={229,18}, bodyWidth=205, win=$pnlName
	SetVariable digitV title="digit", pos={13,59}, size={78,18}, bodyWidth=50, win=$pnlName
	SetVariable digitV format="%d", limits={0,inf,1}, win=$pnlName
	ModifyControlList "stringV;digitV", proc=SIDAMLayerAnnotation#pnlSetVar, win=$pnlName

	CheckBox unitC title="add unit after $value$", pos={42,89}, size={130,15}, win=$pnlName
	CheckBox signC title="add \"+\" before $value$", pos={42,114}, size={137,15}, win=$pnlName
	CheckBox prefixC title="use \"k\" (1e3), \"m\" (1e-3), etc.", pos={42,139}, size={167,15}, win=$pnlName
	ModifyControlList "unitC;signC;prefixC", proc=SIDAMLayerAnnotation#pnlCheck, win=$pnlName
		
	Button doB title="Do it", pos={7,170}, win=$pnlName
	Button deleteB title="Delete", pos={77, 170}, win=$pnlName
	Button cancelB title="Cancel", pos={186,170}, win=$pnlName
	ModifyControlList "doB;deleteB;cancelB" size={60,22}, proc=SIDAMLayerAnnotation#pnlButton, win=$pnlName
	
	ModifyControlList ControlNameList(pnlName) focusRing=0, win=$pnlName
	
	saveInitial(grfName, "cancelB")
	
	ControlInfo/W=$pnlName imageP
	reflectData(pnlName, S_Value)
End

Static Function/S ImageNameList3D(String grfName)
	String listStr = ImageNameList(grfName,";")
	int i
	for (i = ItemsInList(listStr)-1; i >= 0; i--)
		if (WaveDims(ImageNameToWaveRef(grfName,StringFromList(i,listStr))) != 3)
			listStr = RemoveListItem(i,listStr)
		endif
	endfor
	return listStr
End

Static Function pnlHook(STRUCT WMWinHookStruct &s)
	//	When the close button is pressed
	//	(When the panel is closed by pnlButton(), restoreInitial() here is not necessary.)
	if (s.eventCode == 17 && !strlen(GetRTStackInfo(2)))		
		restoreInitial(StringFromList(0,s.winName,"#"), "cancelB")
		
	//	When the esc key is pressed
	elseif ((s.eventCode == 11 && s.keycode == 27))
		restoreInitial(StringFromList(0,s.winName,"#"), "cancelB")
		KillWindow $s.winName
		
	endif
	return 0
End

//-------------------------------------------------------------
//	Controls
//-------------------------------------------------------------
Static Function pnlCheck(STRUCT WMCheckboxAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	String grfName = StringFromList(0,s.win,"#")
	ControlInfo/W=$s.win imageP
	String imgName = S_Value

	STRUCT paramStruct ps	
	getData(grfName, "", imgName, ps)
	
	strswitch (s.ctrlName)
		case "unitC":
			ps.unit = s.checked
			break
		case "signC":
			ps.sign = s.checked
			break
		case "prefixC":
			ps.prefix = s.checked
			break
		default:
			return 0
	endswitch
	
	ps.layer = -1	//	force updating
	setLegend(grfName, imgName, ps)	
End

Static Function pnlButton(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	STRUCT paramStruct ps
	String grfName = StringFromList(0,s.win,"#")
	ControlInfo/W=$s.win imageP
	String imgName = S_Value
	
	//	Both "do" and "delete" work only for the selected image because the main command
	//	is designed to work for an image passed as a parameter. To gurantee this, call
	//	restoreInitial() before calling the main command.
	strswitch (s.ctrlName)
		case "doB":
			//	Retrive the present parameters to be passed to the main command before
			//	calling restoreInitial()
			getData(grfName, "", imgName, ps)
			restoreInitial(grfName, "cancelB")
			SIDAMLayerAnnotation(grfName,	imgName, ps.legendStr,\
			digit=ps.digit, unit=ps.unit, sign=ps.sign, prefix=ps.prefix, history=1)
			break

		case "deleteB":
			restoreInitial(grfName, "cancelB")
			//	If the legend is removed by restoreInitial(), the main command does not
			//	have to be called.
			if (getData(grfName, "", imgName, ps))
				SIDAMLayerAnnotation(grfName,	imgName, "", history=1)
			endif
			break
			
		case "cancelB":
			restoreInitial(grfName, "cancelB")
			break

	endswitch
	KillWindow $s.win
End

Static Function pnlSetVar(STRUCT WMSetVariableAction &s)
	//	Handle either mouse up or enter key
	if (s.eventCode != 1 && s.eventCode != 2)
		return 1
	endif
	
	String grfName = StringFromList(0, s.win, "#")
	
	ControlInfo/W=$s.win imageP
	String imgName = S_Value
	
	STRUCT paramStruct ps
	getData(grfName, "", imgName, ps)
	
	strswitch (s.ctrlName)
		case "stringV":
			ps.legendStr = s.sval
			break
		case "digitV":
			ps.digit = s.dval
			break
	endswitch
	
	ps.layer = -1	//	force updating
	setLegend(grfName, imgName, ps)
End

Static Function pnlPopup(STRUCT WMPopupAction &s)
	if (s.eventCode == 2)	// mouseup
		restoreInitial(StringFromList(0,s.win,"#"), "cancelB")
		reflectData(s.win, s.popStr)
	endif
End

//-------------------------------------------------------------
//	Save the initial data to userData of the cancel button
//-------------------------------------------------------------
Static Function saveInitial(String grfName, String ctrlName)
	STRUCT paramStruct s
	String listStr = ImageNameList(grfName,";"), imgName
	int i
	
	for (i = 0; i < ItemsInList(listStr); i++)
		imgName = StringFromList(i,listStr)
		if (getData(grfName, "", imgName, s))
			setData(grfName+"#SIDAM_LA", ctrlName, imgName, s)
		endif
	endfor
End

//-------------------------------------------------------------
//	Restore the initial states of annotation
//-------------------------------------------------------------
Static Function restoreInitial(String grfName, String ctrlName)
	STRUCT paramStruct s
	String listStr = ImageNameList(grfName,";"), imgName
	int i
	
	for (i = 0; i < ItemsInList(listStr); i++)
		imgName = StringFromList(i,listStr)
		if (getData(grfName+"#SIDAM_LA", ctrlName, imgName, s))
			s.layer = -1	//	force updating
			setLegend(grfName, imgName, s)
		else
			clearLegend(grfName, imgName)
		endif
	endfor
End

//-------------------------------------------------------------
//	Reflect the data to the panel.
//	If data is not found, set the legend with initial parameters.
//	This is called from the popup and the panel when opened.
//-------------------------------------------------------------
Static Function reflectData(String pnlName, String imgName)
	String grfName = StringFromList(0,pnlName,"#")
	STRUCT paramStruct s
	if (!getData(grfName, "", imgName, s))
		s.legendStr = "$value$"
		s.legendName = UniqueName("Text", 14, 0, grfName)
		s.digit = 0
		s.unit = 1
		s.sign = 1
		s.prefix = 0
		s.layer = -1	//	force updating
		setLegend(grfName, imgName, s)
	endif

	SetVariable stringV value=_STR:s.legendStr, win=$pnlName
	SetVariable digitV value=_NUM:s.digit, win=$pnlName
	CheckBox unitC value=s.unit, win=$pnlName
	CheckBox signC value=s.sign, win=$pnlName
	CheckBox prefixC value=s.prefix, win=$pnlName	
End


//=====================================================================================================


Static Function backCompFromLayerViewerAA(String grfName)
	String oldString = GetUserData(grfName,"","AAstr")
	String imgName = StringFromList(0,ImageNameList(grfName,";"))
	
	STRUCT paramStruct s
	s.legendStr = ReplaceString("$unit$",ReplaceString("$+$",oldString,""),"")
	s.legendName = GetUserData(grfName, "", "AAname")
	s.digit = str2num(GetUserData(grfName,"","AAdigit"))
	s.unit = strsearch(oldString, "$unit$", 0) >= 0
	s.sign = strsearch(oldString, "$+$",0) >= 0
	s.prefix = 0
	s.layer = -1	//	force updating
	setLegend(grfName, imgName, s)

	SetWindow $grfName hook(AA)=$""
	SetWindow $grfName userData(AAstr)=""
	SetWindow $grfName userData(AAdigit)=""
	SetWindow $grfName userData(AAlayer)=""
	SetWindow $grfName userData(AAname)=""
End
