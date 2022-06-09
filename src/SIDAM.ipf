#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion=8.03

//******************************************************************************
//	Start SIDAM
//******************************************************************************
Function sidam()
	Execute/P "INSERTINCLUDE \"SIDAM_StartExit\""
	Execute/P "COMPILEPROCEDURES "
	Execute/P/Q "SIDAMStart()"
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
