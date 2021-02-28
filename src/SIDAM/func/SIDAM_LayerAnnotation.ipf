#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma moduleName = SIDAMLayerAnnotation

#include "SIDAM_Utilities_Bias"
#include "SIDAM_Utilities_Panel"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Constant LISTSEP = 29
Static Constant KEYSEP = 30
Static Constant ITEMSEP =31
Static StrConstant USERDATANAME = "SIDAMLayerAnnotation"


//@
//	Add an annotation text following the layer value of an image.
//
//	Parameters
//	----------
//	legendStr : string
//		Legend string. If empty, stop updating the layer annotation.
//	grfName : string, default ``WinName(0,1,1)``
//		The name of window.
//	imgName : string, default ``StringFromList(0, ImageNameList(grfName, ";"))``
//		The name of image.
//	digit : int, default 0
//		The number of digits after the decimal point.
//	unit : int, default 1
//		Set !0 to use the unit of the wave.
//	sign : int, default 1
//		Set !0 to use "+" for positive values.
//	prefix: int, default 0
//		Set !0 to use prefix such as k and m.
//
//	Returns
//	-------
//	string
//		The name of textbox.
//@
Function/S SIDAMLayerAnnotation(String legendStr, [String grfName,
	String imgName, int digit, int unit, int sign, int prefix])

	STRUCT paramStruct s
	s.grfName = SelectString(ParamIsDefault(grfName), grfName, WinName(0,1,1))
	s.imgName = SelectString(ParamIsDefault(imgName), imgName, \
		StringFromList(0, ImageNameList(s.grfName, ";")))

	if (validate(s))
		print s.errMsg
		return ""
	endif
	
	s.digit = ParamIsDefault(digit) ? 0 : digit
	s.unit = ParamIsDefault(unit) ? 1 : unit
	s.sign = ParamIsDefault(sign) ? 1 : sign
	s.prefix = ParamIsDefault(prefix) ? 0 : prefix
	
	if (!getData(s.grfName, "", s.imgName, s))
		s.legendName = UniqueName("Text", 14, 0, s.grfName)
	endif

	s.layer = -1		//	force updating

	if (strlen(legendStr))
		s.legendStr = legendStr
		setLegend(s.grfName, s.imgName, s)
	else
		clearLegend(s.grfName, s.imgName)
	endif
	
	return s.legendName
End

Static Function validate(STRUCT paramStruct &s)
	s.errMsg = PRESTR_CAUTION + "SIDAMLayerAnnotation gave error: "

	if (!strlen(s.grfName))
		s.errMsg += "graph not found."
		return 1
	elseif (!SIDAMWindowExists(s.grfName))
		s.errMsg += "a graph named " + s.grfName + " is not found."
		return 1
	elseif (!strlen(ImageNameList(s.grfName,";")))
		s.errMsg += s.grfName + " has no image."
		return 1
	endif
	
	String imgList = ImageNameList(s.grfName,";")
	if (!strlen(imgList))
		s.errMsg += "no image."
		return 1
	elseif (WhichListItem(s.imgName, imgList) < 0)
		s.errMsg += "\"" + s.imgName + "\" is not found." 
		return 1
	endif
	
	if (WaveDims(ImageNameToWaveRef(s.grfName, s.imgName)) != 3)
		s.errMsg += "an image of a 3D wave must be given."
		return 1
	endif
	
	return 0
End

Static Structure paramStruct
	String	grfName
	String	imgName
	String	legendStr
	String	legendName
	uint16	digit
	uchar	unit
	uchar	sign
	uchar	prefix
	int16	layer
	String	errMsg
EndStructure

Static Function/S menuDo()
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
	//	ReplaceString for the backward compatibility
	//	s.legendStr = tw[0]
	s.legendStr = ReplaceString("$value$", tw[0], "${value} ")
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
	
	int layer = SIDAMGetLayerIndex(grfName)
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
		formatStr += "f" + SelectString(s.unit, "", WaveUnits(w,2))
	endif
	String str
	sprintf str, ReplaceString("${value}", s.legendStr, formatStr), s.digit, SIDAMIndexToScale(w,layer,2)
	
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

	CheckBox unitC title="add unit after ${value}", pos={42,89}, size={130,15}, win=$pnlName
	CheckBox signC title="add \"+\" before ${value}", pos={42,114}, size={137,15}, win=$pnlName
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
	ps.grfName = StringFromList(0,s.win,"#")
	ControlInfo/W=$s.win imageP
	ps.imgName = S_Value
	
	//	Both "do" and "delete" work only for the selected image because the main command
	//	is designed to work for an image passed as a parameter. To gurantee this, call
	//	restoreInitial() before calling the main command.
	strswitch (s.ctrlName)
		case "doB":
			//	Retrive the present parameters to be passed to the main command before
			//	calling restoreInitial()
			getData(ps.grfName, "", ps.imgName, ps)
			restoreInitial(ps.grfName, "cancelB")
			SIDAMLayerAnnotation(ps.legendStr, grfName=ps.grfName, imgName=ps.imgName,\
				digit=ps.digit, unit=ps.unit, sign=ps.sign, prefix=ps.prefix)
			printHistory(ps)
			break

		case "deleteB":
			restoreInitial(ps.grfName, "cancelB")
			//	If the legend is removed by restoreInitial(), the main command does not
			//	have to be called.
			if (getData(ps.grfName, "", ps.imgName, ps))
				SIDAMLayerAnnotation("", grfName=ps.grfName, imgName=ps.imgName)
				ps.legendStr = ""
				printHistory(ps)
			endif
			break
			
		case "cancelB":
			restoreInitial(ps.grfName, "cancelB")
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
		s.legendStr = "${value}"
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

Static Function printHistory(STRUCT paramStruct &s)
	String paramStr = ""
	if (strlen(s.legendStr))
		paramStr += ",grfName=\""+s.grfName+"\""
		paramStr += ",imgName=\""+s.imgName+"\""
		paramStr += SelectString(s.digit!=0,"",",digit="+num2istr(s.digit))
		paramStr += SelectString(s.unit!=0,",unit="+num2istr(s.unit),"")
		paramStr += SelectString(s.sign!=0,",sign="+num2istr(s.sign),"")
		paramStr += SelectString(s.prefix!=0,"",",prefix="+num2istr(s.prefix))
	endif
	printf "%sSIDAMLayerAnnotation(\"%s\"%s)\r", PRESTR_CMD, s.legendStr, paramStr
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
