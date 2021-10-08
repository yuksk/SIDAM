#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

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

