#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName = SIDAMUtilHelp

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Function/S SIDAMBrowseHelp(String kind)
	strswitch(kind)
		case "home":
			BrowseURL SIDAM_URL_HOME
			break			
		case "commands":
			BrowseURL SIDAM_URL_COMMANDS
			break
		case "shortcuts":
			BrowseURL SIDAM_URL_SHORTCUTS
			break
	endswitch
End

Function SIDAMAbout()
	String promptStr
	Sprintf promptStr, "SIDAM v%d.%d.%d", SIDAM_VERSION_MAJOR, SIDAM_VERSION_MINOR, SIDAM_VERSION_PATCH
	DoAlert 0, promptStr
End

Function SIDAMCheckUpdate()
	Variable new = existsNew()
	if (numtype(new))
		// error
		DoAlert 0, "No version infomation is available (error)."
	elseif (new)
		// new
		DoAlert 1, "A new version of SIDAM is available. " \
			+ "Do you want to open the homepage of SIDAM?"
		if (V_flag == 1)
			BrowseURL SIDAM_URL_HOME
		endif
	else
		// latest
		DoAlert 0, "You are using the latest version of SIDAM."
	endif
End

Static Function existsNew()
	String response = FetchURL(SIDAM_URL_API_RELEASE)
	
	//	Get the latest tag name
	int i0 = strsearch(response, "tag_name", 0)
	if (i0 < 0)
		return NaN
	endif
	
	int i1 = strsearch(response, ",", i0)
	String verStr = response[i0+12,i1-2]	// e.g., 9.6.0
	int major, minor, patch
	sscanf verStr, "%d.%d.%d", major, minor, patch
	if (major > SIDAM_VERSION_MAJOR)
		return 1
	elseif (minor > SIDAM_VERSION_MINOR)
		return 2
	elseif (patch > SIDAM_VERSION_PATCH)
		return 3
	else
		return 0
	endif
End

Function SIDAMApplyHelpStrings(String pnlName, String ctrlName, String str,
	[int oneline])
	oneline = ParamIsDefault(oneline) ? 40 : oneline
	
	if (!strlen(pnlName) || !strlen(ctrlName) || !strlen(str))
		return 0
	endif
	
	Make/T/FREE kind = {"Button", "Checkbox", "PopupMenu", "ValDisplay", \
		"SetVariable", "Chart", "Slider", "TabControl", "Groupbox", \
		"TitleBox", "ListBox", "CustomControl"}
	ControlInfo/W=$pnlName $ctrlName
	if (!V_flag)
		return 0
	endif
	
	String cmdStr
	sprintf cmdStr, "%s %s help={\"%s\"}, win=%s", kind[abs(V_flag)-1], ctrlName\
		, breakStrings(str, oneline), pnlName
	Execute/Q cmdStr
End

Function SIDAMApplyHelpStringsWave(String pnlName, Wave/T w, [int oneline])
	oneline = ParamIsDefault(oneline) ? 40 : oneline
	
	int i
	for (i = 0; i < DimSize(w,1); i++)
		SIDAMApplyHelpStrings(pnlName, w[0][i], w[1][i], oneline=oneline)
	endfor
End

Static Function/S breakStrings(String inputStr, int oneline)
	String newStr = "", str
	int i0 = 0, pos_space, pos_break
	do
		if (i0 + oneline >= strlen(inputStr))
			newStr += inputStr[i0,strlen(inputStr)-1]
			break
		endif
		str = inputStr[i0,i0+oneline-1]
		pos_break = strsearch(str, "\\r", 0)
		pos_space = strsearch(str, " ", inf, 1)
		if (pos_break >= 0)
			newStr += str[0,pos_break+2]
			i0 += pos_break+3
		elseif (pos_space >= 0)
			newStr += str[0,pos_space-1] + "\\r"
			i0 += pos_space + 1
		else
			newStr += str + "\\r"
			i0 += oneline
		endif
	while(1)
	
	if (strlen(newStr) > MAX_HELP_STR)
		return newStr[0, MAX_HELP_STR-3] + "..."
	else
		return newStr
	endif
End