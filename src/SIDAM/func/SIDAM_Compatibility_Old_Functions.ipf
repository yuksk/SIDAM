#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "SIDAM_Utilities_Window"

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

//******************************************************************************
//	deprecated functions, to be removed in future
//******************************************************************************

//	print a list of deprecated functions in the history window
Function/S SIDAMDeprecatedFunctions()
	String fnName, fnList = FunctionList("*", ";", "KIND:2")
	String fileName, deprecatedList = ""
	int i, n

	for (i = 0, n = ItemsInList(fnList); i < n; i++)
		fnName = StringFromList(i,fnList)
		fileName = StringByKey("PROCWIN", FunctionInfo(fnName))
		if (CmpStr(filename, "SIDAM_Compatibility_Old_Functions.ipf"))
			continue
		endif
		deprecatedList += fnName+";"
	endfor
	return deprecatedList
End

//	print caution in the history window
Static Function deprecatedCaution(String newName)
	if (strlen(newName))
		printf "%s%s is deprecated. Use %s.\r", PRESTR_CAUTION, GetRTStackInfo(2), newName
	else
		printf "%s%s is deprecated and will be removed in future.\r", PRESTR_CAUTION, GetRTStackInfo(2)
	endif

	String info = GetRTStackInfo(3)
	Make/T/N=3/FREE tw = StringFromList(p,StringFromList(ItemsInList(info)-3,info),",")
	if (strlen(tw[0]))
		printf "%s(called from \"%s\" in %s (line %s))\r", PRESTR_CAUTION, tw[0], tw[1], tw[2]
	endif
End

Function/S SIDAMNewPanel(String title, Variable width, Variable height,
	[int float, int resizable])

	deprecatedCaution("")

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

//---
Function SIDAMTraceColor([String grfName, String clrTab, STRUCT RGBColor &clr])

	deprecatedCaution("")
		
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
//---
