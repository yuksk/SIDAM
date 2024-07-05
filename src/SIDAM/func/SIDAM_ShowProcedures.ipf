#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma ModuleName=SIDAMShowProcedure

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Static Function/S mainMenuItem()
	return SelectString(defined(SIDAMshowProc), "Show", "Hide")+" SIDAM Procedures"
End

//------------------------------------------------------------------------------
//	Show or hide procedures of SIDAM in the procedure list
//	(Window > Procedure Windows)
//------------------------------------------------------------------------------
Function SIDAMShowProcedures()
	if (defined(SIDAMshowProc))
		Execute/P/Q "SetIgorOption poundUndefine=SIDAMshowProc"
	else
		Execute/P/Q "SetIgorOption poundDefine=SIDAMshowProc"
	endif
	Execute/P "COMPILEPROCEDURES "
End
