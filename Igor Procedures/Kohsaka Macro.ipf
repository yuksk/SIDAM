#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion=7.08

//	マクロ起動
Function KM()
	//	起動
	Execute/P/Q "SetIgorOption poundDefine=KMstarting"
	Execute/P "INSERTINCLUDE \"KM OnStart\""
	Execute/P "COMPILEPROCEDURES "
	Execute/P/Q "KMonStart()"
	Execute/P/Q "SetIgorOption poundUndefine=KMstarting"
	Execute/P "DELETEINCLUDE \"KM OnStart\""
	Execute/P "COMPILEPROCEDURES "
	
	return 0
End

//	Macrosメニューに表示
Menu "Macros", dynamic
	SelectString(strlen(FunctionList("KMLoadData",";","")), "Kohsaka Macros", ""), /Q, KM()
End