#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma ModuleName= KMShowProc

#ifndef KMshowProcedures
#pragma hide = 1
#endif

Function KMShowProcedures()
	if (defined(KMShowProcedures))
		Execute/P/Q "SetIgorOption poundUndefine=KMshowProcedures"
	else
		Execute/P/Q "SetIgorOption poundDefine=KMshowProcedures"
	endif
	Execute/P "COMPILEPROCEDURES "
End

Static Function/S menu()
	return SelectString(defined(KMShowProcedures), "Show", "Hide")+" KM Procedures"
End