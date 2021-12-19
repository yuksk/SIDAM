#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma moduleName=SIDAMExit

#ifndef SIDAMshowProc
#pragma hide = 1
#endif

Function SIDAMExit()
	SetIgorHook/K BeforeFileOpenHook = SIDAMFileOpenHook
	SetIgorHook/K AfterCompiledHook = SIDAMAfterCompiledHook
	SetIgorHook/K BeforeExperimentSaveHook = SIDAMBeforeExperimentSaveHook
	Execute/P/Q/Z "DELETEINCLUDE \""+SIDAM_FILE_INCLUDE+"\""
	Execute/P/Q/Z "SetIgorOption poundUndefine=SIDAMshowProc"
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "BuildMenu \"All\""
End

Static Function/S mainMenuItem()
	//	"Restart" when the shift key is pressed
	return SelectString(GetKeyState(0) && 0x04, "Exit", "Restart") + " SIDAM"
End

Static Function mainMenuDo()
	GetLastUserMenuInfo
	int isRestart = !CmpStr(S_value, "Restart SIDAM")

	SIDAMExit()

	if (isRestart)
		sidam()
	endif
End