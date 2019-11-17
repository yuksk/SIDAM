#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilControl

#include "SIDAM_Utilities_Panel"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	Change the disable state of controls and subwindows in a tab.
//	Controls and subwindows to be changed must have userData(tab), where a tab
//	number is recorded. The initial disable state of each control and subwindow
//	specified when created reflects the disable state when a corresponding tab
//	is opened first time.
//******************************************************************************
Function SIDAMTabControlProc(STRUCT WMTabControlAction &s)
	int tabNum, disable_saved, i, n

	//	controls
	String ctrlName, ctrlList = ControlNameList(s.win)
	for (i = 0, n = ItemsInList(ctrlList); i < n; i++)
		ctrlName = StringFromList(i,ctrlList)
		tabNum = str2num(GetUserData(s.win, ctrlName, "tab"))
		switch (whichTab(tabNum, s))
			case INCLUDED_IN_PRESENT:
				disable_saved = str2num(GetUserData(s.win, s.ctrlName, ctrlName))
				ModifyControl/Z $ctrlName, disable=disable_saved, win=$s.win
				break
			case INCLUDED_IN_LAST:
				ControlInfo/W=$s.win $ctrlName
				TabControl $s.ctrlName userData($ctrlName)=num2istr(V_Disable), win=$s.win
				ModifyControl/Z $ctrlName, disable=1, win=$s.win
				break
		endswitch
	endfor

	//	subwindows
	String subWinName, subWwinList = ChildWindowList(s.win)
	for (i = 0, n = ItemsInList(subWwinList); i < n; i += 1)
		subWinName = s.win + "#" + StringFromList(i, subWwinList)
		tabNum = str2num(GetUserData(subWinName, "", "tab"))
		switch (whichTab(tabNum, s))
			case INCLUDED_IN_PRESENT:
				disable_saved = str2num(GetUserData(s.win, s.ctrlName, subWinName))
				SetWindow $subWinName hide=disable_saved
				break
			case INCLUDED_IN_LAST:
				GetWindow $subWinName hide
				TabControl $s.ctrlName userData($subWinName)=num2istr(V_value), win=$s.win
				SetWindow $subWinName hide=1
				break
		endswitch
	endfor

	TabControl $s.ctrlName userData(SIDAMlastTab)=num2istr(s.tab), win=$s.win
End

Static Constant INCLUDED_IN_PRESENT = 1
Static Constant INCLUDED_IN_LAST = 2
Static Function whichTab(int tabNum, STRUCT WMTabControlAction &s)
	int lastTab = str2num(GetUserData(s.win,s.ctrlName,"SIDAMlastTab"))
	if (tabNum == s.tab)
		return INCLUDED_IN_PRESENT
	elseif (tabNum == lastTab)
		return INCLUDED_IN_LAST
	else
		return 0
	endif
End

//-------------------------------------------------------------
//	Record the disable state of each control designated when
//	a panel is created, and then show/hide controls and child
//	windows correspondint to the selected tab.
//-------------------------------------------------------------
Function SIDAMInitializeTab(String pnlName, String tabName)
	String listStr, tabInfo, ctrlName, cwinName
	int i, n

	ControlInfo/W=$pnlName $tabName
	int tabNum = V_Value

	//	controls
	listStr = ControlNameList(pnlName)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		ctrlName = StringFromList(i,listStr)
		tabInfo = GetUserData(pnlName,ctrlName,"tab")
		if (!strlen(tabInfo))
			continue
		endif
		ControlInfo/W=$pnlName $ctrlName
		TabControl $tabName userData($ctrlName)=num2istr(V_Disable), win=$pnlName
		if (str2num(tabInfo) != tabNum)
			ModifyControl/Z $ctrlName, disable=1, win=$pnlName
		endif
	endfor

	//	subwindows
	listStr = ChildWindowList(pnlName)
	for (i = 0, n = ItemsInList(listStr); i < n; i++)
		cwinName = pnlName + "#" + StringFromList(i, listStr)
		tabInfo = GetUserData(cwinName, "", "tab")
		if (!strlen(tabInfo))
			continue
		endif
		GetWindow $cwinName hide
		TabControl $tabName userData($cwinName)=num2istr(V_value), win=$pnlName
		SetWindow $cwinName hide=(str2num(tabInfo) != tabNum)
	endfor

	TabControl $tabName userData(SIDAMlastTab)=num2str(tabNum), win=$pnlName
End


//******************************************************************************
//	Varidate if a string of SetVariable satisfies a condition specified by
//	the mode parameter.
//	When mode=0, check the length of string.
//	When mode=1, check if eval is possible.
//******************************************************************************
Function SIDAMValidateSetVariableString(String pnlName, String ctrlName,
	int mode, [int minlength, int maxlength])

	minlength = ParamIsDefault(minlength) ? 1 : minlength
	maxlength = ParamIsDefault(maxlength) ? MAX_OBJ_NAME : maxlength

	int hasProblem = 1

	ControlInfo/W=$pnlName $ctrlName
	if (abs(V_flag) != 5)
		return 0
	endif

	int type = valueType(S_recreation)
	int isInternalString = type == 2
	int isExternalString = type == 3
	String str
	if (isInternalString)
		str = S_Value
	elseif (isExternalString)
		str = StrVarOrDefault(S_DataFolder+S_value,"")
	else
		return 0
	endif

	hasProblem = mode ? \
		numtype(eval(str))!=0 : \
		strlen(str) < minlength || strlen(str) > maxlength

	if (hasProblem)
		Variable clr_r = SIDAM_CLR_CAUTION_R, clr_g = SIDAM_CLR_CAUTION_G, clr_b = SIDAM_CLR_CAUTION_R
		SetVariable $ctrlName valueBackColor=(clr_r,clr_g,clr_b), userData(check)="1", win=$pnlName
	else
		SetVariable $ctrlName valueBackColor=0, userData(check)="", win=$pnlName
	endif

	return hasProblem
End

Static Function eval(String str)
	DFREF dfrSav = GetDataFolderDFR(), dfrTmp = NewFreeDataFolder()
	SetDataFolder dfrTmp
	Execute/Q/Z "Variable/G v=" + str
	SetDataFolder dfrSav

	if (V_flag)
		return NaN
	else
		NVAR/SDFR=dfrTmp v
		return v
	endif
End


//******************************************************************************
//	Retern a wave containing values of controls in a graph/panel
//******************************************************************************
//	Return a numeric wave containing number values of controls in a graph/panel.
Function/WAVE SIDAMGetCtrlValues(String win, String ctrlList)

	Make/D/N=(ItemsInList(ctrlList))/FREE resw
	String ctrlName
	int i, n

	for (i = 0, n = ItemsInList(ctrlList); i < n; i++)
		ctrlName = StringFromList(i, ctrlList)
		SetDimLabel 0, i, $ctrlName, resw
		ControlInfo/W=$win $ctrlName
		switch (abs(V_Flag))
			case 0:	//	not found
			case 9:	//	Groupbox
			case 10:	//	TitleBox
				resw[i] = nan
				break

			case 5:	//	SetVariable
				switch (valueType(S_recreation))
					case 0:
					case 1:
						resw[i] = V_Value
						break
					case 2:
						resw[i] = eval(S_Value)
						break
					case 3:
						SVAR/SDFR=$S_DataFolder str = $S_value
						resw[i] = eval(str)
						break
					default:
						resw[i] = NaN
				endswitch
				break

			default:
				//	1: Button
				//	2: CheckBox
				//	3: PopupMenu
				//	4: ValDisplay
				//	6: Chart
				//	7: Slider
				//	8: TabControl
				//	11:	 ListBox
				//	12:	 CustomControl
				resw[i] = V_Value
		endswitch
	endfor

	return resw
End

//	Return a text wave containing string values of controls in a graph/panel.
Function/WAVE SIDAMGetCtrlTexts(String win, String ctrlList)

	Make/T/N=(ItemsInList(ctrlList))/FREE resw
	String ctrlName
	int i, n

	for (i = 0, n = ItemsInList(ctrlList); i < n; i++)
		ctrlName = StringFromList(i, ctrlList)
		SetDimLabel 0, i, $ctrlName, resw
		ControlInfo/W=$win $ctrlName
		switch (abs(V_Flag))
			case 3:	//	PopupMenu: text of the current item
			case 9:	//	GroupBox: title text
				resw[i] = S_Value
				break

			case 4:	//	ValDisplay
				resw[i] = num2str(V_Value)
				break

			case 5:	//	SetVariable
				switch (valueType(S_recreation))
					case 0:
					case 1:
						resw[i] = num2str(V_Value)
						break
					case 2:
						resw[i] = S_Value
						break
					case 3:
						SVAR/SDFR=$S_DataFolder str = $S_Value
						resw[i] = str
						break
					default:
						resw[i] = ""
				endswitch
				break

			case 7:	//	Slider
				resw[i] = num2str(V_value)
				break

			case 10:	//	TitleBox
				if (strlen(S_title))		//	title is given directly
					resw[i] = S_title
				elseif (strlen(S_value))	//	title is given by a string
					SVAR/SDFR=$S_DataFolder str = $S_value
					resw[i] = str
				else
					resw[i] = ""
				endif
				break

			default:
				//	0: not found
				//	1: Button
				//	2: CheckBox
				//	6: Chart
				//	8: TabControl
				//	11:	 ListBox
				//	12:	 CustomControl
				resw[i] = ""
		endswitch
	endfor

	return resw
End

//	Return type of variable used for a SetVariable control
Static Function valueType(String recreationStr)
	Variable n0 = strsearch(recreationStr, "value=", 0)
	Variable n1 = strsearch(recreationStr, ",", n0)
	Variable n2 = strsearch(recreationStr, "\r", n0)
	Variable n3 = (n1 == -1) ? n2 : min(n1, n2)
	String valueStr = recreationStr[n0+6,n3-1]

	NVAR/Z npath = $valueStr
	SVAR/Z spath = $valueStr
	if (strsearch(valueStr, "_NUM:", 0) != -1)
		return 0		//	internal number
	elseif (NVAR_Exists(npath))
		return 1		//	external number
	elseif (strsearch(valueStr, "_STR:", 0) != -1)
		return 2		//	internal string
	elseif (SVAR_Exists(spath))
		return 3		//	external string
	else
		return -1		//	?
	endif
End


//******************************************************************************
//	Run "To cmd line" or "To clip"
//******************************************************************************
Function SIDAMPopupTo(STRUCT WMPopupAction &s, String paramStr)
	switch (s.popNum)
		case 1:
			ToCommandLine paramStr
			break
		case 2:
			PutScrapText paramStr
			break
	endswitch
End


//******************************************************************************
//	Bahave as if a checkbox is clicked
//******************************************************************************
Function SIDAMClickCheckBox(String pnlName, String ctrlName)
	if (!SIDAMWindowExists(pnlName))
		return 1
	endif

	ControlInfo/W=$pnlName $ctrlName
	if (V_Flag != 2)
		return 2
	endif

	//	If the checkbox is a radio button, the new value is always 1.
	//	If the checkbox is a default checkbox, the new value is opposite to the initial value.
	int isRadioButton = NumberByKey("mode",S_recreation,"=",",") == 1
	int newValue = isRadioButton ? 1 : !V_Value
	CheckBox $ctrlName value=newValue, win=$pnlName

	//	If there is no procedure, there is nothing to do more.
	String fnName = getActionFunctionName(S_recreation)
	if (!strlen(fnName))
		return 3
	endif

	STRUCT WMCheckboxAction s
	s.ctrlName = ctrlName
	s.win = pnlName
	getWinRect(pnlName, s.winRect)				//	winRect
	getCtrlRect(pnlName, ctrlName, s.ctrlRect)	//	ctrlRect
	//s.mouseLoc.v =
	//s.mouseLoc.h =
	s.eventCode = 2
	s.eventMod = getEventMod()
	s.userData = S_UserData
	s.checked = newValue

	FUNCREF SIDAMClickCheckBoxPrototype fn = $fnName
	fn(s)

	return 0
End
//-------------------------------------------------------------
//	Prototypes of control procedure functions
//-------------------------------------------------------------
Function SIDAMClickCheckBoxPrototype(STRUCT WMCheckboxAction &s)
End
//-------------------------------------------------------------
//	Return a name of procedure for a control
//-------------------------------------------------------------
Static Function/S getActionFunctionName(String recreationStr)
	int i0 = strsearch(recreationStr,"proc=",0)
	if (i0 == -1)
		return ""
	endif
	int i1 = strsearch(recreationStr,",",i0+5)
	int i2 = strsearch(recreationStr,"\r",i0+5)
	if (i1 == -1)
		return recreationStr[i0+5,i2-1]
	else
		return recreationStr[i0+5,min(i1,i2)-1]
	endif
End
//-------------------------------------------------------------
//	Put coordinates of a window
//-------------------------------------------------------------
Static Function getWinRect(String pnlName, STRUCT Rect &winRect)
	GetWindow $pnlName wsizeDC
	winRect.top = V_top
	winRect.left = V_left
	winRect.bottom = V_bottom
	winRect.right = V_right
End
//-------------------------------------------------------------
//	Put coordinates of a control to a structure
//-------------------------------------------------------------
Static Function getCtrlRect(String pnlName, String ctrlName, STRUCT Rect &ctrlRect)
	ControlInfo/W=$pnlName $ctrlName
	ctrlRect.top = V_top
	ctrlRect.left = V_left
	ctrlRect.bottom = V_top + V_Height
	ctrlRect.right = V_left + V_Width
End
//-------------------------------------------------------------
//	Return eventMod
//-------------------------------------------------------------
Static Function getEventMod()
	int key = GetKeyState(1)
	int isCtrlPressed = !!(key & 1)
	int isAltPressed = !!(key & 2)
	int isShiftPressed = !!(key & 4)
	int eventMod = 0
	eventMod += 1	//	This function is used when a control is clicked
	eventMod += isShiftPressed*2 + isAltPressed*4 + isCtrlPressed*8
	return eventMod
End
