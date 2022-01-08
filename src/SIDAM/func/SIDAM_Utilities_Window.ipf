#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilPanel

#include "SIDAM_Utilities_Df"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Returns a non-zero value if specified graph or panel exist,
//	and 0 otherwise.
//
//	## Parameters
//	pnlName : string
//		The name of graph or panel. This can be a subwindow.
//
//	## Returns
//	variable
//		* 0: The window does not exists
//		* !0: Otherwise.
//@
Function SIDAMWindowExists(String pnlName)
	if (!strlen(pnlName))
		return 0
	endif

	int hasChild = strsearch(pnlName, "#", 0) != -1
	if (!hasChild)
		DoWindow $pnlName
		return V_flag
	endif

	String hostName = RemoveEnding(ParseFilePath(1,pnlName,"#",1,0),"#")
	String subName = ParseFilePath(0,pnlName,"#",1,0)

	//	listStr is empty if "hostName" does not exist or
	//	"hostName" does not have a child window
	String listStr = ChildWindowList(hostName)

	//	if listStr is empty, the following WhichListItem returns -1
	return WhichListItem(subName, listStr) != -1
End


//******************************************************************************
//	Window hook function to kill the temporary datafolder
//******************************************************************************
Function SIDAMWindowHookClose(STRUCT WMWinHookStruct &s)
	int isKillVote = s.eventCode == 17
	int isEscPressed = (s.eventCode == 11) && (s.keycode == 27)

	if (!isKillVote && !isEscPressed)
		return 0
	endif

	// s.winName can be the parent window even if this function is called
	// from a hook function attached to a subwindow. This happens, for example,
	// when you click the title bar of a subwindow after clicking inside of
	// a parent window. In this case, do nothing to prevent closing the parent
	// window.
	GetWindow $s.winName exterior
	if (V_Value != 1)
		return 0
	endif

	SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
	if (isEscPressed)
		KillWindow $s.winName
	endif
	return 0
End

//******************************************************************************
///	SIDAMGetWindow
///	@param grfName
///		Name of a window.
///	@param s
///		Information about grfName is returned.
//******************************************************************************
Structure SIDAMWindowInfo
	float width
	String widthStr
	float height
	String heightStr
	float axThick
	uchar tick
	float expand
	STRUCT RectF margin
	String labelLeft
	String labelBottom
EndStructure

Function SIDAMGetWindow(String grfName, STRUCT SIDAMWindowInfo &s)
	String recStr = getRecStr(grfName)

	s.axThick = getValueFromRecStr(recStr, "axThick", 1)
	s.tick = getValueFromRecStr(recStr, "tick", 0)

	GetWindow $grfName psize
	s.width = V_right - V_left
	s.height = V_bottom - V_top
	s.widthStr = getStrFromRecStr(recStr, "width", "0")
	s.heightStr = getStrFromRecStr(recStr, "height", "0")

	s.expand = abs(getValueFromRecStr(recStr, "expand", 1))

	s.margin.left = getValueFromRecStr(recStr, "margin(left)",0)
	s.margin.right = getValueFromRecStr(recStr, "margin(right)",0)
	s.margin.top = getValueFromRecStr(recStr, "margin(top)",0)
	s.margin.bottom = getValueFromRecStr(recStr, "margin(bottom)",0)

	//	label
	int n0 = strsearch(recStr, "Label/Z left", 0), n1
	if (n0 == -1)
		s.labelLeft = ""
	else
		n1 = strsearch(recStr, "\r", n0)
		s.labelLeft = recStr[n0+14, n1-2]
	endif

	n0 = strsearch(recStr, "Label/Z bottom", 0)
	if (n0 == -1)
		s.labelBottom = ""
	else
		n1 = strsearch(recStr, "\r", n0)
		s.labelBottom = recStr[n0+16, n1-2]
	endif	
End

//	Get the necessary part of the string returned by WinRecreation.
//	Works also for a subwindow.
Static Function/S getRecStr(String grfName)
	int type = WinType(grfName)
	if (type != 1)
		return ""
	endif

	int isSubWindow = strsearch(grfName, "#", 0) >= 0
	String recStr = WinRecreation(StringFromList(0, grfName, "#"), !isSubWindow+4)
	int v0, v1

	if (!isSubWindow)
		//	Even if grfName is not a subwindow, if it contains a subwindow, a recreation
		//	macro for the subwindow is included. The following is necessary to remove
		//	the recreation macro.
		v0 = strsearch(recStr, "NewPanel",0)
		v0 = (v0 == -1) ? strlen(recStr)-1 : v0
		return recStr[0,v0]
	endif

	String subWinName = ParseFilePath(0, grfName, "#", 1, 0)
	String endline
	sprintf endline, "RenameWindow #,%s", subWinName

	v1 = strsearch(recStr, endline, 0)
	v0 = strsearch(recStr, "Display", v1, 3)
	return recStr[v0, v1-1]
End

Static Function getValueFromRecStr(String recStr, String key, Variable defaultValue)
	int n0 = strsearch(recStr, key, 0)
	if (n0 == -1)
		return defaultValue
	endif
	int n1 = strsearch(recStr, "\r", n0), n2 = strsearch(recStr, ",", n0)
	n1 = (n1 == -1) ? inf : n1
	n2 = (n2 == -1) ? inf : n2
	return str2num(recStr[n0+strlen(key)+1, min(n1, n2)-1])	// +1 is for "="
End

Static Function/S getStrFromRecStr(String recStr, String key, String defaultStr)
	int n0 = strsearch(recStr, key, 0)
	if (n0 == -1)
		return defaultStr
	endif

	int n1, n2

	if (!numtype(str2num(recStr[n0+strlen(key)+1])))
		n1 = strsearch(recStr, "\r", n0)
		n2 = strsearch(recStr, ",", n0)
		n1 = (n1 == -1) ? inf : n1
		n2 = (n2 == -1) ? inf : n2
		return recStr[n0+strlen(key)+1, min(n1, n2)-1]	// +1 is for "="
	endif

	n1 = strsearch(recStr, "{", n0)
	n2 = strsearch(recStr, "(", n0)
	if (n1 != -1 && (n1 < n2 || n2 == -1))
		n2 = strsearch(recStr, "}", n1)
		return recStr[n1, n2]
	endif

	if (n2 != -1 && (n2 < n1 || n1 == -1))
		n1 = strsearch(recStr, ")", n2)
		return recStr[n2, n1]
	endif
End
