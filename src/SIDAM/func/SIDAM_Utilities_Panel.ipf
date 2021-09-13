#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilPanel

#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//@
//	Create a panel at the center of Igor window or screen.
//
//	## Parameters
//	title : string
//		The title of the panel.
//	width : variable
//		The width of the panel.
//	height : variable
//		The height of the panel.
//	float : int {0 or !0}, default 0
//		Set !0 to make the panel floating.
//	resizable : int {0 or !0}, default 0
//		Set !0 to make the panel resizable.
//
//	## Returns
//	string
//		The name of the created panel.
//@
Function/S SIDAMNewPanel(String title, Variable width, Variable height,
	[int float, int resizable])
	
	float = ParamIsDefault(float) ? 0 : float
	resizable = ParamIsDefault(resizable) ? 0 : resizable

	GetWindow kwFrameOuter, wsizeRM

	Variable left = (V_right-V_left)/2-width/2
	Variable top = (V_bottom-V_top)/2-height
	Variable right = left+width
	Variable bottom = top+height

	NewPanel/FLT=(float)/W=(left, top, right, bottom)/K=1 as title
	String pnlName = S_name
	if (float)
		SetActiveSubwindow _endfloat_
	endif
	if (!resizable)
		ModifyPanel/W=$pnlName fixedSize=1
	endif

	KillStrings/Z S_name
	return pnlName
End


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
	int isEscPressed = (s.eventCode != 11) && (s.keycode == 27)

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
