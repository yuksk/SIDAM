#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion=7.08

//******************************************************************************
//	Start SIDAM
//******************************************************************************
Function sidam()
	Execute/P/Q "SetIgorOption poundDefine=SIDAMstarting"
	Execute/P "INSERTINCLUDE \"SIDAM_StartExit\""
	Execute/P "COMPILEPROCEDURES "
	Execute/P/Q "SIDAMStart()"
	Execute/P/Q "SetIgorOption poundUndefine=SIDAMstarting"
	Execute/P "DELETEINCLUDE \"SIDAM_StartExit\""
	Execute/P "COMPILEPROCEDURES "
	return 0
End

//******************************************************************************
//	Menu item
//******************************************************************************
Menu "Macros", dynamic
	//	nothing is displayed after SIDAM is started
	SelectString(strlen(FunctionList("SIDAMLoadData",";","")), "SIDAM", ""), /Q, sidam()
End