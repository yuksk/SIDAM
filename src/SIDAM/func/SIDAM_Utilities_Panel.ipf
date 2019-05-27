#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMUtilPanel

#include "SIDAM_Utilities_WaveDf"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
///	Show a panel at the center of Igor window or screen
///	@param title		Title of the panel
///	@param width		Width of the panel
///	@param height	Height of the panel
///	@param float		Set !0 to make the panel floating.
///						The default value is 0.
///	@param resizable	Set !0 to make the panel resizable.
///						The default value is 0.
///	@return	Name of the created panel
//******************************************************************************
Function/S SIDAMNewPanel(String title, Variable width, Variable height,
	[int float, int resizable])	//	tested

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


///******************************************************************************
///	Returns 0 if the window does not exists, !0 otherwise
///	@param pnlName	name of graph/panel
///******************************************************************************
Function SIDAMWindowExists(String pnlName)		//	tested
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

	SIDAMKillDataFolder($GetUserData(s.winName, "", "dfTmp"))
	if (isEscPressed)
		KillWindow $s.winName
	endif
	return 0
End
